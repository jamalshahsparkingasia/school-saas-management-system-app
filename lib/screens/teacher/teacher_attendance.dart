import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/api_client.dart';
import '../../state/session.dart';
import '../../widgets/common.dart';

/// Take (or correct) the attendance register — the most interactive
/// screen in the teacher app.
///
/// It chains TWO requests:
///   1. on open:  GET /teacher/sections          → which registers exist
///   2. on pick:  GET /teacher/attendance?...    → the students in one
///                                                  section on one date
/// and one save: POST /teacher/attendance with every student's status.
///
/// The interesting state-management lesson here: the screen keeps the
/// user's un-saved choices in a plain map (`_statuses`) that sits NEXT TO
/// the loaded roster. The API tells us what is stored on the server; the
/// map tells us what the teacher wants it to become. Only "Save
/// attendance" reconciles the two.
class TeacherAttendanceScreen extends StatefulWidget {
  const TeacherAttendanceScreen({super.key});

  @override
  State<TeacherAttendanceScreen> createState() => _TeacherAttendanceScreenState();
}

class _TeacherAttendanceScreenState extends State<TeacherAttendanceScreen> {
  /// The four statuses the register understands, in display order.
  static const _statusOptions = ['present', 'absent', 'late', 'excused'];

  late Future<Map<String, dynamic>> _sectionsFuture;

  int? _sectionId; // which register is open (null = none picked yet)
  DateTime _date = DateTime.now(); // which day we are marking

  /// Null until a section is picked — that's how build() knows whether
  /// to show the "pick a section" hint or the student list.
  Future<Map<String, dynamic>>? _rosterFuture;

  /// The students of the loaded roster, kept OUTSIDE the FutureBuilder so
  /// the Save button (which lives outside it too) can see them.
  List<Map<String, dynamic>> _students = [];

  /// The teacher's picks: student id (as a String, ready for JSON) →
  /// status. Pre-filled from the server, then edited by tapping.
  final Map<String, String> _statuses = {};

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _sectionsFuture = _loadSections();
  }

  // ---------------------------------------------------------------- load

  Future<Map<String, dynamic>> _loadSections() async {
    final session = context.read<Session>();
    try {
      return await session.api.get('/teacher/sections');
    } catch (e) {
      session.handleAuthError(e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _loadRoster() async {
    final session = context.read<Session>();
    try {
      final data = await session.api.get('/teacher/attendance', query: {
        'section_id': '$_sectionId',
        'date': _dateString,
      });

      // Remember the roster and give every student a starting status:
      // whatever the server already has, else 'present' (the common case
      // — a teacher usually only taps the few who are NOT present).
      _students = [
        for (final s in (data['students'] as List<dynamic>? ?? []))
          s as Map<String, dynamic>
      ];
      _statuses.clear();
      for (final s in _students) {
        _statuses['${s['student_id']}'] = (s['status'] as String?) ?? 'present';
      }

      // Subtle but important: when this future completes, FutureBuilder
      // only rebuilds ITS OWN subtree. The Save button sits outside it
      // (in bottomNavigationBar), so we nudge the whole screen to
      // rebuild — otherwise the button would stay disabled.
      if (mounted) setState(() {});

      return data;
    } catch (e) {
      session.handleAuthError(e);
      rethrow;
    }
  }

  /// Reset local edits and fetch the roster for the current pick.
  /// Called from inside setState() whenever section or date changes.
  void _reloadRoster() {
    _students = [];
    _statuses.clear();
    _rosterFuture = _loadRoster();
  }

  // ---------------------------------------------------------------- date

  /// 'YYYY-MM-DD' — exactly the string format the API speaks, built by
  /// hand so we don't need any date-formatting package.
  String get _dateString {
    final d = _date;
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      // Registers can be corrected up to 60 days back, but never dated
      // in the future.
      firstDate: now.subtract(const Duration(days: 60)),
      lastDate: now,
    );
    if (picked == null) return; // user dismissed the picker

    setState(() {
      _date = picked;
      // Only refetch if a section is already open.
      if (_sectionId != null) _reloadRoster();
    });
  }

  // ---------------------------------------------------------------- save

  Future<void> _save() async {
    if (_sectionId == null || _students.isEmpty) return;

    setState(() => _saving = true); // disables the button immediately
    final session = context.read<Session>();

    try {
      final result = await session.api.post('/teacher/attendance', {
        'section_id': _sectionId,
        'date': _dateString,
        // The API wants {"<student_id>": {"status": "..."}} — our map
        // already keys by the id-as-string, so this is a direct reshape.
        'attendance': {
          for (final entry in _statuses.entries)
            entry.key: {'status': entry.value},
        },
      });

      if (!mounted) return; // screen may have been closed mid-request
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text((result['message'] as String?) ?? 'Attendance saved.'),
        ),
      );
    } on ApiException catch (e) {
      session.handleAuthError(e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } catch (e) {
      // Anything non-API (no network, etc.) still deserves feedback.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: ApiFutureView<Map<String, dynamic>>(
        future: _sectionsFuture,
        onRetry: () => setState(() => _sectionsFuture = _loadSections()),
        builder: (context, data) {
          final sections = data['sections'] as List<dynamic>? ?? [];

          return Column(
            children: [
              // ---- controls: which register, which day ----
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Column(
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: _sectionId,
                      decoration: const InputDecoration(
                        labelText: 'Class & section',
                        prefixIcon: Icon(Icons.groups_rounded),
                      ),
                      hint: const Text('Pick a class & section'),
                      items: [
                        for (final s in sections)
                          DropdownMenuItem(
                            value: ((s as Map<String, dynamic>)['id'] as num?)
                                ?.toInt(),
                            child: Text((s['label'] as String?) ?? 'Section'),
                          ),
                      ],
                      onChanged: (id) => setState(() {
                        _sectionId = id;
                        if (id != null) _reloadRoster();
                      }),
                    ),
                    const SizedBox(height: 10),
                    // The date "field" is really just a display + button:
                    // tapping anywhere on it opens the calendar.
                    InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Date',
                          prefixIcon: const Icon(Icons.today_rounded),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.edit_calendar_rounded),
                            onPressed: _pickDate,
                          ),
                        ),
                        child: Text(_dateString),
                      ),
                    ),
                  ],
                ),
              ),

              // ---- the register itself ----
              Expanded(
                child: _rosterFuture == null
                    ? const EmptyState(
                        icon: Icons.fact_check_outlined,
                        message:
                            'Pick a class & section above to load its register.',
                      )
                    : ApiFutureView<Map<String, dynamic>>(
                        future: _rosterFuture!,
                        onRetry: () =>
                            setState(() => _rosterFuture = _loadRoster()),
                        builder: (context, roster) {
                          final students =
                              roster['students'] as List<dynamic>? ?? [];
                          if (students.isEmpty) {
                            return const EmptyState(
                              icon: Icons.person_off_outlined,
                              message: 'No students in this section.',
                            );
                          }
                          return RefreshIndicator(
                            onRefresh: () async => setState(
                                () => _rosterFuture = _loadRoster()),
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              itemCount: students.length,
                              itemBuilder: (context, i) => _studentTile(
                                  context, students[i] as Map<String, dynamic>),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),

      // The save button lives in bottomNavigationBar so it is ALWAYS
      // visible — no scrolling to the bottom of a 30-student list.
      // SafeArea keeps it clear of home indicators on modern phones.
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton(
          // Disabled while saving (prevents double-taps → duplicate
          // POSTs) and until a roster with students is on screen.
          onPressed: (_saving || _students.isEmpty) ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Text('Save attendance'),
        ),
      ),
    );
  }

  /// One row of the register: name + roll number, then a segmented
  /// control with the four statuses.
  Widget _studentTile(BuildContext context, Map<String, dynamic> student) {
    final scheme = Theme.of(context).colorScheme;
    final key = '${student['student_id']}';
    final notes = student['notes'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    (student['full_name'] as String?) ?? 'Student',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  'Roll ${student['roll_number'] ?? '—'}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              // Stretch so the four segments share the row evenly.
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: [
                  for (final option in _statusOptions)
                    ButtonSegment(
                      value: option,
                      // 'present' → 'Present' — tiny inline capitalise.
                      label: Text(
                          '${option[0].toUpperCase()}${option.substring(1)}'),
                    ),
                ],
                // SegmentedButton works with a SET of selections; ours is
                // always exactly one status per student.
                selected: {_statuses[key] ?? 'present'},
                onSelectionChanged: (selection) =>
                    setState(() => _statuses[key] = selection.first),
                showSelectedIcon: false,
                // Compact styling so four labels fit on a phone screen.
                style: const ButtonStyle(
                  visualDensity: VisualDensity(horizontal: -3, vertical: -3),
                  textStyle: WidgetStatePropertyAll(
                    TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  padding: WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 6),
                  ),
                ),
              ),
            ),
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                notes,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/session.dart';
import '../../widgets/common.dart';

/// The teacher's homework hub — three jobs, three widgets, one file:
///
///   [TeacherHomeworkScreen]   list every assignment (the tab itself)
///   [_CreateAssignmentScreen] full-screen form to post a new one
///   [_SubmissionsScreen]      review + grade what students handed in
///
/// The two helper screens are private (leading `_`) because nothing
/// outside this file ever navigates to them directly — keeping them
/// private documents that fact and keeps the app's public surface small.

/// 'YYYY-MM-DD' — the one date format the API speaks. Built by hand so
/// we don't need a date-formatting package.
String _ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

// =========================================================== list screen

class TeacherHomeworkScreen extends StatefulWidget {
  const TeacherHomeworkScreen({super.key});

  @override
  State<TeacherHomeworkScreen> createState() => _TeacherHomeworkScreenState();
}

class _TeacherHomeworkScreenState extends State<TeacherHomeworkScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final session = context.read<Session>();
    try {
      return await session.api.get('/teacher/assignments');
    } catch (e) {
      session.handleAuthError(e); // 401 → login screen
      rethrow; // everything else → retry view
    }
  }

  /// Push the create form and wait for it to close. It pops with the
  /// server's success message (a String) when an assignment was created,
  /// or null when the teacher just backed out — so "did anything change?"
  /// is simply "is the result non-null?".
  Future<void> _openCreate() async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const _CreateAssignmentScreen(),
        fullscreenDialog: true, // slides up + shows an X, like "compose"
      ),
    );

    if (message != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      setState(() => _future = _load()); // show the new assignment
    }
  }

  Future<void> _openSubmissions(Map<String, dynamic> assignment) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _SubmissionsScreen(
          assignmentId: ((assignment['id'] as num?) ?? 0).toInt(),
        ),
      ),
    );
    // Grading may have changed statuses/counts — refresh on the way back.
    if (mounted) setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Homework'),
        actions: [
          IconButton(
            tooltip: 'New assignment',
            icon: const Icon(Icons.add),
            onPressed: _openCreate,
          ),
        ],
      ),
      body: ApiFutureView<Map<String, dynamic>>(
        future: _future,
        onRetry: () => setState(() => _future = _load()),
        builder: (context, data) {
          final assignments = data['assignments'] as List<dynamic>? ?? [];

          return RefreshIndicator(
            onRefresh: () async => setState(() => _future = _load()),
            child: assignments.isEmpty
                // EmptyState inside a ListView so pull-to-refresh still
                // works when there is nothing to show.
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 80),
                      EmptyState(
                        icon: Icons.menu_book_outlined,
                        message: 'No assignments yet.\nTap + to create the first one.',
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    itemCount: assignments.length,
                    itemBuilder: (context, i) => _assignmentCard(
                        context, assignments[i] as Map<String, dynamic>),
                  ),
          );
        },
      ),
    );
  }

  /// One assignment as a floating card: subject-tinted icon badge, bold
  /// title with its StatusChip, then the due-date/marks meta row and a
  /// "handed in" counter pill (the tap target's "why open me").
  Widget _assignmentCard(BuildContext context, Map<String, dynamic> a) {
    final scheme = Theme.of(context).colorScheme;
    final subject = (a['subject'] as String?) ?? '';

    // `class` is a perfectly fine JSON key, even though it is a reserved
    // word in Dart — map access with a string is unaffected.
    final target = [
      if (a['class'] != null) '${a['class']}',
      '${a['section'] ?? 'All sections'}',
      if (subject.isNotEmpty) subject,
    ].join(' · ');

    return SoftCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      onTap: () => _openSubmissions(a),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(
            Icons.menu_book_rounded,
            // Same colour as the subject gets everywhere else in the app.
            color: colorFor(
                subject.isEmpty ? (a['title'] as String?) ?? 'Assignment' : subject),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (a['title'] as String?) ?? 'Assignment',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusChip((a['status'] as String?) ?? 'open'),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  target,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7686),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.event,
                        size: 15, color: Color(0xFF8A94A6)),
                    const SizedBox(width: 4),
                    Text(
                      '${a['due_date'] ?? 'No due date'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7686),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (a['max_marks'] != null) ...[
                      const SizedBox(width: 12),
                      const Icon(Icons.grade_outlined,
                          size: 15, color: Color(0xFF8A94A6)),
                      const SizedBox(width: 4),
                      Text(
                        '${a['max_marks']} marks',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7686),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const Spacer(),
                    // Submission-count pill in the brand tint.
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${a['submissions_count'] ?? 0} handed in',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ========================================================= create screen

/// Full-screen "compose" form for a new assignment.
///
/// It loads its dropdown options from `/teacher/assignments/meta` first
/// (classes with their sections, plus subjects) — the same ApiFutureView
/// pattern as every read-only screen, just with a form in the builder.
/// The fields are grouped into two floating cards ("Basics" for the
/// what/who, "Details" for the extras) so the form scans in two beats.
class _CreateAssignmentScreen extends StatefulWidget {
  const _CreateAssignmentScreen();

  @override
  State<_CreateAssignmentScreen> createState() =>
      _CreateAssignmentScreenState();
}

class _CreateAssignmentScreenState extends State<_CreateAssignmentScreen> {
  /// Sentinel meaning "the whole class, every section". A real section is
  /// a name like "A"; using an impossible name for the special choice
  /// lets one String field cover both cases.
  static const _allSections = '__all__';

  late Future<Map<String, dynamic>> _metaFuture;

  final _title = TextEditingController();
  final _instructions = TextEditingController();
  final _maxMarks = TextEditingController();

  int? _classId;
  String _section = _allSections;
  int? _subjectId;
  DateTime? _dueDate; // optional — null means "no due date"
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _metaFuture = _loadMeta();
  }

  @override
  void dispose() {
    // Controllers hold native resources — always release them.
    _title.dispose();
    _instructions.dispose();
    _maxMarks.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _loadMeta() async {
    final session = context.read<Session>();
    try {
      return await session.api.get('/teacher/assignments/meta');
    } catch (e) {
      session.handleAuthError(e);
      rethrow;
    }
  }

  /// The section choices depend on which class is picked — walk the meta
  /// list and return that class's sections (or nothing before a pick).
  List<String> _sectionsForClass(List<dynamic> classes) {
    for (final c in classes) {
      final map = c as Map<String, dynamic>;
      if ((map['id'] as num?)?.toInt() == _classId) {
        return [for (final s in (map['sections'] as List<dynamic>? ?? [])) '$s'];
      }
    }
    return const [];
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: now, // homework can't be due in the past
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  Future<void> _submit() async {
    // Cheap client-side checks first — the server validates too, but
    // catching the obvious mistakes locally is instant and offline-safe.
    final title = _title.text.trim();
    if (title.isEmpty) return _showError('Please enter a title.');
    if (_classId == null) return _showError('Please pick a class.');
    if (_subjectId == null) return _showError('Please pick a subject.');

    num? maxMarks;
    final marksText = _maxMarks.text.trim();
    if (marksText.isNotEmpty) {
      maxMarks = num.tryParse(marksText);
      if (maxMarks == null || maxMarks <= 0) {
        return _showError('Max marks must be a positive number.');
      }
    }

    setState(() => _saving = true);
    final session = context.read<Session>();

    try {
      final result = await session.api.post('/teacher/assignments', {
        'title': title,
        'school_class_id': _classId,
        'subject_id': _subjectId,
        // null = "all sections" — the sentinel never leaves the app.
        'section': _section == _allSections ? null : _section,
        'instructions': _instructions.text.trim().isEmpty
            ? null
            : _instructions.text.trim(),
        'due_date': _dueDate == null ? null : _ymd(_dueDate!),
        'max_marks': maxMarks,
      });

      if (!mounted) return;
      // Pop WITH the success message — the list screen shows the
      // SnackBar and refreshes (this screen is about to disappear, so it
      // can't show its own).
      Navigator.of(context)
          .pop((result['message'] as String?) ?? 'Assignment created.');
    } catch (e) {
      session.handleAuthError(e);
      if (!mounted) return;
      setState(() => _saving = false);
      _showError(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New assignment')),
      body: ApiFutureView<Map<String, dynamic>>(
        future: _metaFuture,
        onRetry: () => setState(() => _metaFuture = _loadMeta()),
        builder: (context, meta) {
          final classes = meta['classes'] as List<dynamic>? ?? [];
          final subjects = meta['subjects'] as List<dynamic>? ?? [];
          final sections = _sectionsForClass(classes);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              // ---- what & who ----
              const SectionHeader('Basics'),
              SoftCard(
                child: Column(
                  children: [
                    TextField(
                      controller: _title,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        prefixIcon: Icon(Icons.title_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),

                    DropdownButtonFormField<int>(
                      initialValue: _classId,
                      decoration: const InputDecoration(
                        labelText: 'Class',
                        prefixIcon: Icon(Icons.school_rounded),
                      ),
                      hint: const Text('Pick a class'),
                      items: [
                        for (final c in classes)
                          DropdownMenuItem(
                            value: ((c as Map<String, dynamic>)['id'] as num?)
                                ?.toInt(),
                            child: Text((c['name'] as String?) ?? 'Class'),
                          ),
                      ],
                      onChanged: (id) => setState(() {
                        _classId = id;
                        // A different class has different sections — reset
                        // the pick so a stale "Section C" can't be
                        // submitted.
                        _section = _allSections;
                      }),
                    ),
                    const SizedBox(height: 14),

                    DropdownButtonFormField<String>(
                      // Changing the key forces Flutter to rebuild this
                      // field from scratch when the class changes,
                      // discarding the old internal selection.
                      key: ValueKey('sections-$_classId'),
                      initialValue: _section,
                      decoration: const InputDecoration(
                        labelText: 'Section',
                        prefixIcon: Icon(Icons.grid_view_rounded),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: _allSections,
                          child: Text('All sections'),
                        ),
                        for (final s in sections)
                          DropdownMenuItem(value: s, child: Text('Section $s')),
                      ],
                      // Disabled (greyed out) until a class is picked.
                      onChanged: _classId == null
                          ? null
                          : (v) => setState(() => _section = v ?? _allSections),
                    ),
                    const SizedBox(height: 14),

                    DropdownButtonFormField<int>(
                      initialValue: _subjectId,
                      decoration: const InputDecoration(
                        labelText: 'Subject',
                        prefixIcon: Icon(Icons.menu_book_rounded),
                      ),
                      hint: const Text('Pick a subject'),
                      items: [
                        for (final s in subjects)
                          DropdownMenuItem(
                            value: ((s as Map<String, dynamic>)['id'] as num?)
                                ?.toInt(),
                            child: Text((s['name'] as String?) ?? 'Subject'),
                          ),
                      ],
                      onChanged: (id) => setState(() => _subjectId = id),
                    ),
                  ],
                ),
              ),

              // ---- the extras ----
              const SectionHeader('Details'),
              SoftCard(
                child: Column(
                  children: [
                    TextField(
                      controller: _instructions,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Instructions (optional)',
                        alignLabelWithHint: true, // label sits at the top-left
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Due date: a tappable display, not a text field —
                    // dates are picked, never typed.
                    InkWell(
                      onTap: _pickDueDate,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Due date (optional)',
                          prefixIcon: const Icon(Icons.event),
                          suffixIcon: _dueDate == null
                              ? const Icon(Icons.edit_calendar_rounded)
                              : IconButton(
                                  tooltip: 'Clear due date',
                                  icon: const Icon(Icons.close),
                                  onPressed: () =>
                                      setState(() => _dueDate = null),
                                ),
                        ),
                        child: Text(
                            _dueDate == null ? 'No due date' : _ymd(_dueDate!)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: _maxMarks,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Max marks (optional)',
                        prefixIcon: Icon(Icons.grade_outlined),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      // Same always-visible white save bar as the attendance register.
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: softShadow(context),
        ),
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const Text('Create assignment'),
          ),
        ),
      ),
    );
  }
}

// ==================================================== submissions screen

/// Everything students handed in for ONE assignment, with grading.
class _SubmissionsScreen extends StatefulWidget {
  const _SubmissionsScreen({required this.assignmentId});

  final int assignmentId;

  @override
  State<_SubmissionsScreen> createState() => _SubmissionsScreenState();
}

class _SubmissionsScreenState extends State<_SubmissionsScreen> {
  late Future<Map<String, dynamic>> _future;

  /// Kept outside the FutureBuilder because the grade dialog (opened
  /// later, from a button) needs it to validate the marks range.
  num? _maxMarks;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final session = context.read<Session>();
    try {
      final data = await session.api
          .get('/teacher/assignments/${widget.assignmentId}/submissions');
      _maxMarks =
          (data['assignment'] as Map<String, dynamic>?)?['max_marks'] as num?;
      return data;
    } catch (e) {
      session.handleAuthError(e);
      rethrow;
    }
  }

  /// Open the grading dialog for one submission. The dialog manages its
  /// own little state (error text, saving spinner) via [StatefulBuilder]
  /// — a lightweight alternative to a whole StatefulWidget when the
  /// state never outlives the dialog.
  Future<void> _openGradeDialog(Map<String, dynamic> submission) async {
    final session = context.read<Session>();
    // Pre-fill with the existing grade so "edit" starts from what's there.
    final marksCtrl =
        TextEditingController(text: submission['marks']?.toString() ?? '');
    final feedbackCtrl =
        TextEditingController(text: (submission['feedback'] as String?) ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        String? marksError;
        var saving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text('${submission['student'] ?? 'Submission'}'),
            content: Column(
              mainAxisSize: MainAxisSize.min, // hug content, don't stretch
              children: [
                TextField(
                  controller: marksCtrl,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: _maxMarks == null
                        ? 'Marks'
                        : 'Marks (out of $_maxMarks)',
                    errorText: marksError, // inline validation message
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: feedbackCtrl,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Feedback (optional)',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed:
                    saving ? null : () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        // Validate before touching the network.
                        final marks = num.tryParse(marksCtrl.text.trim());
                        final max = _maxMarks;
                        if (marks == null ||
                            marks < 0 ||
                            (max != null && marks > max)) {
                          setDialogState(() => marksError = max == null
                              ? 'Enter marks (0 or more).'
                              : 'Enter marks between 0 and $max.');
                          return;
                        }

                        setDialogState(() {
                          marksError = null;
                          saving = true;
                        });

                        try {
                          await session.api.post(
                            '/teacher/submissions/${submission['id']}/grade',
                            {
                              'marks': marks,
                              'feedback': feedbackCtrl.text.trim(),
                            },
                          );
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, true);
                          }
                        } catch (e) {
                          session.handleAuthError(e);
                          if (!dialogContext.mounted) return;
                          setDialogState(() => saving = false);
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: Text('$e'),
                              backgroundColor:
                                  Theme.of(dialogContext).colorScheme.error,
                            ),
                          );
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save grade'),
              ),
            ],
          ),
        );
      },
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Grade saved.')));
      setState(() => _future = _load()); // pull the fresh marks/status
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submissions')),
      body: ApiFutureView<Map<String, dynamic>>(
        future: _future,
        onRetry: () => setState(() => _future = _load()),
        builder: (context, data) {
          final assignment = data['assignment'] as Map<String, dynamic>? ?? {};
          final submissions = data['submissions'] as List<dynamic>? ?? [];
          final subject = (assignment['subject'] as String?) ?? '';

          return RefreshIndicator(
            onRefresh: () async => setState(() => _future = _load()),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                // What are we grading? A small reminder card.
                SoftCard(
                  child: Row(
                    children: [
                      IconBadge(
                        Icons.menu_book_rounded,
                        color: colorFor(subject.isEmpty
                            ? (assignment['title'] as String?) ?? 'Assignment'
                            : subject),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (assignment['title'] as String?) ?? 'Assignment',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              assignment['max_marks'] == null
                                  ? 'No maximum marks set'
                                  : 'Out of ${assignment['max_marks']} marks',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7686),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SectionHeader('Submissions (${submissions.length})'),
                if (submissions.isEmpty)
                  const EmptyState(
                    icon: Icons.inbox_outlined,
                    message: 'Nothing handed in yet.',
                  )
                else
                  ...submissions.map((s) =>
                      _submissionCard(context, s as Map<String, dynamic>)),
              ],
            ),
          );
        },
      ),
    );
  }

  /// One submission: student + status up top, the handed-in text in a
  /// grey inset box, then the big marks (once graded) beside the Grade
  /// button.
  Widget _submissionCard(BuildContext context, Map<String, dynamic> s) {
    final content = s['content'] as String?;
    final feedback = s['feedback'] as String?;
    final graded = s['marks'] != null;

    return SoftCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (s['student'] as String?) ?? 'Student',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusChip((s['status'] as String?) ?? 'submitted'),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'Roll ${s['roll_number'] ?? '—'} · submitted ${s['submitted_at'] ?? '—'}',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7686),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (content != null && content.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6F9), // grey-50 inset
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(content),
            ),
          ],
          if (graded && feedback != null && feedback.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              feedback,
              style: const TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 12.5,
                color: Color(0xFF6B7686),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                // Big marks readout once graded ("18 / 20"); empty box
                // keeps the Grade button pinned right either way.
                child: graded
                    ? Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${s['marks']}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (_maxMarks != null)
                              TextSpan(
                                text: ' / $_maxMarks',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6B7686),
                                ),
                              ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              FilledButton.tonalIcon(
                // The global FilledButton theme is sized for full-width
                // bars — shrink this one back to an inline action.
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onPressed: () => _openGradeDialog(s),
                icon: const Icon(Icons.grade_outlined, size: 18),
                label: Text(graded ? 'Edit grade' : 'Grade'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

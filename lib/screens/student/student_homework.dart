import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/api_client.dart';
import '../../state/session.dart';
import '../../widgets/common.dart';

// The red used app-wide for "needs attention" (same as StatusChip's red).
const _dangerRed = Color(0xFFB91C1C);

/// The homework tab: every assignment for the student's class, with the
/// state of THEIR submission on each card. Tapping a card opens a
/// bottom sheet with the full instructions — and, if the work hasn't
/// been graded yet, a box to type and submit an answer.
class StudentHomeworkScreen extends StatefulWidget {
  const StudentHomeworkScreen({super.key});

  @override
  State<StudentHomeworkScreen> createState() => _StudentHomeworkScreenState();
}

class _StudentHomeworkScreenState extends State<StudentHomeworkScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final session = context.read<Session>();
    try {
      return await session.api.get('/student/homework');
    } catch (e) {
      session.handleAuthError(e); // 401 → back to login
      rethrow; // anything else → ApiFutureView's retry view
    }
  }

  /// Opens the detail sheet for one assignment.
  ///
  /// `isScrollControlled` lets the sheet grow taller than half the
  /// screen (needed once the keyboard appears for the answer box), and
  /// `useSafeArea` keeps it out from under notches and status bars.
  void _openDetail(Map<String, dynamic> homework) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _HomeworkDetailSheet(
        homework: homework,
        // After a successful submit the LIST is stale (the card still
        // says "pending"), so the sheet asks us to reload it.
        onSubmitted: () => setState(() => _future = _load()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Homework')),
      body: ApiFutureView<Map<String, dynamic>>(
        future: _future,
        onRetry: () => setState(() => _future = _load()),
        builder: (context, data) {
          final homework = data['homework'] as List<dynamic>? ?? [];

          if (homework.isEmpty) {
            return const EmptyState(
              icon: Icons.menu_book_outlined,
              message: 'No homework assigned yet. Lucky you!',
            );
          }

          return RefreshIndicator(
            onRefresh: () async => setState(() => _future = _load()),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: homework.length,
              itemBuilder: (context, i) =>
                  _homeworkCard(context, homework[i] as Map<String, dynamic>),
            ),
          );
        },
      ),
    );
  }

  Widget _homeworkCard(BuildContext context, Map<String, dynamic> hw) {
    final scheme = Theme.of(context).colorScheme;
    final submission = hw['my_submission'] as Map<String, dynamic>?;

    // "Overdue" only matters if nothing was handed in — a submitted
    // assignment past its due date is the teacher's problem, not ours.
    final missedDeadline = hw['is_overdue'] == true && submission == null;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => _openDetail(hw),
        title: Text(
          (hw['title'] as String?) ?? 'Homework',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${hw['subject'] ?? ''} · ${hw['teacher'] ?? ''}'),
            Text(
              'Due ${hw['due_date'] ?? '-'}',
              style: TextStyle(
                color: missedDeadline ? _dangerRed : scheme.onSurfaceVariant,
                fontWeight: missedDeadline ? FontWeight.w700 : null,
              ),
            ),
          ],
        ),
        isThreeLine: true,
        // The chip shows the SUBMISSION's status — 'pending' until the
        // student hands something in.
        trailing: StatusChip((submission?['status'] as String?) ?? 'pending'),
      ),
    );
  }
}

/// The bottom sheet for one assignment.
///
/// A separate StatefulWidget (instead of a StatefulBuilder inline)
/// because it owns real state: the answer TextField's controller and a
/// "submitting…" flag. Giving it its own class keeps that lifecycle
/// (dispose the controller!) tidy and testable.
class _HomeworkDetailSheet extends StatefulWidget {
  const _HomeworkDetailSheet({
    required this.homework,
    required this.onSubmitted,
  });

  final Map<String, dynamic> homework;
  final VoidCallback onSubmitted;

  @override
  State<_HomeworkDetailSheet> createState() => _HomeworkDetailSheetState();
}

class _HomeworkDetailSheetState extends State<_HomeworkDetailSheet> {
  late final TextEditingController _answer;
  bool _busy = false;

  Map<String, dynamic>? get _submission =>
      widget.homework['my_submission'] as Map<String, dynamic>?;

  /// Once marks exist (or the status says so) the work is graded and
  /// locked — re-submitting after grading would make no sense.
  bool get _isGraded =>
      (_submission?['status'] as String?) == 'graded' ||
      _submission?['marks'] != null;

  @override
  void initState() {
    super.initState();
    // Pre-fill with the previous answer so "submit again before it's
    // graded" means EDITING, not retyping from scratch.
    _answer =
        TextEditingController(text: (_submission?['content'] as String?) ?? '');
  }

  @override
  void dispose() {
    _answer.dispose(); // controllers hold native resources — release them
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _answer.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write your answer first.')),
      );
      return;
    }

    setState(() => _busy = true);
    final session = context.read<Session>();

    try {
      await session.api.post(
        '/student/homework/${widget.homework['id']}/submit',
        {'content': text},
      );

      // `mounted` guard: the user may have dismissed the sheet while
      // the request was in flight — using a dead context crashes.
      if (!mounted) return;

      // Show the toast BEFORE popping: ScaffoldMessenger lives above
      // the sheet, so the SnackBar survives the pop.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Homework submitted.')),
      );
      Navigator.of(context).pop();
      widget.onSubmitted(); // tell the list screen to reload
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: _dangerRed),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not submit. Check your connection.'),
          backgroundColor: _dangerRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hw = widget.homework;
    final submission = _submission;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      // Lift the sheet above the on-screen keyboard: viewInsets.bottom
      // IS the keyboard height (0 when it's hidden).
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min, // hug content, don't fill screen
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (hw['title'] as String?) ?? 'Homework',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              '${hw['subject'] ?? ''} · ${hw['teacher'] ?? ''} · ${hw['class'] ?? ''}',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                StatusChip((submission?['status'] as String?) ?? 'pending'),
                const SizedBox(width: 8),
                Text(
                  'Due ${hw['due_date'] ?? '-'}'
                  '${hw['max_marks'] != null ? ' · Max ${hw['max_marks']} marks' : ''}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),

            const SectionHeader('Instructions'),
            Text((hw['instructions'] as String?) ?? 'No instructions given.'),

            // Only present once something was handed in.
            if (submission != null) ...[
              const SectionHeader('My submission'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((submission['content'] as String?) ?? ''),
                      const SizedBox(height: 8),
                      Text(
                        'Submitted ${submission['submitted_at'] ?? '-'}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      if (submission['marks'] != null)
                        Text(
                          'Marks: ${submission['marks']}'
                          '${hw['max_marks'] != null ? ' / ${hw['max_marks']}' : ''}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      if ((submission['feedback'] as String?)?.isNotEmpty ==
                          true) ...[
                        const SizedBox(height: 6),
                        Text('Teacher feedback: ${submission['feedback']}'),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            // The answer box — hidden once the work is graded.
            if (!_isGraded) ...[
              SectionHeader(
                  submission == null ? 'Your answer' : 'Update your answer'),
              TextField(
                controller: _answer,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Type your answer here…',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _busy ? null : _submit, // disable while in flight
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Text('Submit homework'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

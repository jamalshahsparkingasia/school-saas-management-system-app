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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
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
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              itemCount: homework.length,
              itemBuilder: (context, i) =>
                  _homeworkCard(context, homework[i] as Map<String, dynamic>),
            ),
          );
        },
      ),
    );
  }

  /// One assignment as a SoftCard: subject-coloured badge on the left,
  /// title + meta in the middle, the submission's status on the right.
  Widget _homeworkCard(BuildContext context, Map<String, dynamic> hw) {
    final submission = hw['my_submission'] as Map<String, dynamic>?;
    final subject = (hw['subject'] as String?) ?? '';
    final tint = colorFor(subject.isEmpty ? 'Homework' : subject);

    // "Overdue" only matters if nothing was handed in — a submitted
    // assignment past its due date is the teacher's problem, not ours.
    final missedDeadline = hw['is_overdue'] == true && submission == null;

    return SoftCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      onTap: () => _openDetail(hw),
      child: Row(
        children: [
          IconBadge(Icons.menu_book_rounded, color: tint),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (hw['title'] as String?) ?? 'Homework',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${hw['subject'] ?? ''} · ${hw['teacher'] ?? ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7686),
                  ),
                ),
                const SizedBox(height: 4),
                // Due date with a tiny calendar glyph — turns red and
                // bold once the deadline is missed.
                Row(
                  children: [
                    Icon(
                      Icons.event_rounded,
                      size: 13,
                      color: missedDeadline
                          ? _dangerRed
                          : const Color(0xFF8A94A6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Due ${hw['due_date'] ?? '-'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: missedDeadline
                            ? _dangerRed
                            : const Color(0xFF6B7686),
                        fontWeight: missedDeadline
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // The chip shows the SUBMISSION's status — 'pending' until the
          // student hands something in.
          StatusChip((submission?['status'] as String?) ?? 'pending'),
        ],
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
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min, // hug content, don't fill screen
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The drag handle every bottom sheet in the app starts with.
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),

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
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7686),
              ),
            ),
            const SizedBox(height: 10),
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
            // Instructions live in a quiet tinted box so they read as
            // "the teacher's words", separate from the sheet chrome.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                (hw['instructions'] as String?) ?? 'No instructions given.',
                style: const TextStyle(height: 1.5),
              ),
            ),

            // Only present once something was handed in.
            if (submission != null) ...[
              const SectionHeader('My submission'),
              // Primary-tinted box: "this part is YOURS".
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((submission['content'] as String?) ?? ''),
                    const SizedBox(height: 8),
                    Text(
                      'Submitted ${submission['submitted_at'] ?? '-'}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7686),
                      ),
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/session.dart';
import '../../widgets/common.dart';

/// The lessons library, grouped by subject. Each subject expands to its
/// lessons; tapping a lesson opens a bottom sheet with the full notes.
/// Reached from the "More" tab.
class StudentLessonsScreen extends StatefulWidget {
  const StudentLessonsScreen({super.key});

  @override
  State<StudentLessonsScreen> createState() => _StudentLessonsScreenState();
}

class _StudentLessonsScreenState extends State<StudentLessonsScreen> {
  // Future held in State — rebuilds must never re-fire the request.
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final session = context.read<Session>();
    try {
      return await session.api.get('/student/lessons');
    } catch (e) {
      session.handleAuthError(e); // 401 → back to login
      rethrow;
    }
  }

  /// The lesson reader. Read-only content, so a plain builder function
  /// is enough — no state to manage (compare with the homework sheet,
  /// which needs a whole StatefulWidget for its answer box).
  void _openLesson(Map<String, dynamic> lesson, String subject) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true, // lesson notes can be long
      useSafeArea: true,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min, // hug content, don't fill screen
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (lesson['title'] as String?) ?? 'Lesson',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  subject,
                  if (lesson['unit'] != null) 'Unit ${lesson['unit']}',
                  if (lesson['topic'] != null) '${lesson['topic']}',
                ].join(' · '),
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              Text(
                (lesson['lesson_date'] as String?) ?? '',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const Divider(height: 28),
              Text(
                (lesson['content'] as String?) ??
                    'No notes for this lesson yet.',
                // A touch of line height makes long notes readable.
                style: const TextStyle(height: 1.5),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lessons')),
      body: ApiFutureView<Map<String, dynamic>>(
        future: _future,
        onRetry: () => setState(() => _future = _load()),
        builder: (context, data) {
          final subjects = data['subjects'] as List<dynamic>? ?? [];

          if (subjects.isEmpty) {
            return const EmptyState(
              icon: Icons.auto_stories_outlined,
              message: 'No lessons published yet.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async => setState(() => _future = _load()),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: subjects.length,
              itemBuilder: (context, i) =>
                  _subjectGroup(context, subjects[i] as Map<String, dynamic>),
            ),
          );
        },
      ),
    );
  }

  /// One subject with its lessons folded inside an ExpansionTile.
  Widget _subjectGroup(BuildContext context, Map<String, dynamic> group) {
    final scheme = Theme.of(context).colorScheme;
    final subject = (group['subject'] as String?) ?? 'Subject';
    final lessons = group['lessons'] as List<dynamic>? ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      // Without clipping, the expanded tile's ink would poke out past
      // the card's rounded corners.
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        // ExpansionTile paints its own top/bottom dividers when open;
        // inside a Card they look like glitches, so remove them.
        shape: const Border(),
        collapsedShape: const Border(),
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Text(
            subject.isNotEmpty ? subject[0].toUpperCase() : '?',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: scheme.onPrimaryContainer,
            ),
          ),
        ),
        title: Text(subject, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
            '${lessons.length} lesson${lessons.length == 1 ? '' : 's'}'),
        children: [
          for (final l in lessons)
            _lessonTile(context, l as Map<String, dynamic>, subject),
        ],
      ),
    );
  }

  Widget _lessonTile(
      BuildContext context, Map<String, dynamic> lesson, String subject) {
    return ListTile(
      onTap: () => _openLesson(lesson, subject),
      leading: const Icon(Icons.article_outlined),
      title: Text((lesson['title'] as String?) ?? 'Lesson'),
      subtitle: Text([
        if (lesson['topic'] != null) '${lesson['topic']}',
        if (lesson['lesson_date'] != null) '${lesson['lesson_date']}',
      ].join(' · ')),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SingleChildScrollView(
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
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7686),
                ),
              ),
              Text(
                (lesson['lesson_date'] as String?) ?? '',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7686),
                ),
              ),
              const SizedBox(height: 18),

              // The notes live in a quiet tinted box so they read as
              // "the material", separate from the sheet chrome.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  (lesson['content'] as String?) ??
                      'No notes for this lesson yet.',
                  // A touch of line height makes long notes readable.
                  style: const TextStyle(height: 1.5),
                ),
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
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              itemCount: subjects.length,
              itemBuilder: (context, i) =>
                  _subjectGroup(context, subjects[i] as Map<String, dynamic>),
            ),
          );
        },
      ),
    );
  }

  /// One subject as a SoftCard with its lessons folded inside an
  /// ExpansionTile, anchored by the subject's stable colour.
  Widget _subjectGroup(BuildContext context, Map<String, dynamic> group) {
    final subject = (group['subject'] as String?) ?? 'Subject';
    final lessons = group['lessons'] as List<dynamic>? ?? [];

    return SoftCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.zero,
      // Without clipping, the expanded tile's ink would poke out past
      // the card's rounded corners.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ExpansionTile(
          // ExpansionTile paints its own top/bottom dividers when open;
          // inside a card they look like glitches, so remove them.
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: IconBadge(Icons.auto_stories_rounded,
              color: colorFor(subject)),
          title: Text(
            subject,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          subtitle: Text(
            '${lessons.length} lesson${lessons.length == 1 ? '' : 's'}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7686),
            ),
          ),
          children: [
            for (final l in lessons)
              _lessonTile(context, l as Map<String, dynamic>, subject),
          ],
        ),
      ),
    );
  }

  Widget _lessonTile(
      BuildContext context, Map<String, dynamic> lesson, String subject) {
    return ListTile(
      onTap: () => _openLesson(lesson, subject),
      leading: const Icon(Icons.article_outlined, color: Color(0xFF8A94A6)),
      title: Text((lesson['title'] as String?) ?? 'Lesson'),
      subtitle: Text([
        if (lesson['topic'] != null) '${lesson['topic']}',
        if (lesson['unit'] != null) 'Unit ${lesson['unit']}',
        if (lesson['lesson_date'] != null) '${lesson['lesson_date']}',
      ].join(' · ')),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFFB6BEC9)),
    );
  }
}

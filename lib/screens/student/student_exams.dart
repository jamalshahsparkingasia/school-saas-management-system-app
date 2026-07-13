import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/session.dart';
import '../../widgets/common.dart';

/// The exam schedule, split into what's coming up and what's already
/// happened. Reached from the "More" tab.
class StudentExamsScreen extends StatefulWidget {
  const StudentExamsScreen({super.key});

  @override
  State<StudentExamsScreen> createState() => _StudentExamsScreenState();
}

class _StudentExamsScreenState extends State<StudentExamsScreen> {
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
      return await session.api.get('/student/exams');
    } catch (e) {
      session.handleAuthError(e); // 401 → back to login
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exams')),
      body: ApiFutureView<Map<String, dynamic>>(
        future: _future,
        onRetry: () => setState(() => _future = _load()),
        builder: (context, data) {
          final upcoming = data['upcoming'] as List<dynamic>? ?? [];
          final past = data['past'] as List<dynamic>? ?? [];

          // Nothing scheduled at all → one friendly empty screen
          // instead of two hollow section headers.
          if (upcoming.isEmpty && past.isEmpty) {
            return const EmptyState(
              icon: Icons.quiz_outlined,
              message: 'No exams scheduled yet.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async => setState(() => _future = _load()),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                if (upcoming.isNotEmpty) ...[
                  const SectionHeader('Upcoming'),
                  ...upcoming.map((e) => _examCard(
                      context, e as Map<String, dynamic>,
                      upcoming: true)),
                ],
                if (past.isNotEmpty) ...[
                  const SectionHeader('Past'),
                  ...past.map((e) => _examCard(
                      context, e as Map<String, dynamic>,
                      upcoming: false)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  /// One exam as a SoftCard: subject-coloured badge (calendar for
  /// what's ahead, history for what's behind), name + meta on the left,
  /// date + details + status on the right.
  Widget _examCard(BuildContext context, Map<String, dynamic> exam,
      {required bool upcoming}) {
    final subject = (exam['subject'] as String?) ?? '';
    final status = (exam['status'] as String?) ?? '';
    final tint = colorFor(subject.isEmpty ? 'Exam' : subject);

    return SoftCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // The icon (not the colour) tells past from future — the
          // colour always belongs to the subject.
          IconBadge(
            upcoming ? Icons.event_outlined : Icons.history,
            color: tint,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (exam['name'] as String?) ?? 'Exam',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (subject.isNotEmpty) subject,
                    if (exam['term'] != null) '${exam['term']}',
                  ].join(' · '),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7686),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                (exam['scheduled_at'] as String?) ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  if (exam['duration'] != null) '${exam['duration']} min',
                  if (exam['max_marks'] != null)
                    'Max ${exam['max_marks']}',
                ].join(' · '),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7686),
                ),
              ),
              if (status.isNotEmpty) ...[
                const SizedBox(height: 4),
                StatusChip(status),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

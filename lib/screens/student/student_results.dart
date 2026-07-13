import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/session.dart';
import '../../widgets/common.dart';

/// Every published result across all exams and terms — reached from
/// the "More" tab (it didn't earn a bottom-bar slot of its own).
class StudentResultsScreen extends StatefulWidget {
  const StudentResultsScreen({super.key});

  @override
  State<StudentResultsScreen> createState() => _StudentResultsScreenState();
}

class _StudentResultsScreenState extends State<StudentResultsScreen> {
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
      return await session.api.get('/student/results');
    } catch (e) {
      session.handleAuthError(e); // 401 → back to login
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Results')),
      body: ApiFutureView<Map<String, dynamic>>(
        future: _future,
        onRetry: () => setState(() => _future = _load()),
        builder: (context, data) {
          final results = data['results'] as List<dynamic>? ?? [];

          if (results.isEmpty) {
            return const EmptyState(
              icon: Icons.grade_outlined,
              message: 'No results published yet.\nCheck back after exams.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async => setState(() => _future = _load()),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              itemCount: results.length,
              itemBuilder: (context, i) =>
                  _resultCard(context, results[i] as Map<String, dynamic>),
            ),
          );
        },
      ),
    );
  }

  /// One result as a SoftCard: subject-coloured badge, exam + subject,
  /// and the grade as a big tinted pill over the raw marks.
  Widget _resultCard(BuildContext context, Map<String, dynamic> result) {
    final subject = (result['subject'] as String?) ?? '';
    final isAbsent = result['is_absent'] == true;
    final tint = colorFor(subject.isEmpty ? 'Result' : subject);

    return SoftCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconBadge(Icons.workspace_premium_outlined, color: tint),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${result['exam'] ?? 'Exam'} — $subject',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${result['term'] ?? ''} · ${result['date'] ?? ''}',
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
          // Absent students have no marks to show — the chip says it all.
          if (isAbsent)
            const StatusChip('absent')
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // The grade is the headline — a big pill tinted in the
                // subject's colour, like StatusChip but louder.
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    (result['grade'] as String?) ?? '-',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: tint,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${result['marks_obtained'] ?? '-'} / ${result['max_marks'] ?? '-'}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7686),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

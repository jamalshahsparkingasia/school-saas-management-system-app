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
              padding: const EdgeInsets.all(16),
              itemCount: results.length,
              itemBuilder: (context, i) =>
                  _resultCard(context, results[i] as Map<String, dynamic>),
            ),
          );
        },
      ),
    );
  }

  Widget _resultCard(BuildContext context, Map<String, dynamic> result) {
    final scheme = Theme.of(context).colorScheme;
    final isAbsent = result['is_absent'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(
          '${result['exam'] ?? 'Exam'} — ${result['subject'] ?? ''}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text('${result['term'] ?? ''} · ${result['date'] ?? ''}'),
        // Absent students have no marks to show — the chip says it all.
        trailing: isAbsent
            ? const StatusChip('absent')
            : Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // The grade is the headline — big, bold, brand-coloured.
                  Text(
                    (result['grade'] as String?) ?? '-',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.primary,
                        ),
                  ),
                  Text(
                    '${result['marks_obtained'] ?? '-'} / ${result['max_marks'] ?? '-'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
      ),
    );
  }
}

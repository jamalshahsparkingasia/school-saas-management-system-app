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
              padding: const EdgeInsets.all(16),
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

  Widget _examCard(BuildContext context, Map<String, dynamic> exam,
      {required bool upcoming}) {
    final scheme = Theme.of(context).colorScheme;
    final status = (exam['status'] as String?) ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          // Tinted for what's ahead, muted for what's behind —
          // a quick visual cue before you even read the dates.
          backgroundColor:
              upcoming ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          child: Icon(
            upcoming ? Icons.event_outlined : Icons.history,
            color:
                upcoming ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
          ),
        ),
        title: Text(
          '${exam['name'] ?? 'Exam'} — ${exam['subject'] ?? ''}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${exam['term'] ?? ''} · ${exam['scheduled_at'] ?? ''}'),
            Text([
              if (exam['duration'] != null) '${exam['duration']} min',
              if (exam['max_marks'] != null) 'Max ${exam['max_marks']} marks',
            ].join(' · ')),
          ],
        ),
        isThreeLine: true,
        trailing: status.isNotEmpty ? StatusChip(status) : null,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/session.dart';
import '../../widgets/common.dart';

/// The school notice board, shared by students, teachers AND parents —
/// the server already filters notices to what the signed-in role may see.
///
/// This endpoint is PAGINATED, so we use api.getRaw() instead of get():
/// getRaw returns the whole envelope {success, data: [rows], meta: {…}}
/// because the rows live in `data` as a LIST (get() would flatten a
/// list away — it only knows how to hand back a map).
///
///   { "data": [ {id, title, body, is_pinned, publish_at} ],
///     "meta": {current_page, last_page, …} }
///
/// We show the first page (15 notices) — a school notice board rarely
/// has more that are still worth reading, and pull-to-refresh always
/// brings in the newest ones.
class NoticesScreen extends StatefulWidget {
  const NoticesScreen({super.key});

  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final session = context.read<Session>();
    try {
      return await session.api.getRaw('/notices');
    } catch (e) {
      // Token expired? Session drops us back to the login screen.
      session.handleAuthError(e);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notice board')),
      body: ApiFutureView<Map<String, dynamic>>(
        future: _future,
        onRetry: () => setState(() => _future = _load()),
        builder: (context, envelope) {
          final rows = (envelope['data'] as List<dynamic>? ?? [])
              .map((n) => n as Map<String, dynamic>)
              .toList();

          // Pinned notices float to the top in their own group so the
          // office's "don't miss this" items are impossible to miss.
          final pinned = rows.where((n) => n['is_pinned'] == true).toList();
          final others = rows.where((n) => n['is_pinned'] != true).toList();

          return RefreshIndicator(
            onRefresh: () async => setState(() => _future = _load()),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (rows.isEmpty)
                  const EmptyState(
                    icon: Icons.campaign_outlined,
                    message: 'No notices yet.',
                  )
                else ...[
                  if (pinned.isNotEmpty) ...[
                    const SectionHeader('Pinned'),
                    for (final notice in pinned)
                      _NoticeCard(notice: notice, pinned: true),
                  ],
                  // Only label the second group when there ARE two groups —
                  // a lone "All notices" header would just be noise.
                  if (pinned.isNotEmpty && others.isNotEmpty)
                    const SectionHeader('All notices'),
                  for (final notice in others)
                    _NoticeCard(notice: notice, pinned: false),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// One notice: title + date on the first line, full body below.
class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.notice, required this.pinned});

  final Map<String, dynamic> notice;
  final bool pinned;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final body = (notice['body'] as String?) ?? '';
    final date = (notice['publish_at'] as String?) ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (pinned) ...[
                  Icon(Icons.push_pin, size: 16, color: scheme.primary),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    (notice['title'] as String?) ?? 'Notice',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (date.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    date, // already a friendly YYYY-MM-DD string
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(body),
            ],
          ],
        ),
      ),
    );
  }
}

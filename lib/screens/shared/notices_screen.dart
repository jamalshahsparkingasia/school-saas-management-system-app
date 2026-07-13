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

          // Pinned notices float to the top — each one wears a small
          // "PINNED" pill so the office's "don't miss this" items are
          // impossible to miss even while scrolling fast.
          final pinned = rows.where((n) => n['is_pinned'] == true).toList();
          final others = rows.where((n) => n['is_pinned'] != true).toList();

          return RefreshIndicator(
            onRefresh: () async => setState(() => _future = _load()),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                if (rows.isEmpty)
                  const EmptyState(
                    icon: Icons.campaign_outlined,
                    message: 'No notices yet.',
                  )
                else ...[
                  for (final notice in pinned)
                    _NoticeCard(notice: notice, pinned: true),
                  // Only label the second group when there ARE two
                  // groups — a lone "All notices" header would be noise.
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

/// One notice card: the optional PINNED pill, a bold title, the full
/// body in muted grey, and a tiny calendar + date footer.
class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.notice, required this.pinned});

  final Map<String, dynamic> notice;
  final bool pinned;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final body = (notice['body'] as String?) ?? '';
    final date = (notice['publish_at'] as String?) ?? '';

    return SoftCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pinned) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.push_pin_rounded, size: 12, color: scheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    'PINNED',
                    style: TextStyle(
                      color: scheme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          Text(
            (notice['title'] as String?) ?? 'Notice',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15.5,
            ),
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              body,
              style: const TextStyle(
                color: Color(0xFF6B7686),
                fontSize: 13.5,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (date.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 13,
                  color: Color(0xFF8A94A6),
                ),
                const SizedBox(width: 5),
                Text(
                  date, // already a friendly YYYY-MM-DD string
                  style: const TextStyle(
                    color: Color(0xFF8A94A6),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

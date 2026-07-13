import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/api_client.dart';
import '../../state/session.dart';
import '../../widgets/common.dart';

/// The user's personal in-app notifications ("Fee due", "Homework
/// graded", …) — unlike the notice board these are addressed to ONE
/// person, and each row carries an is_read flag we can flip.
///
/// Paginated endpoint → api.getRaw() gives the whole envelope:
///   { "data": [ {id, type, title, body, is_read, created_at} ],
///     "meta": {…} }
///
/// Two write actions live here, both simple POSTs followed by a
/// reload — the server is the source of truth for read-state, so
/// instead of hand-editing our local list (easy to get wrong) we just
/// ask for the fresh list again:
///   POST /notifications/{id}/read   (tap an unread row)
///   POST /notifications/read-all    (app-bar button)
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<Map<String, dynamic>> _future;

  /// True while "Mark all read" is in flight — disables the button so
  /// an impatient double-tap can't fire the request twice.
  bool _markingAll = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final session = context.read<Session>();
    try {
      return await session.api.getRaw('/notifications');
    } catch (e) {
      session.handleAuthError(e);
      rethrow;
    }
  }

  void _refresh() => setState(() => _future = _load());

  /// Tapping an unread row: tell the server, then reload the list so
  /// the tint and dot disappear. Already-read rows do nothing.
  Future<void> _markRead(int id) async {
    final session = context.read<Session>();
    try {
      await session.api.post('/notifications/$id/read');
      if (mounted) _refresh();
    } catch (e) {
      session.handleAuthError(e);
      _showError(e);
    }
  }

  Future<void> _markAllRead() async {
    setState(() => _markingAll = true);
    final session = context.read<Session>();
    try {
      await session.api.post('/notifications/read-all');
      if (mounted) _refresh();
    } catch (e) {
      session.handleAuthError(e);
      _showError(e);
    } finally {
      // `mounted` check: the user may have navigated away while the
      // request was running — calling setState then would crash.
      if (mounted) setState(() => _markingAll = false);
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    // ApiException.toString() is already a human-friendly message.
    final message = e is ApiException ? e.message : 'Something went wrong.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: _markingAll ? null : _markAllRead,
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: ApiFutureView<Map<String, dynamic>>(
        future: _future,
        onRetry: _refresh,
        builder: (context, envelope) {
          final rows = (envelope['data'] as List<dynamic>? ?? [])
              .map((n) => n as Map<String, dynamic>)
              .toList();

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: rows.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      EmptyState(
                        icon: Icons.notifications_none,
                        message: 'Nothing here yet.',
                      ),
                    ],
                  )
                // Notifications are short uniform rows, so the whole
                // inbox lives in ONE grouped SoftCard with hairline
                // dividers — not a stack of separate cards.
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: [
                      SoftCard(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          children: [
                            for (var i = 0; i < rows.length; i++) ...[
                              _NotificationTile(
                                row: rows[i],
                                onTap: rows[i]['is_read'] == true
                                    ? null // read rows aren't tappable
                                    : () => _markRead(
                                        (rows[i]['id'] as num?)?.toInt() ?? 0),
                              ),
                              if (i != rows.length - 1)
                                const Divider(
                                    height: 1, indent: 72, endIndent: 16),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

/// One notification row inside the grouped card. Unread rows get a
/// faint primary wash, a heavier title and a primary dot right after
/// it — the classic "inbox" language every user already knows.
class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.row, required this.onTap});

  final Map<String, dynamic> row;
  final VoidCallback? onTap;

  /// A recognisable icon per notification type. Unknown types fall
  /// back to a bell, so a new server-side type never breaks the app.
  IconData _iconFor(String type) {
    if (type.contains('fee') || type.contains('invoice')) {
      return Icons.receipt_long;
    }
    if (type.contains('homework') || type.contains('assignment')) {
      return Icons.menu_book;
    }
    if (type.contains('exam') || type.contains('result')) return Icons.quiz;
    if (type.contains('attendance')) return Icons.fact_check;
    if (type.contains('notice')) return Icons.campaign;
    return Icons.notifications;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final type = (row['type'] as String?) ?? '';
    final isRead = row['is_read'] == true;
    final body = (row['body'] as String?) ?? '';
    final createdAt = (row['created_at'] as String?) ?? '';

    return ListTile(
      onTap: onTap,
      // The faint tint is the loudest unread signal — a 5% wash of the
      // brand colour behind the row inside the group.
      tileColor: isRead ? null : scheme.primary.withValues(alpha: .05),
      // The badge colour is stable per TYPE, so all fee alerts share a
      // colour, all homework alerts share another — same trick the
      // subject colours use everywhere else.
      leading: IconBadge(_iconFor(type), color: colorFor(type)),
      title: Row(
        children: [
          Flexible(
            child: Text(
              (row['title'] as String?) ?? 'Notification',
              style: TextStyle(
                // Unread = heavy, read = normal — just like an inbox.
                fontWeight: isRead ? FontWeight.w700 : FontWeight.w800,
              ),
            ),
          ),
          if (!isRead) ...[
            const SizedBox(width: 6),
            // The unread dot, suffixed right after the title.
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (body.isNotEmpty) Text(body),
          if (createdAt.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                createdAt, // "YYYY-MM-DD HH:MM" straight from the API
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF8A94A6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

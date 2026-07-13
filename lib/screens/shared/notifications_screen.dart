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
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: rows.length,
                    itemBuilder: (context, i) {
                      final row = rows[i];
                      return _NotificationTile(
                        row: row,
                        onTap: row['is_read'] == true
                            ? null // read rows aren't tappable
                            : () => _markRead((row['id'] as num?)?.toInt() ?? 0),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}

/// One notification row. Unread rows get a soft primary tint, bold
/// title and a dot on the right — the classic "inbox" language every
/// user already knows how to read.
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

    final isRead = row['is_read'] == true;
    final body = (row['body'] as String?) ?? '';
    final createdAt = (row['created_at'] as String?) ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      // The tint is the loudest unread signal: a see-through wash of
      // the theme's primaryContainer over the normal card colour.
      color: isRead ? null : scheme.primaryContainer.withValues(alpha: .35),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Icon(
            _iconFor((row['type'] as String?) ?? ''),
            size: 20,
            color: scheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          (row['title'] as String?) ?? 'Notification',
          style: TextStyle(
            // Unread = heavy, read = normal — just like an email inbox.
            fontWeight: isRead ? FontWeight.w500 : FontWeight.w800,
          ),
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
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        trailing: isRead
            ? null
            : Container(
                // The unread dot.
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
      ),
    );
  }
}

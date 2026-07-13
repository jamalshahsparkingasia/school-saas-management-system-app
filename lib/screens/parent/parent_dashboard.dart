import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/session.dart';
import '../../widgets/common.dart';
import 'child_detail.dart';

/// The parent's home tab: one card per child, plus a family-wide
/// "you owe the school money" banner when any fees are outstanding.
///
/// GET /parent/dashboard returns:
///   {
///     "children": [ { id, full_name, class_name, section, status,
///                     fee_due, attendance: {…summary…}, last_result } ],
///     "total_family_due": 570
///   }
///
/// This is a [StatefulWidget] for one reason only: it must HOLD the
/// Future between rebuilds. If we created the Future inside build(),
/// every repaint would fire a brand-new network request — a classic
/// Flutter mistake the ApiFutureView pattern is designed to avoid.
class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    // Kick off the request ONCE when the screen first appears.
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    // context.read = grab the Session without subscribing to changes
    // (we only need it for a moment, not for the widget's lifetime).
    final session = context.read<Session>();
    try {
      return await session.api.get('/parent/dashboard');
    } catch (e) {
      // A 401 means the token died — Session bounces us to the login
      // screen. We still rethrow so ApiFutureView shows its error view
      // for every OTHER kind of failure (no network, server down…).
      session.handleAuthError(e);
      rethrow;
    }
  }

  void _refresh() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<Session>().currency;

    return Scaffold(
      appBar: AppBar(title: const Text('My children')),
      body: ApiFutureView<Map<String, dynamic>>(
        future: _future,
        onRetry: _refresh,
        builder: (context, data) {
          final children = (data['children'] as List<dynamic>? ?? []);
          final totalDue = (data['total_family_due'] as num? ?? 0).toDouble();

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              // Even when the list is short, keep it scrollable so the
              // pull-to-refresh gesture always works.
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (totalDue > 0) ...[
                  _FamilyDueBanner(amount: totalDue, currency: currency),
                  const SizedBox(height: 12),
                ],
                if (children.isEmpty)
                  const EmptyState(
                    icon: Icons.family_restroom,
                    message:
                        'No children are linked to your account yet.\nAsk the school office to link them.',
                  )
                else
                  for (final child in children)
                    _ChildCard(
                      child: child as Map<String, dynamic>,
                      currency: currency,
                      onTap: () {
                        // Push the per-child detail screen. When the user
                        // comes back the dashboard is still here, exactly
                        // as they left it (the Future is preserved).
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChildDetailScreen(
                              childId: (child['id'] as num?)?.toInt() ?? 0,
                              childName:
                                  (child['full_name'] as String?) ?? 'Child',
                            ),
                          ),
                        );
                      },
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A warm amber banner shown only when the family owes money.
/// Same warm colour StatusChip uses for "pending", so the palette
/// stays consistent across the app.
class _FamilyDueBanner extends StatelessWidget {
  const _FamilyDueBanner({required this.amount, required this.currency});

  final double amount;
  final String currency;

  static const _warm = Color(0xFFB45309);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _warm.withValues(alpha: .10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.account_balance_wallet_outlined, color: _warm),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Family balance due: $currency${amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: _warm,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One tappable summary card per child: who they are, plus three
/// at-a-glance numbers (attendance %, fees due, last exam result).
class _ChildCard extends StatelessWidget {
  const _ChildCard({
    required this.child,
    required this.currency,
    required this.onTap,
  });

  final Map<String, dynamic> child;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final name = (child['full_name'] as String?) ?? 'Child';
    final className = (child['class_name'] as String?) ?? '';
    final section = (child['section'] as String?) ?? '';
    final attendance = child['attendance'] as Map<String, dynamic>? ?? {};
    final percent = attendance['percent'] as num?;
    final feeDue = (child['fee_due'] as num? ?? 0).toDouble();
    final lastResult = child['last_result'] as Map<String, dynamic>?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      // Card + InkWell (instead of ListTile) because we want a custom
      // two-row layout AND the ripple effect on tap.
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: scheme.primaryContainer,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          [
                            if (className.isNotEmpty) className,
                            if (section.isNotEmpty) section,
                          ].join(' · '),
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 12),
              // Wrap (not Row) so the pills flow to a second line on
              // narrow phones instead of overflowing.
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MiniStat(
                    icon: Icons.fact_check_outlined,
                    label: percent != null ? '$percent% attendance' : 'No attendance yet',
                    color: _attendanceColor(percent, scheme),
                  ),
                  _MiniStat(
                    icon: Icons.receipt_long_outlined,
                    label: feeDue > 0
                        ? 'Due $currency${feeDue.toStringAsFixed(2)}'
                        : 'No dues',
                    color: feeDue > 0
                        ? const Color(0xFFB91C1C) // red — action needed
                        : const Color(0xFF15803D), // green — all clear
                  ),
                  if (lastResult != null)
                    _MiniStat(
                      icon: Icons.grade_outlined,
                      label: _lastResultLabel(lastResult),
                      color: scheme.primary,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Traffic-light colours for the attendance pill, matching the
  /// green/amber/red constants StatusChip already uses.
  Color _attendanceColor(num? percent, ColorScheme scheme) {
    if (percent == null) return scheme.onSurfaceVariant;
    if (percent >= 90) return const Color(0xFF15803D);
    if (percent >= 75) return const Color(0xFFB45309);
    return const Color(0xFFB91C1C);
  }

  /// "Maths: A" if the exam was graded, otherwise "Maths: 18/20",
  /// or "Absent" when the child missed the exam entirely.
  String _lastResultLabel(Map<String, dynamic> result) {
    final subject = (result['subject'] as String?) ?? 'Last exam';
    if (result['is_absent'] == true) return '$subject: Absent';

    final grade = result['grade'] as String?;
    if (grade != null && grade.isNotEmpty) return '$subject: $grade';

    final marks = result['marks_obtained'] as num?;
    final max = result['max_marks'] as num?;
    return '$subject: ${marks ?? '–'}/${max ?? '–'}';
  }
}

/// A small coloured pill: icon + short label. Visually a cousin of
/// StatusChip but with an icon and free-form text.
class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

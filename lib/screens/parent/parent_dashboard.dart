import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/session.dart';
import '../../widgets/common.dart';
import 'child_detail.dart';

/// The parent's home tab: a gradient hero greeting, a family-wide
/// "you owe the school money" card floating over it when fees are
/// outstanding, then one card per child.
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
    final session = context.watch<Session>();
    final currency = session.currency;

    // "Esther Stowell" → "Esther". `split` never returns an empty list,
    // so `.first` is safe even for an empty string.
    final firstName = session.userName.split(' ').first;

    // Dashboards get NO AppBar: the gradient HeroHeader owns the top of
    // the screen (it pads itself below the status bar).
    return Scaffold(
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
              // pull-to-refresh gesture always works. Zero padding: the
              // hero banner must bleed edge-to-edge.
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                // The signature dashboard composition: the content below
                // the banner floats 30px up over its bottom edge. When
                // fees are due, the amber "family balance" card is the
                // floating piece; otherwise the children section itself
                // overlaps the banner.
                HeroHeader.overlap(
                  overlap: 30,
                  header: HeroHeader(
                    caption: session.schoolName.toUpperCase(),
                    title: 'Hi, ${firstName.isEmpty ? 'there' : firstName} 👋',
                    subtitle: 'Your children at a glance',
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (totalDue > 0)
                          _FamilyDueBanner(
                            amount: totalDue,
                            currency: currency,
                          ),
                        if (children.isEmpty)
                          const EmptyState(
                            icon: Icons.family_restroom,
                            message:
                                'No children are linked to your account yet.\nAsk the school office to link them.',
                          )
                        else ...[
                          const SectionHeader('Children'),
                          for (final child in children)
                            _ChildCard(
                              child: child as Map<String, dynamic>,
                              currency: currency,
                              onTap: () {
                                // Push the per-child detail screen. When
                                // the user comes back the dashboard is
                                // still here, exactly as they left it
                                // (the Future is preserved).
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ChildDetailScreen(
                                      childId:
                                          (child['id'] as num?)?.toInt() ?? 0,
                                      childName:
                                          (child['full_name'] as String?) ??
                                              'Child',
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ],
                    ),
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

/// The floating "family balance due" card — an amber wallet badge next
/// to one big number. Same warm colour StatusChip uses for "pending",
/// so the palette stays consistent across the app.
class _FamilyDueBanner extends StatelessWidget {
  const _FamilyDueBanner({required this.amount, required this.currency});

  final double amount;
  final String currency;

  static const _warm = Color(0xFFB45309);

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const IconBadge(Icons.account_balance_wallet_rounded, color: _warm),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Family balance due',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7686),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$currency${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _warm,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One tappable summary card per child: who they are, plus three
/// at-a-glance pills (attendance %, fees due, last exam result).
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

    // Each child gets a stable identity colour — the same one their
    // name would get anywhere else in the app.
    final tint = colorFor(name);

    return SoftCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: tint.withValues(alpha: .14),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: tint,
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
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (className.isNotEmpty) className,
                        if (section.isNotEmpty) section,
                      ].join(' · '),
                      style: const TextStyle(
                        color: Color(0xFF6B7686),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFB6BEC9)),
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
                label: percent != null
                    ? '$percent% attendance'
                    : 'No attendance yet',
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
                  // Subject accent = the subject's stable colour, same
                  // as the timetable and homework screens.
                  color: colorFor(
                      (lastResult['subject'] as String?) ?? 'Last exam'),
                ),
            ],
          ),
        ],
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

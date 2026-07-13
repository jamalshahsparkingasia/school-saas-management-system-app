import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';

/// The app's design system: every screen is assembled from the pieces in
/// this file, so the whole app stays visually consistent — and a tweak
/// here restyles everything at once.
///
/// The look: a soft near-white canvas, floating white cards with gentle
/// shadows, one big gradient "hero" header per dashboard in the school's
/// brand colours, and colour-coded icon badges.

// ─────────────────────────────────────────────────────────────────
//  Foundations
// ─────────────────────────────────────────────────────────────────

/// The soft drop shadow every floating card uses.
List<BoxShadow> softShadow(BuildContext context) => [
      BoxShadow(
        color: const Color(0xFF1A2330).withValues(alpha: .06),
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
    ];

/// A stable pastel colour for any label (subject names, categories...):
/// the same string always gets the same colour, so "Mathematics" is
/// identical on the timetable, homework and results screens.
Color colorFor(String label) {
  const palette = [
    Color(0xFF0EA5E9), // sky
    Color(0xFF8B5CF6), // violet
    Color(0xFFF59E0B), // amber
    Color(0xFF10B981), // emerald
    Color(0xFFEF4444), // red
    Color(0xFFEC4899), // pink
    Color(0xFF14B8A6), // teal
    Color(0xFF6366F1), // indigo
  ];
  var hash = 0;
  for (final unit in label.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return palette[hash % palette.length];
}

/// A rounded-square tinted icon — the visual anchor of list rows.
class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.color, this.size = 44});

  final IconData icon;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.primary;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(size * .32),
      ),
      child: Icon(icon, color: tint, size: size * .5),
    );
  }
}

/// A white floating card — the surface everything sits on.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: softShadow(context),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Hero header — the signature look of every dashboard
// ─────────────────────────────────────────────────────────────────

/// The big rounded gradient banner at the top of each dashboard, painted
/// in the school's brand colours. Put quick stats (or anything) in
/// [child] and it renders on the gradient; the widget below the header
/// can overlap it by wrapping the page in [HeroHeader.overlap].
class HeroHeader extends StatelessWidget {
  const HeroHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.caption,
    this.child,
    this.trailing,
  });

  /// Small line above the title (e.g. "Monday, 13 July").
  final String? caption;

  /// The big line — usually "Hi, Ava 👋".
  final String title;

  /// Line under the title (e.g. "Class 5 — A · Westfield Academy").
  final String? subtitle;

  /// Right-hand widget, defaults to the user's initial in a ring.
  final Widget? trailing;

  /// Optional content rendered inside the gradient, under the texts.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final scheme = Theme.of(context).colorScheme;

    // Brand gradient: school primary → secondary (or a deeper primary).
    final start = scheme.primary;
    final end = _parseHex(session.school['secondary_color'] as String?) ??
        HSLColor.fromColor(start).withLightness(
          (HSLColor.fromColor(start).lightness - .18).clamp(0.0, 1.0),
        ).toColor();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.paddingOf(context).top + 24, 20, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [start, end],
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (caption != null)
                      Text(
                        caption!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .75),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .3,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .82),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              trailing ?? _Avatar(name: session.userName),
            ],
          ),
          if (child != null) ...[
            const SizedBox(height: 20),
            child!,
          ],
        ],
      ),
    );
  }

  /// Lays a widget so it overlaps the bottom edge of the hero — the
  /// classic "stats card floating over the banner" composition:
  ///
  ///   HeroHeader.overlap(
  ///     header: HeroHeader(...),
  ///     child: Padding(... stat grid ...),
  ///     overlap: 34,
  ///   )
  static Widget overlap({
    required Widget header,
    required Widget child,
    double overlap = 34,
  }) {
    return Column(
      children: [
        header,
        Transform.translate(
          offset: Offset(0, -overlap),
          child: child,
        ),
      ],
    );
  }

  static Color? _parseHex(String? hex) {
    if (hex == null) return null;
    final cleaned = hex.replaceFirst('#', '');
    if (cleaned.length != 6) return null;
    final value = int.tryParse(cleaned, radix: 16);
    return value == null ? null : Color(0xFF000000 | value);
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: .55), width: 2),
      ),
      child: CircleAvatar(
        radius: 22,
        backgroundColor: Colors.white.withValues(alpha: .22),
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Stats
// ─────────────────────────────────────────────────────────────────

/// A compact statistic tile ("Attendance 96%", "Due $25"...).
/// Use inside a GridView with `mainAxisExtent: 92` so tiles keep a neat
/// fixed height on every screen size.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: softShadow(context),
      ),
      child: Row(
        children: [
          IconBadge(icon, color: tint, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7686),
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

/// The standard 2-column stat grid used on all dashboards. Fixed tile
/// height (not aspect ratio!) so cards stay compact on wide screens.
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.cards});

  final List<StatCard> cards;

  @override
  Widget build(BuildContext context) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 76,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      children: cards,
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Text + status pieces
// ─────────────────────────────────────────────────────────────────

/// Section title with breathing room, used between groups of cards.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A little coloured pill for statuses: present/absent, paid/pending...
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final String status;

  static const _colors = <String, Color>{
    'present': Color(0xFF15803D),
    'paid': Color(0xFF15803D),
    'graded': Color(0xFF15803D),
    'submitted': Color(0xFF0369A1),
    'scheduled': Color(0xFF0369A1),
    'late': Color(0xFFB45309),
    'partial': Color(0xFFB45309),
    'pending': Color(0xFFB45309),
    'absent': Color(0xFFB91C1C),
    'overdue': Color(0xFFB91C1C),
    'excused': Color(0xFF6D28D9),
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[status.toLowerCase()] ??
        Theme.of(context).colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: .2,
        ),
      ),
    );
  }
}

/// Friendly placeholder for lists with nothing in them yet.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: .07),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: scheme.primary.withValues(alpha: .55)),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF6B7686),
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Data loading
// ─────────────────────────────────────────────────────────────────

/// Standard wrapper for screens that load data from the API.
///
/// Give it a [future] and a [builder]; it shows a spinner while loading,
/// a retry view on failure, and your content on success. This is the
/// pattern behind every data screen in the app.
class ApiFutureView<T> extends StatelessWidget {
  const ApiFutureView({
    super.key,
    required this.future,
    required this.builder,
    required this.onRetry,
  });

  final Future<T> future;
  final Widget Function(BuildContext context, T data) builder;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const IconBadge(Icons.cloud_off_rounded, size: 60),
                  const SizedBox(height: 14),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7686),
                    ),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          );
        }
        return builder(context, snapshot.data as T);
      },
    );
  }
}

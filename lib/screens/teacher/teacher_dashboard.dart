import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/session.dart';
import '../../widgets/common.dart';

/// The teacher's landing tab — one glance answers "what does my day
/// look like?": headline counts, today's periods, how attendance is
/// shaping up, and any exams on the horizon.
///
/// Like every dashboard it has NO AppBar: the gradient [HeroHeader] is
/// the header, greeting the teacher and carrying their identity line
/// (designation · subject · employee id), with the stat grid floating
/// over the banner's bottom edge via [HeroHeader.overlap].
///
/// It is a [StatefulWidget] for one reason only: it must HOLD the
/// [Future] returned by the API call. If we created the future inside
/// `build`, every rebuild (a rotation, a theme change...) would fire a
/// brand new network request. Storing it in state means "load once,
/// reload only when *we* decide to" — the pattern every data screen in
/// this app follows.
class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load(); // kick off the request as soon as the tab opens
  }

  Future<Map<String, dynamic>> _load() async {
    // `read` (not `watch`): we only want the Session object, we are not
    // subscribing this method to its changes.
    final session = context.read<Session>();
    try {
      return await session.api.get('/teacher/dashboard');
    } catch (e) {
      // If the token died (401) this bounces the user to the login
      // screen; any other error is rethrown so ApiFutureView can show
      // its "Try again" view.
      session.handleAuthError(e);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    // The user's name is already in the Session (saved at login), so the
    // hero can greet them instantly — no need to wait for the API.
    final firstName = session.userName.trim().isEmpty
        ? ''
        : session.userName.trim().split(' ').first;

    return Scaffold(
      body: ApiFutureView<Map<String, dynamic>>(
        future: _future,
        // Retry simply swaps in a fresh future; FutureBuilder notices
        // the new object and starts over (spinner → data / error).
        onRetry: () => setState(() => _future = _load()),
        builder: (context, data) {
          // Defensive reads: every field could be missing, so each cast
          // falls back to an empty map/list instead of crashing.
          final teacher = data['teacher'] as Map<String, dynamic>? ?? {};
          final counts = data['counts'] as Map<String, dynamic>? ?? {};
          final periods = data['today_periods'] as List<dynamic>? ?? [];
          final attendance =
              data['today_attendance'] as Map<String, dynamic>? ?? {};
          final exams = data['upcoming_exams'] as List<dynamic>? ?? [];

          // Identity line for the hero subtitle, built from whichever
          // bits the API sent and glued with a middle dot.
          final details = <String>[
            if (teacher['designation'] != null) '${teacher['designation']}',
            if (teacher['subject'] != null) '${teacher['subject']}',
            if (teacher['employee_id'] != null) 'ID ${teacher['employee_id']}',
          ].join(' · ');

          return RefreshIndicator(
            // Pull-to-refresh reuses the exact same trick as onRetry.
            onRefresh: () async => setState(() => _future = _load()),
            child: ListView(
              // AlwaysScrollable lets you pull-to-refresh even when the
              // content is shorter than the screen; zero padding lets the
              // hero gradient run edge-to-edge under the status bar.
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                HeroHeader.overlap(
                  overlap: 30,
                  header: HeroHeader(
                    caption: session.schoolName.toUpperCase(),
                    title: firstName.isEmpty ? 'Hi 👋' : 'Hi, $firstName 👋',
                    subtitle: details.isEmpty ? null : details,
                  ),
                  // Everything below rides 30px up so the stat grid
                  // floats over the banner's bottom edge.
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Headline numbers — the shared fixed-height grid.
                        StatGrid(cards: [
                          StatCard(
                            label: 'Students',
                            value: '${counts['students'] ?? 0}',
                            icon: Icons.groups_rounded,
                            color: const Color(0xFF0EA5E9),
                          ),
                          StatCard(
                            label: 'Classes',
                            value: '${counts['classes'] ?? 0}',
                            icon: Icons.school_rounded,
                            color: const Color(0xFF8B5CF6),
                          ),
                          StatCard(
                            label: 'Subjects',
                            value: '${counts['subjects'] ?? 0}',
                            icon: Icons.menu_book_rounded,
                            color: const Color(0xFF10B981),
                          ),
                          StatCard(
                            label: 'Sections',
                            value: '${counts['sections'] ?? 0}',
                            icon: Icons.grid_view_rounded,
                            color: const Color(0xFFF59E0B),
                          ),
                        ]),

                        const SectionHeader("Today's classes"),
                        if (periods.isEmpty)
                          const EmptyState(
                            icon: Icons.free_breakfast_outlined,
                            message: 'No classes today.',
                          )
                        else
                          ...periods.map((p) =>
                              _periodRow(context, p as Map<String, dynamic>)),

                        // Only show the attendance summary when the API
                        // actually sent some counts — an empty map means
                        // "nothing marked yet".
                        if (attendance.isNotEmpty) ...[
                          const SectionHeader("Today's attendance"),
                          SoftCard(
                            child: Wrap(
                              spacing: 14,
                              runSpacing: 10,
                              children: [
                                for (final entry in attendance.entries)
                                  // "[present] 10" — the coloured pill
                                  // comes from the shared StatusChip so
                                  // colours stay consistent with every
                                  // other screen.
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      StatusChip(entry.key),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${entry.value}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],

                        const SectionHeader('Upcoming exams'),
                        if (exams.isEmpty)
                          const EmptyState(
                            icon: Icons.quiz_outlined,
                            message: 'No upcoming exams.',
                          )
                        else
                          ...exams.map((e) =>
                              _examRow(context, e as Map<String, dynamic>)),
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

  /// One period of today's schedule, drawn exactly like the timetable
  /// timeline (time column on the left, colour-spined card on the right)
  /// so the two screens feel like the same app.
  Widget _periodRow(BuildContext context, Map<String, dynamic> period) {
    final subject = (period['subject'] as String?) ?? 'Class';
    final tint = colorFor(subject); // same colour on every screen

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time column.
          SizedBox(
            width: 52,
            child: Column(
              children: [
                Text(
                  '${period['start'] ?? ''}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${period['end'] ?? ''}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF8A94A6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Subject card with a colour spine and a "P3" period pill.
          Expanded(
            child: SoftCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: tint,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (period['section'] != null)
                              '${period['section']}',
                            if (period['room'] != null)
                              'Room ${period['room']}',
                          ].join(' · '),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7686),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'P${period['period']}',
                      style: TextStyle(
                        color: tint,
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// One upcoming exam — icon badge tinted by subject, date on the right.
  Widget _examRow(BuildContext context, Map<String, dynamic> exam) {
    final subject = (exam['subject'] as String?) ?? '';
    final tint = colorFor(subject.isEmpty
        ? (exam['name'] as String?) ?? 'Exam'
        : subject);

    return SoftCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconBadge(Icons.quiz_rounded, color: tint),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (exam['name'] as String?) ?? 'Exam',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
                if (subject.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subject,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7686),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Dates come from the API as ready-to-show strings — display
          // them as-is rather than re-parsing (no date library needed).
          Text(
            '${exam['scheduled_at'] ?? ''}',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7686),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

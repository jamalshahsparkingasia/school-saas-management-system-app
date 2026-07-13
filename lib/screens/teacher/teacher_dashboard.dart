import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/session.dart';
import '../../widgets/common.dart';

/// The teacher's landing tab — one glance answers "what does my day
/// look like?": headline counts, today's periods, how attendance is
/// shaping up, and any exams on the horizon.
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
    // AppBar can greet them instantly — no need to wait for the API.
    final firstName =
        session.userName.trim().isEmpty ? '' : session.userName.trim().split(' ').first;

    return Scaffold(
      appBar: AppBar(title: Text(firstName.isEmpty ? 'Home' : 'Hi, $firstName')),
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

          return RefreshIndicator(
            // Pull-to-refresh reuses the exact same trick as onRetry.
            onRefresh: () async => setState(() => _future = _load()),
            child: ListView(
              // AlwaysScrollable lets you pull-to-refresh even when the
              // content is shorter than the screen.
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _teacherCard(context, teacher),
                const SizedBox(height: 4),

                // Headline numbers. shrinkWrap + NeverScrollable turn the
                // grid into a plain block inside the outer ListView (two
                // nested scrollables would fight over drag gestures).
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.5,
                  children: [
                    StatCard(
                      label: 'Students',
                      value: '${counts['students'] ?? 0}',
                      icon: Icons.groups_rounded,
                    ),
                    StatCard(
                      label: 'Classes',
                      value: '${counts['classes'] ?? 0}',
                      icon: Icons.school_rounded,
                      color: const Color(0xFF0369A1),
                    ),
                    StatCard(
                      label: 'Subjects',
                      value: '${counts['subjects'] ?? 0}',
                      icon: Icons.menu_book_rounded,
                      color: const Color(0xFF15803D),
                    ),
                    StatCard(
                      label: 'Sections',
                      value: '${counts['sections'] ?? 0}',
                      icon: Icons.grid_view_rounded,
                      color: const Color(0xFFB45309),
                    ),
                  ],
                ),

                const SectionHeader("Today's classes"),
                if (periods.isEmpty)
                  const EmptyState(
                    icon: Icons.free_breakfast_outlined,
                    message: 'No classes today.',
                  )
                else
                  ...periods.map((p) => _periodTile(context, p as Map<String, dynamic>)),

                // Only show the attendance summary when the API actually
                // sent some counts — an empty map means "nothing marked yet".
                if (attendance.isNotEmpty) ...[
                  const SectionHeader("Today's attendance"),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Wrap(
                        spacing: 14,
                        runSpacing: 10,
                        children: [
                          for (final entry in attendance.entries)
                            // "[present] 10" — the coloured pill comes from
                            // the shared StatusChip so colours stay
                            // consistent with every other screen.
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                StatusChip(entry.key),
                                const SizedBox(width: 5),
                                Text(
                                  '${entry.value}',
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                        ],
                      ),
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
                  ...exams.map((e) => _examTile(context, e as Map<String, dynamic>)),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Who am I? — small identity card so the teacher knows the app is
  /// looking at the right profile (handy in schools with shared devices).
  Widget _teacherCard(BuildContext context, Map<String, dynamic> teacher) {
    final scheme = Theme.of(context).colorScheme;

    // Build the subtitle from whichever bits the API sent, skipping the
    // missing ones, and glue them with a middle dot.
    final details = <String>[
      if (teacher['designation'] != null) '${teacher['designation']}',
      if (teacher['subject'] != null) '${teacher['subject']}',
      if (teacher['employee_id'] != null) 'ID ${teacher['employee_id']}',
    ].join(' · ');

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Icon(Icons.co_present_rounded, color: scheme.onPrimaryContainer),
        ),
        title: Text(
          (teacher['full_name'] as String?) ?? 'Teacher',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: details.isEmpty ? null : Text(details),
      ),
    );
  }

  /// One period of today's schedule — same look as the timetable screen
  /// so the two feel like the same app.
  Widget _periodTile(BuildContext context, Map<String, dynamic> period) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Text(
            '${period['period'] ?? ''}',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: scheme.onPrimaryContainer,
            ),
          ),
        ),
        title: Text(
          (period['subject'] as String?) ?? 'Class',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text([
          if (period['section'] != null) '${period['section']}',
          if (period['room'] != null) 'Room ${period['room']}',
        ].join(' · ')),
        trailing: Text(
          '${period['start'] ?? ''}\n${period['end'] ?? ''}',
          textAlign: TextAlign.right,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }

  Widget _examTile(BuildContext context, Map<String, dynamic> exam) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(Icons.quiz_rounded, color: scheme.primary),
        title: Text(
          (exam['name'] as String?) ?? 'Exam',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text((exam['subject'] as String?) ?? ''),
        // Dates come from the API as ready-to-show strings — display
        // them as-is rather than re-parsing (no date library needed).
        trailing: Text(
          '${exam['scheduled_at'] ?? ''}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

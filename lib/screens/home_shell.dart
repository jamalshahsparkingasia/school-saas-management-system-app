import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../widgets/common.dart';
import 'parent/parent_dashboard.dart';
import 'shared/notices_screen.dart';
import 'shared/notifications_screen.dart';
import 'student/student_dashboard.dart';
import 'student/student_exams.dart';
import 'student/student_fees.dart';
import 'student/student_homework.dart';
import 'student/student_lessons.dart';
import 'student/student_results.dart';
import 'student/student_timetable.dart';
import 'teacher/teacher_attendance.dart';
import 'teacher/teacher_dashboard.dart';
import 'teacher/teacher_homework.dart';
import 'teacher/teacher_timetable.dart';

/// The signed-in frame of the app: a bottom navigation bar whose tabs
/// depend on WHO is signed in. One shell, three different apps:
///
///   student → Home · Timetable · Homework · Fees · More
///   teacher → Home · Timetable · Attendance · Homework · More
///   parent  → Home · Notices · Alerts · More
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final role = context.watch<Session>().role;

    final tabs = switch (role) {
      'student' => [
          (const StudentDashboardScreen(), Icons.home_rounded, 'Home'),
          (const StudentTimetableScreen(), Icons.calendar_month, 'Timetable'),
          (const StudentHomeworkScreen(), Icons.menu_book_rounded, 'Homework'),
          (const StudentFeesScreen(), Icons.receipt_long, 'Fees'),
          (const MoreScreen(), Icons.more_horiz, 'More'),
        ],
      'teacher' => [
          (const TeacherDashboardScreen(), Icons.home_rounded, 'Home'),
          (const TeacherTimetableScreen(), Icons.calendar_month, 'Timetable'),
          (const TeacherAttendanceScreen(), Icons.fact_check, 'Attendance'),
          (const TeacherHomeworkScreen(), Icons.menu_book_rounded, 'Homework'),
          (const MoreScreen(), Icons.more_horiz, 'More'),
        ],
      _ => [
          (const ParentDashboardScreen(), Icons.home_rounded, 'Home'),
          (const NoticesScreen(), Icons.campaign_rounded, 'Notices'),
          (const NotificationsScreen(), Icons.notifications_rounded, 'Alerts'),
          (const MoreScreen(), Icons.more_horiz, 'More'),
        ],
    };

    // Guard: switching roles (logout → login as someone else) can leave
    // _index past the end of a shorter tab list.
    final index = _index < tabs.length ? _index : 0;

    return Scaffold(
      body: tabs[index].$1,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final tab in tabs)
            NavigationDestination(icon: Icon(tab.$2), label: tab.$3),
        ],
      ),
    );
  }
}

/// The "More" tab: everything that didn't earn a bottom-bar slot,
/// plus the profile hero and the sign-out button.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final scheme = Theme.of(context).colorScheme;

    // Extra destinations that differ per role.
    final items = <(IconData, String, String, Widget)>[
      if (session.role == 'student') ...[
        (Icons.grade_rounded, 'Results', 'Marks and grades per exam',
            const StudentResultsScreen()),
        (Icons.quiz_rounded, 'Exams', 'Upcoming and past exams',
            const StudentExamsScreen()),
        (Icons.auto_stories_rounded, 'Lessons', 'Study material by subject',
            const StudentLessonsScreen()),
      ],
      (Icons.campaign_rounded, 'Notice board', 'Announcements from school',
          const NoticesScreen()),
      (Icons.notifications_rounded, 'Notifications', 'Your personal alerts',
          const NotificationsScreen()),
    ];

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          HeroHeader(
            caption: session.schoolName.toUpperCase(),
            title: session.userName,
            subtitle:
                '${session.role[0].toUpperCase()}${session.role.substring(1)} account · ${session.user?['email'] ?? ''}',
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                SoftCard(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      for (final item in items) ...[
                        ListTile(
                          leading: IconBadge(item.$1, color: colorFor(item.$2)),
                          title: Text(item.$2),
                          subtitle: Text(item.$3),
                          trailing: const Icon(Icons.chevron_right,
                              color: Color(0xFFB6BEC9)),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => item.$4),
                          ),
                        ),
                        if (item != items.last)
                          const Divider(height: 1, indent: 72, endIndent: 16),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SoftCard(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: IconBadge(Icons.logout_rounded,
                        color: scheme.error),
                    title: Text('Sign out',
                        style: TextStyle(
                            color: scheme.error,
                            fontWeight: FontWeight.w700)),
                    subtitle: const Text('You will need to log in again'),
                    onTap: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Sign out?'),
                          content:
                              const Text('You will need to log in again.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Sign out'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true && context.mounted) {
                        await context.read<Session>().logout();
                      }
                    },
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

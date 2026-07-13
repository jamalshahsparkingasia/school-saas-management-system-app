import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/session.dart';
import '../../widgets/common.dart';
import '../../widgets/timetable_view.dart';

/// The teacher's weekly timetable.
///
/// Notice how SHORT this file is: all the visual work (day-picker chips,
/// period cards) lives in the shared [TimetableView] widget, because the
/// student timetable API returns the exact same JSON shape. This screen
/// only has to do the two things that differ:
///   1. call the *teacher* endpoint,
///   2. put an AppBar around the result.
///
/// That is the payoff of extracting widgets — one bug fix or restyle in
/// TimetableView instantly fixes both roles.
class TeacherTimetableScreen extends StatefulWidget {
  const TeacherTimetableScreen({super.key});

  @override
  State<TeacherTimetableScreen> createState() => _TeacherTimetableScreenState();
}

class _TeacherTimetableScreenState extends State<TeacherTimetableScreen> {
  // The future lives in state so rebuilds don't re-fire the request —
  // see TeacherDashboardScreen for the full explanation of this pattern.
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final session = context.read<Session>();
    try {
      return await session.api.get('/teacher/timetable');
    } catch (e) {
      session.handleAuthError(e); // 401 → back to the login screen
      rethrow; // everything else → ApiFutureView's retry view
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My timetable')),
      body: ApiFutureView<Map<String, dynamic>>(
        future: _future,
        onRetry: () => setState(() => _future = _load()),
        builder: (context, data) {
          return RefreshIndicator(
            onRefresh: () async => setState(() => _future = _load()),
            child: ListView(
              // Keeps pull-to-refresh working even on quiet weeks where
              // the content doesn't fill the screen.
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                // TimetableView expects the whole `data` map:
                // {"today": "mon", "days": {"mon": [...], ...}}
                TimetableView(data: data),
              ],
            ),
          );
        },
      ),
    );
  }
}

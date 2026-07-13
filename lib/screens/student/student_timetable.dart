import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/session.dart';
import '../../widgets/common.dart';
import '../../widgets/timetable_view.dart';

/// The student's weekly timetable tab.
///
/// Notice how SMALL this screen is: all the day-picking and the timeline
/// rendering lives in the shared [TimetableView] widget (teachers use
/// the exact same one). This screen only has to (1) fetch the data and
/// (2) show which class/section it belongs to.
class StudentTimetableScreen extends StatefulWidget {
  const StudentTimetableScreen({super.key});

  @override
  State<StudentTimetableScreen> createState() => _StudentTimetableScreenState();
}

class _StudentTimetableScreenState extends State<StudentTimetableScreen> {
  // The Future lives in State (not build!) so a repaint never re-fires
  // the network request.
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final session = context.read<Session>();
    try {
      return await session.api.get('/student/timetable');
    } catch (e) {
      // 401 → session expired → back to login. Everything else is
      // rethrown for ApiFutureView's error + retry view.
      session.handleAuthError(e);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Timetable')),
      body: ApiFutureView<Map<String, dynamic>>(
        future: _future,
        onRetry: () => setState(() => _future = _load()),
        builder: (context, data) {
          final section = (data['section'] as String?) ?? '';

          return RefreshIndicator(
            onRefresh: () async => setState(() => _future = _load()),
            child: SingleChildScrollView(
              // AlwaysScrollable so pull-to-refresh works even on days
              // with only a couple of periods.
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Which class this timetable belongs to, e.g.
                  // "Class 5 — A", as a small uppercase caption above
                  // the day picker.
                  if (section.isNotEmpty) ...[
                    Text(
                      section.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .6,
                        color: Color(0xFF6B7686),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // The shared widget does the rest: day pills + the
                  // colour-coded timeline, opening on today's column.
                  TimetableView(data: data),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

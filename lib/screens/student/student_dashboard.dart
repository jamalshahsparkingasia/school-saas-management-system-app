import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/session.dart';
import '../../widgets/common.dart';

/// Formats a number as money WITHOUT the intl package: whole amounts show
/// as "25", fractional ones as "25.50". (Doubles print as "25.0" by
/// default, which looks odd on a receipt.)
String _money(num value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(2);

/// The student's home tab — a one-glance summary of their school life:
/// who they are, attendance, money, upcoming exams and latest results.
///
/// This is a [StatefulWidget] for one reason only: it must HOLD the
/// [Future] returned by the API call. If we called the API inside
/// `build()` instead, every repaint would fire a brand-new request —
/// the classic FutureBuilder mistake.
class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  // `late` = "I promise to assign this before anyone reads it" —
  // we do so immediately in initState.
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    // context.read = grab the Session once, without subscribing to it.
    // (Subscribing inside a load method would be pointless — it runs once.)
    final session = context.read<Session>();
    try {
      return await session.api.get('/student/dashboard');
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
    // `watch` here (unlike `read` above) because the AppBar shows the
    // user's name — if the session changes, the title should too.
    final session = context.watch<Session>();
    final scheme = Theme.of(context).colorScheme;

    // "Esther Stowell" → "Esther". `split` never returns an empty list,
    // so `.first` is safe even for an empty string.
    final firstName = session.userName.split(' ').first;

    return Scaffold(
      appBar: AppBar(
        title: Text('Hi, ${firstName.isEmpty ? 'there' : firstName}'),
      ),
      body: ApiFutureView<Map<String, dynamic>>(
        future: _future,
        // Retry simply swaps in a fresh Future; FutureBuilder notices
        // the new object and starts over (spinner → data/error).
        onRetry: () => setState(() => _future = _load()),
        builder: (context, data) {
          final student = data['student'] as Map<String, dynamic>? ?? {};
          final attendance = data['attendance'] as Map<String, dynamic>? ?? {};
          final fees = data['fees'] as Map<String, dynamic>? ?? {};
          final exams = data['upcoming_exams'] as List<dynamic>? ?? [];
          final results = data['latest_results'] as List<dynamic>? ?? [];

          return RefreshIndicator(
            onRefresh: () async => setState(() => _future = _load()),
            child: ListView(
              // AlwaysScrollable so pull-to-refresh works even when the
              // content is shorter than the screen.
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _greetingCard(context, student),
                const SizedBox(height: 4),

                // The four headline numbers. shrinkWrap + NeverScrollable
                // because this grid lives INSIDE a ListView — the outer
                // list does the scrolling, the grid just lays out tiles.
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.5,
                  children: [
                    StatCard(
                      label: 'Attendance',
                      value: '${attendance['percent'] ?? 0}%',
                      icon: Icons.fact_check_outlined,
                    ),
                    StatCard(
                      label: 'Fees due',
                      value:
                          '${session.currency}${_money(fees['total_due'] as num? ?? 0)}',
                      icon: Icons.account_balance_wallet_outlined,
                      color: const Color(0xFFB91C1C), // red = needs attention
                    ),
                    StatCard(
                      label: 'Total paid',
                      value:
                          '${session.currency}${_money(fees['total_paid'] as num? ?? 0)}',
                      icon: Icons.verified_outlined,
                      color: const Color(0xFF15803D), // green = all good
                    ),
                    StatCard(
                      label: 'Library loans',
                      value: '${data['open_loans'] ?? 0}',
                      icon: Icons.local_library_outlined,
                      color: const Color(0xFF6D28D9),
                    ),
                  ],
                ),

                const SectionHeader('Upcoming exams'),
                if (exams.isEmpty)
                  const EmptyState(
                    icon: Icons.celebration_outlined,
                    message: 'No exams coming up. Enjoy the calm!',
                  )
                else
                  ...exams.map(
                      (e) => _examCard(context, e as Map<String, dynamic>)),

                const SectionHeader('Latest results'),
                if (results.isEmpty)
                  const EmptyState(
                    icon: Icons.grade_outlined,
                    message: 'No results published yet.',
                  )
                else
                  ...results.map((r) =>
                      _resultTile(context, r as Map<String, dynamic>, scheme)),
              ],
            ),
          );
        },
      ),
    );
  }

  /// The "who am I" card at the top: avatar, name, class and status.
  Widget _greetingCard(BuildContext context, Map<String, dynamic> student) {
    final scheme = Theme.of(context).colorScheme;
    final name = (student['full_name'] as String?) ?? '';
    final status = (student['status'] as String?) ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: scheme.primaryContainer,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  Text(
                    '${student['class_name'] ?? ''} — ${student['section'] ?? ''}'
                    ' · Roll ${student['roll_number'] ?? '-'}',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  Text(
                    'Admission no. ${student['admission_no'] ?? '-'}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (status.isNotEmpty) StatusChip(status),
          ],
        ),
      ),
    );
  }

  /// One upcoming exam. The shape matches the /student/exams rows, so
  /// we read the same keys defensively (any missing key → fallback).
  Widget _examCard(BuildContext context, Map<String, dynamic> exam) {
    final scheme = Theme.of(context).colorScheme;
    final status = (exam['status'] as String?) ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.secondaryContainer,
          child: Icon(Icons.quiz_outlined, color: scheme.onSecondaryContainer),
        ),
        title: Text(
          '${exam['name'] ?? 'Exam'} — ${exam['subject'] ?? ''}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text([
          if (exam['term'] != null) '${exam['term']}',
          if (exam['scheduled_at'] != null) '${exam['scheduled_at']}',
          if (exam['duration'] != null) '${exam['duration']} min',
        ].join(' · ')),
        trailing: status.isNotEmpty ? StatusChip(status) : null,
      ),
    );
  }

  /// One published result: subject + exam on the left, a grade "chip"
  /// (or an Absent pill) plus the raw marks on the right.
  Widget _resultTile(BuildContext context, Map<String, dynamic> result,
      ColorScheme scheme) {
    final isAbsent = result['is_absent'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(
          (result['subject'] as String?) ?? 'Subject',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text((result['exam'] as String?) ?? ''),
        trailing: isAbsent
            ? const StatusChip('absent')
            : Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // The grade in a small tinted pill, like StatusChip
                  // but themed with the school's primary colour.
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      (result['grade'] as String?) ?? '-',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${result['marks_obtained'] ?? '-'} / ${result['max_marks'] ?? '-'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
      ),
    );
  }
}

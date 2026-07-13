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
/// a gradient hero with who they are, a floating stat grid (attendance,
/// money, library), then upcoming exams and latest results.
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
    // `watch` here (unlike `read` above) because the hero shows the
    // user's name and school — if the session changes, so should they.
    final session = context.watch<Session>();

    // "Esther Stowell" → "Esther". `split` never returns an empty list,
    // so `.first` is safe even for an empty string.
    final firstName = session.userName.split(' ').first;

    // No AppBar: the gradient HeroHeader IS the top of this screen and
    // already pads itself below the status bar.
    return Scaffold(
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

          // Attendance tint follows the number: green when high, amber
          // when slipping, red when it needs a conversation at home.
          final attendancePct = attendance['percent'] as num? ?? 0;
          final attendanceColor = attendancePct >= 90
              ? const Color(0xFF15803D)
              : attendancePct >= 75
                  ? const Color(0xFFB45309)
                  : const Color(0xFFB91C1C);

          return RefreshIndicator(
            onRefresh: () async => setState(() => _future = _load()),
            child: ListView(
              // AlwaysScrollable so pull-to-refresh works even when the
              // content is shorter than the screen. Zero padding so the
              // hero gradient bleeds edge-to-edge.
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                // The signature composition: gradient banner with the
                // student's identity, and the stat grid floating over
                // its bottom edge.
                HeroHeader.overlap(
                  header: HeroHeader(
                    caption: session.schoolName.toUpperCase(),
                    title: 'Hi, ${firstName.isEmpty ? 'there' : firstName} 👋',
                    subtitle:
                        '${student['class_name'] ?? ''} — ${student['section'] ?? ''}'
                        ' · Roll ${student['roll_number'] ?? '-'}',
                  ),
                  overlap: 30,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: StatGrid(cards: [
                      StatCard(
                        label: 'Attendance',
                        value: '$attendancePct%',
                        icon: Icons.fact_check_outlined,
                        color: attendanceColor,
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
                    ]),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    children: [
                      const SectionHeader('Upcoming exams'),
                      if (exams.isEmpty)
                        const EmptyState(
                          icon: Icons.celebration_outlined,
                          message: 'No exams coming up. Enjoy the calm!',
                        )
                      else
                        ...exams.map((e) =>
                            _examCard(context, e as Map<String, dynamic>)),

                      const SectionHeader('Latest results'),
                      if (results.isEmpty)
                        const EmptyState(
                          icon: Icons.grade_outlined,
                          message: 'No results published yet.',
                        )
                      else
                        ...results.map((r) =>
                            _resultCard(context, r as Map<String, dynamic>)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// One upcoming exam: a SoftCard row anchored by the subject's stable
  /// colour. The shape matches the /student/exams rows, so we read the
  /// same keys defensively (any missing key → fallback).
  Widget _examCard(BuildContext context, Map<String, dynamic> exam) {
    final subject = (exam['subject'] as String?) ?? '';
    final status = (exam['status'] as String?) ?? '';
    final tint = colorFor(subject.isEmpty ? 'Exam' : subject);

    return SoftCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconBadge(Icons.quiz_outlined, color: tint),
          const SizedBox(width: 12),
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
                const SizedBox(height: 2),
                Text(
                  [
                    if (subject.isNotEmpty) subject,
                    if (exam['term'] != null) '${exam['term']}',
                    if (exam['duration'] != null) '${exam['duration']} min',
                  ].join(' · '),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7686),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                (exam['scheduled_at'] as String?) ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
              if (status.isNotEmpty) ...[
                const SizedBox(height: 4),
                StatusChip(status),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// One published result: subject + exam on the left, a big grade pill
  /// (tinted in the subject's colour) plus the raw marks on the right.
  Widget _resultCard(BuildContext context, Map<String, dynamic> result) {
    final subject = (result['subject'] as String?) ?? 'Subject';
    final isAbsent = result['is_absent'] == true;
    final tint = colorFor(subject);

    return SoftCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconBadge(Icons.workspace_premium_outlined, color: tint),
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
                  (result['exam'] as String?) ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7686),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Absent students have no marks to show — the chip says it all.
          if (isAbsent)
            const StatusChip('absent')
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // The grade is the headline — a big pill in the
                // subject's colour, like StatusChip but louder.
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    (result['grade'] as String?) ?? '-',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: tint,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${result['marks_obtained'] ?? '-'} / ${result['max_marks'] ?? '-'}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7686),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/session.dart';
import '../../widgets/common.dart';
import '../../widgets/timetable_view.dart';

/// Everything about ONE child, in five tabs:
/// Attendance · Homework · Results · Fees · Timetable.
///
/// The parent API deliberately mirrors the student API — each tab hits
/// /parent/children/{id}/… and receives exactly what the child would
/// see in their own app, so the widgets here match the student screens.
///
/// Design decision: every tab is its OWN widget that loads its OWN
/// endpoint. Nothing downloads until you open a tab, and a failure in
/// one tab (say Fees) never breaks the others.
class ChildDetailScreen extends StatelessWidget {
  const ChildDetailScreen({
    super.key,
    required this.childId,
    required this.childName,
  });

  final int childId;
  final String childName;

  @override
  Widget build(BuildContext context) {
    // DefaultTabController wires the TabBar (the row of labels) to the
    // TabBarView (the swipeable pages) without any manual bookkeeping.
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(childName),
          bottom: const TabBar(
            // Five labels don't fit on a phone — let the bar scroll.
            isScrollable: true,
            tabs: [
              Tab(text: 'Attendance'),
              Tab(text: 'Homework'),
              Tab(text: 'Results'),
              Tab(text: 'Fees'),
              Tab(text: 'Timetable'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _AttendanceTab(childId: childId),
            _HomeworkTab(childId: childId),
            _ResultsTab(childId: childId),
            _FeesTab(childId: childId),
            _TimetableTab(childId: childId),
          ],
        ),
      ),
    );
  }
}

/// Show "18" instead of "18.0" but keep real decimals like "17.5".
/// JSON numbers arrive as int OR double, so every mark goes through here.
String _num(num? n) {
  if (n == null) return '–';
  return n == n.roundToDouble() ? n.toInt().toString() : n.toString();
}

// ---------------------------------------------------------------------------
// Attendance tab
// ---------------------------------------------------------------------------

/// GET /parent/children/{id}/attendance →
///   { "month": "2026-07",
///     "summary": {present, absent, late, excused, total, percent},
///     "records": [ {date, status, notes} ] }
class _AttendanceTab extends StatefulWidget {
  const _AttendanceTab({required this.childId});

  final int childId;

  @override
  State<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<_AttendanceTab>
    // TabBarView normally THROWS AWAY off-screen tabs, which would
    // re-download the data every swipe. This mixin says "keep me alive",
    // so each tab loads once and stays loaded.
    with AutomaticKeepAliveClientMixin {
  late Future<Map<String, dynamic>> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final session = context.read<Session>();
    try {
      return await session.api
          .get('/parent/children/${widget.childId}/attendance');
    } catch (e) {
      session.handleAuthError(e);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin

    return ApiFutureView<Map<String, dynamic>>(
      future: _future,
      onRetry: () => setState(() => _future = _load()),
      builder: (context, data) {
        final month = (data['month'] as String?) ?? '';
        final summary = data['summary'] as Map<String, dynamic>? ?? {};
        final records = data['records'] as List<dynamic>? ?? [];
        final percent = summary['percent'] as num?;

        return RefreshIndicator(
          onRefresh: () async => setState(() => _future = _load()),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              // The month's numbers as a 2-column grid of StatCards —
              // the same layout every dashboard in the app uses.
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.5,
                children: [
                  StatCard(
                    label: 'Attendance',
                    value: percent != null ? '$percent%' : '–',
                    icon: Icons.percent,
                  ),
                  StatCard(
                    label: 'Present',
                    value: '${summary['present'] ?? 0}',
                    icon: Icons.check_circle_outline,
                    color: const Color(0xFF15803D),
                  ),
                  StatCard(
                    label: 'Absent',
                    value: '${summary['absent'] ?? 0}',
                    icon: Icons.cancel_outlined,
                    color: const Color(0xFFB91C1C),
                  ),
                  StatCard(
                    label: 'Late',
                    value: '${summary['late'] ?? 0}',
                    icon: Icons.schedule,
                    color: const Color(0xFFB45309),
                  ),
                ],
              ),
              SectionHeader('Day by day${month.isNotEmpty ? ' · $month' : ''}'),
              if (records.isEmpty)
                const EmptyState(
                  icon: Icons.event_available,
                  message: 'No attendance recorded this month yet.',
                )
              else
                for (final r in records) _recordTile(r as Map<String, dynamic>),
            ],
          ),
        );
      },
    );
  }

  Widget _recordTile(Map<String, dynamic> record) {
    final notes = (record['notes'] as String?) ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.calendar_today_outlined),
        title: Text((record['date'] as String?) ?? ''),
        // Only claim subtitle space when the teacher actually wrote a note.
        subtitle: notes.isNotEmpty ? Text(notes) : null,
        trailing: StatusChip((record['status'] as String?) ?? 'unknown'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Homework tab (read-only — parents watch, students submit)
// ---------------------------------------------------------------------------

/// GET /parent/children/{id}/homework →
///   { "homework": [ {id, title, instructions, subject, teacher, class,
///                    due_date, max_marks, is_overdue,
///                    my_submission: null | {status, content, submitted_at,
///                                           marks, feedback}} ] }
class _HomeworkTab extends StatefulWidget {
  const _HomeworkTab({required this.childId});

  final int childId;

  @override
  State<_HomeworkTab> createState() => _HomeworkTabState();
}

class _HomeworkTabState extends State<_HomeworkTab>
    with AutomaticKeepAliveClientMixin {
  late Future<Map<String, dynamic>> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final session = context.read<Session>();
    try {
      return await session.api
          .get('/parent/children/${widget.childId}/homework');
    } catch (e) {
      session.handleAuthError(e);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ApiFutureView<Map<String, dynamic>>(
      future: _future,
      onRetry: () => setState(() => _future = _load()),
      builder: (context, data) {
        final items = data['homework'] as List<dynamic>? ?? [];

        return RefreshIndicator(
          onRefresh: () async => setState(() => _future = _load()),
          child: items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    EmptyState(
                      icon: Icons.menu_book_outlined,
                      message: 'No homework assigned yet.',
                    ),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, i) =>
                      _HomeworkCard(item: items[i] as Map<String, dynamic>),
                ),
        );
      },
    );
  }
}

/// One assignment. NO submit button on purpose: the parent app is a
/// window into the child's work, submitting stays in the student app.
class _HomeworkCard extends StatelessWidget {
  const _HomeworkCard({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final subject = (item['subject'] as String?) ?? '';
    final teacher = (item['teacher'] as String?) ?? '';
    final instructions = (item['instructions'] as String?) ?? '';
    final dueDate = (item['due_date'] as String?) ?? '';
    final submission = item['my_submission'] as Map<String, dynamic>?;
    final marks = submission?['marks'] as num?;
    final feedback = (submission?['feedback'] as String?) ?? '';

    // The chip tells the story at a glance: what the CHILD did with it
    // (submitted/graded/late), or "overdue"/"pending" if nothing yet.
    final status = (submission?['status'] as String?) ??
        (item['is_overdue'] == true ? 'overdue' : 'pending');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    (item['title'] as String?) ?? 'Homework',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                StatusChip(status),
              ],
            ),
            if (subject.isNotEmpty || teacher.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                [
                  if (subject.isNotEmpty) subject,
                  if (teacher.isNotEmpty) teacher,
                ].join(' · '),
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ],
            if (instructions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                instructions,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (dueDate.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.event, size: 15, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 5),
                  Text(
                    'Due $dueDate',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
            // Only graded work has marks — show them plus any comment
            // the teacher left, so parents get the full picture.
            if (marks != null) ...[
              const SizedBox(height: 8),
              Text(
                'Marks: ${_num(marks)} / ${_num(item['max_marks'] as num?)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
            if (feedback.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Teacher: $feedback',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Results tab
// ---------------------------------------------------------------------------

/// GET /parent/children/{id}/results →
///   { "results": [ {id, exam, subject, term, date, marks_obtained,
///                   max_marks, grade, is_absent} ] }
class _ResultsTab extends StatefulWidget {
  const _ResultsTab({required this.childId});

  final int childId;

  @override
  State<_ResultsTab> createState() => _ResultsTabState();
}

class _ResultsTabState extends State<_ResultsTab>
    with AutomaticKeepAliveClientMixin {
  late Future<Map<String, dynamic>> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final session = context.read<Session>();
    try {
      return await session.api
          .get('/parent/children/${widget.childId}/results');
    } catch (e) {
      session.handleAuthError(e);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ApiFutureView<Map<String, dynamic>>(
      future: _future,
      onRetry: () => setState(() => _future = _load()),
      builder: (context, data) {
        final results = data['results'] as List<dynamic>? ?? [];

        return RefreshIndicator(
          onRefresh: () async => setState(() => _future = _load()),
          child: results.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    EmptyState(
                      icon: Icons.grade_outlined,
                      message: 'No exam results yet.',
                    ),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: results.length,
                  itemBuilder: (context, i) =>
                      _resultTile(context, results[i] as Map<String, dynamic>),
                ),
        );
      },
    );
  }

  Widget _resultTile(BuildContext context, Map<String, dynamic> result) {
    final scheme = Theme.of(context).colorScheme;

    final grade = (result['grade'] as String?) ?? '';
    final subject = (result['subject'] as String?) ?? '';
    final term = (result['term'] as String?) ?? '';
    final date = (result['date'] as String?) ?? '';
    final isAbsent = result['is_absent'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Text(
            // The grade makes the best avatar; fall back to a generic
            // icon-ish letter when the exam is ungraded or missed.
            grade.isNotEmpty ? grade : (isAbsent ? '–' : '#'),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: scheme.onPrimaryContainer,
            ),
          ),
        ),
        title: Text(
          (result['exam'] as String?) ?? 'Exam',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text([
          if (subject.isNotEmpty) subject,
          if (term.isNotEmpty) term,
          if (date.isNotEmpty) date,
        ].join(' · ')),
        trailing: isAbsent
            ? const StatusChip('absent')
            : Text(
                '${_num(result['marks_obtained'] as num?)} / ${_num(result['max_marks'] as num?)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fees tab
// ---------------------------------------------------------------------------

/// GET /parent/children/{id}/fees →
///   { "totals": {due, paid},
///     "invoices": [ {id, invoice_number, fee_type, period, due_date,
///                    status, is_overdue, amount, paid, balance} ],
///     "payments": [ {receipt_number, amount, method, paid_at,
///                    invoice_number} ] }
class _FeesTab extends StatefulWidget {
  const _FeesTab({required this.childId});

  final int childId;

  @override
  State<_FeesTab> createState() => _FeesTabState();
}

class _FeesTabState extends State<_FeesTab>
    with AutomaticKeepAliveClientMixin {
  late Future<Map<String, dynamic>> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final session = context.read<Session>();
    try {
      return await session.api.get('/parent/children/${widget.childId}/fees');
    } catch (e) {
      session.handleAuthError(e);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // watch: if the school's currency symbol ever changes mid-session
    // (re-login to another school), the amounts re-render correctly.
    final currency = context.watch<Session>().currency;

    return ApiFutureView<Map<String, dynamic>>(
      future: _future,
      onRetry: () => setState(() => _future = _load()),
      builder: (context, data) {
        final totals = data['totals'] as Map<String, dynamic>? ?? {};
        final invoices = data['invoices'] as List<dynamic>? ?? [];
        final payments = data['payments'] as List<dynamic>? ?? [];
        final due = (totals['due'] as num? ?? 0).toDouble();
        final paid = (totals['paid'] as num? ?? 0).toDouble();

        return RefreshIndicator(
          onRefresh: () async => setState(() => _future = _load()),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.5,
                children: [
                  StatCard(
                    label: 'Balance due',
                    value: '$currency${due.toStringAsFixed(2)}',
                    icon: Icons.hourglass_bottom,
                    // Red only when money is actually owed.
                    color: due > 0 ? const Color(0xFFB91C1C) : null,
                  ),
                  StatCard(
                    label: 'Total paid',
                    value: '$currency${paid.toStringAsFixed(2)}',
                    icon: Icons.verified_outlined,
                    color: const Color(0xFF15803D),
                  ),
                ],
              ),
              const SectionHeader('Invoices'),
              if (invoices.isEmpty)
                const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  message: 'No invoices yet.',
                )
              else
                for (final inv in invoices)
                  _InvoiceTile(
                    invoice: inv as Map<String, dynamic>,
                    currency: currency,
                  ),
              const SectionHeader('Recent payments'),
              if (payments.isEmpty)
                const EmptyState(
                  icon: Icons.payments_outlined,
                  message: 'No payments recorded yet.',
                )
              else
                for (final p in payments)
                  _paymentTile(context, p as Map<String, dynamic>, currency),
            ],
          ),
        );
      },
    );
  }

  Widget _paymentTile(
    BuildContext context,
    Map<String, dynamic> payment,
    String currency,
  ) {
    final method = (payment['method'] as String?) ?? '';
    final paidAt = (payment['paid_at'] as String?) ?? '';
    final invoiceNo = (payment['invoice_number'] as String?) ?? '';
    final amount = (payment['amount'] as num? ?? 0).toDouble();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.receipt_outlined),
        title: Text(
          'Receipt ${payment['receipt_number'] ?? '–'}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text([
          if (method.isNotEmpty) method,
          if (paidAt.isNotEmpty) paidAt,
          if (invoiceNo.isNotEmpty) invoiceNo,
        ].join(' · ')),
        trailing: Text(
          '$currency${amount.toStringAsFixed(2)}',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: Color(0xFF15803D), // paid money = green
          ),
        ),
      ),
    );
  }
}

/// One invoice row. Custom layout (not a ListTile) because we stack a
/// StatusChip ABOVE the balance on the right — a ListTile's trailing
/// slot is too short for both and would overflow on small phones.
class _InvoiceTile extends StatelessWidget {
  const _InvoiceTile({required this.invoice, required this.currency});

  final Map<String, dynamic> invoice;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final feeType = (invoice['fee_type'] as String?) ?? 'Fee';
    final number = (invoice['invoice_number'] as String?) ?? '';
    final period = (invoice['period'] as String?) ?? '';
    final dueDate = (invoice['due_date'] as String?) ?? '';
    final balance = (invoice['balance'] as num? ?? 0).toDouble();
    // "overdue" beats the raw status: an unpaid invoice past its due
    // date is the thing a parent most needs to notice.
    final status = invoice['is_overdue'] == true
        ? 'overdue'
        : (invoice['status'] as String?) ?? 'pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feeType,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (number.isNotEmpty) number,
                      if (period.isNotEmpty) period,
                      if (dueDate.isNotEmpty) 'Due $dueDate',
                    ].join(' · '),
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusChip(status),
                const SizedBox(height: 6),
                Text(
                  // The remaining balance is what a parent cares about,
                  // not the original invoice amount.
                  '$currency${balance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Timetable tab
// ---------------------------------------------------------------------------

/// GET /parent/children/{id}/timetable → same {today, days} shape the
/// student and teacher screens use, so the shared TimetableView widget
/// does all the rendering work here.
class _TimetableTab extends StatefulWidget {
  const _TimetableTab({required this.childId});

  final int childId;

  @override
  State<_TimetableTab> createState() => _TimetableTabState();
}

class _TimetableTabState extends State<_TimetableTab>
    with AutomaticKeepAliveClientMixin {
  late Future<Map<String, dynamic>> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final session = context.read<Session>();
    try {
      return await session.api
          .get('/parent/children/${widget.childId}/timetable');
    } catch (e) {
      session.handleAuthError(e);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ApiFutureView<Map<String, dynamic>>(
      future: _future,
      onRetry: () => setState(() => _future = _load()),
      builder: (context, data) {
        final section = (data['section'] as String?) ?? '';

        return RefreshIndicator(
          onRefresh: () async => setState(() => _future = _load()),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              if (section.isNotEmpty) ...[
                Text(
                  section,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 10),
              ],
              // The shared widget handles the day picker + period cards.
              TimetableView(data: data),
            ],
          ),
        );
      },
    );
  }
}

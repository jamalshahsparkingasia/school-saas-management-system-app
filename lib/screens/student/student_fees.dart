import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/session.dart';
import '../../widgets/common.dart';

// Shared "money mood" colours (same values StatusChip uses).
const _dangerRed = Color(0xFFB91C1C);
const _okGreen = Color(0xFF15803D);

/// Formats a number as money WITHOUT the intl package: whole amounts
/// show as "200", fractional ones as "12.50".
String _money(num value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(2);

/// The fees tab: how much is owed vs paid, every invoice with its
/// remaining balance, and the recent payment receipts underneath.
class StudentFeesScreen extends StatefulWidget {
  const StudentFeesScreen({super.key});

  @override
  State<StudentFeesScreen> createState() => _StudentFeesScreenState();
}

class _StudentFeesScreenState extends State<StudentFeesScreen> {
  // Held in State so rebuilds never re-fire the request.
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final session = context.read<Session>();
    try {
      return await session.api.get('/student/fees');
    } catch (e) {
      session.handleAuthError(e); // 401 → back to login
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    // watch (not read) because the currency symbol comes from the
    // session and is printed all over this screen.
    final session = context.watch<Session>();

    return Scaffold(
      appBar: AppBar(title: const Text('Fees')),
      body: ApiFutureView<Map<String, dynamic>>(
        future: _future,
        onRetry: () => setState(() => _future = _load()),
        builder: (context, data) {
          final totals = data['totals'] as Map<String, dynamic>? ?? {};
          final invoices = data['invoices'] as List<dynamic>? ?? [];
          final payments = data['payments'] as List<dynamic>? ?? [];

          return RefreshIndicator(
            onRefresh: () async => setState(() => _future = _load()),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                // The two numbers a parent/student cares about most.
                StatGrid(cards: [
                  StatCard(
                    label: 'Due',
                    value:
                        '${session.currency}${_money(totals['due'] as num? ?? 0)}',
                    icon: Icons.hourglass_bottom,
                    color: _dangerRed,
                  ),
                  StatCard(
                    label: 'Paid',
                    value:
                        '${session.currency}${_money(totals['paid'] as num? ?? 0)}',
                    icon: Icons.verified_outlined,
                    color: _okGreen,
                  ),
                ]),

                const SectionHeader('Invoices'),
                if (invoices.isEmpty)
                  const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    message: 'No invoices yet.',
                  )
                else
                  ...invoices.map((inv) => _invoiceCard(
                      context, inv as Map<String, dynamic>, session.currency)),

                const SectionHeader('Recent payments'),
                if (payments.isEmpty)
                  const EmptyState(
                    icon: Icons.payments_outlined,
                    message: 'No payments recorded yet.',
                  )
                else
                  // Receipts are short, uniform rows — so they share ONE
                  // SoftCard, separated by hairline dividers (the same
                  // grouped-list pattern as the "More" tab).
                  SoftCard(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        for (var i = 0; i < payments.length; i++) ...[
                          _paymentTile(
                              context,
                              payments[i] as Map<String, dynamic>,
                              session.currency),
                          if (i != payments.length - 1)
                            const Divider(
                                height: 1, indent: 72, endIndent: 16),
                        ],
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

  /// One invoice as its own SoftCard. Built with a plain Row (not a
  /// ListTile) because the right side stacks a chip on top of two
  /// amounts — more than a ListTile's `trailing` slot can hold.
  Widget _invoiceCard(
      BuildContext context, Map<String, dynamic> inv, String currency) {
    final overdue = inv['is_overdue'] == true;
    final balance = inv['balance'] as num? ?? 0;

    return SoftCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (inv['fee_type'] as String?) ?? 'Fee',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${inv['invoice_number'] ?? ''} · ${inv['period'] ?? ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7686),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Due ${inv['due_date'] ?? '-'}',
                  style: TextStyle(
                    fontSize: 12,
                    // Red + bold when the deadline has passed.
                    color: overdue ? _dangerRed : const Color(0xFF6B7686),
                    fontWeight: overdue ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Show 'overdue' in the chip even when the raw status
              // says 'pending' — it's the more urgent truth.
              StatusChip(
                  overdue ? 'overdue' : (inv['status'] as String?) ?? ''),
              const SizedBox(height: 6),
              // The BALANCE is the emphasized number: it's what still
              // needs paying (green zero = settled).
              Text(
                '$currency${_money(balance)}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: balance > 0 ? _dangerRed : _okGreen,
                ),
              ),
              Text(
                'of $currency${_money(inv['amount'] as num? ?? 0)}',
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

  /// One payment receipt — a row inside the grouped receipts card.
  Widget _paymentTile(
      BuildContext context, Map<String, dynamic> pay, String currency) {
    return ListTile(
      leading: IconBadge(Icons.receipt_outlined, color: _okGreen),
      title: Text(
        '$currency${_money(pay['amount'] as num? ?? 0)} · ${pay['method'] ?? ''}',
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
      ),
      subtitle: Text(
        '${pay['receipt_number'] ?? ''} · ${pay['invoice_number'] ?? ''}',
      ),
      trailing: Text(
        (pay['paid_at'] as String?) ?? '',
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF6B7686),
        ),
      ),
    );
  }
}

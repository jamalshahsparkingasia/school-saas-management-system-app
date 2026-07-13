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
              padding: const EdgeInsets.all(16),
              children: [
                // The two numbers a parent/student cares about most.
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.5,
                  children: [
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
                  ],
                ),

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
                  ...payments.map((p) => _paymentTile(
                      context, p as Map<String, dynamic>, session.currency)),
              ],
            ),
          );
        },
      ),
    );
  }

  /// One invoice. Built with a plain Row (not a ListTile) because the
  /// right side stacks a chip on top of two amounts — more than a
  /// ListTile's `trailing` slot can comfortably hold.
  Widget _invoiceCard(
      BuildContext context, Map<String, dynamic> inv, String currency) {
    final scheme = Theme.of(context).colorScheme;
    final overdue = inv['is_overdue'] == true;
    final balance = inv['balance'] as num? ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (inv['fee_type'] as String?) ?? 'Fee',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${inv['invoice_number'] ?? ''} · ${inv['period'] ?? ''}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  Text(
                    'Due ${inv['due_date'] ?? '-'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          // Red + bold when the deadline has passed.
                          color:
                              overdue ? _dangerRed : scheme.onSurfaceVariant,
                          fontWeight: overdue ? FontWeight.w700 : null,
                        ),
                  ),
                ],
              ),
            ),
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: balance > 0 ? _dangerRed : _okGreen,
                      ),
                ),
                Text(
                  'of $currency${_money(inv['amount'] as num? ?? 0)}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// One payment receipt — a simple tile, no card needed.
  Widget _paymentTile(
      BuildContext context, Map<String, dynamic> pay, String currency) {
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _okGreen.withValues(alpha: .12),
        child: const Icon(Icons.receipt_outlined, color: _okGreen),
      ),
      title: Text(
        '$currency${_money(pay['amount'] as num? ?? 0)} · ${pay['method'] ?? ''}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${pay['receipt_number'] ?? ''} · ${pay['invoice_number'] ?? ''}',
        style: TextStyle(color: scheme.onSurfaceVariant),
      ),
      trailing: Text(
        (pay['paid_at'] as String?) ?? '',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

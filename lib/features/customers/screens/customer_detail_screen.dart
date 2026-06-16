import 'package:flutter/material.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/money.dart';
import '../../auth/models/app_profile.dart';
import '../data/customer_repository.dart';
import '../models/customer.dart';
import 'customer_form_screen.dart';
import 'record_payment_screen.dart';

class CustomerDetailScreen extends StatefulWidget {
  const CustomerDetailScreen({super.key, required this.customer, required this.profile});
  final Customer customer;
  final AppProfile profile;

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  final _repo = CustomerRepository();
  late Customer _customer;
  late Future<(List<Map<String, dynamic>>, List<Map<String, dynamic>>)> _future;

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
    _reload();
  }

  void _reload() {
    setState(() {
      _future = Future.wait([
        _repo.listCreditSales(_customer.id),
        _repo.listPayments(_customer.id),
      ]).then((r) => (r[0], r[1]));
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canEdit = widget.profile.isOwner || widget.profile.isManager;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_customer.name),
          actions: [
            if (canEdit)
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit customer',
                onPressed: () async {
                  final updated = await Navigator.of(context).push<bool>(MaterialPageRoute(
                    builder: (_) => CustomerFormScreen(profile: widget.profile, customer: _customer),
                  ));
                  if (updated == true && mounted) Navigator.of(context).pop(true);
                },
              ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Credit Sales'),
              Tab(text: 'Payments'),
            ],
          ),
        ),
        body: Column(
          children: [
            _CustomerHeader(
              customer: _customer,
              cs: cs,
              onRecordPayment: () async {
                final recorded = await Navigator.of(context).push<bool>(MaterialPageRoute(
                  builder: (_) => RecordPaymentScreen(customer: _customer),
                ));
                if (recorded == true && mounted) Navigator.of(context).pop(true);
              },
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<(List<Map<String, dynamic>>, List<Map<String, dynamic>>)>(
                future: _future,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 12),
                          Text(
                            friendlyError(snap.error!, fallback: 'Could not load customer data.'),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _reload,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try Again'),
                          ),
                        ]),
                      ),
                    );
                  }
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  final (sales, payments) = snap.data!;
                  return TabBarView(children: [
                    _CreditSalesList(sales: sales),
                    _PaymentsList(payments: payments),
                  ]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerHeader extends StatelessWidget {
  const _CustomerHeader({required this.customer, required this.cs, required this.onRecordPayment});
  final Customer customer;
  final ColorScheme cs;
  final VoidCallback onRecordPayment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: cs.primaryContainer,
                child: Icon(Icons.person, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                          customer.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      if (!customer.isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('Inactive',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                        ),
                    ]),
                    if (customer.phone != null) ...[
                      const SizedBox(height: 3),
                      Row(children: [
                        const Icon(Icons.phone_outlined, size: 14, color: Colors.black45),
                        const SizedBox(width: 4),
                        Text(customer.phone!, style: const TextStyle(fontSize: 13)),
                      ]),
                    ],
                    if (customer.location != null) ...[
                      const SizedBox(height: 3),
                      Row(children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: Colors.black45),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(customer.location!, style: const TextStyle(fontSize: 13)),
                        ),
                      ]),
                    ],
                    if (customer.notes != null) ...[
                      const SizedBox(height: 3),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.notes_outlined, size: 14, color: Colors.black45),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(customer.notes!,
                              style: const TextStyle(fontSize: 13, color: Colors.black54)),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            color: customer.hasDebt ? cs.errorContainer : Colors.green.shade50,
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(
                Icons.account_balance_wallet_outlined,
                color: customer.hasDebt ? cs.error : Colors.green.shade700,
              ),
              title: Text(
                customer.hasDebt ? 'Outstanding balance' : 'No outstanding debt',
                style: const TextStyle(fontSize: 14),
              ),
              trailing: Text(
                money(customer.totalBalance),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: customer.hasDebt ? cs.error : Colors.green.shade700,
                ),
              ),
            ),
          ),
          if (customer.hasDebt) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: onRecordPayment,
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Record Payment'),
            ),
          ],
        ],
      ),
    );
  }
}

class _CreditSalesList extends StatelessWidget {
  const _CreditSalesList({required this.sales});
  final List<Map<String, dynamic>> sales;

  @override
  Widget build(BuildContext context) {
    if (sales.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No credit sales yet.', textAlign: TextAlign.center),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: sales.length,
      itemBuilder: (context, i) {
        final s = sales[i];
        final status = s['payment_status'] as String? ?? 'unpaid';
        final date = DateTime.tryParse(s['created_at'] as String? ?? '');
        final balance = (s['balance_amount'] as num).toDouble();

        Color statusColor() {
          switch (status) {
            case 'paid':
              return Colors.green.shade700;
            case 'partial':
              return Colors.orange.shade700;
            default:
              return Colors.red.shade700;
          }
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Row(children: [
              Expanded(
                child: Text(s['invoice_no'] as String? ?? '-',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor().withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(status.toUpperCase(),
                    style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.bold, color: statusColor())),
              ),
            ]),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (date != null)
                  Text(formatDateTime(date),
                      style: const TextStyle(fontSize: 11, color: Colors.black45)),
                const SizedBox(height: 2),
                Row(children: [
                  Text('Total: ${money((s['total_amount'] as num).toDouble())}',
                      style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 12),
                  Text('Balance: ${money(balance)}',
                      style: TextStyle(
                          fontSize: 12,
                          color: balance > 0 ? Colors.red.shade700 : Colors.green.shade700)),
                ]),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}

class _PaymentsList extends StatelessWidget {
  const _PaymentsList({required this.payments});
  final List<Map<String, dynamic>> payments;

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No payments recorded yet.', textAlign: TextAlign.center),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: payments.length,
      itemBuilder: (context, i) {
        final p = payments[i];
        final date = DateTime.tryParse(p['created_at'] as String? ?? '');
        final method = p['payment_method'] as String? ?? 'cash';
        final refNo = p['reference_no'] as String?;
        final receivedBy =
            (p['profiles'] as Map<String, dynamic>?)?['full_name'] as String?;

        String methodLabel() {
          switch (method) {
            case 'bank':
              return 'Bank transfer';
            case 'mobile_money':
              return 'Mobile money';
            default:
              return 'Cash';
          }
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green.shade50,
              child: Icon(Icons.check_circle_outline, color: Colors.green.shade700),
            ),
            title: Text(money((p['amount'] as num).toDouble()),
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(methodLabel(), style: const TextStyle(fontSize: 12)),
                if (refNo != null)
                  Text('Ref: $refNo', style: const TextStyle(fontSize: 12)),
                if (receivedBy != null)
                  Text('Received by: $receivedBy',
                      style: const TextStyle(fontSize: 11, color: Colors.black45)),
                if (date != null)
                  Text(formatDateTime(date),
                      style: const TextStyle(fontSize: 11, color: Colors.black45)),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}

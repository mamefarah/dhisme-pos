import 'package:flutter/material.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/models/app_profile.dart';
import '../data/sales_repository.dart';
import 'receipt_screen.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key, required this.profile});
  final AppProfile profile;

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final _repo = SalesRepository();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.salesHistory();
  }

  void _reload() => setState(() => _future = _repo.salesHistory());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales History'),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    const Text(
                      'Could not load sales history.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final sales = snapshot.data!;
          if (sales.isEmpty) {
            return const EmptyState(
              message: 'No sales yet. Completed sales will appear here.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: sales.length,
              itemBuilder: (context, i) => _SaleTile(
                sale: sales[i],
                profile: widget.profile,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SaleTile extends StatelessWidget {
  const _SaleTile({required this.sale, required this.profile});
  final Map<String, dynamic> sale;
  final AppProfile profile;

  String get _invoiceLabel {
    final inv = sale['invoice_no'] as String?;
    if (inv != null && inv.isNotEmpty) return inv;
    final id = sale['id'] as String? ?? '';
    return id.length >= 8 ? '#${id.substring(0, 8).toUpperCase()}' : '#$id';
  }

  String get _sellerName =>
      (sale['profiles'] as Map?)?['full_name'] as String? ?? '—';

  String get _customerName =>
      (sale['customers'] as Map?)?['name'] as String? ?? 'Walk-in customer';

  String get _dateLabel {
    final raw = sale['created_at'] as String?;
    if (raw == null) return '—';
    final dt = DateTime.tryParse(raw);
    return dt != null ? formatDateTime(dt) : raw;
  }

  String get _paymentLabel {
    switch (sale['payment_method'] as String?) {
      case 'cash':
        return 'Cash';
      case 'bank':
        return 'Bank transfer';
      case 'mobile_money':
        return 'Mobile money';
      case 'credit_request':
        return 'Credit';
      default:
        return sale['payment_method'] as String? ?? '—';
    }
  }

  Color _statusColor(BuildContext context) {
    switch ((sale['status'] as String?)?.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  String get _statusLabel {
    final s = sale['status'] as String?;
    if (s == null || s.isEmpty) return 'Completed';
    return s[0].toUpperCase() + s.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final total = (sale['total_amount'] as num?)?.toDouble() ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ReceiptScreen(
                saleId: sale['id'] as String,
                profile: profile,
                initialData: sale,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _invoiceLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor(context).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _statusLabel,
                      style: TextStyle(
                        color: _statusColor(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 13, color: Colors.black45),
                  const SizedBox(width: 4),
                  Text(_dateLabel, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  const Spacer(),
                  Text(
                    money(total),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 13, color: Colors.black45),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _customerName,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _paymentIcon,
                    size: 13,
                    color: Colors.black45,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _paymentLabel,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
              if (profile.isOwner) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.badge_outlined, size: 13, color: Colors.black45),
                    const SizedBox(width: 4),
                    Text(
                      'Seller: $_sellerName',
                      style: const TextStyle(fontSize: 12, color: Colors.black45),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData get _paymentIcon {
    switch (sale['payment_method'] as String?) {
      case 'cash':
        return Icons.payments_outlined;
      case 'bank':
        return Icons.account_balance_outlined;
      case 'mobile_money':
        return Icons.phone_android_outlined;
      case 'credit_request':
        return Icons.credit_score_outlined;
      default:
        return Icons.payment_outlined;
    }
  }
}

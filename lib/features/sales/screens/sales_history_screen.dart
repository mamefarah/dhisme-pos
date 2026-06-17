import 'package:flutter/material.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/models/app_profile.dart';
import '../data/sales_repository.dart';
import 'receipt_screen.dart';

enum _DateFilter { today, thisWeek, thisMonth, all }

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key, required this.profile});
  final AppProfile profile;

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final _repo = SalesRepository();
  final _searchCtrl = TextEditingController();
  late Future<List<Map<String, dynamic>>> _future;
  _DateFilter _dateFilter = _DateFilter.today;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  (DateTime? from, DateTime? to) get _dateRange {
    final now = DateTime.now();
    switch (_dateFilter) {
      case _DateFilter.today:
        final start = DateTime(now.year, now.month, now.day);
        return (start, start.add(const Duration(days: 1)));
      case _DateFilter.thisWeek:
        final start = DateTime(now.year, now.month, now.day - (now.weekday - 1));
        return (start, now.add(const Duration(days: 1)));
      case _DateFilter.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        return (start, now.add(const Duration(days: 1)));
      case _DateFilter.all:
        return (null, null);
    }
  }

  void _reload() {
    final (from, to) = _dateRange;
    setState(() {
      _future = _repo.salesHistory(from: from, to: to, limit: _dateFilter == _DateFilter.all ? 200 : 500);
    });
  }

  List<Map<String, dynamic>> _applySearch(List<Map<String, dynamic>> sales) {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return sales;
    return sales.where((s) {
      final invoice = (s['invoice_no'] as String? ?? '').toLowerCase();
      final customer = ((s['customers'] as Map?)?['name'] as String? ?? '').toLowerCase();
      final seller = ((s['profiles'] as Map?)?['full_name'] as String? ?? '').toLowerCase();
      return invoice.contains(q) || customer.contains(q) || seller.contains(q);
    }).toList();
  }

  String _emptyMessage(BuildContext context) {
    switch (_dateFilter) {
      case _DateFilter.today:
        return context.tr('Maanta weli iib ma jiro.', 'No sales today yet.');
      case _DateFilter.thisWeek:
        return context.tr('Toddobaadkan weli iib ma jiro.', 'No sales this week yet.');
      case _DateFilter.thisMonth:
        return context.tr('Bishan weli iib ma jiro.', 'No sales this month yet.');
      case _DateFilter.all:
        return context.tr('Weli iib ma jiro. Iibka dhammaaday halkan ayuu ka muuqan doonaa.', 'No sales yet. Completed sales will appear here.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLanguage.instance,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(context.tr('Taariikhda Iibka', 'Sales History')),
          actions: [IconButton(onPressed: _reload, icon: const Icon(Icons.refresh), tooltip: context.tr('Cusboonaysii', 'Refresh'))],
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                labelText: context.tr('Ku raadi invoice, macmiil, ama iibiye', 'Search by invoice, customer, or seller'),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _DateChip(label: context.tr('Maanta', 'Today'), selected: _dateFilter == _DateFilter.today, onTap: () { setState(() => _dateFilter = _DateFilter.today); _reload(); }),
                const SizedBox(width: 8),
                _DateChip(label: context.tr('Toddobaadkan', 'This Week'), selected: _dateFilter == _DateFilter.thisWeek, onTap: () { setState(() => _dateFilter = _DateFilter.thisWeek); _reload(); }),
                const SizedBox(width: 8),
                _DateChip(label: context.tr('Bishan', 'This Month'), selected: _dateFilter == _DateFilter.thisMonth, onTap: () { setState(() => _dateFilter = _DateFilter.thisMonth); _reload(); }),
                const SizedBox(width: 8),
                _DateChip(label: context.tr('Dhammaan', 'All'), selected: _dateFilter == _DateFilter.all, onTap: () { setState(() => _dateFilter = _DateFilter.all); _reload(); }),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(friendlyError(snapshot.error!, fallback: context.tr('Taariikhda iibka lama soo gelin karin.', 'Could not load sales history.')), textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton.icon(onPressed: _reload, icon: const Icon(Icons.refresh), label: Text(context.tr('Mar kale isku day', 'Try Again'))),
                      ]),
                    ),
                  );
                }
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final filtered = _applySearch(snapshot.data!);
                if (snapshot.data!.isEmpty) return EmptyState(message: _emptyMessage(context));
                if (filtered.isEmpty) return EmptyState(message: context.tr('Iib ku habboon raadinta lama helin.', 'No sales match your search.'));
                final total = filtered.fold<double>(0, (s, e) => s + ((e['total_amount'] as num?)?.toDouble() ?? 0));
                return Column(children: [
                  Container(
                    color: Colors.grey.shade100,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(children: [
                      Text(context.tr('${filtered.length} iib', '${filtered.length} sale${filtered.length == 1 ? '' : 's'}'), style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      const Spacer(),
                      Text(money(total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ]),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async => _reload(),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) => _SaleTile(sale: filtered[i], profile: widget.profile),
                      ),
                    ),
                  ),
                ]);
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(color: selected ? c.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20), border: Border.all(color: selected ? c : Colors.grey.shade300)),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.bold : FontWeight.normal, color: selected ? c : Colors.black54)),
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

  String get _sellerName => (sale['profiles'] as Map?)?['full_name'] as String? ?? '—';
  String _customerName(BuildContext context) => (sale['customers'] as Map?)?['name'] as String? ?? context.tr('Macmiil socod ah', 'Walk-in customer');

  String get _dateLabel {
    final raw = sale['created_at'] as String?;
    if (raw == null) return '—';
    final dt = DateTime.tryParse(raw);
    return dt != null ? formatDateTime(dt) : raw;
  }

  String _paymentLabel(BuildContext context) {
    final saleType = sale['sale_type'] as String?;
    if (saleType == 'credit') return sale['payment_status'] == 'paid' ? context.tr('Deyn (la bixiyay)', 'Credit (paid)') : context.tr('Deyn', 'Credit');
    switch (sale['payment_method'] as String?) {
      case 'cash':
        return context.tr('Caddaan', 'Cash');
      case 'bank':
        return context.tr('Bangiga', 'Bank Transfer');
      case 'mobile_money':
        return 'Mobile Money';
      case 'mixed':
        return context.tr('Isku dhafan', 'Mixed');
      default:
        return saleType == 'partial' ? context.tr('Qayb bixin', 'Partial') : (saleType ?? '—');
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

  String _statusLabel(BuildContext context) {
    final s = (sale['status'] as String?)?.toLowerCase();
    switch (s) {
      case 'pending':
        return context.tr('Sugaya', 'Pending');
      case 'cancelled':
        return context.tr('La joojiyay', 'Cancelled');
      case 'completed':
      case null:
      case '':
        return context.tr('Dhammaystiran', 'Completed');
      default:
        return s[0].toUpperCase() + s.substring(1);
    }
  }

  IconData get _paymentIcon {
    final saleType = sale['sale_type'] as String?;
    if (saleType == 'credit') return Icons.credit_score_outlined;
    switch (sale['payment_method'] as String?) {
      case 'bank': return Icons.account_balance_outlined;
      case 'mobile_money': return Icons.phone_android_outlined;
      default: return Icons.payments_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = (sale['total_amount'] as num?)?.toDouble() ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReceiptScreen(saleId: sale['id'] as String, profile: profile, initialData: sale))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(_invoiceLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _statusColor(context).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Text(_statusLabel(context), style: TextStyle(color: _statusColor(context), fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.calendar_today_outlined, size: 13, color: Colors.black45),
              const SizedBox(width: 4),
              Text(_dateLabel, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              const Spacer(),
              Text(money(total), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Theme.of(context).colorScheme.primary)),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.person_outline, size: 13, color: Colors.black45),
              const SizedBox(width: 4),
              Expanded(child: Text(_customerName(context), style: const TextStyle(fontSize: 12, color: Colors.black54), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              Icon(_paymentIcon, size: 13, color: Colors.black45),
              const SizedBox(width: 4),
              Text(_paymentLabel(context), style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ]),
            if (profile.isOwner) ...[
              const SizedBox(height: 2),
              Row(children: [
                const Icon(Icons.badge_outlined, size: 13, color: Colors.black45),
                const SizedBox(width: 4),
                Text('${context.tr('Iibiye', 'Seller')}: $_sellerName', style: const TextStyle(fontSize: 12, color: Colors.black45)),
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}

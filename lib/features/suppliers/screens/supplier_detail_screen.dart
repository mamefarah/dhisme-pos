import 'package:flutter/material.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/money.dart';
import '../data/supplier_repository.dart';
import '../models/supplier.dart';
import 'supplier_form_screen.dart';
import 'supplier_payment_screen.dart';

class SupplierDetailScreen extends StatefulWidget {
  const SupplierDetailScreen({super.key, required this.supplier});
  final Supplier supplier;

  @override
  State<SupplierDetailScreen> createState() => _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends State<SupplierDetailScreen> {
  final _repo = SupplierRepository();
  late Future<(List<Map<String, dynamic>>, List<Map<String, dynamic>>)> _future;

  @override
  void initState() { super.initState(); _reload(); }
  void _reload() => setState(() => _future = Future.wait([_repo.listPurchases(widget.supplier.id), _repo.listPayments(widget.supplier.id)]).then((r) => (r[0], r[1])));

  @override
  Widget build(BuildContext context) {
    final s = widget.supplier;
    return AnimatedBuilder(
      animation: AppLanguage.instance,
      builder: (context, _) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: Text(s.name),
            actions: [IconButton(icon: const Icon(Icons.edit_outlined), tooltip: context.tr('Wax ka beddel', 'Edit'), onPressed: () async { await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SupplierFormScreen(supplier: s))); if (mounted) Navigator.of(context).pop(true); })],
            bottom: TabBar(tabs: [Tab(text: context.tr('Iibsiyo', 'Purchases')), Tab(text: context.tr('Bixinno', 'Payments'))]),
          ),
          body: Column(children: [
            Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [CircleAvatar(backgroundColor: Colors.teal.withValues(alpha: 0.12), child: const Icon(Icons.local_shipping_outlined, color: Colors.teal)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(s.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), if (s.phone != null) Text(s.phone!, style: const TextStyle(fontSize: 13, color: Colors.black54)), if (s.contactPerson != null) Text('${context.tr('Xiriir', 'Contact')}: ${s.contactPerson}', style: const TextStyle(fontSize: 13, color: Colors.black54))]))]),
              const SizedBox(height: 12),
              Card(color: s.hasDebt ? Colors.orange.shade50 : Colors.green.shade50, margin: EdgeInsets.zero, child: ListTile(leading: Icon(Icons.account_balance_wallet_outlined, color: s.hasDebt ? Colors.orange.shade800 : Colors.green.shade700), title: Text(s.hasDebt ? context.tr('Deyn taagan', 'Outstanding balance') : context.tr('Deyn ma jirto', 'No supplier debt')), trailing: Text(money(s.totalBalance), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: s.hasDebt ? Colors.orange.shade800 : Colors.green.shade700)))),
              if (s.hasDebt) ...[const SizedBox(height: 10), FilledButton.icon(onPressed: () async { final paid = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => SupplierPaymentScreen(supplier: s))); if (paid == true && mounted) Navigator.of(context).pop(true); }, icon: const Icon(Icons.payments_outlined), label: Text(context.tr('Diiwaangeli Bixin', 'Record Payment')))],
            ])),
            const Divider(height: 1),
            Expanded(child: FutureBuilder<(List<Map<String, dynamic>>, List<Map<String, dynamic>>)>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(friendlyError(snapshot.error!, fallback: context.tr('Xogta alaab-qeybiyaha lama soo gelin karin.', 'Could not load supplier data.')), textAlign: TextAlign.center)));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final (purchases, payments) = snapshot.data!;
                return TabBarView(children: [_PurchaseList(rows: purchases), _PaymentList(rows: payments)]);
              },
            )),
          ]),
        ),
      ),
    );
  }
}

class _PurchaseList extends StatelessWidget {
  const _PurchaseList({required this.rows});
  final List<Map<String, dynamic>> rows;
  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return Center(child: Text(context.tr('Weli iibsi lama diiwaangelin.', 'No purchases recorded yet.')));
    return ListView.builder(padding: const EdgeInsets.all(12), itemCount: rows.length, itemBuilder: (context, i) {
      final p = rows[i];
      final balance = ((p['balance_amount'] as num?) ?? 0).toDouble();
      return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(title: Text(p['invoice_ref'] as String? ?? context.tr('Iibsi', 'Purchase'), style: const TextStyle(fontWeight: FontWeight.w600)), subtitle: Text('${p['purchase_date'] ?? ''} • ${context.tr('Deyn', 'Balance')}: ${money(balance)}'), trailing: Text(money(((p['total_amount'] as num?) ?? 0).toDouble()), style: const TextStyle(fontWeight: FontWeight.bold))));
    });
  }
}

class _PaymentList extends StatelessWidget {
  const _PaymentList({required this.rows});
  final List<Map<String, dynamic>> rows;
  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return Center(child: Text(context.tr('Weli bixin lama diiwaangelin.', 'No payments recorded yet.')));
    return ListView.builder(padding: const EdgeInsets.all(12), itemCount: rows.length, itemBuilder: (context, i) {
      final p = rows[i];
      final dt = DateTime.tryParse(p['created_at'] as String? ?? '');
      final by = (p['profiles'] as Map?)?['full_name'] as String?;
      return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(leading: CircleAvatar(backgroundColor: Colors.green.shade50, child: Icon(Icons.check_circle_outline, color: Colors.green.shade700)), title: Text(money(((p['amount'] as num?) ?? 0).toDouble()), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700)), subtitle: Text('${p['payment_method'] ?? ''}${by != null ? ' • $by' : ''}${dt != null ? ' • ${formatDateTime(dt)}' : ''}')));
    });
  }
}

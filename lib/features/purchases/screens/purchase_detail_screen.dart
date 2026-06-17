import 'package:flutter/material.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/utils/money.dart';
import '../data/purchase_repository.dart';
import '../models/purchase.dart';

class PurchaseDetailScreen extends StatefulWidget {
  const PurchaseDetailScreen({super.key, required this.purchase});
  final Purchase purchase;

  @override
  State<PurchaseDetailScreen> createState() => _PurchaseDetailScreenState();
}

class _PurchaseDetailScreenState extends State<PurchaseDetailScreen> {
  final _repo = PurchaseRepository();
  late Future<List<PurchaseItem>> _future;

  @override
  void initState() { super.initState(); _future = _repo.getPurchaseItems(widget.purchase.id); }

  @override
  Widget build(BuildContext context) {
    final p = widget.purchase;
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: AppLanguage.instance,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(p.invoiceRef != null ? '${context.tr('Iibsi', 'Purchase')} #${p.invoiceRef}' : context.tr('Faahfaahinta Iibsiga', 'Purchase Details'))),
        body: FutureBuilder<List<PurchaseItem>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final items = snapshot.data!;
            return ListView(padding: const EdgeInsets.all(16), children: [
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
                _InfoRow(label: context.tr('Taariikh', 'Date'), value: _formatDate(p.purchaseDate)),
                if (p.supplierName != null) _InfoRow(label: context.tr('Alaab-qeybiye', 'Supplier'), value: p.supplierName!),
                if (p.invoiceRef != null) _InfoRow(label: context.tr('Invoice ref', 'Invoice ref'), value: p.invoiceRef!),
                _InfoRow(label: context.tr('Bixin', 'Payment'), value: _paymentLabel(context, p.paymentStatus), valueColor: _paymentColor(p.paymentStatus)),
                if (p.recordedByName != null) _InfoRow(label: context.tr('Diiwaangeliyay', 'Recorded by'), value: p.recordedByName!),
                if (p.notes != null && p.notes!.isNotEmpty) _InfoRow(label: context.tr('Qoraal', 'Notes'), value: p.notes!),
              ]))),
              const SizedBox(height: 12),
              Text(context.tr('Alaabta', 'Items'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...items.map((item) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(title: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600)), subtitle: Text('${item.quantity} ${item.unit} × ${money(item.unitCost)}'), trailing: Text(money(item.totalCost), style: const TextStyle(fontWeight: FontWeight.bold))))),
              const Divider(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(context.tr('Wadar', 'Total'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text(money(p.totalAmount), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: cs.primary))]),
            ]);
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _paymentLabel(BuildContext context, String status) { switch (status) { case 'paid': return context.tr('La bixiyay', 'Paid'); case 'partial': return context.tr('Qayb la bixiyay', 'Partially paid'); default: return context.tr('Lama bixin', 'Unpaid'); } }
  Color _paymentColor(String status) { switch (status) { case 'paid': return Colors.green.shade700; case 'partial': return Colors.orange.shade700; default: return Colors.red.shade700; } }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13))), Expanded(child: Text(value, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: valueColor)))]));
}

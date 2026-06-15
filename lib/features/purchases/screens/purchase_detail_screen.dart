import 'package:flutter/material.dart';
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
  void initState() {
    super.initState();
    _future = _repo.getPurchaseItems(widget.purchase.id);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.purchase;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(p.invoiceRef != null ? 'Purchase #${p.invoiceRef}' : 'Purchase Details')),
      body: FutureBuilder<List<PurchaseItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final items = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _InfoRow(label: 'Date', value: _formatDate(p.purchaseDate)),
                      if (p.supplierName != null)
                        _InfoRow(label: 'Supplier', value: p.supplierName!),
                      if (p.invoiceRef != null)
                        _InfoRow(label: 'Invoice ref', value: p.invoiceRef!),
                      _InfoRow(
                        label: 'Payment',
                        value: _paymentLabel(p.paymentStatus),
                        valueColor: _paymentColor(p.paymentStatus),
                      ),
                      if (p.recordedByName != null)
                        _InfoRow(label: 'Recorded by', value: p.recordedByName!),
                      if (p.notes != null && p.notes!.isNotEmpty)
                        _InfoRow(label: 'Notes', value: p.notes!),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Items
              Text('Items', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...items.map((item) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${item.quantity} ${item.unit} × ${money(item.unitCost)}',
                      ),
                      trailing: Text(
                        money(item.totalCost),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  )),

              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                    money(p.totalAmount),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _paymentLabel(String status) {
    switch (status) {
      case 'paid':    return 'Paid';
      case 'partial': return 'Partially paid';
      default:        return 'Unpaid';
    }
  }

  Color _paymentColor(String status) {
    switch (status) {
      case 'paid':    return Colors.green.shade700;
      case 'partial': return Colors.orange.shade700;
      default:        return Colors.red.shade700;
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

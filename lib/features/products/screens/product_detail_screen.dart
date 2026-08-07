import 'package:flutter/material.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/money.dart';
import '../../auth/models/app_profile.dart';
import '../data/product_repository.dart';
import '../models/product.dart';
import 'adjust_stock_screen.dart';
import 'product_form_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.product, required this.profile});
  final Product product;
  final AppProfile profile;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final _repo = ProductRepository();
  late Future<List<Map<String, dynamic>>> _movementsFuture;
  late Product _product;
  bool get _canEdit => widget.profile.isOwner || widget.profile.isManager;

  @override
  void initState() { super.initState(); _product = widget.product; _loadMovements(); }
  void _loadMovements() => _movementsFuture = _repo.listStockMovements(_product.id);
  void _reload() => setState(_loadMovements);

  String _stockText(BuildContext context) {
    if (_product.isOutOfStock) return context.tr('Kayd ma leh', 'Out of stock');
    if (_product.isLowStock) return context.tr('Kayd yar', 'Low stock');
    return context.tr('Kayd leh', 'In stock');
  }

  Color _stockColor(BuildContext context) {
    if (_product.isOutOfStock) return Theme.of(context).colorScheme.error;
    if (_product.isLowStock) return Colors.orange.shade700;
    return Colors.green.shade700;
  }

  @override
  Widget build(BuildContext context) {
    final p = _product;
    final color = _stockColor(context);
    return AnimatedBuilder(
      animation: AppLanguage.instance,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(p.name),
          actions: [
            if (_canEdit)
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: context.tr('Wax ka beddel alaabta', 'Edit product'),
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  final updated = await navigator.push<bool>(MaterialPageRoute(builder: (_) => ProductFormScreen(profile: widget.profile, product: p)));
                  if (updated == true && mounted) navigator.pop(true);
                },
              ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Card(
              color: color.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.tr('Kaydka Hadda', 'Current Stock'), style: const TextStyle(color: Colors.black54, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('${p.currentStock.toStringAsFixed(p.currentStock % 1 == 0 ? 0 : 2)} ${p.unit}', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
                    const SizedBox(height: 4),
                    Text(_stockText(context), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                  ])),
                  if (_canEdit) FilledButton.tonalIcon(onPressed: () async { final adjusted = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => AdjustStockScreen(product: _product))); if (adjusted == true) _reload(); }, icon: const Icon(Icons.tune, size: 18), label: Text(context.tr('Sax', 'Adjust'))),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
              if (p.categoryName != null) _InfoRow(label: context.tr('Qayb', 'Category'), value: p.categoryName!),
              _InfoRow(label: context.tr('Halbeeg', 'Unit'), value: p.unit),
              _InfoRow(label: context.tr('Qiimaha iibsiga', 'Buying price'), value: money(p.buyingPrice)),
              _InfoRow(label: context.tr('Qiimaha iibka', 'Selling price'), value: money(p.sellingPrice)),
              _InfoRow(label: context.tr('Qiimaha ugu hooseeya', 'Minimum price'), value: money(p.minimumSellingPrice)),
              _InfoRow(label: context.tr('Digniinta kaydka yar', 'Low stock alert'), value: '${p.minimumStock} ${p.unit}'),
              _InfoRow(label: context.tr('Xaalad', 'Status'), value: p.isActive ? context.tr('Shaqaynaya', 'Active') : context.tr('Aan shaqayn', 'Inactive')),
              if (p.notes != null && p.notes!.isNotEmpty) _InfoRow(label: context.tr('Qoraal', 'Notes'), value: p.notes!),
            ]))),
            const SizedBox(height: 16),
            Text(context.tr('Taariikhda Kaydka', 'Stock History'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _movementsFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) return Padding(padding: const EdgeInsets.all(16), child: Text(friendlyError(snapshot.error!, fallback: context.tr('Taariikhda kaydka lama soo gelin karin.', 'Could not load stock history.')), style: const TextStyle(color: Colors.red)));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final rows = snapshot.data!;
                if (rows.isEmpty) return Padding(padding: const EdgeInsets.all(16), child: Text(context.tr('Weli dhaqdhaqaaq kayd ma jiro.', 'No stock movements yet.'), style: const TextStyle(color: Colors.black45)));
                return Column(children: rows.map((m) => _MovementTile(movement: m)).toList());
              },
            ),
          ]),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 130, child: Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13))), Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)))]));
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.movement});
  final Map<String, dynamic> movement;
  String _label(BuildContext context, String type) {
    switch (type) {
      case 'purchase': return context.tr('Iibsi', 'Purchase');
      case 'sale': return context.tr('Iib', 'Sale');
      case 'adjustment_in': return context.tr('Kayd lagu daray', 'Stock added');
      case 'adjustment_out': return context.tr('Kayd laga jaray', 'Stock reduced');
      case 'return': return context.tr('Soo celin', 'Return');
      default: return type;
    }
  }
  String _fmt(double v) => v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
  @override
  Widget build(BuildContext context) {
    final type = movement['movement_type'] as String;
    final qty = (movement['quantity'] as num).toDouble();
    final previous = (movement['previous_stock'] as num).toDouble();
    final next = (movement['new_stock'] as num).toDouble();
    final notes = movement['notes'] as String?;
    final by = (movement['profiles'] as Map<String, dynamic>?)?['full_name'] as String?;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.swap_horiz, size: 18)),
        title: Row(children: [Expanded(child: Text(_label(context, type), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))), Text(_fmt(qty), style: const TextStyle(fontWeight: FontWeight.bold))]),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${_fmt(previous)} → ${_fmt(next)}', style: const TextStyle(fontSize: 11)),
          if (notes != null && notes.isNotEmpty) Text(notes, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          if (by != null) Text('${context.tr('Waxaa sameeyay', 'By')} $by', style: const TextStyle(fontSize: 11, color: Colors.black45)),
        ]),
        isThreeLine: (notes != null && notes.isNotEmpty) || by != null,
      ),
    );
  }
}

import 'package:flutter/material.dart';
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
  void initState() {
    super.initState();
    _product = widget.product;
    _loadMovements();
  }

  void _loadMovements() {
    _movementsFuture = _repo.listStockMovements(_product.id);
  }

  void _reload() => setState(() => _loadMovements());

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = _product;

    Color stockColor() {
      if (p.isOutOfStock) return cs.error;
      if (p.isLowStock) return Colors.orange.shade700;
      return Colors.green.shade700;
    }

    String stockLabel() {
      if (p.isOutOfStock) return 'Out of stock';
      if (p.isLowStock) return 'Low stock';
      return 'In stock';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(p.name),
        actions: [
          if (_canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit product',
              onPressed: () async {
                final updated = await Navigator.of(context).push<bool>(MaterialPageRoute(
                  builder: (_) => ProductFormScreen(profile: widget.profile, product: p),
                ));
                if (updated == true && mounted) Navigator.of(context).pop(true);
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Stock status
            Card(
              color: stockColor().withOpacity(0.08),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Current Stock', style: TextStyle(color: Colors.black54, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(
                            '${p.currentStock.toStringAsFixed(p.currentStock % 1 == 0 ? 0 : 2)} ${p.unit}',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: stockColor(),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: stockColor().withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              stockLabel(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: stockColor(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_canEdit)
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          final adjusted = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                              builder: (_) => AdjustStockScreen(product: _product),
                            ),
                          );
                          if (adjusted == true) _reload();
                        },
                        icon: const Icon(Icons.tune, size: 18),
                        label: const Text('Adjust'),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Product details
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (p.categoryName != null)
                      _Row(label: 'Category', value: p.categoryName!),
                    _Row(label: 'Unit', value: p.unit),
                    _Row(label: 'Buying price', value: money(p.buyingPrice)),
                    _Row(label: 'Selling price', value: money(p.sellingPrice)),
                    _Row(label: 'Min. selling price', value: money(p.minimumSellingPrice)),
                    _Row(label: 'Min. stock alert', value: '${p.minimumStock} ${p.unit}'),
                    _Row(
                      label: 'Status',
                      value: p.isActive ? 'Active' : 'Inactive',
                      valueColor: p.isActive ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                    if (p.notes != null && p.notes!.isNotEmpty)
                      _Row(label: 'Notes', value: p.notes!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Stock movement history
            Text(
              'Stock History',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            FutureBuilder<List<Map<String, dynamic>>>(
              future: _movementsFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      friendlyError(snapshot.error!, fallback: 'Could not load stock history.'),
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final movements = snapshot.data!;
                if (movements.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No stock movements yet.', style: TextStyle(color: Colors.black45)),
                  );
                }
                return Column(
                  children: movements.map((m) => _MovementTile(movement: m)).toList(),
                );
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.movement});
  final Map<String, dynamic> movement;

  IconData _icon(String type) {
    switch (type) {
      case 'purchase':       return Icons.shopping_cart_outlined;
      case 'sale':           return Icons.point_of_sale_outlined;
      case 'adjustment_in':  return Icons.add_circle_outline;
      case 'adjustment_out': return Icons.remove_circle_outline;
      case 'return':         return Icons.undo;
      default:               return Icons.swap_horiz;
    }
  }

  Color _color(String type) {
    switch (type) {
      case 'purchase':
      case 'adjustment_in':
      case 'return':        return Colors.green.shade700;
      default:              return Colors.red.shade700;
    }
  }

  String _label(String type) {
    switch (type) {
      case 'purchase':       return 'Purchase';
      case 'sale':           return 'Sale';
      case 'adjustment_in':  return 'Stock added';
      case 'adjustment_out': return 'Stock removed';
      case 'return':         return 'Return';
      default:               return type;
    }
  }

  String _formatDate(String iso) {
    final d = DateTime.parse(iso).toLocal();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final type = movement['movement_type'] as String;
    final qty = (movement['quantity'] as num).toDouble();
    final prev = (movement['previous_stock'] as num).toDouble();
    final next = (movement['new_stock'] as num).toDouble();
    final notes = movement['notes'] as String?;
    final recorder = (movement['profiles'] as Map<String, dynamic>?)?['full_name'] as String?;
    final isPositive = ['purchase', 'adjustment_in', 'return'].contains(type);

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _color(type).withOpacity(0.12),
          child: Icon(_icon(type), color: _color(type), size: 18),
        ),
        title: Row(
          children: [
            Expanded(child: Text(_label(type), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
            Text(
              '${isPositive ? '+' : '−'}${qty.toStringAsFixed(qty % 1 == 0 ? 0 : 2)}',
              style: TextStyle(fontWeight: FontWeight.bold, color: _color(type)),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$prev → $next  •  ${_formatDate(movement['created_at'] as String)}',
                style: const TextStyle(fontSize: 11)),
            if (notes != null && notes.isNotEmpty)
              Text(notes, style: const TextStyle(fontSize: 11, color: Colors.black54)),
            if (recorder != null)
              Text('By $recorder', style: const TextStyle(fontSize: 11, color: Colors.black45)),
          ],
        ),
        isThreeLine: (notes != null && notes.isNotEmpty) || recorder != null,
      ),
    );
  }
}

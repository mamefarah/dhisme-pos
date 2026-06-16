import 'package:flutter/material.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/models/app_profile.dart';
import '../../purchases/screens/purchases_screen.dart';
import '../../suppliers/screens/suppliers_screen.dart';
import '../data/product_repository.dart';
import '../models/product.dart';
import 'product_detail_screen.dart';
import 'product_form_screen.dart';

enum _StockFilter { all, inStock, lowStock, outOfStock }

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key, required this.profile});
  final AppProfile profile;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _repo = ProductRepository();
  final _search = TextEditingController();
  late Future<List<Product>> _future;
  _StockFilter _filter = _StockFilter.all;

  @override
  void initState() {
    super.initState();
    _future = _repo.listProducts();
  }

  void _reload() => setState(() => _future = _repo.listProducts(search: _search.text));

  List<Product> _applyFilter(List<Product> all) {
    switch (_filter) {
      case _StockFilter.inStock:
        return all.where((p) => !p.isOutOfStock && !p.isLowStock).toList();
      case _StockFilter.lowStock:
        return all.where((p) => p.isLowStock).toList();
      case _StockFilter.outOfStock:
        return all.where((p) => p.isOutOfStock).toList();
      case _StockFilter.all:
        return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = widget.profile.isOwner || widget.profile.isManager;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products & Stock'),
        actions: [
          if (canEdit)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'More options',
              onSelected: (value) async {
                if (value == 'add_product') {
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ProductFormScreen(profile: widget.profile),
                  ));
                  _reload();
                } else if (value == 'suppliers') {
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SuppliersScreen(profile: widget.profile),
                  ));
                } else if (value == 'purchases') {
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => PurchasesScreen(profile: widget.profile),
                  ));
                  _reload();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'add_product',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.add),
                    title: Text('Add product'),
                  ),
                ),
                PopupMenuItem(
                  value: 'suppliers',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.local_shipping_outlined),
                    title: Text('Suppliers'),
                  ),
                ),
                PopupMenuItem(
                  value: 'purchases',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.shopping_cart_outlined),
                    title: Text('Purchases'),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Search products',
                isDense: true,
              ),
              onChanged: (_) => _reload(),
            ),
          ),
          const SizedBox(height: 8),
          // Filter chips
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _FilterChip(label: 'All', selected: _filter == _StockFilter.all,
                    onTap: () => setState(() => _filter = _StockFilter.all)),
                const SizedBox(width: 8),
                _FilterChip(label: 'In Stock', selected: _filter == _StockFilter.inStock,
                    color: Colors.green, onTap: () => setState(() => _filter = _StockFilter.inStock)),
                const SizedBox(width: 8),
                _FilterChip(label: 'Low Stock', selected: _filter == _StockFilter.lowStock,
                    color: Colors.orange, onTap: () => setState(() => _filter = _StockFilter.lowStock)),
                const SizedBox(width: 8),
                _FilterChip(label: 'Out of Stock', selected: _filter == _StockFilter.outOfStock,
                    color: Colors.red, onTap: () => setState(() => _filter = _StockFilter.outOfStock)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: FutureBuilder<List<Product>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text(snapshot.error.toString(), textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton.icon(onPressed: _reload,
                          icon: const Icon(Icons.refresh), label: const Text('Try Again')),
                    ]),
                  ));
                }
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final filtered = _applyFilter(snapshot.data!);

                if (snapshot.data!.isEmpty) {
                  return EmptyState(
                    message: canEdit
                        ? 'No products yet. Tap ⋮ → Add product.'
                        : 'No products yet.',
                  );
                }
                if (filtered.isEmpty) {
                  return const EmptyState(message: 'No products match this filter.');
                }

                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final p = filtered[index];
                      return _ProductTile(
                        product: p,
                        onTap: () async {
                          final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
                            builder: (_) => ProductDetailScreen(product: p, profile: widget.profile),
                          ));
                          if (changed == true) _reload();
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap, this.color});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.withOpacity(0.15) : Colors.grey.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? c : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? c : Colors.black54,
          ),
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product, required this.onTap});
  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = product;
    Color stockColor() {
      if (p.isOutOfStock) return Colors.red.shade700;
      if (p.isLowStock) return Colors.orange.shade700;
      return Colors.green.shade700;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: stockColor().withOpacity(0.12),
          child: Text(
            p.unit.substring(0, 1).toUpperCase(),
            style: TextStyle(color: stockColor(), fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            if (p.isOutOfStock)
              _badge('OUT', Colors.red.shade700)
            else if (p.isLowStock)
              _badge('LOW', Colors.orange.shade700),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stock: ${p.currentStock.toStringAsFixed(p.currentStock % 1 == 0 ? 0 : 2)} ${p.unit}'
              '  •  ${money(p.sellingPrice)}',
              style: const TextStyle(fontSize: 12),
            ),
            if (p.categoryName != null)
              Text(p.categoryName!, style: const TextStyle(fontSize: 11, color: Colors.black45)),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.black26),
        isThreeLine: p.categoryName != null,
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
      );
}

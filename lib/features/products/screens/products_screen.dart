import 'package:flutter/material.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/models/app_profile.dart';
import '../../purchases/screens/purchases_screen.dart';
import '../../suppliers/screens/suppliers_screen.dart';
import '../data/product_repository.dart';
import '../models/product.dart';
import 'product_form_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _future = _repo.listProducts();
  }

  void _reload() => setState(() => _future = _repo.listProducts(search: _search.text));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products & Stock'),
        actions: [
          if (widget.profile.isOwner || widget.profile.isManager)
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
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Search products'),
              onChanged: (_) => _reload(),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Product>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final products = snapshot.data!;
                if (products.isEmpty) return const EmptyState(message: 'No products yet. Owner can add products.');
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final p = products[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(child: Text(p.unit.substring(0, 1).toUpperCase())),
                        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Stock: ${p.currentStock} ${p.unit} • Min: ${p.minimumStock} • ${money(p.sellingPrice)}'),
                        trailing: p.isLowStock ? const Icon(Icons.warning_amber, color: Colors.orange) : null,
                        onTap: (widget.profile.isOwner || widget.profile.isManager)
                            ? () async {
                                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductFormScreen(profile: widget.profile, product: p)));
                                _reload();
                              }
                            : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

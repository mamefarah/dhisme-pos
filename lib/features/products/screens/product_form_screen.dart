import 'package:flutter/material.dart';
import '../../auth/models/app_profile.dart';
import '../data/product_repository.dart';
import '../models/product.dart';

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, required this.profile, this.product});
  final AppProfile profile;
  final Product? product;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _repo = ProductRepository();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _unit;
  late final TextEditingController _buying;
  late final TextEditingController _selling;
  late final TextEditingController _minSelling;
  late final TextEditingController _stock;
  late final TextEditingController _minStock;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?.name ?? '');
    _unit = TextEditingController(text: p?.unit ?? 'bag');
    _buying = TextEditingController(text: p?.buyingPrice.toString() ?? '0');
    _selling = TextEditingController(text: p?.sellingPrice.toString() ?? '0');
    _minSelling = TextEditingController(text: p?.minimumSellingPrice.toString() ?? '0');
    _stock = TextEditingController(text: p?.currentStock.toString() ?? '0');
    _minStock = TextEditingController(text: p?.minimumStock.toString() ?? '0');
  }

  @override
  void dispose() {
    _name.dispose(); _unit.dispose(); _buying.dispose(); _selling.dispose(); _minSelling.dispose(); _stock.dispose(); _minStock.dispose();
    super.dispose();
  }

  double _d(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      if (widget.product == null) {
        await _repo.addProduct(
          storeId: widget.profile.storeId,
          name: _name.text.trim(), unit: _unit.text.trim(),
          buyingPrice: _d(_buying), sellingPrice: _d(_selling), minimumSellingPrice: _d(_minSelling),
          currentStock: _d(_stock), minimumStock: _d(_minStock),
        );
      } else {
        await _repo.updateProduct(widget.product!, {
          'name': _name.text.trim(), 'unit': _unit.text.trim(),
          'buying_price': _d(_buying), 'selling_price': _d(_selling), 'minimum_selling_price': _d(_minSelling),
          'current_stock': _d(_stock), 'minimum_stock': _d(_minStock), 'updated_at': DateTime.now().toIso8601String(),
        });
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.product == null ? 'Add Product' : 'Edit Product')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Product name'), validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _unit, decoration: const InputDecoration(labelText: 'Unit: bag, piece, m3, kg, meter'), validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _buying, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Buying price')),
            const SizedBox(height: 12),
            TextFormField(controller: _selling, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Selling price')),
            const SizedBox(height: 12),
            TextFormField(controller: _minSelling, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Minimum selling price')),
            const SizedBox(height: 12),
            TextFormField(controller: _stock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Current stock')),
            const SizedBox(height: 12),
            TextFormField(controller: _minStock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Minimum stock alert')),
            const SizedBox(height: 20),
            FilledButton.icon(onPressed: _loading ? null : _save, icon: const Icon(Icons.save), label: Text(_loading ? 'Saving...' : 'Save')),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../core/utils/errors.dart';
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
  late final TextEditingController _notes;

  String? _categoryId;
  List<Map<String, dynamic>> _categories = [];
  bool _isActive = true;
  bool _loading = false;
  bool _loadingCategories = true;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?.name ?? '');
    _unit = TextEditingController(text: p?.unit ?? 'bag');
    _buying = TextEditingController(text: p != null ? p.buyingPrice.toStringAsFixed(2) : '0');
    _selling = TextEditingController(text: p != null ? p.sellingPrice.toStringAsFixed(2) : '0');
    _minSelling = TextEditingController(text: p != null ? p.minimumSellingPrice.toStringAsFixed(2) : '0');
    _stock = TextEditingController(text: p != null ? p.currentStock.toStringAsFixed(p.currentStock % 1 == 0 ? 0 : 2) : '0');
    _minStock = TextEditingController(text: p != null ? p.minimumStock.toStringAsFixed(p.minimumStock % 1 == 0 ? 0 : 2) : '0');
    _notes = TextEditingController(text: p?.notes ?? '');
    _categoryId = p?.categoryId;
    _isActive = p?.isActive ?? true;
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _repo.listCategories();
      if (mounted) setState(() { _categories = cats; _loadingCategories = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  @override
  void dispose() {
    _name.dispose(); _unit.dispose(); _buying.dispose(); _selling.dispose();
    _minSelling.dispose(); _stock.dispose(); _minStock.dispose(); _notes.dispose();
    super.dispose();
  }

  double _d(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      if (!_isEditing) {
        await _repo.addProduct(
          storeId: widget.profile.storeId,
          name: _name.text.trim(),
          unit: _unit.text.trim(),
          buyingPrice: _d(_buying),
          sellingPrice: _d(_selling),
          minimumSellingPrice: _d(_minSelling),
          currentStock: _d(_stock),
          minimumStock: _d(_minStock),
          categoryId: _categoryId,
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        );
      } else {
        await _repo.updateProduct(widget.product!, {
          'name': _name.text.trim(),
          'unit': _unit.text.trim(),
          'buying_price': _d(_buying),
          'selling_price': _d(_selling),
          'minimum_selling_price': _d(_minSelling),
          'minimum_stock': _d(_minStock),
          'category_id': _categoryId,
          'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          'is_active': _isActive,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text(friendlyError(e, fallback: 'Save failed. Please check your information and try again.')),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Product' : 'Add Product')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Name
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Product name *',
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Product name is required' : null,
            ),
            const SizedBox(height: 12),

            // Category
            if (_loadingCategories)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              )
            else
              DropdownButtonFormField<String?>(
                value: _categoryId,
                decoration: const InputDecoration(
                  labelText: 'Category (optional)',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('No category')),
                  ..._categories.map((c) => DropdownMenuItem(
                        value: c['id'] as String,
                        child: Text(c['name'] as String),
                      )),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
            const SizedBox(height: 12),

            // Unit
            TextFormField(
              controller: _unit,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Unit *',
                hintText: 'bag, piece, kg, m³, meter…',
                prefixIcon: Icon(Icons.straighten_outlined),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Unit is required' : null,
            ),
            const SizedBox(height: 12),

            // Prices
            TextFormField(
              controller: _buying,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Buying price (ETB)',
                prefixIcon: Icon(Icons.price_change_outlined),
              ),
              validator: (v) => (double.tryParse(v ?? '') ?? -1) < 0 ? 'Enter a valid price' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _selling,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Selling price (ETB)',
                prefixIcon: Icon(Icons.sell_outlined),
              ),
              validator: (v) => (double.tryParse(v ?? '') ?? -1) < 0 ? 'Enter a valid price' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _minSelling,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Minimum selling price (ETB)',
                prefixIcon: Icon(Icons.money_off_outlined),
              ),
              validator: (v) => (double.tryParse(v ?? '') ?? -1) < 0 ? 'Enter a valid price' : null,
            ),
            const SizedBox(height: 12),

            // Initial stock — only on add; on edit stock changes via Adjust Stock
            if (!_isEditing) ...[
              TextFormField(
                controller: _stock,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Initial stock',
                  prefixIcon: Icon(Icons.layers_outlined),
                ),
                validator: (v) => (double.tryParse(v ?? '') ?? -1) < 0 ? 'Enter 0 or more' : null,
              ),
              const SizedBox(height: 12),
            ] else ...[
              Card(
                color: Colors.amber.shade50,
                child: const ListTile(
                  leading: Icon(Icons.info_outline, color: Colors.amber),
                  title: Text('Current stock is managed via Adjust Stock'),
                  subtitle: Text('Use the Adjust button on the product detail screen to correct stock levels.'),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Minimum stock
            TextFormField(
              controller: _minStock,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Minimum stock alert',
                prefixIcon: Icon(Icons.warning_amber_outlined),
              ),
              validator: (v) => (double.tryParse(v ?? '') ?? -1) < 0 ? 'Enter 0 or more' : null,
            ),
            const SizedBox(height: 12),

            // Notes
            TextFormField(
              controller: _notes,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                prefixIcon: Icon(Icons.notes_outlined),
                alignLabelWithHint: true,
              ),
            ),

            // Active toggle — edit only
            if (_isEditing) ...[
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                subtitle: Text(_isActive
                    ? 'Product is available for sale.'
                    : 'Product is hidden from POS and purchase forms.'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
            ],

            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loading ? null : _save,
              icon: _loading
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save),
              label: Text(_isEditing ? 'Save Changes' : 'Add Product'),
            ),
          ],
        ),
      ),
    );
  }
}

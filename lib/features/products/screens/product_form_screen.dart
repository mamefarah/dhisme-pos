import 'package:flutter/material.dart';
import '../../../core/i18n/app_language.dart';
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
  void dispose() { _name.dispose(); _unit.dispose(); _buying.dispose(); _selling.dispose(); _minSelling.dispose(); _stock.dispose(); _minStock.dispose(); _notes.dispose(); super.dispose(); }
  double _d(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      if (!_isEditing) {
        await _repo.addProduct(storeId: widget.profile.storeId, name: _name.text.trim(), unit: _unit.text.trim(), buyingPrice: _d(_buying), sellingPrice: _d(_selling), minimumSellingPrice: _d(_minSelling), currentStock: _d(_stock), minimumStock: _d(_minStock), categoryId: _categoryId, notes: _notes.text.trim().isEmpty ? null : _notes.text.trim());
      } else {
        await _repo.updateProduct(widget.product!, {'name': _name.text.trim(), 'unit': _unit.text.trim(), 'buying_price': _d(_buying), 'selling_price': _d(_selling), 'minimum_selling_price': _d(_minSelling), 'minimum_stock': _d(_minStock), 'category_id': _categoryId, 'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(), 'is_active': _isActive, 'updated_at': DateTime.now().toIso8601String()});
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(SnackBar(content: Text(friendlyError(e, fallback: context.tr('Kaydintu way fashilantay. Hubi xogta oo mar kale isku day.', 'Save failed. Please check your information and try again.'))), backgroundColor: Theme.of(context).colorScheme.error, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 5)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLanguage.instance,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(_isEditing ? context.tr('Wax ka beddel Alaab', 'Edit Product') : context.tr('Ku dar Alaab', 'Add Product'))),
        body: Form(
          key: _formKey,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            TextFormField(controller: _name, textCapitalization: TextCapitalization.words, textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: context.tr('Magaca alaabta *', 'Product name *'), prefixIcon: const Icon(Icons.inventory_2_outlined)), validator: (v) => (v == null || v.trim().isEmpty) ? context.tr('Magaca alaabta waa loo baahan yahay', 'Product name is required') : null),
            const SizedBox(height: 12),
            if (_loadingCategories) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator()) else DropdownButtonFormField<String?>(initialValue: _categoryId, decoration: InputDecoration(labelText: context.tr('Qayb (ikhtiyaari)', 'Category (optional)'), prefixIcon: const Icon(Icons.category_outlined)), items: [DropdownMenuItem(value: null, child: Text(context.tr('Qayb ma leh', 'No category'))), ..._categories.map((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['name'] as String)))], onChanged: (v) => setState(() => _categoryId = v)),
            const SizedBox(height: 12),
            TextFormField(controller: _unit, textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: context.tr('Halbeeg *', 'Unit *'), hintText: 'bag, piece, kg, m³, meter…', prefixIcon: const Icon(Icons.straighten_outlined)), validator: (v) => (v == null || v.trim().isEmpty) ? context.tr('Halbeeg waa loo baahan yahay', 'Unit is required') : null),
            const SizedBox(height: 12),
            _priceField(_buying, context.tr('Qiimaha iibsiga (ETB)', 'Buying price (ETB)'), Icons.price_change_outlined),
            const SizedBox(height: 12),
            _priceField(_selling, context.tr('Qiimaha iibka (ETB)', 'Selling price (ETB)'), Icons.sell_outlined),
            const SizedBox(height: 12),
            _priceField(_minSelling, context.tr('Qiimaha iibka ugu hooseeya (ETB)', 'Minimum selling price (ETB)'), Icons.money_off_outlined),
            const SizedBox(height: 12),
            if (!_isEditing) ...[
              TextFormField(controller: _stock, keyboardType: const TextInputType.numberWithOptions(decimal: true), textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: context.tr('Kaydka bilowga', 'Initial stock'), prefixIcon: const Icon(Icons.layers_outlined)), validator: (v) => (double.tryParse(v ?? '') ?? -1) < 0 ? context.tr('Geli 0 ama ka badan', 'Enter 0 or more') : null),
              const SizedBox(height: 12),
            ] else ...[
              Card(color: Colors.amber.shade50, child: ListTile(leading: const Icon(Icons.info_outline, color: Colors.amber), title: Text(context.tr('Kaydka hadda waxaa lagu maamulaa Sax Kaydka', 'Current stock is managed via Adjust Stock')), subtitle: Text(context.tr('Isticmaal badhanka Sax ee faahfaahinta alaabta si aad kaydka u saxdo.', 'Use the Adjust button on the product detail screen to correct stock levels.')))),
              const SizedBox(height: 12),
            ],
            TextFormField(controller: _minStock, keyboardType: const TextInputType.numberWithOptions(decimal: true), textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: context.tr('Digniinta kaydka ugu yar', 'Minimum stock alert'), prefixIcon: const Icon(Icons.warning_amber_outlined)), validator: (v) => (double.tryParse(v ?? '') ?? -1) < 0 ? context.tr('Geli 0 ama ka badan', 'Enter 0 or more') : null),
            const SizedBox(height: 12),
            TextFormField(controller: _notes, textCapitalization: TextCapitalization.sentences, textInputAction: TextInputAction.done, maxLines: 2, decoration: InputDecoration(labelText: context.tr('Qoraal (ikhtiyaari)', 'Notes (optional)'), prefixIcon: const Icon(Icons.notes_outlined), alignLabelWithHint: true)),
            if (_isEditing) ...[
              const SizedBox(height: 16),
              SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(context.tr('Shaqaynaya', 'Active')), subtitle: Text(_isActive ? context.tr('Alaabtu iib waa diyaar.', 'Product is available for sale.') : context.tr('Alaabtu POS iyo form-yada iibsiga kama muuqanayso.', 'Product is hidden from POS and purchase forms.')), value: _isActive, onChanged: (v) => setState(() => _isActive = v)),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(onPressed: _loading ? null : _save, icon: _loading ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save), label: Text(_isEditing ? context.tr('Kaydi Isbeddelka', 'Save Changes') : context.tr('Ku dar Alaab', 'Add Product'))),
          ]),
        ),
      ),
    );
  }

  Widget _priceField(TextEditingController controller, String label, IconData icon) => TextFormField(controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true), textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)), validator: (v) => (double.tryParse(v ?? '') ?? -1) < 0 ? context.tr('Geli qiime sax ah', 'Enter a valid price') : null);
}

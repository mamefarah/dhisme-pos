import 'package:flutter/material.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/money.dart';
import '../../products/data/product_repository.dart';
import '../../products/models/product.dart';
import '../../suppliers/data/supplier_repository.dart';
import '../../suppliers/models/supplier.dart';
import '../data/purchase_repository.dart';

class NewPurchaseScreen extends StatefulWidget {
  const NewPurchaseScreen({super.key});

  @override
  State<NewPurchaseScreen> createState() => _NewPurchaseScreenState();
}

class _NewPurchaseScreenState extends State<NewPurchaseScreen> {
  final _repo = PurchaseRepository();
  final _productRepo = ProductRepository();
  final _supplierRepo = SupplierRepository();
  final _invoiceRef = TextEditingController();
  final _notes = TextEditingController();
  DateTime _purchaseDate = DateTime.now();
  String _paymentStatus = 'paid';
  Supplier? _selectedSupplier;
  List<Supplier> _suppliers = [];
  List<Product> _products = [];
  final List<_ItemRow> _items = [];
  bool _loading = false;
  bool _submitting = false;

  @override
  void initState() { super.initState(); _loadData(); }
  @override
  void dispose() { _invoiceRef.dispose(); _notes.dispose(); for (final r in _items) { r.dispose(); } super.dispose(); }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([_supplierRepo.listSuppliers(activeOnly: true), _productRepo.listProducts()]);
      if (mounted) setState(() { _suppliers = results[0] as List<Supplier>; _products = results[1] as List<Product>; _loading = false; _addItem(); });
    } catch (e) {
      if (mounted) { setState(() => _loading = false); ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(SnackBar(content: Text(friendlyError(e, fallback: context.tr('Alaabta lama soo gelin karin. Fadlan mar kale isku day.', 'Could not load products. Please try again.'))), backgroundColor: Theme.of(context).colorScheme.error, behavior: SnackBarBehavior.floating)); }
    }
  }

  void _addItem() => setState(() => _items.add(_ItemRow()));
  void _removeItem(int index) { setState(() { _items[index].dispose(); _items.removeAt(index); }); }
  double get _grandTotal => _items.fold(0, (sum, r) => sum + r.lineTotal);

  Future<void> _submit() async {
    if (_items.isEmpty) { _showError(context.tr('Ku dar ugu yaraan hal alaab.', 'Add at least one product.')); return; }
    for (int i = 0; i < _items.length; i++) {
      final row = _items[i];
      if (row.product == null) { _showError(context.tr('Dooro alaabta item ${i + 1}.', 'Select a product for item ${i + 1}.')); return; }
      if (row.quantity <= 0) { _showError(context.tr('Tiradu waa inay ka weyn tahay 0 item ${i + 1}.', 'Quantity must be greater than 0 for item ${i + 1}.')); return; }
      if (row.unitCost < 0) { _showError(context.tr('Qiimaha unit-ku ma noqon karo taban item ${i + 1}.', 'Unit cost cannot be negative for item ${i + 1}.')); return; }
    }
    setState(() => _submitting = true);
    try {
      final items = _items.map((r) => {'product_id': r.product!.id, 'quantity': r.quantity, 'unit_cost': r.unitCost}).toList();
      await _repo.recordPurchase(items: items, supplierId: _selectedSupplier?.id, invoiceRef: _invoiceRef.text.trim().isEmpty ? null : _invoiceRef.text.trim(), purchaseDate: _purchaseDate, paymentStatus: _paymentStatus, notes: _notes.text.trim().isEmpty ? null : _notes.text.trim());
      if (mounted) { ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(SnackBar(content: Text(context.tr('Iibsi waa la diiwaangeliyay. Kaydka waa la cusboonaysiiyay.', 'Purchase recorded. Stock updated.')), behavior: SnackBarBehavior.floating)); Navigator.of(context).pop(); }
    } catch (e) { if (mounted) _showError(friendlyError(e, fallback: context.tr('Iibsi lama diiwaangelin karin. Fadlan mar kale isku day.', 'Could not record purchase. Please try again.'))); }
    finally { if (mounted) setState(() => _submitting = false); }
  }

  void _showError(String msg) { ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(SnackBar(content: Text(msg), backgroundColor: Theme.of(context).colorScheme.error, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 5))); }
  Future<void> _pickDate() async { final picked = await showDatePicker(context: context, initialDate: _purchaseDate, firstDate: DateTime(2020), lastDate: DateTime.now()); if (picked != null) setState(() => _purchaseDate = picked); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return AnimatedBuilder(
      animation: AppLanguage.instance,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(context.tr('Iibsi Cusub', 'New Purchase')), actions: [_submitting ? const Padding(padding: EdgeInsets.all(16), child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))) : TextButton(onPressed: _submit, child: Text(context.tr('Kaydi', 'Save')))]),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
            ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.calendar_today_outlined), title: Text(context.tr('Taariikhda iibsiga', 'Purchase date')), subtitle: Text(_formatDate(_purchaseDate)), trailing: const Icon(Icons.chevron_right, color: Colors.black26), onTap: _pickDate),
            const Divider(height: 1),
            ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.local_shipping_outlined), title: Text(context.tr('Alaab-qeybiye (ikhtiyaari)', 'Supplier (optional)')), subtitle: Text(_selectedSupplier?.name ?? context.tr('Midna lama dooran', 'None selected')), trailing: const Icon(Icons.chevron_right, color: Colors.black26), onTap: _pickSupplier),
            const Divider(height: 1),
            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: TextField(controller: _invoiceRef, textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: context.tr('Invoice / reference no. (ikhtiyaari)', 'Invoice / reference no. (optional)'), prefixIcon: const Icon(Icons.tag_outlined), isDense: true))),
            const Divider(height: 1),
            Padding(padding: const EdgeInsets.only(top: 8), child: DropdownButtonFormField<String>(value: _paymentStatus, decoration: InputDecoration(labelText: context.tr('Xaaladda bixinta', 'Payment status'), prefixIcon: const Icon(Icons.payments_outlined), isDense: true), items: [DropdownMenuItem(value: 'paid', child: Text(context.tr('La bixiyay', 'Paid'))), DropdownMenuItem(value: 'partial', child: Text(context.tr('Qayb la bixiyay', 'Partially paid'))), DropdownMenuItem(value: 'unpaid', child: Text(context.tr('Lama bixin', 'Unpaid')))], onChanged: (v) { if (v != null) setState(() => _paymentStatus = v); })),
          ]))),
          const SizedBox(height: 16),
          Row(children: [Text(context.tr('Alaabta', 'Items'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)), const Spacer(), TextButton.icon(onPressed: _addItem, icon: const Icon(Icons.add, size: 18), label: Text(context.tr('Ku dar alaab', 'Add item')))]),
          const SizedBox(height: 4),
          ..._items.asMap().entries.map((entry) => _ItemCard(key: ValueKey(entry.value), row: entry.value, products: _products, index: entry.key, onRemove: _items.length > 1 ? () => _removeItem(entry.key) : null, onChanged: () => setState(() {}))),
          const Divider(height: 24),
          TextField(controller: _notes, textCapitalization: TextCapitalization.sentences, maxLines: 2, decoration: InputDecoration(labelText: context.tr('Qoraal (ikhtiyaari)', 'Notes (optional)'), prefixIcon: const Icon(Icons.notes_outlined), alignLabelWithHint: true)),
          const SizedBox(height: 24),
          Card(color: cs.primaryContainer, child: Padding(padding: const EdgeInsets.all(16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(context.tr('Wadar', 'Total'), style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary)), Text(money(_grandTotal), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: cs.primary))]))),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: _submitting ? null : _submit, icon: _submitting ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save), label: Text(context.tr('Diiwaangeli Iibsi', 'Record Purchase'))),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  Future<void> _pickSupplier() async { final picked = await showModalBottomSheet<Supplier?>(context: context, builder: (ctx) => _SupplierPicker(suppliers: _suppliers)); if (mounted) setState(() => _selectedSupplier = picked == _selectedSupplier ? null : picked); }
  String _formatDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _ItemRow {
  Product? product;
  final TextEditingController qtyController = TextEditingController(text: '1');
  final TextEditingController costController = TextEditingController();
  double get quantity => double.tryParse(qtyController.text) ?? 0;
  double get unitCost => double.tryParse(costController.text) ?? 0;
  double get lineTotal => quantity * unitCost;
  void dispose() { qtyController.dispose(); costController.dispose(); }
}

class _ItemCard extends StatefulWidget {
  const _ItemCard({super.key, required this.row, required this.products, required this.index, required this.onRemove, required this.onChanged});
  final _ItemRow row;
  final List<Product> products;
  final int index;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;
  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
  @override
  void initState() { super.initState(); widget.row.qtyController.addListener(_notify); widget.row.costController.addListener(_notify); }
  void _notify() { widget.onChanged(); setState(() {}); }
  @override
  void dispose() { widget.row.qtyController.removeListener(_notify); widget.row.costController.removeListener(_notify); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Text('${context.tr('Alaab', 'Item')} ${widget.index + 1}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)), const Spacer(), if (widget.onRemove != null) IconButton(onPressed: widget.onRemove, icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), padding: EdgeInsets.zero, constraints: const BoxConstraints())]),
      const SizedBox(height: 8),
      DropdownButtonFormField<Product>(value: row.product, decoration: InputDecoration(labelText: context.tr('Alaab *', 'Product *'), prefixIcon: const Icon(Icons.inventory_2_outlined), isDense: true), items: widget.products.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(), onChanged: (p) { setState(() { row.product = p; if (p != null && row.costController.text.isEmpty) row.costController.text = p.buyingPrice.toStringAsFixed(2); }); widget.onChanged(); }),
      const SizedBox(height: 8),
      Row(children: [Expanded(child: TextField(controller: row.qtyController, keyboardType: const TextInputType.numberWithOptions(decimal: true), textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: '${context.tr('Tiro', 'Qty')}${row.product != null ? ' (${row.product!.unit})' : ''}', isDense: true))), const SizedBox(width: 12), Expanded(child: TextField(controller: row.costController, keyboardType: const TextInputType.numberWithOptions(decimal: true), textInputAction: TextInputAction.done, decoration: InputDecoration(labelText: context.tr('Qiimaha unit-ka (ETB)', 'Unit cost (ETB)'), isDense: true)))]),
      if (row.quantity > 0 && row.unitCost > 0) ...[const SizedBox(height: 6), Align(alignment: Alignment.centerRight, child: Text('${context.tr('Wadarta line-ka', 'Line total')}: ${money(row.lineTotal)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)))],
    ])));
  }
}

class _SupplierPicker extends StatelessWidget {
  const _SupplierPicker({required this.suppliers});
  final List<Supplier> suppliers;
  @override
  Widget build(BuildContext context) {
    return SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [Padding(padding: const EdgeInsets.all(16), child: Text(context.tr('Dooro Alaab-qeybiye', 'Select Supplier'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))), ListTile(leading: const Icon(Icons.clear), title: Text(context.tr('Midna', 'None')), onTap: () => Navigator.of(context).pop(null)), const Divider(height: 1), ...suppliers.map((s) => ListTile(leading: const Icon(Icons.local_shipping_outlined), title: Text(s.name), subtitle: s.phone != null ? Text(s.phone!) : null, onTap: () => Navigator.of(context).pop(s))), const SizedBox(height: 8)]));
  }
}

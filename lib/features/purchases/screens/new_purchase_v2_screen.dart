import 'package:flutter/material.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/idempotency.dart';
import '../../../core/utils/money.dart';
import '../../products/data/product_repository.dart';
import '../../products/models/product.dart';
import '../../suppliers/data/supplier_repository.dart';
import '../../suppliers/models/supplier.dart';
import '../data/purchase_repository.dart';

class NewPurchaseV2Screen extends StatefulWidget {
  const NewPurchaseV2Screen({super.key});

  @override
  State<NewPurchaseV2Screen> createState() => _NewPurchaseV2ScreenState();
}

class _NewPurchaseV2ScreenState extends State<NewPurchaseV2Screen> {
  final _repo = PurchaseRepository();
  final _productsRepo = ProductRepository();
  final _suppliersRepo = SupplierRepository();
  final _invoice = TextEditingController();
  final _notes = TextEditingController();
  final _paid = TextEditingController();
  final List<_PurchaseLine> _lines = [];

  List<Product> _products = [];
  List<Supplier> _suppliers = [];
  Supplier? _supplier;
  DateTime _date = DateTime.now();
  String _status = 'paid';
  String _method = 'cash';
  String? _operationKey;
  bool _loading = true;
  bool _saving = false;

  double get _total => _lines.fold(0, (sum, line) => sum + line.total);
  double get _paidAmount {
    if (_status == 'paid') return _total;
    if (_status == 'unpaid') return 0;
    return double.tryParse(_paid.text.trim()) ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _invoice.dispose();
    _notes.dispose();
    _paid.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final result = await Future.wait([
        _productsRepo.listProducts(),
        _suppliersRepo.listSuppliers(activeOnly: true),
      ]);
      if (!mounted) return;
      setState(() {
        _products = result[0] as List<Product>;
        _suppliers = result[1] as List<Supplier>;
        _lines.add(_PurchaseLine());
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _error(friendlyError(e, fallback: context.tr('Xogta lama soo gelin karin.', 'Could not load purchase data.')));
    }
  }

  void _addLine() => setState(() => _lines.add(_PurchaseLine()));

  void _removeLine(int index) {
    setState(() {
      _lines[index].dispose();
      _lines.removeAt(index);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_lines.isEmpty) {
      _error(context.tr('Ku dar ugu yaraan hal alaab.', 'Add at least one item.'));
      return;
    }
    for (final line in _lines) {
      if (line.product == null || line.quantity <= 0 || line.unitCost < 0) {
        _error(context.tr('Hubi alaabta, tirada iyo qiimaha.', 'Check every product, quantity, and unit cost.'));
        return;
      }
    }
    if (_total <= 0) {
      _error(context.tr('Wadartu waa inay ka weyn tahay eber.', 'Total must be greater than zero.'));
      return;
    }
    final paid = _paidAmount;
    if (_status == 'partial' && (paid <= 0 || paid >= _total)) {
      _error(context.tr('Qayb bixintu waa inay u dhexaysaa 0 iyo wadarta.', 'Partial payment must be between zero and the total.'));
      return;
    }
    if (paid < _total && _supplier == null) {
      _error(context.tr('Alaab-qeybiye ayaa loo baahan yahay marka deyn jirto.', 'A supplier is required when a balance remains.'));
      return;
    }

    _operationKey ??= newOperationKey('purchase');
    setState(() => _saving = true);
    try {
      await _repo.recordPurchaseV2(
        items: _lines
            .map((line) => {
                  'product_id': line.product!.id,
                  'quantity': line.quantity,
                  'unit_cost': line.unitCost,
                })
            .toList(),
        supplierId: _supplier?.id,
        invoiceRef: _invoice.text.trim().isEmpty ? null : _invoice.text.trim(),
        purchaseDate: _date,
        paidAmount: paid,
        paymentMethod: _method,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        idempotencyKey: _operationKey,
      );
      if (!mounted) return;
      _operationKey = null;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.tr('Iibsiga, kaydka iyo deynta waa la cusboonaysiiyay.', 'Purchase, stock, and supplier balance were updated.')),
        behavior: SnackBarBehavior.floating,
      ));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        _error(friendlyError(
          e,
          fallback: context.tr(
            'Iibsiga lama xaqiijin. Mar kale isku day; laba-diiwaangelin waa la xannibay.',
            'Purchase could not be confirmed. Retry safely; duplicates are blocked.',
          ),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _error(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return AnimatedBuilder(
      animation: AppLanguage.instance,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(context.tr('Iibsi Cusub', 'New Purchase'))),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: Text(context.tr('Taariikhda', 'Purchase date')),
                    subtitle: Text(_date.toIso8601String().substring(0, 10)),
                    onTap: _pickDate,
                  ),
                  DropdownButtonFormField<Supplier?>(
                    initialValue: _supplier,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: context.tr('Alaab-qeybiye', 'Supplier')),
                    items: [
                      DropdownMenuItem<Supplier?>(value: null, child: Text(context.tr('Midna', 'None'))),
                      ..._suppliers.map((s) => DropdownMenuItem<Supplier?>(value: s, child: Text(s.name))),
                    ],
                    onChanged: (value) => setState(() => _supplier = value),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _invoice,
                    decoration: InputDecoration(labelText: context.tr('Invoice / reference', 'Invoice / reference')),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: InputDecoration(labelText: context.tr('Xaaladda bixinta', 'Payment status')),
                    items: [
                      DropdownMenuItem(value: 'paid', child: Text(context.tr('La bixiyay', 'Paid'))),
                      DropdownMenuItem(value: 'partial', child: Text(context.tr('Qayb la bixiyay', 'Partially paid'))),
                      DropdownMenuItem(value: 'unpaid', child: Text(context.tr('Lama bixin', 'Unpaid'))),
                    ],
                    onChanged: (value) => setState(() {
                      _status = value ?? 'paid';
                      if (_status != 'partial') _paid.clear();
                    }),
                  ),
                  if (_status == 'partial') ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _paid,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: context.tr('Qadarka la bixiyay', 'Amount paid')),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                  if (_status != 'unpaid') ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _method,
                      decoration: InputDecoration(labelText: context.tr('Qaabka bixinta', 'Payment method')),
                      items: [
                        DropdownMenuItem(value: 'cash', child: Text(context.tr('Caddaan', 'Cash'))),
                        DropdownMenuItem(value: 'bank', child: Text(context.tr('Bangiga', 'Bank'))),
                        DropdownMenuItem(value: 'mobile_money', child: Text(context.tr('Lacagta dhijitaalka', 'Mobile money'))),
                      ],
                      onChanged: (value) => setState(() => _method = value ?? 'cash'),
                    ),
                  ],
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Text(context.tr('Alaabta', 'Items'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton.icon(onPressed: _addLine, icon: const Icon(Icons.add), label: Text(context.tr('Ku dar', 'Add'))),
            ]),
            ..._lines.asMap().entries.map((entry) {
              final line = entry.value;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    Row(children: [
                      Expanded(
                        child: DropdownButtonFormField<Product>(
                          initialValue: line.product,
                          isExpanded: true,
                          decoration: InputDecoration(labelText: context.tr('Alaab', 'Product')),
                          items: _products.map((p) => DropdownMenuItem(value: p, child: Text(p.name, overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (product) => setState(() {
                            line.product = product;
                            if (product != null && line.cost.text.isEmpty) {
                              line.cost.text = product.buyingPrice.toStringAsFixed(2);
                            }
                          }),
                        ),
                      ),
                      if (_lines.length > 1)
                        IconButton(onPressed: () => _removeLine(entry.key), icon: const Icon(Icons.delete_outline, color: Colors.red)),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: line.qty,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(labelText: context.tr('Tiro', 'Quantity')),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: line.cost,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(labelText: context.tr('Qiimaha unit-ka', 'Unit cost')),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ]),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(money(line.total), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ]),
                ),
              );
            }),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: InputDecoration(labelText: context.tr('Qoraal', 'Notes')),
            ),
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  _MoneyRow(label: context.tr('Wadar', 'Total'), value: _total),
                  _MoneyRow(label: context.tr('La bixiyay', 'Paid'), value: _paidAmount),
                  _MoneyRow(label: context.tr('Deyn', 'Balance'), value: (_total - _paidAmount).clamp(0, double.infinity)),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label: Text(context.tr('Diiwaangeli Iibsi', 'Record Purchase')),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseLine {
  Product? product;
  final qty = TextEditingController(text: '1');
  final cost = TextEditingController();

  double get quantity => double.tryParse(qty.text.trim()) ?? 0;
  double get unitCost => double.tryParse(cost.text.trim()) ?? 0;
  double get total => quantity * unitCost;

  void dispose() {
    qty.dispose();
    cost.dispose();
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label),
          Text(money(value), style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
      );
}

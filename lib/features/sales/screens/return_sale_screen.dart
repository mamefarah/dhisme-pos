import 'package:flutter/material.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/money.dart';
import '../data/sales_repository.dart';

class ReturnSaleScreen extends StatefulWidget {
  const ReturnSaleScreen({super.key, required this.sale});
  final Map<String, dynamic> sale;

  @override
  State<ReturnSaleScreen> createState() => _ReturnSaleScreenState();
}

class _ReturnSaleScreenState extends State<ReturnSaleScreen> {
  final _repo = SalesRepository();
  final _reason = TextEditingController();
  final Map<String, TextEditingController> _qty = {};
  String _refundMethod = 'cash';
  bool _loading = false;

  List<Map<String, dynamic>> get _items {
    final raw = widget.sale['sale_items'];
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(raw as List);
  }

  @override
  void initState() {
    super.initState();
    for (final item in _items) {
      _qty[item['id'] as String] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _reason.dispose();
    for (final c in _qty.values) c.dispose();
    super.dispose();
  }

  double _itemQty(Map<String, dynamic> item) => ((item['quantity'] as num?) ?? 0).toDouble();
  double _itemPrice(Map<String, dynamic> item) => ((item['unit_price'] as num?) ?? 0).toDouble();
  String _fmt(double v) => v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  List<Map<String, dynamic>> _selectedItems() {
    final rows = <Map<String, dynamic>>[];
    for (final item in _items) {
      final id = item['id'] as String;
      final q = double.tryParse(_qty[id]?.text.trim() ?? '') ?? 0;
      if (q > 0) rows.add({'sale_item_id': id, 'quantity': q});
    }
    return rows;
  }

  double get _refundTotal {
    var total = 0.0;
    for (final item in _items) {
      final q = double.tryParse(_qty[item['id']]?.text.trim() ?? '') ?? 0;
      if (q > 0) total += q * _itemPrice(item);
    }
    return total;
  }

  Future<void> _submit() async {
    final rows = _selectedItems();
    if (rows.isEmpty) {
      _showError(context.tr('Dooro ugu yaraan hal alaab oo la celinayo.', 'Select at least one item to return.'));
      return;
    }
    for (final item in _items) {
      final q = double.tryParse(_qty[item['id']]?.text.trim() ?? '') ?? 0;
      if (q > _itemQty(item)) {
        _showError(context.tr('Tirada celinta kama badnaan karto tirada la iibiyay.', 'Return quantity cannot exceed sold quantity.'));
        return;
      }
    }
    if (_reason.text.trim().length < 3) {
      _showError(context.tr('Geli sababta celinta.', 'Enter the return reason.'));
      return;
    }
    setState(() => _loading = true);
    try {
      await _repo.recordReturn(saleId: widget.sale['id'] as String, items: rows, refundMethod: _refundMethod, reason: _reason.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(SnackBar(content: Text(context.tr('Celinta waa la diiwaangeliyay, kaydkana waa la cusboonaysiiyay.', 'Return recorded and stock updated.')), behavior: SnackBarBehavior.floating));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _showError(friendlyError(e, fallback: context.tr('Celinta lama diiwaangelin karin.', 'Could not record return.')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(SnackBar(content: Text(msg), backgroundColor: Theme.of(context).colorScheme.error, behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final invoice = widget.sale['invoice_no'] as String? ?? '#${(widget.sale['id'] as String).substring(0, 8)}';
    return AnimatedBuilder(
      animation: AppLanguage.instance,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text('${context.tr('Celinta Iibka', 'Return Sale')} $invoice')),
        body: _items.isEmpty
            ? Center(child: Text(context.tr('Faahfaahinta alaabta iibkan lama heli karo.', 'Item details are not available for this sale.')))
            : ListView(padding: const EdgeInsets.all(16), children: [
                Text(context.tr('Dooro alaabta la celinayo iyo tirada.', 'Select items and quantities to return.'), style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 12),
                ..._items.map((item) {
                  final id = item['id'] as String;
                  final maxQty = _itemQty(item);
                  return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item['product_name'] as String? ?? context.tr('Alaab', 'Item'), style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('${context.tr('La iibiyay', 'Sold')}: ${_fmt(maxQty)} ${item['unit'] ?? ''} × ${money(_itemPrice(item))}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ])),
                    const SizedBox(width: 12),
                    SizedBox(width: 86, child: TextField(controller: _qty[id], keyboardType: const TextInputType.numberWithOptions(decimal: true), textAlign: TextAlign.center, decoration: InputDecoration(labelText: context.tr('Celis', 'Return'), isDense: true, border: const OutlineInputBorder()), onChanged: (_) => setState(() {}))),
                  ])));
                }),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(value: _refundMethod, decoration: InputDecoration(labelText: context.tr('Qaabka celinta lacagta', 'Refund method'), prefixIcon: const Icon(Icons.payments_outlined)), items: [
                  DropdownMenuItem(value: 'cash', child: Text(context.tr('Caddaan', 'Cash'))),
                  DropdownMenuItem(value: 'bank', child: Text(context.tr('Bangiga', 'Bank'))),
                  const DropdownMenuItem(value: 'mobile_money', child: Text('Mobile Money')),
                  DropdownMenuItem(value: 'credit_adjustment', child: Text(context.tr('Ka jar deynta', 'Credit adjustment'))),
                ], onChanged: (v) { if (v != null) setState(() => _refundMethod = v); }),
                const SizedBox(height: 12),
                TextField(controller: _reason, textCapitalization: TextCapitalization.sentences, maxLines: 2, decoration: InputDecoration(labelText: context.tr('Sababta celinta *', 'Return reason *'), prefixIcon: const Icon(Icons.notes_outlined), alignLabelWithHint: true)),
                const SizedBox(height: 16),
                Card(color: Colors.orange.shade50, child: ListTile(title: Text(context.tr('Wadarta celinta', 'Refund total')), trailing: Text(money(_refundTotal), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.orange.shade800)))),
                const SizedBox(height: 16),
                FilledButton.icon(onPressed: _loading ? null : _submit, icon: _loading ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.undo_outlined), label: Text(context.tr('Diiwaangeli Celin', 'Record Return'))),
              ]),
      ),
    );
  }
}

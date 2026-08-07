import 'package:flutter/material.dart';
import '../../../core/finance/financial_rules.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/idempotency.dart';
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
  Map<String, double> _alreadyRefunded = const {};
  String _refundMethod = 'cash';
  String? _operationKey;
  String? _refundTotalsError;
  bool _refundTotalsLoading = true;
  bool _loading = false;

  List<Map<String, dynamic>> get _items {
    final raw = widget.sale['sale_items'];
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(raw as List);
  }

  bool get _isCredit => widget.sale['sale_type'] == 'credit';

  @override
  void initState() {
    super.initState();
    if (_isCredit && ((widget.sale['balance_amount'] as num?)?.toDouble() ?? 0) > 0) {
      _refundMethod = 'credit_adjustment';
    }
    for (final item in _items) {
      _qty[item['id'] as String] = TextEditingController();
    }
    _loadRefundTotals();
  }

  Future<void> _loadRefundTotals() async {
    if (mounted) {
      setState(() {
        _refundTotalsLoading = true;
        _refundTotalsError = null;
      });
    }
    try {
      final totals = await _repo.returnedRefundTotals(
        _items.map((item) => item['id'] as String).toList(growable: false),
      );
      if (!mounted) return;
      setState(() {
        _alreadyRefunded = totals;
        _refundTotalsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _refundTotalsLoading = false;
        _refundTotalsError = friendlyError(
          e,
          fallback: context.tr(
            'Lacagihii hore loo celiyay lama xaqiijin karin.',
            'Previous refund amounts could not be verified.',
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _reason.dispose();
    for (final c in _qty.values) {
      c.dispose();
    }
    super.dispose();
  }

  double _soldQty(Map<String, dynamic> item) => ((item['quantity'] as num?) ?? 0).toDouble();
  double _returnedQty(Map<String, dynamic> item) => ((item['returned_quantity'] as num?) ?? 0).toDouble();
  double _remainingQty(Map<String, dynamic> item) => (_soldQty(item) - _returnedQty(item)).clamp(0, double.infinity);
  double _itemPrice(Map<String, dynamic> item) => ((item['unit_price'] as num?) ?? 0).toDouble();
  double _lineTotal(Map<String, dynamic> item) => ((item['total_price'] as num?) ?? 0).toDouble();
  String _fmt(double v) => v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  double _lineRefund(Map<String, dynamic> item, double quantity) {
    if (!FinancialRules.returnQuantityAllowed(
      sold: _soldQty(item),
      alreadyReturned: _returnedQty(item),
      requested: quantity,
    )) {
      return 0;
    }

    return FinancialRules.lineRefundAmount(
      lineTotal: _lineTotal(item),
      soldQuantity: _soldQty(item),
      alreadyReturnedQuantity: _returnedQty(item),
      alreadyRefundedAmount: _alreadyRefunded[item['id'] as String] ?? 0,
      requestedQuantity: quantity,
    );
  }

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
      if (q > 0) total += _lineRefund(item, q);
    }
    return total;
  }

  Future<void> _submit() async {
    if (_refundTotalsLoading || _refundTotalsError != null) {
      _showError(context.tr(
        'Sug inta xogta celinta la xaqiijinayo.',
        'Wait until the refund data is verified.',
      ));
      return;
    }

    final rows = _selectedItems();
    if (rows.isEmpty) {
      _showError(context.tr('Dooro ugu yaraan hal alaab oo la celinayo.', 'Select at least one item to return.'));
      return;
    }
    for (final item in _items) {
      final q = double.tryParse(_qty[item['id']]?.text.trim() ?? '') ?? 0;
      if (q > _remainingQty(item)) {
        _showError(context.tr('Tirada celinta kama badnaan karto tirada weli la celin karo.', 'Return quantity cannot exceed the remaining returnable quantity.'));
        return;
      }
    }
    if (_reason.text.trim().length < 3) {
      _showError(context.tr('Geli sababta celinta.', 'Enter the return reason.'));
      return;
    }
    if (_refundMethod == 'credit_adjustment' && !_isCredit) {
      _showError(context.tr('Ka-jarista deynta waxaa loo isticmaali karaa iib deyn ah oo keliya.', 'Credit adjustment can only be used for a credit sale.'));
      return;
    }

    _operationKey ??= newOperationKey('return');
    setState(() => _loading = true);
    try {
      await _repo.recordReturn(
        saleId: widget.sale['id'] as String,
        items: rows,
        refundMethod: _refundMethod,
        reason: _reason.text.trim(),
        idempotencyKey: _operationKey,
      );
      if (!mounted) return;
      _operationKey = null;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text(context.tr('Celinta, kaydka, lacagta iyo warbixinnada waa la cusboonaysiiyay.', 'Return, stock, financial ledger, and reports were updated.')),
          behavior: SnackBarBehavior.floating,
        ));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _showError(friendlyError(
        e,
        fallback: context.tr(
          'Celinta lama xaqiijin. Mar kale isku day; laba-celin waa la xannibay.',
          'Return could not be confirmed. Retry safely; duplicate returns are blocked.',
        ),
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final saleId = widget.sale['id'] as String;
    final safeId = saleId.substring(0, saleId.length.clamp(0, 8));
    final invoice = widget.sale['invoice_no'] as String? ?? '#$safeId';
    final availableItems = _items.where((item) => _remainingQty(item) > 0).toList();

    return AnimatedBuilder(
      animation: AppLanguage.instance,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text('${context.tr('Celinta Iibka', 'Return Sale')} $invoice')),
        body: availableItems.isEmpty
            ? Center(child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(context.tr('Dhammaan alaabta iibkan waa la celiyay ama faahfaahinta lama heli karo.', 'All items have already been returned or item details are unavailable.'), textAlign: TextAlign.center),
              ))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(context.tr('Dooro alaabta la celinayo iyo tirada weli la celin karo.', 'Select items and quantities still eligible for return.'), style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 12),
                  if (_refundTotalsLoading)
                    const LinearProgressIndicator()
                  else if (_refundTotalsError != null)
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: ListTile(
                        leading: Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
                        title: Text(_refundTotalsError!),
                        trailing: IconButton(
                          onPressed: _loadRefundTotals,
                          icon: const Icon(Icons.refresh),
                          tooltip: context.tr('Mar kale isku day', 'Try again'),
                        ),
                      ),
                    ),
                  if (_refundTotalsLoading || _refundTotalsError != null)
                    const SizedBox(height: 12),
                  ...availableItems.map((item) {
                    final id = item['id'] as String;
                    final sold = _soldQty(item);
                    final returned = _returnedQty(item);
                    final remaining = _remainingQty(item);
                    final requested = double.tryParse(_qty[id]?.text.trim() ?? '') ?? 0;
                    final lineRefund = _refundTotalsLoading || _refundTotalsError != null
                        ? 0.0
                        : _lineRefund(item, requested);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(item['product_name'] as String? ?? context.tr('Alaab', 'Item'), style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text('${context.tr('La iibiyay', 'Sold')}: ${_fmt(sold)} • ${context.tr('Hore loo celiyay', 'Previously returned')}: ${_fmt(returned)}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                              Text('${context.tr('La celin karo', 'Returnable')}: ${_fmt(remaining)} ${item['unit'] ?? ''} × ${money(_itemPrice(item))}', style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                              if (requested > 0 && lineRefund > 0)
                                Text('${context.tr('Lacagta saxda ah', 'Exact refund')}: ${money(lineRefund)}', style: TextStyle(fontSize: 12, color: Colors.orange.shade800, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 86,
                            child: TextField(
                              controller: _qty[id],
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(labelText: context.tr('Celis', 'Return'), isDense: true, border: const OutlineInputBorder()),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ]),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _refundMethod,
                    decoration: InputDecoration(labelText: context.tr('Qaabka celinta lacagta', 'Refund method'), prefixIcon: const Icon(Icons.payments_outlined)),
                    items: [
                      DropdownMenuItem(value: 'cash', child: Text(context.tr('Caddaan', 'Cash'))),
                      DropdownMenuItem(value: 'bank', child: Text(context.tr('Bangiga', 'Bank'))),
                      DropdownMenuItem(value: 'mobile_money', child: Text(context.tr('Lacagta dhijitaalka', 'Mobile money'))),
                      if (_isCredit) DropdownMenuItem(value: 'credit_adjustment', child: Text(context.tr('Ka jar deynta', 'Credit adjustment'))),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _refundMethod = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _reason,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 2,
                    decoration: InputDecoration(labelText: context.tr('Sababta celinta *', 'Return reason *'), prefixIcon: const Icon(Icons.notes_outlined), alignLabelWithHint: true),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.orange.shade50,
                    child: ListTile(
                      title: Text(context.tr('Wadarta celinta', 'Refund total')),
                      trailing: _refundTotalsLoading
                          ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(money(_refundTotal), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.orange.shade800)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _loading || _refundTotalsLoading || _refundTotalsError != null ? null : _submit,
                    icon: _loading ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.undo_outlined),
                    label: Text(context.tr('Diiwaangeli Celin', 'Record Return')),
                  ),
                ],
              ),
      ),
    );
  }
}

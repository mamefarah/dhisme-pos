import 'package:flutter/material.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/utils/errors.dart';
import '../data/product_repository.dart';
import '../models/product.dart';

class AdjustStockScreen extends StatefulWidget {
  const AdjustStockScreen({super.key, required this.product});
  final Product product;

  @override
  State<AdjustStockScreen> createState() => _AdjustStockScreenState();
}

class _AdjustStockScreenState extends State<AdjustStockScreen> {
  final _repo = ProductRepository();
  final _formKey = GlobalKey<FormState>();
  final _qty = TextEditingController();
  final _reason = TextEditingController();
  bool _isAdd = true;
  bool _loading = false;

  @override
  void dispose() { _qty.dispose(); _reason.dispose(); super.dispose(); }
  double get _change => (_isAdd ? 1 : -1) * (double.tryParse(_qty.text) ?? 0);
  double get _newStock => widget.product.currentStock + _change;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      await _repo.adjustStock(productId: widget.product.id, quantityChange: _change, reason: _reason.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(SnackBar(content: Text(context.tr('Kaydka si guul leh ayaa loo saxay.', 'Stock adjusted successfully.')), behavior: SnackBarBehavior.floating));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(SnackBar(content: Text(friendlyError(e, fallback: context.tr('Kaydka lama sixi karin. Fadlan mar kale isku day.', 'Could not adjust stock. Please try again.'))), backgroundColor: Theme.of(context).colorScheme.error, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 5)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final qtyValue = double.tryParse(_qty.text) ?? 0;
    return AnimatedBuilder(
      animation: AppLanguage.instance,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text('${context.tr('Sax Kaydka', 'Adjust Stock')} — ${widget.product.name}')),
        body: Form(
          key: _formKey,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Card(child: ListTile(leading: const Icon(Icons.inventory_2_outlined), title: Text(context.tr('Kaydka hadda', 'Current stock')), trailing: Text('${widget.product.currentStock} ${widget.product.unit}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: RadioGroup<bool>(
                  groupValue: _isAdd,
                  onChanged: (value) {
                    if (value != null) setState(() => _isAdd = value);
                  },
                  child: Row(children: [
                    Expanded(child: RadioListTile<bool>(value: true, title: Text(context.tr('Kayd ku dar', 'Add stock')), contentPadding: const EdgeInsets.symmetric(horizontal: 8))),
                    Expanded(child: RadioListTile<bool>(value: false, title: Text(context.tr('Kayd ka jar', 'Remove stock')), contentPadding: const EdgeInsets.symmetric(horizontal: 8))),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _qty,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: '${context.tr('Tirada', 'Quantity')} (${widget.product.unit})', prefixIcon: Icon(_isAdd ? Icons.add : Icons.remove)),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n <= 0) return context.tr('Geli tiro ka weyn eber', 'Enter a positive quantity');
                if (!_isAdd && n > widget.product.currentStock) return context.tr('Kama jari kartid wax ka badan kaydka hadda (${widget.product.currentStock})', 'Cannot remove more than current stock (${widget.product.currentStock})');
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _reason,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              maxLines: 2,
              decoration: InputDecoration(labelText: context.tr('Sabab *', 'Reason *'), hintText: context.tr('Tusaale: alaab dhaawacantay, saxitaanka tirinta kaydka…', 'e.g. Damaged goods, stock count correction…'), prefixIcon: const Icon(Icons.notes_outlined), alignLabelWithHint: true),
              validator: (v) => (v == null || v.trim().length < 3) ? context.tr('Sabab waa loo baahan yahay (ugu yaraan 3 xaraf)', 'Reason is required (min 3 characters)') : null,
            ),
            if (qtyValue > 0) ...[
              const SizedBox(height: 16),
              Card(color: cs.primaryContainer, child: ListTile(leading: Icon(Icons.arrow_forward, color: cs.primary), title: Text(context.tr('Kaydka cusub kadib sixitaanka', 'New stock after adjustment')), trailing: Text('${_newStock.toStringAsFixed(_newStock % 1 == 0 ? 0 : 2)} ${widget.product.unit}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _newStock < 0 ? cs.error : cs.primary)))),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(onPressed: _loading ? null : _save, icon: _loading ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check), label: Text(context.tr('Xaqiiji Sixitaanka', 'Confirm Adjustment'))),
          ]),
        ),
      ),
    );
  }
}

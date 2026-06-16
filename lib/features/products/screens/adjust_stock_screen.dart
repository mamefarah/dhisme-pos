import 'package:flutter/material.dart';
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
  void dispose() {
    _qty.dispose();
    _reason.dispose();
    super.dispose();
  }

  double get _change => (_isAdd ? 1 : -1) * (double.tryParse(_qty.text) ?? 0);
  double get _newStock => widget.product.currentStock + _change;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      await _repo.adjustStock(
        productId: widget.product.id,
        quantityChange: _change,
        reason: _reason.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(
            content: Text('Stock adjusted successfully.'),
            behavior: SnackBarBehavior.floating,
          ));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text(friendlyError(e, fallback: 'Could not adjust stock. Please try again.')),
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
    final cs = Theme.of(context).colorScheme;
    final qtyValue = double.tryParse(_qty.text) ?? 0;

    return Scaffold(
      appBar: AppBar(title: Text('Adjust Stock — ${widget.product.name}')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Current stock info
            Card(
              child: ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: const Text('Current stock'),
                trailing: Text(
                  '${widget.product.currentStock} ${widget.product.unit}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Add / Remove toggle
            Card(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: RadioListTile<bool>(
                        value: true,
                        groupValue: _isAdd,
                        title: const Text('Add stock'),
                        onChanged: (v) => setState(() => _isAdd = v!),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<bool>(
                        value: false,
                        groupValue: _isAdd,
                        title: const Text('Remove stock'),
                        onChanged: (v) => setState(() => _isAdd = v!),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Quantity
            TextFormField(
              controller: _qty,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Quantity (${widget.product.unit})',
                prefixIcon: Icon(_isAdd ? Icons.add : Icons.remove),
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n <= 0) return 'Enter a positive quantity';
                if (!_isAdd && n > widget.product.currentStock) {
                  return 'Cannot remove more than current stock (${widget.product.currentStock})';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Reason
            TextFormField(
              controller: _reason,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Reason *',
                hintText: 'e.g. Damaged goods, stock count correction…',
                prefixIcon: Icon(Icons.notes_outlined),
                alignLabelWithHint: true,
              ),
              validator: (v) {
                if (v == null || v.trim().length < 3) return 'Reason is required (min 3 characters)';
                return null;
              },
            ),

            // Preview new stock
            if (qtyValue > 0) ...[
              const SizedBox(height: 16),
              Card(
                color: cs.primaryContainer,
                child: ListTile(
                  leading: Icon(Icons.arrow_forward, color: cs.primary),
                  title: const Text('New stock after adjustment'),
                  trailing: Text(
                    '${_newStock.toStringAsFixed(_newStock % 1 == 0 ? 0 : 2)} ${widget.product.unit}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _newStock < 0 ? cs.error : cs.primary,
                    ),
                  ),
                ),
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
                  : const Icon(Icons.check),
              label: const Text('Confirm Adjustment'),
            ),
          ],
        ),
      ),
    );
  }
}

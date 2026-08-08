import 'package:flutter/material.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/idempotency.dart';
import '../../../core/utils/money.dart';
import '../data/supplier_repository.dart';
import '../models/supplier.dart';

class SupplierPaymentScreen extends StatefulWidget {
  const SupplierPaymentScreen({super.key, required this.supplier});
  final Supplier supplier;

  @override
  State<SupplierPaymentScreen> createState() => _SupplierPaymentScreenState();
}

class _SupplierPaymentScreenState extends State<SupplierPaymentScreen> {
  final _repo = SupplierRepository();
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  String _paymentMethod = 'cash';
  String? _operationKey;
  bool _loading = false;

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null) return;
    _operationKey ??= newOperationKey('supplier-payment');
    setState(() => _loading = true);
    try {
      await _repo.recordPayment(
        supplierId: widget.supplier.id,
        amount: amount,
        paymentMethod: _paymentMethod,
        referenceNo: _reference.text.trim().isEmpty ? null : _reference.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        idempotencyKey: _operationKey,
      );
      if (!mounted) return;
      _operationKey = null;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text(context.tr('Lacag bixinta alaab-qeybiyaha waa la diiwaangeliyay lana qaybiyay iibsiyada.', 'Supplier payment was recorded and allocated to purchases.')),
          behavior: SnackBarBehavior.floating,
        ));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text(friendlyError(
            e,
            fallback: context.tr(
              'Lacag bixinta lama xaqiijin. Mar kale isku day; laba-diiwaangelin waa la xannibay.',
              'Payment could not be confirmed. Retry safely; duplicates are blocked.',
            ),
          )),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLanguage.instance,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text('${context.tr('Bixi Alaab-qeybiye', 'Pay Supplier')} — ${widget.supplier.name}')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: Colors.orange.shade50,
                child: ListTile(
                  leading: Icon(Icons.account_balance_wallet_outlined, color: Colors.orange.shade800),
                  title: Text(context.tr('Deyn taagan', 'Outstanding balance')),
                  trailing: Text(money(widget.supplier.totalBalance), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: context.tr('Qadarka bixinta (ETB) *', 'Payment amount (ETB) *'), prefixIcon: const Icon(Icons.payments_outlined)),
                validator: (v) {
                  final n = double.tryParse(v?.trim() ?? '');
                  if (n == null || n <= 0) return context.tr('Geli lacag sax ah', 'Enter a valid amount');
                  if (n > widget.supplier.totalBalance) return context.tr('Lacagtu waxay ka badan tahay deynta.', 'Amount exceeds supplier balance.');
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _paymentMethod,
                decoration: InputDecoration(labelText: context.tr('Qaabka bixinta', 'Payment method'), prefixIcon: const Icon(Icons.credit_card_outlined)),
                items: [
                  DropdownMenuItem(value: 'cash', child: Text(context.tr('Caddaan', 'Cash'))),
                  DropdownMenuItem(value: 'bank', child: Text(context.tr('Bangiga', 'Bank'))),
                  DropdownMenuItem(value: 'mobile_money', child: Text(context.tr('Lacagta dhijitaalka', 'Mobile money'))),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _paymentMethod = v);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(controller: _reference, textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: context.tr('Reference (ikhtiyaari)', 'Reference (optional)'), prefixIcon: const Icon(Icons.tag_outlined))),
              const SizedBox(height: 12),
              TextFormField(controller: _notes, maxLines: 2, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(labelText: context.tr('Qoraal (ikhtiyaari)', 'Notes (optional)'), prefixIcon: const Icon(Icons.notes_outlined), alignLabelWithHint: true)),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loading ? null : _save,
                icon: _loading ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check),
                label: Text(context.tr('Xaqiiji Bixinta', 'Confirm Payment')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

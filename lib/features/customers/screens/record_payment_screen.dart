import 'package:flutter/material.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/idempotency.dart';
import '../../../core/utils/money.dart';
import '../data/customer_repository.dart';
import '../models/customer.dart';

class RecordPaymentScreen extends StatefulWidget {
  const RecordPaymentScreen({super.key, required this.customer});
  final Customer customer;

  @override
  State<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends State<RecordPaymentScreen> {
  final _repo = CustomerRepository();
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _referenceNo = TextEditingController();
  final _notes = TextEditingController();
  String _paymentMethod = 'cash';
  String? _operationKey;
  bool _loading = false;

  @override
  void dispose() {
    _amount.dispose();
    _referenceNo.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount = double.parse(_amount.text.trim());
    _operationKey ??= newOperationKey('customer-payment');
    setState(() => _loading = true);
    try {
      await _repo.recordPayment(
        customerId: widget.customer.id,
        amount: amount,
        paymentMethod: _paymentMethod,
        referenceNo: _referenceNo.text.trim().isEmpty ? null : _referenceNo.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        idempotencyKey: _operationKey,
      );
      if (!mounted) return;
      _operationKey = null;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text(context.tr('Lacag bixinta ${money(amount)} waa la diiwaangeliyay.', 'Payment of ${money(amount)} recorded.')),
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
              'Lacag bixinta lama xaqiijin. Mar kale isku day; nidaamku wuxuu ka hortagayaa in laba jeer la diiwaangeliyo.',
              'Payment could not be confirmed. Retry safely; duplicate recording is prevented.',
            ),
          )),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: AppLanguage.instance,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text('${context.tr('Diiwaangeli Lacag Bixin', 'Record Payment')} — ${widget.customer.name}')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: cs.errorContainer,
                child: ListTile(
                  leading: Icon(Icons.account_balance_wallet_outlined, color: cs.error),
                  title: Text(context.tr('Deyn taagan', 'Outstanding balance')),
                  trailing: Text(money(widget.customer.totalBalance), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: cs.error)),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: context.tr('Qadarka lacag bixinta (ETB) *', 'Payment amount (ETB) *'), prefixIcon: const Icon(Icons.payments_outlined)),
                validator: (v) {
                  final n = double.tryParse(v?.trim() ?? '');
                  if (n == null || n <= 0) return context.tr('Geli lacag sax ah', 'Enter a valid amount');
                  if (n > widget.customer.totalBalance) {
                    return context.tr('Lacagtu waxay ka badan tahay deynta (${money(widget.customer.totalBalance)})', 'Amount exceeds balance (${money(widget.customer.totalBalance)})');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _paymentMethod,
                decoration: InputDecoration(labelText: context.tr('Qaabka lacag bixinta *', 'Payment method *'), prefixIcon: const Icon(Icons.credit_card_outlined)),
                items: [
                  DropdownMenuItem(value: 'cash', child: Text(context.tr('Caddaan', 'Cash'))),
                  DropdownMenuItem(value: 'bank', child: Text(context.tr('Bangiga', 'Bank transfer'))),
                  DropdownMenuItem(value: 'mobile_money', child: Text(context.tr('Lacagta dhijitaalka', 'Mobile money'))),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _paymentMethod = v);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(controller: _referenceNo, textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: context.tr('Reference number (ikhtiyaari)', 'Reference number (optional)'), prefixIcon: const Icon(Icons.tag_outlined))),
              const SizedBox(height: 12),
              TextFormField(controller: _notes, textCapitalization: TextCapitalization.sentences, textInputAction: TextInputAction.done, maxLines: 2, decoration: InputDecoration(labelText: context.tr('Qoraal (ikhtiyaari)', 'Notes (optional)'), prefixIcon: const Icon(Icons.notes_outlined), alignLabelWithHint: true)),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loading ? null : _save,
                icon: _loading ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check),
                label: Text(context.tr('Xaqiiji Lacag Bixinta', 'Confirm Payment')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../core/utils/errors.dart';
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
    setState(() => _loading = true);
    try {
      await _repo.recordPayment(
        customerId: widget.customer.id,
        amount: double.parse(_amount.text.trim()),
        paymentMethod: _paymentMethod,
        referenceNo: _referenceNo.text.trim().isEmpty ? null : _referenceNo.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text('Payment of ${money(double.parse(_amount.text))} recorded.'),
            behavior: SnackBarBehavior.floating,
          ));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text(friendlyError(e, fallback: 'Could not record payment. Please try again.')),
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

    return Scaffold(
      appBar: AppBar(title: Text('Record Payment — ${widget.customer.name}')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Outstanding balance card
            Card(
              color: cs.errorContainer,
              child: ListTile(
                leading: Icon(Icons.account_balance_wallet_outlined, color: cs.error),
                title: const Text('Outstanding balance'),
                trailing: Text(
                  money(widget.customer.totalBalance),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: cs.error,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Amount
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Payment amount (ETB) *',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              validator: (v) {
                final n = double.tryParse(v?.trim() ?? '');
                if (n == null || n <= 0) return 'Enter a valid amount';
                if (n > widget.customer.totalBalance) {
                  return 'Amount exceeds balance (${money(widget.customer.totalBalance)})';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Payment method
            DropdownButtonFormField<String>(
              value: _paymentMethod,
              decoration: const InputDecoration(
                labelText: 'Payment method *',
                prefixIcon: Icon(Icons.credit_card_outlined),
              ),
              items: const [
                DropdownMenuItem(value: 'cash',         child: Text('Cash')),
                DropdownMenuItem(value: 'bank',         child: Text('Bank transfer')),
                DropdownMenuItem(value: 'mobile_money', child: Text('Mobile money')),
              ],
              onChanged: (v) { if (v != null) setState(() => _paymentMethod = v); },
            ),
            const SizedBox(height: 12),

            // Reference no (for bank/mobile money)
            TextFormField(
              controller: _referenceNo,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Reference / transaction no. (optional)',
                prefixIcon: Icon(Icons.tag_outlined),
              ),
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
            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: _loading ? null : _save,
              icon: _loading
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check),
              label: const Text('Confirm Payment'),
            ),
          ],
        ),
      ),
    );
  }
}

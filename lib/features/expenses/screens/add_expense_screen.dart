import 'package:flutter/material.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/money.dart';
import '../data/expense_repository.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _repo = ExpenseRepository();
  final _formKey = GlobalKey<FormState>();
  final _category = TextEditingController();
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  DateTime _date = DateTime.now();
  String _paymentMethod = 'cash';
  bool _loading = false;

  @override
  void dispose() {
    _category.dispose();
    _amount.dispose();
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now());
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null) return;
    setState(() => _loading = true);
    try {
      await _repo.recordExpense(
        category: _category.text.trim(),
        amount: amount,
        paymentMethod: _paymentMethod,
        expenseDate: _date,
        referenceNo: _reference.text.trim().isEmpty ? null : _reference.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(context.tr('Kharashka ${money(amount)} waa la diiwaangeliyay.', 'Expense of ${money(amount)} recorded.')), behavior: SnackBarBehavior.floating));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(friendlyError(e, fallback: context.tr('Kharashka lama diiwaangelin karin.', 'Could not record expense.'))), backgroundColor: Theme.of(context).colorScheme.error, behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _dateText(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLanguage.instance,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(context.tr('Diiwaangeli Kharash', 'Record Expense'))),
        body: Form(
          key: _formKey,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text(context.tr('Taariikhda kharashka', 'Expense date')),
              subtitle: Text(_dateText(_date)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickDate,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _category,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: context.tr('Qaybta kharashka *', 'Expense category *'), prefixIcon: const Icon(Icons.category_outlined), hintText: context.tr('Tusaale: Transport, Shaah, Kirada…', 'e.g. Transport, tea, rent…')),
              validator: (v) => v == null || v.trim().length < 2 ? context.tr('Qaybta kharashka waa loo baahan yahay', 'Expense category is required') : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: context.tr('Lacagta (ETB) *', 'Amount (ETB) *'), prefixIcon: const Icon(Icons.payments_outlined)),
              validator: (v) {
                final n = double.tryParse(v?.trim() ?? '');
                if (n == null || n <= 0) return context.tr('Geli lacag sax ah', 'Enter a valid amount');
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
                DropdownMenuItem(value: 'mobile_money', child: Text(context.tr('Lacagta dhijitaalka', 'Mobile Money'))),
              ],
              onChanged: (v) { if (v != null) setState(() => _paymentMethod = v); },
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _reference, textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: context.tr('Reference (ikhtiyaari)', 'Reference (optional)'), prefixIcon: const Icon(Icons.tag_outlined))),
            const SizedBox(height: 12),
            TextFormField(controller: _notes, textCapitalization: TextCapitalization.sentences, maxLines: 2, decoration: InputDecoration(labelText: context.tr('Qoraal (ikhtiyaari)', 'Notes (optional)'), prefixIcon: const Icon(Icons.notes_outlined), alignLabelWithHint: true)),
            const SizedBox(height: 24),
            FilledButton.icon(onPressed: _loading ? null : _save, icon: _loading ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save), label: Text(context.tr('Kaydi Kharash', 'Save Expense'))),
          ]),
        ),
      ),
    );
  }
}

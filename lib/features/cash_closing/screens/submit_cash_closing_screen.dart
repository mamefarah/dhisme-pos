import 'package:flutter/material.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/errors.dart';
import '../../auth/models/app_profile.dart';
import '../data/cash_closing_repository.dart';

class SubmitCashClosingScreen extends StatefulWidget {
  const SubmitCashClosingScreen({super.key, required this.profile});
  final AppProfile profile;

  @override
  State<SubmitCashClosingScreen> createState() =>
      _SubmitCashClosingScreenState();
}

class _SubmitCashClosingScreenState extends State<SubmitCashClosingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = CashClosingRepository();
  final _cash = TextEditingController();
  final _notes = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _cash.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final cash = double.tryParse(_cash.text.trim());
    if (cash == null) return; // validator already caught this

    setState(() => _loading = true);
    try {
      await _repo.submit(
        closingDate: todayIsoDate(),
        actualCash: cash,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text('Cash closing submitted successfully.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        _cash.clear();
        _notes.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(
                friendlyError(
                  e,
                  fallback:
                      'Could not submit cash closing. Please try again.',
                ),
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Cash Closing')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Closing date'),
                subtitle: Text(
                  todayIsoDate(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cash,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Actual cash in hand (ETB)',
                prefixIcon: Icon(Icons.payments_outlined),
                hintText: '0.00',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please enter the actual cash amount';
                }
                final val = double.tryParse(v.trim());
                if (val == null) return 'Please enter a valid number';
                if (val < 0) return 'Amount cannot be negative';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              minLines: 3,
              maxLines: 5,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Notes / shortage explanation (optional)',
                prefixIcon: Icon(Icons.notes_outlined),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _loading ? null : _submit,
              icon: _loading
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_outlined),
              label: const Text('Submit Closing'),
            ),
          ],
        ),
      ),
    );
  }
}

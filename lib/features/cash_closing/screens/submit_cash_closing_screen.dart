import 'package:flutter/material.dart';
import '../../../core/utils/dates.dart';
import '../../auth/models/app_profile.dart';
import '../data/cash_closing_repository.dart';

class SubmitCashClosingScreen extends StatefulWidget {
  const SubmitCashClosingScreen({super.key, required this.profile});
  final AppProfile profile;

  @override
  State<SubmitCashClosingScreen> createState() => _SubmitCashClosingScreenState();
}

class _SubmitCashClosingScreenState extends State<SubmitCashClosingScreen> {
  final _repo = CashClosingRepository();
  final _cash = TextEditingController();
  final _notes = TextEditingController();
  bool _loading = false;

  @override
  void dispose() { _cash.dispose(); _notes.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final cash = double.tryParse(_cash.text.trim());
    if (cash == null || cash < 0) return;
    setState(() => _loading = true);
    try {
      await _repo.submit(closingDate: todayIsoDate(), actualCash: cash, notes: _notes.text.trim());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cash closing submitted.')));
      _cash.clear(); _notes.clear();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submit failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Daily Cash Closing')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Text('Closing date: ${todayIsoDate()}', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      TextField(controller: _cash, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Actual cash in hand')),
      const SizedBox(height: 12),
      TextField(controller: _notes, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: 'Notes / shortage explanation')),
      const SizedBox(height: 20),
      FilledButton.icon(onPressed: _loading ? null : _submit, icon: const Icon(Icons.send), label: const Text('Submit Closing')),
    ]),
  );
}

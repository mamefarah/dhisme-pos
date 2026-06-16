import 'package:flutter/material.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/money.dart';
import '../../auth/models/app_profile.dart';
import '../data/cash_closing_repository.dart';

class SubmitCashClosingScreen extends StatefulWidget {
  const SubmitCashClosingScreen({super.key, required this.profile});
  final AppProfile profile;

  @override
  State<SubmitCashClosingScreen> createState() => _SubmitCashClosingScreenState();
}

class _SubmitCashClosingScreenState extends State<SubmitCashClosingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = CashClosingRepository();
  final _cash = TextEditingController();
  final _notes = TextEditingController();

  late Future<Map<String, double>> _statsFuture;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _statsFuture = _repo.todayStats();
  }

  @override
  void dispose() {
    _cash.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final cash = double.tryParse(_cash.text.trim());
    if (cash == null) return;

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
          ..showSnackBar(const SnackBar(
            content: Text('Cash closing submitted successfully.'),
            behavior: SnackBarBehavior.floating,
          ));
        _cash.clear();
        _notes.clear();
        setState(() => _statsFuture = _repo.todayStats());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text(friendlyError(e, fallback: 'Could not submit cash closing. Please try again.')),
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
      appBar: AppBar(title: const Text('Daily Cash Closing')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Date card
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
            const SizedBox(height: 12),

            // Today's sales summary (async, non-blocking)
            FutureBuilder<Map<String, double>>(
              future: _statsFuture,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Card(
                    color: Colors.grey.shade50,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Row(children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.black38),
                        SizedBox(width: 8),
                        Text(
                          "Could not load today's sales summary.",
                          style: TextStyle(fontSize: 12, color: Colors.black45),
                        ),
                      ]),
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                final s = snap.data!;
                final cashTotal = s['cash'] ?? 0;
                final bank = s['bank'] ?? 0;
                final mobile = s['mobile_money'] ?? 0;
                final credit = s['credit'] ?? 0;
                final grandTotal = cashTotal + bank + mobile + credit;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.bar_chart, size: 18, color: Colors.black54),
                          const SizedBox(width: 6),
                          Text(
                            "Today's Sales Summary",
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        // Expected in drawer — highlighted
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: cs.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: cs.primary.withOpacity(0.25)),
                          ),
                          child: Row(children: [
                            Icon(Icons.payments_outlined, size: 18, color: cs.primary),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Expected in drawer',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            Text(
                              money(cashTotal),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: cs.primary,
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 8),
                        _SummaryRow(label: 'Bank transfers', value: bank, icon: Icons.account_balance_outlined),
                        _SummaryRow(label: 'Mobile money', value: mobile, icon: Icons.phone_android_outlined),
                        _SummaryRow(label: 'Credit sales', value: credit, icon: Icons.credit_score_outlined),
                        const Divider(height: 16),
                        Row(children: [
                          const Expanded(
                            child: Text('Total sales today',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          Text(money(grandTotal),
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ]),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Actual cash field
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
                if (v == null || v.trim().isEmpty) return 'Please enter the actual cash amount';
                final val = double.tryParse(v.trim());
                if (val == null) return 'Please enter a valid number';
                if (val < 0) return 'Amount cannot be negative';
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Notes field
            TextFormField(
              controller: _notes,
              minLines: 3,
              maxLines: 5,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.sentences,
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
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, required this.icon});
  final String label;
  final double value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Icon(icon, size: 15, color: Colors.black45),
        const SizedBox(width: 6),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54))),
        Text(money(value), style: const TextStyle(fontSize: 13)),
      ]),
    );
  }
}

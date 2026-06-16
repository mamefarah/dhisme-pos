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

  // Combined: (today's closing row or null, today's stats)
  late Future<(Map<String, dynamic>?, Map<String, double>)> _future;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _cash.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = Future.wait([
        _repo.todayClosing(),
        _repo.todayStats(),
      ]).then((r) => (r[0] as Map<String, dynamic>?, r[1] as Map<String, double>));
    });
  }

  void _prefill(Map<String, dynamic> closing) {
    final prev = (closing['actual_cash'] as num?)?.toDouble() ?? 0;
    _cash.text = prev > 0 ? prev.toStringAsFixed(2) : '';
    _notes.text = closing['notes'] as String? ?? '';
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
        _reload();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text(friendlyError(e, fallback: 'Could not submit. Please try again.')),
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
      appBar: AppBar(
        title: const Text('Daily Cash Closing'),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<(Map<String, dynamic>?, Map<String, double>)>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(
                    friendlyError(snapshot.error!, fallback: 'Could not load closing data.'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                  ),
                ]),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final (closing, stats) = snapshot.data!;
          final status = closing?['status'] as String?;

          // ── Approved: locked view ──────────────────────────────────────────
          if (status == 'approved') {
            return _ApprovedView(closing: closing!, stats: stats, cs: cs);
          }

          // ── Submitted or Rejected: pre-fill form ───────────────────────────
          if ((status == 'submitted' || status == 'rejected') && _cash.text.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _prefill(closing!));
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Status banner
                if (status == 'submitted') ...[
                  _StatusBanner(
                    icon: Icons.check_circle_outline,
                    color: Colors.amber.shade700,
                    background: Colors.amber.shade50,
                    message: "Already submitted for today. You can update the figures below.",
                  ),
                  const SizedBox(height: 12),
                ] else if (status == 'rejected') ...[
                  _StatusBanner(
                    icon: Icons.cancel_outlined,
                    color: Colors.red.shade700,
                    background: Colors.red.shade50,
                    message: "Rejected by owner${closing!['owner_comment'] != null ? ': ${closing['owner_comment']}' : '.'}  Correct and resubmit.",
                  ),
                  const SizedBox(height: 12),
                ],

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

                // Today's sales summary
                _StatsCard(stats: stats, cs: cs),
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
                  label: Text(status == 'submitted' ? 'Update Closing' : 'Submit Closing'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Approved locked view ──────────────────────────────────────────────────────

class _ApprovedView extends StatelessWidget {
  const _ApprovedView({required this.closing, required this.stats, required this.cs});
  final Map<String, dynamic> closing;
  final Map<String, double> stats;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final expected = (closing['expected_cash'] as num?)?.toDouble() ?? 0;
    final actual = (closing['actual_cash'] as num?)?.toDouble() ?? 0;
    final diff = (closing['cash_difference'] as num?)?.toDouble() ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatusBanner(
          icon: Icons.verified_outlined,
          color: Colors.green.shade700,
          background: Colors.green.shade50,
          message: "Today's closing has been approved by the owner.",
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.task_alt, size: 18, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Approved Closing — ${closing['closing_date']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ]),
                const SizedBox(height: 12),
                _ClosingRow(label: 'Expected in drawer', value: expected),
                _ClosingRow(label: 'Actual cash counted', value: actual),
                const Divider(height: 16),
                _ClosingRow(
                  label: diff >= 0 ? 'Surplus' : 'Shortage',
                  value: diff.abs(),
                  color: diff >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                  bold: true,
                ),
                if ((closing['bank_total'] as num?)?.toDouble() != 0) ...[
                  const SizedBox(height: 8),
                  _ClosingRow(label: 'Bank transfers', value: (closing['bank_total'] as num?)?.toDouble() ?? 0),
                ],
                if ((closing['mobile_money_total'] as num?)?.toDouble() != 0) ...[
                  _ClosingRow(label: 'Mobile money', value: (closing['mobile_money_total'] as num?)?.toDouble() ?? 0),
                ],
                if ((closing['credit_sales_total'] as num?)?.toDouble() != 0) ...[
                  _ClosingRow(label: 'Credit sales', value: (closing['credit_sales_total'] as num?)?.toDouble() ?? 0),
                ],
                if (closing['notes'] != null && (closing['notes'] as String).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Notes: ${closing['notes']}',
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.icon, required this.color, required this.background, required this.message});
  final IconData icon;
  final Color color;
  final Color background;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: TextStyle(color: color, fontSize: 13))),
      ]),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats, required this.cs});
  final Map<String, double> stats;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final cashTotal = stats['cash'] ?? 0;
    final bank = stats['bank'] ?? 0;
    final mobile = stats['mobile_money'] ?? 0;
    final credit = stats['credit'] ?? 0;
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
              ),
              child: Row(children: [
                Icon(Icons.payments_outlined, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Expected in drawer', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                Text(
                  money(cashTotal),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: cs.primary),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            if (bank > 0) _SummaryRow(label: 'Bank transfers', value: bank, icon: Icons.account_balance_outlined),
            if (mobile > 0) _SummaryRow(label: 'Mobile money', value: mobile, icon: Icons.phone_android_outlined),
            if (credit > 0) _SummaryRow(label: 'Credit sales', value: credit, icon: Icons.credit_score_outlined),
            const Divider(height: 16),
            Row(children: [
              const Expanded(child: Text('Total sales today', style: TextStyle(fontWeight: FontWeight.bold))),
              Text(money(grandTotal), style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
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

class _ClosingRow extends StatelessWidget {
  const _ClosingRow({required this.label, required this.value, this.color, this.bold = false});
  final String label;
  final double value;
  final Color? color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 13,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      color: color ?? (bold ? Colors.black87 : Colors.black54),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Expanded(child: Text(label, style: style)),
        Text(money(value), style: style),
      ]),
    );
  }
}

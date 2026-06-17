import 'package:flutter/material.dart';
import '../../../core/i18n/app_language.dart';
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
  late Future<(Map<String, dynamic>?, Map<String, double>)> _future;
  bool _loading = false;

  @override
  void initState() { super.initState(); _reload(); }
  @override
  void dispose() { _cash.dispose(); _notes.dispose(); super.dispose(); }

  void _reload() {
    setState(() {
      _future = () async { final closing = await _repo.todayClosing(); final stats = await _repo.todayStats(); return (closing, stats); }();
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
      await _repo.submit(closingDate: todayIsoDate(), actualCash: cash, notes: _notes.text.trim().isEmpty ? null : _notes.text.trim());
      if (mounted) { ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(SnackBar(content: Text(context.tr('Xiritaanka lacagta si guul leh ayaa loo gudbiyay.', 'Cash closing submitted successfully.')), behavior: SnackBarBehavior.floating)); _reload(); }
    } catch (e) {
      if (mounted) { ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(SnackBar(content: Text(friendlyError(e, fallback: context.tr('Lama gudbin karin. Fadlan mar kale isku day.', 'Could not submit. Please try again.'))), backgroundColor: Theme.of(context).colorScheme.error, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 5))); }
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLanguage.instance,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(context.tr('Xiritaanka Lacagta Maalinlaha', 'Daily Cash Closing')), actions: [IconButton(onPressed: _reload, icon: const Icon(Icons.refresh), tooltip: context.tr('Cusboonaysii', 'Refresh'))]),
        body: FutureBuilder<(Map<String, dynamic>?, Map<String, double>)>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) return _ErrorView(error: snapshot.error!, onRetry: _reload);
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final (closing, stats) = snapshot.data!;
            final status = closing?['status'] as String?;
            if (status == 'approved') return _ApprovedView(closing: closing!, stats: stats);
            if ((status == 'submitted' || status == 'rejected') && _cash.text.isEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => _prefill(closing!));
            return Form(key: _formKey, child: ListView(padding: const EdgeInsets.all(16), children: [
              if (status == 'submitted') _StatusBanner(icon: Icons.check_circle_outline, color: Colors.amber.shade700, background: Colors.amber.shade50, message: context.tr('Maanta horay ayaa loo gudbiyay. Waxaad cusboonaysiin kartaa tirada hoose.', 'Already submitted for today. You can update the figures below.')),
              if (status == 'rejected') _StatusBanner(icon: Icons.cancel_outlined, color: Colors.red.shade700, background: Colors.red.shade50, message: context.tr('Milkiiluhu wuu diiday. Sax oo mar kale gudbi.', 'Rejected by owner. Correct and resubmit.')),
              if (status == 'submitted' || status == 'rejected') const SizedBox(height: 12),
              Card(child: ListTile(leading: const Icon(Icons.calendar_today_outlined), title: Text(context.tr('Taariikhda xiritaanka', 'Closing date')), subtitle: Text(todayIsoDate(), style: const TextStyle(fontWeight: FontWeight.bold)))),
              const SizedBox(height: 12),
              _StatsCard(stats: stats),
              const SizedBox(height: 12),
              TextFormField(controller: _cash, keyboardType: const TextInputType.numberWithOptions(decimal: true), textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: context.tr('Lacagta caddaanka ah ee gacanta ku jirta (ETB)', 'Actual cash in hand (ETB)'), prefixIcon: const Icon(Icons.payments_outlined), hintText: '0.00'), validator: (v) { if (v == null || v.trim().isEmpty) return context.tr('Geli lacagta caddaanka ah ee dhabta ah', 'Please enter the actual cash amount'); final val = double.tryParse(v.trim()); if (val == null) return context.tr('Geli tiro sax ah', 'Please enter a valid number'); if (val < 0) return context.tr('Lacagtu taban ma noqon karto', 'Amount cannot be negative'); return null; }),
              const SizedBox(height: 12),
              TextFormField(controller: _notes, minLines: 3, maxLines: 5, textInputAction: TextInputAction.done, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(labelText: context.tr('Qoraal / sharaxaad farqi (ikhtiyaari)', 'Notes / difference explanation (optional)'), prefixIcon: const Icon(Icons.notes_outlined), alignLabelWithHint: true)),
              const SizedBox(height: 20),
              FilledButton.icon(onPressed: _loading ? null : _submit, icon: _loading ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_outlined), label: Text(status == 'submitted' ? context.tr('Cusboonaysii Xiritaanka', 'Update Closing') : context.tr('Gudbi Xiritaanka', 'Submit Closing'))),
            ]));
          },
        ),
      ),
    );
  }
}

class _ApprovedView extends StatelessWidget {
  const _ApprovedView({required this.closing, required this.stats});
  final Map<String, dynamic> closing;
  final Map<String, double> stats;
  @override
  Widget build(BuildContext context) {
    final expected = (closing['expected_cash'] as num?)?.toDouble() ?? 0;
    final actual = (closing['actual_cash'] as num?)?.toDouble() ?? 0;
    final diff = (closing['cash_difference'] as num?)?.toDouble() ?? 0;
    return ListView(padding: const EdgeInsets.all(16), children: [
      _StatusBanner(icon: Icons.verified_outlined, color: Colors.green.shade700, background: Colors.green.shade50, message: context.tr('Xiritaanka maanta milkiiluhu wuu ansixiyay.', "Today's closing has been approved by the owner.")),
      const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [_MoneyRow(label: context.tr('La filayay', 'Expected in drawer'), value: expected), _MoneyRow(label: context.tr('La tiriyay', 'Actual cash counted'), value: actual), const Divider(height: 16), _MoneyRow(label: diff >= 0 ? context.tr('Dheeraad', 'Surplus') : context.tr('Yaraan', 'Shortage'), value: diff.abs(), color: diff >= 0 ? Colors.green.shade700 : Colors.red.shade700, bold: true)]))),
      const SizedBox(height: 12),
      _StatsCard(stats: stats),
    ]);
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});
  final Map<String, double> stats;
  @override
  Widget build(BuildContext context) {
    final cash = stats['cash'] ?? 0;
    final bank = stats['bank'] ?? 0;
    final mobile = stats['mobile_money'] ?? 0;
    final credit = stats['credit'] ?? 0;
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(context.tr('Soo-koobidda Iibka Maanta', "Today's Sales Summary"), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      _MoneyRow(label: context.tr('Caddaan la filayo', 'Expected in drawer'), value: cash, bold: true),
      _MoneyRow(label: context.tr('Bangiga', 'Bank transfers'), value: bank),
      _MoneyRow(label: 'Mobile Money', value: mobile),
      _MoneyRow(label: context.tr('Iib deyn ah', 'Credit sales'), value: credit),
    ])));
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({required this.label, required this.value, this.color, this.bold = false});
  final String label;
  final double value;
  final Color? color;
  final bool bold;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.normal))), Text(money(value), style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.w600, color: color))]));
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.icon, required this.color, required this.background, required this.message});
  final IconData icon;
  final Color color;
  final Color background;
  final String message;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.35))), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 18, color: color), const SizedBox(width: 10), Expanded(child: Text(message, style: TextStyle(color: color, fontSize: 13)))]));
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline, size: 48, color: Colors.red), const SizedBox(height: 12), Text(friendlyError(error, fallback: context.tr('Xogta xiritaanka lama soo gelin karin.', 'Could not load closing data.')), textAlign: TextAlign.center), const SizedBox(height: 12), FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: Text(context.tr('Mar kale isku day', 'Try Again')))])));
}

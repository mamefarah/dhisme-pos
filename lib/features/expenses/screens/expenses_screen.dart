import 'package:flutter/material.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../data/expense_repository.dart';
import 'add_expense_screen.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _repo = ExpenseRepository();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() { super.initState(); _reload(); }
  void _reload() => setState(() => _future = _repo.listExpenses());

  String _paymentLabel(BuildContext context, String method) {
    switch (method) {
      case 'bank': return context.tr('Bangiga', 'Bank');
      case 'mobile_money': return context.tr('Lacagta dhijitaalka', 'Mobile Money');
      default: return context.tr('Caddaan', 'Cash');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLanguage.instance,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(context.tr('Kharashaadka', 'Expenses')), actions: [IconButton(onPressed: _reload, icon: const Icon(Icons.refresh), tooltip: context.tr('Cusboonaysii', 'Refresh'))]),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline, size: 48, color: Colors.red), const SizedBox(height: 12), Text(friendlyError(snapshot.error!, fallback: context.tr('Kharashaadka lama soo gelin karin.', 'Could not load expenses.')), textAlign: TextAlign.center), const SizedBox(height: 12), FilledButton.icon(onPressed: _reload, icon: const Icon(Icons.refresh), label: Text(context.tr('Mar kale isku day', 'Try Again')))])));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final rows = snapshot.data!;
            if (rows.isEmpty) return EmptyState(message: context.tr('Weli kharash lama diiwaangelin. Taabo + si aad u darto.', 'No expenses recorded yet. Tap + to add one.'));
            final total = rows.fold<double>(0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0));
            return Column(children: [
              Container(width: double.infinity, padding: const EdgeInsets.all(14), color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35), child: Row(children: [Expanded(child: Text(context.tr('Wadarta kharashaadka', 'Total expenses'), style: const TextStyle(fontWeight: FontWeight.w600))), Text(money(total), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Theme.of(context).colorScheme.primary))])),
              Expanded(child: RefreshIndicator(onRefresh: () async => _reload(), child: ListView.builder(padding: const EdgeInsets.all(12), itemCount: rows.length, itemBuilder: (context, i) {
                final e = rows[i];
                final dt = DateTime.tryParse(e['created_at'] as String? ?? '');
                final by = (e['profiles'] as Map?)?['full_name'] as String?;
                return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
                  leading: CircleAvatar(backgroundColor: Colors.red.withValues(alpha: 0.1), child: Icon(Icons.money_off_outlined, color: Colors.red.shade700)),
                  title: Row(children: [Expanded(child: Text(e['category'] as String? ?? '-', style: const TextStyle(fontWeight: FontWeight.w600))), Text(money(((e['amount'] as num?) ?? 0).toDouble()), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade700))]),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${e['expense_date'] ?? ''} • ${_paymentLabel(context, e['payment_method'] as String? ?? 'cash')}', style: const TextStyle(fontSize: 12)),
                    if (e['reference_no'] != null) Text('Ref: ${e['reference_no']}', style: const TextStyle(fontSize: 12)),
                    if (e['notes'] != null) Text(e['notes'] as String, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    if (by != null || dt != null) Text('${by ?? ''}${dt != null ? ' • ${formatDateTime(dt)}' : ''}', style: const TextStyle(fontSize: 11, color: Colors.black45)),
                  ]),
                  isThreeLine: true,
                ));
              }))),
            ]);
          },
        ),
        floatingActionButton: FloatingActionButton.extended(onPressed: () async { final added = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const AddExpenseScreen())); if (added == true) _reload(); }, icon: const Icon(Icons.add), label: Text(context.tr('Ku dar Kharash', 'Add Expense'))),
      ),
    );
  }
}

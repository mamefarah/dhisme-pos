import 'package:flutter/material.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/models/app_profile.dart';
import '../data/cash_closing_repository.dart';

class OwnerCashClosingsScreen extends StatefulWidget {
  const OwnerCashClosingsScreen({super.key, required this.profile});
  final AppProfile profile;

  @override
  State<OwnerCashClosingsScreen> createState() => _OwnerCashClosingsScreenState();
}

class _OwnerCashClosingsScreenState extends State<OwnerCashClosingsScreen> {
  final _repo = CashClosingRepository();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() { super.initState(); _future = _repo.listClosings(); }
  void _reload() => setState(() => _future = _repo.listClosings());

  Future<void> _review(String id, String status) async {
    try {
      await _repo.review(id, status);
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text(friendlyError(e, fallback: 'Could not process this decision. Please try again.')),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cash Closings'), actions: [IconButton(onPressed: _reload, icon: const Icon(Icons.refresh))]),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(
                    friendlyError(snapshot.error!, fallback: 'Could not load cash closings. Please try again.'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final rows = snapshot.data!;
        if (rows.isEmpty) return const EmptyState(message: 'No cash closing submitted yet.');
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: rows.length,
          itemBuilder: (context, i) {
            final r = rows[i];
            final status = r['status'] as String;
            return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text('Date: ${r['closing_date']}', style: const TextStyle(fontWeight: FontWeight.bold))), Chip(label: Text(status))]),
              Text('Seller: ${r['profiles']?['full_name'] ?? '-'}'),
              Text('Expected cash: ${money(r['expected_cash'] ?? 0)}'),
              Text('Actual cash: ${money(r['actual_cash'] ?? 0)}'),
              Text('Difference: ${money(r['cash_difference'] ?? 0)}'),
              Text('Bank: ${money(r['bank_total'] ?? 0)} • Mobile: ${money(r['mobile_money_total'] ?? 0)} • Credit: ${money(r['credit_sales_total'] ?? 0)}'),
              if ((r['notes'] ?? '').toString().isNotEmpty) Text('Notes: ${r['notes']}'),
              Text('Submitted: ${formatDateTime(DateTime.parse(r['created_at']))}'),
              if (status == 'submitted') Row(children: [
                Expanded(child: FilledButton(onPressed: () => _review(r['id'], 'approved'), child: const Text('Approve'))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton(onPressed: () => _review(r['id'], 'rejected'), child: const Text('Reject'))),
              ]),
            ])));
          },
        );
      },
    ),
  );
}

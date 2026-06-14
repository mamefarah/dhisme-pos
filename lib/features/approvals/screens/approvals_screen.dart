import 'package:flutter/material.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/models/app_profile.dart';
import '../data/approval_repository.dart';

class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key, required this.profile});
  final AppProfile profile;

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> {
  final _repo = ApprovalRepository();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() { super.initState(); _future = _repo.allApprovals(); }
  void _reload() => setState(() => _future = _repo.allApprovals());

  Future<void> _decide(String id, String decision) async {
    try {
      await _repo.decide(id, decision);
      _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Decision failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Owner Approvals'), actions: [IconButton(onPressed: _reload, icon: const Icon(Icons.refresh))]),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final rows = snapshot.data!;
        if (rows.isEmpty) return const EmptyState(message: 'No approval requests yet.');
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: rows.length,
          itemBuilder: (context, i) {
            final r = rows[i];
            final status = r['status'] as String;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('${r['request_type']}'.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold))),
                    Chip(label: Text(status)),
                  ]),
                  Text('Amount: ${money(r['amount'] ?? 0)}'),
                  Text('Reason: ${r['reason'] ?? ''}'),
                  Text('Requested: ${formatDateTime(DateTime.parse(r['created_at']))}'),
                  const SizedBox(height: 8),
                  if (status == 'pending') Row(children: [
                    Expanded(child: FilledButton.icon(onPressed: () => _decide(r['id'], 'approved'), icon: const Icon(Icons.check), label: const Text('Approve'))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton.icon(onPressed: () => _decide(r['id'], 'rejected'), icon: const Icon(Icons.close), label: const Text('Reject'))),
                  ]),
                ]),
              ),
            );
          },
        );
      },
    ),
  );
}

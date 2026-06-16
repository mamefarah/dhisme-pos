import 'package:flutter/material.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/models/app_profile.dart';
import '../data/cash_closing_repository.dart';

enum _StatusFilter { submitted, all, approved, rejected }

class OwnerCashClosingsScreen extends StatefulWidget {
  const OwnerCashClosingsScreen({super.key, required this.profile});
  final AppProfile profile;

  @override
  State<OwnerCashClosingsScreen> createState() => _OwnerCashClosingsScreenState();
}

class _OwnerCashClosingsScreenState extends State<OwnerCashClosingsScreen> {
  final _repo = CashClosingRepository();
  late Future<List<Map<String, dynamic>>> _future;
  _StatusFilter _filter = _StatusFilter.submitted;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = _repo.listClosings(
        status: _filter == _StatusFilter.all ? null : _filter.name,
      );
    });
  }

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

  Future<void> _confirmAndReview(String id, String status) async {
    final label = status == 'approved' ? 'approve' : 'reject';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${label[0].toUpperCase()}${label.substring(1)} closing?'),
        content: Text('Are you sure you want to $label this cash closing?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: status == 'rejected'
                ? FilledButton.styleFrom(backgroundColor: Colors.red.shade700)
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(label[0].toUpperCase() + label.substring(1)),
          ),
        ],
      ),
    );
    if (confirmed == true) await _review(id, status);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cash Closings'),
        actions: [IconButton(onPressed: _reload, icon: const Icon(Icons.refresh))],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              children: [
                _Chip(
                  label: 'Submitted',
                  selected: _filter == _StatusFilter.submitted,
                  color: Colors.orange,
                  onTap: () { setState(() => _filter = _StatusFilter.submitted); _reload(); },
                ),
                const SizedBox(width: 8),
                _Chip(
                  label: 'All',
                  selected: _filter == _StatusFilter.all,
                  onTap: () { setState(() => _filter = _StatusFilter.all); _reload(); },
                ),
                const SizedBox(width: 8),
                _Chip(
                  label: 'Approved',
                  selected: _filter == _StatusFilter.approved,
                  color: Colors.green,
                  onTap: () { setState(() => _filter = _StatusFilter.approved); _reload(); },
                ),
                const SizedBox(width: 8),
                _Chip(
                  label: 'Rejected',
                  selected: _filter == _StatusFilter.rejected,
                  color: Colors.red,
                  onTap: () { setState(() => _filter = _StatusFilter.rejected); _reload(); },
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
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
                          friendlyError(snapshot.error!, fallback: 'Could not load cash closings. Please try again.'),
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
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final rows = snapshot.data!;
                if (rows.isEmpty) {
                  return EmptyState(
                    message: _filter == _StatusFilter.submitted
                        ? 'No submissions waiting for review.'
                        : 'No cash closings found.',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: rows.length,
                    itemBuilder: (context, i) => _ClosingCard(
                      data: rows[i],
                      onApprove: () => _confirmAndReview(rows[i]['id'] as String, 'approved'),
                      onReject: () => _confirmAndReview(rows[i]['id'] as String, 'rejected'),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Closing card ──────────────────────────────────────────────────────────────

class _ClosingCard extends StatelessWidget {
  const _ClosingCard({required this.data, required this.onApprove, required this.onReject});
  final Map<String, dynamic> data;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  String get _status => data['status'] as String? ?? 'submitted';
  String get _sellerName => (data['profiles'] as Map?)?['full_name'] as String? ?? '—';
  String get _date => data['closing_date'] as String? ?? '—';
  double get _expected => (data['expected_cash'] as num?)?.toDouble() ?? 0;
  double get _actual => (data['actual_cash'] as num?)?.toDouble() ?? 0;
  double get _difference => (data['cash_difference'] as num?)?.toDouble() ?? (_actual - _expected);
  double get _bank => (data['bank_total'] as num?)?.toDouble() ?? 0;
  double get _mobile => (data['mobile_money_total'] as num?)?.toDouble() ?? 0;
  double get _credit => (data['credit_sales_total'] as num?)?.toDouble() ?? 0;
  String? get _notes => data['notes'] as String?;

  String get _submittedAt {
    final raw = data['created_at'] as String?;
    if (raw == null) return '—';
    final dt = DateTime.tryParse(raw);
    return dt != null ? formatDateTime(dt) : raw;
  }

  Color _statusColor() {
    switch (_status) {
      case 'approved': return Colors.green.shade700;
      case 'rejected': return Colors.red.shade700;
      default: return Colors.orange.shade700;
    }
  }

  String get _statusLabel {
    switch (_status) {
      case 'approved': return 'Approved';
      case 'rejected': return 'Rejected';
      default: return 'Submitted';
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();
    final diff = _difference;
    final diffColor = diff < 0 ? Colors.red.shade700 : Colors.green.shade700;
    final diffLabel = diff == 0
        ? 'Exact match'
        : diff > 0
            ? '+ ${money(diff)} surplus'
            : '− ${money(diff.abs())} shortage';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: date + status
            Row(children: [
              Expanded(
                child: Text(
                  _date,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusLabel,
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
            const SizedBox(height: 4),
            // Seller
            Row(children: [
              const Icon(Icons.badge_outlined, size: 14, color: Colors.black45),
              const SizedBox(width: 4),
              Text(_sellerName, style: const TextStyle(fontSize: 13, color: Colors.black54)),
              const Spacer(),
              const Icon(Icons.schedule, size: 13, color: Colors.black45),
              const SizedBox(width: 4),
              Text(_submittedAt, style: const TextStyle(fontSize: 11, color: Colors.black45)),
            ]),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Cash comparison
            _Row(label: 'Expected in drawer', value: money(_expected)),
            _Row(label: 'Actual cash counted', value: money(_actual)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: diffColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: diffColor.withOpacity(0.25)),
              ),
              child: Row(children: [
                Icon(
                  diff < 0 ? Icons.arrow_downward : Icons.arrow_upward,
                  size: 14,
                  color: diffColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Difference',
                    style: TextStyle(fontWeight: FontWeight.w600, color: diffColor),
                  ),
                ),
                Text(
                  diffLabel,
                  style: TextStyle(fontWeight: FontWeight.bold, color: diffColor),
                ),
              ]),
            ),

            // Other payment totals (only show if non-zero)
            if (_bank > 0 || _mobile > 0 || _credit > 0) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              if (_bank > 0)
                _Row(
                  label: 'Bank transfers',
                  value: money(_bank),
                  icon: Icons.account_balance_outlined,
                ),
              if (_mobile > 0)
                _Row(
                  label: 'Mobile money',
                  value: money(_mobile),
                  icon: Icons.phone_android_outlined,
                ),
              if (_credit > 0)
                _Row(
                  label: 'Credit sales',
                  value: money(_credit),
                  icon: Icons.credit_score_outlined,
                ),
            ],

            // Notes
            if (_notes != null && _notes!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.notes_outlined, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(child: Text(_notes!, style: const TextStyle(fontSize: 12))),
                ]),
              ),
            ],

            // Action buttons
            if (_status == 'submitted') ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────────

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.icon});
  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: Colors.black45),
          const SizedBox(width: 4),
        ],
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54))),
        Text(value, style: const TextStyle(fontSize: 13)),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap, this.color});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.withOpacity(0.15) : Colors.grey.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? c : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? c : Colors.black54,
          ),
        ),
      ),
    );
  }
}

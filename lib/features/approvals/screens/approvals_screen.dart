import 'package:flutter/material.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/models/app_profile.dart';
import '../data/approval_repository.dart';

enum _StatusFilter { pending, all, approved, rejected }

class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key, required this.profile});
  final AppProfile profile;

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> {
  final _repo = ApprovalRepository();
  late Future<List<Map<String, dynamic>>> _future;
  _StatusFilter _filter = _StatusFilter.pending;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = _repo.allApprovals(
        status: _filter == _StatusFilter.all ? null : _filter.name,
      );
    });
  }

  Future<void> _approve(String id) async {
    try {
      await _repo.decide(id, 'approved');
      _reload();
    } catch (e) {
      if (mounted) _showError(friendlyError(e, fallback: 'Could not approve this sale. Please try again.'));
    }
  }

  Future<void> _reject(String id) async {
    final comment = await _showRejectDialog();
    if (comment == null || !mounted) return;
    try {
      await _repo.decide(id, 'rejected', comment: comment.trim().isEmpty ? null : comment.trim());
      _reload();
    } catch (e) {
      if (mounted) _showError(friendlyError(e, fallback: 'Could not reject this sale. Please try again.'));
    }
  }

  Future<String?> _showRejectDialog() => showDialog<String>(
        context: context,
        builder: (_) {
          final ctrl = TextEditingController();
          return AlertDialog(
            title: const Text('Reject this sale?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'The sale will be cancelled. You can add an optional note for the seller.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  decoration: const InputDecoration(
                    labelText: 'Note for seller (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
                onPressed: () => Navigator.pop(context, ctrl.text),
                child: const Text('Reject'),
              ),
            ],
          );
        },
      );

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Approvals'),
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
                  label: 'Pending',
                  selected: _filter == _StatusFilter.pending,
                  color: Colors.orange,
                  onTap: () { setState(() => _filter = _StatusFilter.pending); _reload(); },
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
                          friendlyError(snapshot.error!, fallback: 'Could not load approvals.'),
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
                    message: _filter == _StatusFilter.pending
                        ? 'No pending approvals. All caught up!'
                        : 'No approval requests found.',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: rows.length,
                    itemBuilder: (context, i) => _ApprovalCard(
                      data: rows[i],
                      onApprove: () => _approve(rows[i]['id'] as String),
                      onReject: () => _reject(rows[i]['id'] as String),
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

// ── Approval card ─────────────────────────────────────────────────────────────

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({required this.data, required this.onApprove, required this.onReject});
  final Map<String, dynamic> data;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  String get _sellerName =>
      (data['profiles'] as Map?)?['full_name'] as String? ?? '—';

  String? get _customerName =>
      ((data['sales'] as Map?)?['customers'] as Map?)?['name'] as String?;

  String? get _invoiceNo => (data['sales'] as Map?)?['invoice_no'] as String?;

  double get _total =>
      (data['amount'] as num?)?.toDouble() ??
      ((data['sales'] as Map?)?['total_amount'] as num?)?.toDouble() ??
      0;

  double get _discount =>
      ((data['sales'] as Map?)?['discount'] as num?)?.toDouble() ?? 0;

  List<Map<String, dynamic>> get _items {
    final raw = (data['sales'] as Map?)?['sale_items'];
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(raw as List);
  }

  String get _status => data['status'] as String? ?? 'pending';

  String get _reason => data['reason'] as String? ?? '';

  String? get _ownerComment => data['owner_comment'] as String?;

  String get _requestedAt {
    final raw = data['created_at'] as String?;
    if (raw == null) return '—';
    final dt = DateTime.tryParse(raw);
    return dt != null ? formatDateTime(dt) : raw;
  }

  String? get _decidedAt {
    final raw = data['decided_at'] as String?;
    if (raw == null) return null;
    final dt = DateTime.tryParse(raw);
    return dt != null ? formatDateTime(dt) : null;
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
      default: return 'Pending';
    }
  }

  String _fmtQty(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();
    final items = _items;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Seller + status badge
            Row(children: [
              const Icon(Icons.badge_outlined, size: 15, color: Colors.black45),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _sellerName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
            const SizedBox(height: 6),
            // Customer
            if (_customerName != null) ...[
              Row(children: [
                const Icon(Icons.person_outline, size: 15, color: Colors.black45),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(_customerName!, style: const TextStyle(fontSize: 13)),
                ),
              ]),
              const SizedBox(height: 4),
            ],
            // Invoice + timestamp
            Row(children: [
              if (_invoiceNo != null && _invoiceNo!.isNotEmpty) ...[
                const Icon(Icons.receipt_outlined, size: 14, color: Colors.black45),
                const SizedBox(width: 4),
                Text(_invoiceNo!, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(width: 10),
              ],
              const Icon(Icons.schedule, size: 13, color: Colors.black45),
              const SizedBox(width: 4),
              Text(_requestedAt, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ]),
            // Reason
            if (_reason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.blue.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _reason,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ]),
              ),
            ],
            // Items
            if (items.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              for (final item in items) Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '${item['product_name'] ?? 'Item'}  ×  '
                        '${_fmtQty(((item['quantity'] ?? 0) as num).toDouble())} '
                        '${item['unit'] ?? ''}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      money(((item['total_price'] ?? 0) as num).toDouble()),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              if (_discount > 0) ...[
                const SizedBox(height: 2),
                Row(children: [
                  const Expanded(
                    child: Text('Discount', style: TextStyle(fontSize: 12, color: Colors.black54)),
                  ),
                  Text(
                    '− ${money(_discount)}',
                    style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                  ),
                ]),
              ],
              const SizedBox(height: 4),
              const Divider(height: 1),
            ] else
              const SizedBox(height: 8),
            // Total row
            const SizedBox(height: 6),
            Row(children: [
              const Expanded(child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
              Text(
                money(_total),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ]),
            // Decision info (approved / rejected)
            if (_decidedAt != null) ...[
              const SizedBox(height: 6),
              Text(
                '${_statusLabel} on $_decidedAt',
                style: TextStyle(fontSize: 11, color: statusColor),
              ),
            ],
            if (_ownerComment != null && _ownerComment!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.comment_outlined, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(_ownerComment!, style: const TextStyle(fontSize: 12)),
                  ),
                ]),
              ),
            ],
            // Action buttons (pending only)
            if (_status == 'pending') ...[
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

// ── Filter chip ───────────────────────────────────────────────────────────────

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

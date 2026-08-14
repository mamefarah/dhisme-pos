import 'package:flutter/material.dart';
import '../../../core/i18n/app_language.dart';
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
  final Set<String> _busyIds = {};

  @override
  void initState() { super.initState(); _reload(); }
  void _reload() => setState(() => _future = _repo.listClosings(status: _filter == _StatusFilter.all ? null : _filter.name));

  Future<void> _review(String id, String status) async {
    if (_busyIds.contains(id)) return;
    setState(() => _busyIds.add(id));
    try { await _repo.review(id, status); _reload(); }
    catch (e) { if (mounted) { ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(SnackBar(content: Text(friendlyError(e, fallback: context.tr('Go’aankan lama fulin karin. Fadlan mar kale isku day.', 'Could not process this decision. Please try again.'))), backgroundColor: Theme.of(context).colorScheme.error, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 5))); } }
    finally { if (mounted) setState(() => _busyIds.remove(id)); }
  }

  Future<void> _confirmAndReview(String id, String status) async {
    if (_busyIds.contains(id)) return;
    final isApprove = status == 'approved';
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(isApprove ? context.tr('Ansixi xiritaanka?', 'Approve closing?') : context.tr('Diid xiritaanka?', 'Reject closing?')),
      content: Text(isApprove ? context.tr('Ma hubtaa inaad ansixinayso xiritaanka lacagta?', 'Are you sure you want to approve this cash closing?') : context.tr('Ma hubtaa inaad diidayso xiritaanka lacagta?', 'Are you sure you want to reject this cash closing?')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('Jooji', 'Cancel'))), FilledButton(style: isApprove ? null : FilledButton.styleFrom(backgroundColor: Colors.red.shade700), onPressed: () => Navigator.pop(ctx, true), child: Text(isApprove ? context.tr('Ansixi', 'Approve') : context.tr('Diid', 'Reject')))],
    ));
    if (confirmed == true) await _review(id, status);
  }

  String _chipLabel(BuildContext context, _StatusFilter f) {
    switch (f) { case _StatusFilter.submitted: return context.tr('La gudbiyay', 'Submitted'); case _StatusFilter.all: return context.tr('Dhammaan', 'All'); case _StatusFilter.approved: return context.tr('La ansixiyay', 'Approved'); case _StatusFilter.rejected: return context.tr('La diiday', 'Rejected'); }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLanguage.instance,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(context.tr('Xiritaanka Lacagta', 'Cash Closings')), actions: [IconButton(onPressed: _reload, icon: const Icon(Icons.refresh), tooltip: context.tr('Cusboonaysii', 'Refresh'))]),
        body: Column(children: [
          SizedBox(height: 44, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), children: [
            for (final f in _StatusFilter.values) ...[ _Chip(label: _chipLabel(context, f), selected: _filter == f, onTap: () { setState(() => _filter = f); _reload(); }, color: f == _StatusFilter.approved ? Colors.green : f == _StatusFilter.rejected ? Colors.red : f == _StatusFilter.submitted ? Colors.orange : null), const SizedBox(width: 8) ],
          ])),
          Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.hasError) return _ErrorView(error: snapshot.error!, onRetry: _reload);
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final rows = snapshot.data!;
              if (rows.isEmpty) return EmptyState(message: _filter == _StatusFilter.submitted ? context.tr('Xiritaan sugaya dib-u-eegis ma jiro.', 'No submissions waiting for review.') : context.tr('Xiritaan lacag lama helin.', 'No cash closings found.'));
              return RefreshIndicator(onRefresh: () async => _reload(), child: ListView.builder(padding: const EdgeInsets.all(12), itemCount: rows.length, itemBuilder: (context, i) => _ClosingCard(data: rows[i], busy: _busyIds.contains(rows[i]['id'] as String), onApprove: () => _confirmAndReview(rows[i]['id'] as String, 'approved'), onReject: () => _confirmAndReview(rows[i]['id'] as String, 'rejected'))));
            },
          )),
        ]),
      ),
    );
  }
}

class _ClosingCard extends StatelessWidget {
  const _ClosingCard({required this.data, required this.busy, required this.onApprove, required this.onReject});
  final Map<String, dynamic> data;
  final bool busy;
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

  String _statusLabel(BuildContext context) { switch (_status) { case 'approved': return context.tr('La ansixiyay', 'Approved'); case 'rejected': return context.tr('La diiday', 'Rejected'); default: return context.tr('La gudbiyay', 'Submitted'); } }
  Color _statusColor() { switch (_status) { case 'approved': return Colors.green.shade700; case 'rejected': return Colors.red.shade700; default: return Colors.orange.shade700; } }
  String _submittedAt() { final raw = data['created_at'] as String?; if (raw == null) return '—'; final dt = DateTime.tryParse(raw); return dt != null ? formatDateTime(dt) : raw; }

  @override
  Widget build(BuildContext context) {
    final diff = _difference;
    final diffColor = diff < 0 ? Colors.red.shade700 : Colors.green.shade700;
    final diffLabel = diff == 0 ? context.tr('Isku mid', 'Exact match') : diff > 0 ? '+ ${money(diff)} ${context.tr('dheeraad', 'surplus')}' : '− ${money(diff.abs())} ${context.tr('yaraan', 'shortage')}';
    final statusColor = _statusColor();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(_date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), child: Text(_statusLabel(context), style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)))]),
        const SizedBox(height: 4),
        Row(children: [const Icon(Icons.badge_outlined, size: 14, color: Colors.black45), const SizedBox(width: 4), Expanded(child: Text(_sellerName, style: const TextStyle(fontSize: 13, color: Colors.black54))), const Icon(Icons.schedule, size: 13, color: Colors.black45), const SizedBox(width: 4), Text(_submittedAt(), style: const TextStyle(fontSize: 11, color: Colors.black45))]),
        const SizedBox(height: 10), const Divider(height: 1), const SizedBox(height: 10),
        _Row(label: context.tr('La filayay', 'Expected in drawer'), value: money(_expected)),
        _Row(label: context.tr('La tiriyay', 'Actual cash counted'), value: money(_actual)),
        const SizedBox(height: 4),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: diffColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: diffColor.withValues(alpha: 0.25))), child: Row(children: [Expanded(child: Text(context.tr('Farqi', 'Difference'), style: TextStyle(fontWeight: FontWeight.w600, color: diffColor))), Text(diffLabel, style: TextStyle(fontWeight: FontWeight.bold, color: diffColor))])),
        if (_bank > 0 || _mobile > 0 || _credit > 0) ...[const SizedBox(height: 10), const Divider(height: 1), const SizedBox(height: 8), if (_bank > 0) _Row(label: context.tr('Bangiga', 'Bank transfers'), value: money(_bank)), if (_mobile > 0) _Row(label: 'Mobile Money', value: money(_mobile)), if (_credit > 0) _Row(label: context.tr('Iib deyn ah', 'Credit sales'), value: money(_credit))],
        if (_notes != null && _notes!.isNotEmpty) ...[const SizedBox(height: 10), Text('${context.tr('Qoraal', 'Notes')}: $_notes', style: const TextStyle(fontSize: 12, color: Colors.black54))],
        if (_status == 'submitted') ...[const SizedBox(height: 12), Row(children: [
          Expanded(child: FilledButton.icon(
            onPressed: busy ? null : onApprove,
            icon: busy ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check, size: 18),
            label: Text(context.tr('Ansixi', 'Approve')),
          )),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(
            onPressed: busy ? null : onReject,
            icon: const Icon(Icons.close, size: 18),
            label: Text(context.tr('Diid', 'Reject')),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700),
          )),
        ])],
      ])),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54))), Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))]));
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline, size: 48, color: Colors.red), const SizedBox(height: 12), Text(friendlyError(error, fallback: context.tr('Xiritaanka lacagta lama soo gelin karin. Fadlan mar kale isku day.', 'Could not load cash closings. Please try again.')), textAlign: TextAlign.center), const SizedBox(height: 12), FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: Text(context.tr('Mar kale isku day', 'Try Again')))])));
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap, this.color});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;
  @override
  Widget build(BuildContext context) { final c = color ?? Theme.of(context).colorScheme.primary; return GestureDetector(onTap: onTap, child: AnimatedContainer(duration: const Duration(milliseconds: 150), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(color: selected ? c.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20), border: Border.all(color: selected ? c : Colors.grey.shade300)), child: Text(label, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.bold : FontWeight.normal, color: selected ? c : Colors.black54)))); }
}

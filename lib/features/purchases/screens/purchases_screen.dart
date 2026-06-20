import 'package:flutter/material.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/models/app_profile.dart';
import '../data/purchase_repository.dart';
import '../models/purchase.dart';
import 'new_purchase_v2_screen.dart';
import 'purchase_detail_screen.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key, required this.profile});
  final AppProfile profile;

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  final _repo = PurchaseRepository();
  late Future<List<Purchase>> _future;
  bool get _canRecord => widget.profile.isOwner || widget.profile.isManager;

  @override
  void initState() {
    super.initState();
    _future = _repo.listPurchases();
  }

  void _reload() => setState(() => _future = _repo.listPurchases());

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLanguage.instance,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(context.tr('Iibsiyada', 'Purchases')),
          actions: [IconButton(onPressed: _reload, icon: const Icon(Icons.refresh), tooltip: context.tr('Cusboonaysii', 'Refresh'))],
        ),
        body: FutureBuilder<List<Purchase>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(friendlyError(snapshot.error!, fallback: context.tr('Iibsiyada lama soo gelin karin. Fadlan mar kale isku day.', 'Could not load purchases. Please try again.')), textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton.icon(onPressed: _reload, icon: const Icon(Icons.refresh), label: Text(context.tr('Mar kale isku day', 'Try Again'))),
                  ]),
                ),
              );
            }
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final purchases = snapshot.data!;
            if (purchases.isEmpty) {
              return EmptyState(message: _canRecord
                  ? context.tr('Weli iibsi ma jiro. Taabo + si aad u diiwaangeliso kayd alaab-qeybiye laga helay.', 'No purchases yet. Tap + to record stock received from a supplier.')
                  : context.tr('Weli iibsi lama diiwaangelin.', 'No purchases recorded yet.'));
            }
            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: purchases.length,
                itemBuilder: (context, i) {
                  final p = purchases[i];
                  return _PurchaseTile(
                    purchase: p,
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PurchaseDetailScreen(purchase: p)));
                    },
                  );
                },
              ),
            );
          },
        ),
        floatingActionButton: _canRecord
            ? FloatingActionButton.extended(
                onPressed: () async {
                  final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const NewPurchaseV2Screen()));
                  if (changed == true) _reload();
                },
                icon: const Icon(Icons.add),
                label: Text(context.tr('Iibsi Cusub', 'New Purchase')),
              )
            : null,
      ),
    );
  }
}

class _PurchaseTile extends StatelessWidget {
  const _PurchaseTile({required this.purchase, required this.onTap});
  final Purchase purchase;
  final VoidCallback onTap;

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green.shade700;
      case 'partial':
        return Colors.orange.shade700;
      default:
        return Colors.red.shade700;
    }
  }

  String _statusLabel(BuildContext context, String status) {
    switch (status) {
      case 'paid':
        return context.tr('La bixiyay', 'Paid');
      case 'partial':
        return context.tr('Qayb la bixiyay', 'Partial');
      default:
        return context.tr('Lama bixin', 'Unpaid');
    }
  }

  String _formatDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final p = purchase;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(backgroundColor: Colors.blue.withValues(alpha: 0.12), child: const Icon(Icons.shopping_cart_outlined, color: Colors.blue, size: 20)),
        title: Row(children: [
          Expanded(child: Text(p.supplierName ?? context.tr('Alaab-qeybiye ma jiro', 'No supplier'), style: const TextStyle(fontWeight: FontWeight.w600))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: _statusColor(p.paymentStatus).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Text(_statusLabel(context, p.paymentStatus), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _statusColor(p.paymentStatus))),
          ),
        ]),
        subtitle: Row(children: [
          const Icon(Icons.calendar_today_outlined, size: 12, color: Colors.black45),
          const SizedBox(width: 4),
          Text(_formatDate(p.purchaseDate), style: const TextStyle(fontSize: 12)),
          if (p.invoiceRef != null && p.invoiceRef!.isNotEmpty) ...[
            const SizedBox(width: 12),
            const Icon(Icons.tag_outlined, size: 12, color: Colors.black45),
            const SizedBox(width: 2),
            Text(p.invoiceRef!, style: const TextStyle(fontSize: 12)),
          ],
        ]),
        trailing: Text(money(p.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

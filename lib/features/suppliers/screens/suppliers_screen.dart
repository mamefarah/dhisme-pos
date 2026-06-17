import 'package:flutter/material.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/models/app_profile.dart';
import '../data/supplier_repository.dart';
import '../models/supplier.dart';
import 'supplier_detail_screen.dart';
import 'supplier_form_screen.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key, required this.profile});
  final AppProfile profile;

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final _repo = SupplierRepository();
  final _search = TextEditingController();
  late Future<List<Supplier>> _future;
  bool _activeOnly = false;
  bool get _canEdit => widget.profile.isOwner || widget.profile.isManager;

  @override
  void initState() { super.initState(); _future = _repo.listSuppliers(); }
  @override
  void dispose() { _search.dispose(); super.dispose(); }
  void _reload() => setState(() => _future = _repo.listSuppliers(search: _search.text, activeOnly: _activeOnly));

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLanguage.instance,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(context.tr('Alaab-qeybiyeyaasha', 'Suppliers')), actions: [IconButton(onPressed: _reload, icon: const Icon(Icons.refresh), tooltip: context.tr('Cusboonaysii', 'Refresh'))]),
        body: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 0), child: Row(children: [
            Expanded(child: TextField(controller: _search, decoration: InputDecoration(hintText: context.tr('Ku raadi magac ama xiriir…', 'Search by name or contact…'), prefixIcon: const Icon(Icons.search), isDense: true), onChanged: (_) => _reload())),
            const SizedBox(width: 8),
            FilterChip(label: Text(context.tr('Kuwa shaqaynaya', 'Active only')), selected: _activeOnly, onSelected: (v) { setState(() => _activeOnly = v); _reload(); }),
          ])),
          const SizedBox(height: 8),
          Expanded(child: FutureBuilder<List<Supplier>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline, size: 48, color: Colors.red), const SizedBox(height: 12), Text(friendlyError(snapshot.error!, fallback: context.tr('Alaab-qeybiyeyaasha lama soo gelin karin. Fadlan mar kale isku day.', 'Could not load suppliers. Please try again.')), textAlign: TextAlign.center), const SizedBox(height: 12), FilledButton.icon(onPressed: _reload, icon: const Icon(Icons.refresh), label: Text(context.tr('Mar kale isku day', 'Try Again')))])));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final suppliers = snapshot.data!;
              if (suppliers.isEmpty) return EmptyState(message: _activeOnly || _search.text.isNotEmpty ? context.tr('Alaab-qeybiye ku habboon filter-ka lama helin.', 'No suppliers match your filter.') : _canEdit ? context.tr('Weli alaab-qeybiye ma jiro. Taabo + si aad mid ugu darto.', 'No suppliers yet. Tap + to add one.') : context.tr('Weli alaab-qeybiye lama darin.', 'No suppliers added yet.'));
              return RefreshIndicator(onRefresh: () async => _reload(), child: ListView.builder(padding: const EdgeInsets.all(12), itemCount: suppliers.length, itemBuilder: (context, i) { final s = suppliers[i]; return _SupplierTile(supplier: s, canEdit: _canEdit, onTap: () async { await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SupplierDetailScreen(supplier: s))); _reload(); }); }));
            },
          )),
        ]),
        floatingActionButton: _canEdit ? FloatingActionButton.extended(onPressed: () async { await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SupplierFormScreen())); _reload(); }, icon: const Icon(Icons.add), label: Text(context.tr('Ku dar Alaab-qeybiye', 'Add Supplier'))) : null,
      ),
    );
  }
}

class _SupplierTile extends StatelessWidget {
  const _SupplierTile({required this.supplier, required this.canEdit, required this.onTap});
  final Supplier supplier;
  final bool canEdit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = supplier;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(backgroundColor: s.isActive ? Colors.teal.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.15), child: Icon(Icons.local_shipping_outlined, color: s.isActive ? Colors.teal : Colors.grey, size: 20)),
        title: Row(children: [Expanded(child: Text(s.name, style: TextStyle(fontWeight: FontWeight.w600, color: s.isActive ? null : Colors.black38))), if (s.hasDebt) Text(money(s.totalBalance), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade800)), if (!s.isActive) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Text(context.tr('AAN SHAQAYN', 'INACTIVE'), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red.shade700)))]),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (s.phone != null && s.phone!.isNotEmpty) Row(children: [const Icon(Icons.phone_outlined, size: 12, color: Colors.black45), const SizedBox(width: 4), Text(s.phone!, style: const TextStyle(fontSize: 12))]),
          if (s.contactPerson != null && s.contactPerson!.isNotEmpty) Row(children: [const Icon(Icons.person_outlined, size: 12, color: Colors.black45), const SizedBox(width: 4), Text(s.contactPerson!, style: const TextStyle(fontSize: 12))]),
          if (s.address != null && s.address!.isNotEmpty) Row(children: [const Icon(Icons.location_on_outlined, size: 12, color: Colors.black45), const SizedBox(width: 4), Expanded(child: Text(s.address!, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis))]),
        ]),
        trailing: const Icon(Icons.chevron_right, color: Colors.black26),
        isThreeLine: (s.phone != null && s.phone!.isNotEmpty) && (s.contactPerson != null || s.address != null),
      ),
    );
  }
}

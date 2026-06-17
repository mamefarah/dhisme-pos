import 'package:flutter/material.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/utils/errors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/models/app_profile.dart';
import '../data/product_repository.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key, required this.profile});
  final AppProfile profile;

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final _repo = ProductRepository();
  late Future<List<Map<String, dynamic>>> _future;
  bool get _canEdit => widget.profile.isOwner || widget.profile.isManager;

  @override
  void initState() { super.initState(); _reload(); }
  void _reload() => setState(() => _future = _repo.listCategories());

  Future<void> _addCategory() async {
    final name = await _showNameDialog(title: context.tr('Ku dar Qayb', 'Add Category'));
    if (name == null) return;
    try { await _repo.addCategory(storeId: widget.profile.storeId, name: name); _reload(); }
    catch (e) { if (mounted) _showError(friendlyError(e, fallback: context.tr('Qaybta lama dari karin. Magacu hore ayuu u jiri karaa.', 'Could not add category. The name may already exist.'))); }
  }

  Future<void> _renameCategory(Map<String, dynamic> cat) async {
    final name = await _showNameDialog(title: context.tr('Magac beddel Qayb', 'Rename Category'), initial: cat['name'] as String);
    if (name == null) return;
    try { await _repo.updateCategory(id: cat['id'] as String, name: name); _reload(); }
    catch (e) { if (mounted) _showError(friendlyError(e, fallback: context.tr('Magaca qaybta lama beddeli karin. Magacu hore ayuu u jiri karaa.', 'Could not rename category. The name may already exist.'))); }
  }

  Future<String?> _showNameDialog({required String title, String? initial}) async {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(controller: ctrl, textCapitalization: TextCapitalization.words, autofocus: true, decoration: InputDecoration(labelText: context.tr('Magaca qaybta', 'Category name')), onSubmitted: (v) { if (v.trim().isNotEmpty) Navigator.pop(ctx, v.trim()); }),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('Jooji', 'Cancel'))), FilledButton(onPressed: () { final v = ctrl.text.trim(); if (v.isNotEmpty) Navigator.pop(ctx, v); }, child: Text(context.tr('Kaydi', 'Save')))],
    ));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(SnackBar(content: Text(msg), backgroundColor: Theme.of(context).colorScheme.error, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 5)));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLanguage.instance,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(context.tr('Qaybaha', 'Categories')), actions: [IconButton(onPressed: _reload, icon: const Icon(Icons.refresh), tooltip: context.tr('Cusboonaysii', 'Refresh')), if (_canEdit) IconButton(onPressed: _addCategory, icon: const Icon(Icons.add), tooltip: context.tr('Ku dar qayb', 'Add category'))]),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline, size: 48, color: Colors.red), const SizedBox(height: 12), Text(friendlyError(snap.error!, fallback: context.tr('Qaybaha lama soo gelin karin.', 'Could not load categories.')), textAlign: TextAlign.center), const SizedBox(height: 12), FilledButton.icon(onPressed: _reload, icon: const Icon(Icons.refresh), label: Text(context.tr('Mar kale isku day', 'Try Again')))])));
            }
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final cats = snap.data!;
            if (cats.isEmpty) return EmptyState(message: _canEdit ? context.tr('Weli qaybo ma jiraan. Taabo + si aad qaybta koowaad ugu darto.', 'No categories yet. Tap + to add your first one.') : context.tr('Weli qaybo ma jiraan.', 'No categories yet.'));
            return ListView.builder(padding: const EdgeInsets.all(12), itemCount: cats.length, itemBuilder: (context, i) { final cat = cats[i]; return Card(child: ListTile(leading: const Icon(Icons.label_outline), title: Text(cat['name'] as String, style: const TextStyle(fontWeight: FontWeight.w500)), trailing: _canEdit ? IconButton(icon: const Icon(Icons.edit_outlined, size: 20), tooltip: context.tr('Magac beddel', 'Rename'), onPressed: () => _renameCategory(cat)) : null)); });
          },
        ),
      ),
    );
  }
}

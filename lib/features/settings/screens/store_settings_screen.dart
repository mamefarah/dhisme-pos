import 'package:flutter/material.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/utils/errors.dart';
import '../../auth/models/app_profile.dart';
import '../data/store_repository.dart';

class StoreSettingsScreen extends StatefulWidget {
  const StoreSettingsScreen({super.key, required this.profile});
  final AppProfile profile;

  @override
  State<StoreSettingsScreen> createState() => _StoreSettingsScreenState();
}

class _StoreSettingsScreenState extends State<StoreSettingsScreen> {
  final _repo = StoreRepository();
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  bool _dataLoading = true;
  bool _saving = false;

  @override
  void initState() { super.initState(); _loadStore(); }
  @override
  void dispose() { _name.dispose(); _phone.dispose(); _address.dispose(); super.dispose(); }

  Future<void> _loadStore() async {
    setState(() => _dataLoading = true);
    try {
      final store = await _repo.fetchStore(widget.profile.storeId);
      if (mounted && store != null) {
        setState(() { _name.text = store['name'] as String? ?? ''; _phone.text = store['phone'] as String? ?? ''; _address.text = store['address'] as String? ?? ''; _dataLoading = false; });
      } else if (mounted) { setState(() => _dataLoading = false); }
    } catch (e) {
      if (mounted) { setState(() => _dataLoading = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e, fallback: context.tr('Xogta dukaanka lama soo gelin karin. Fadlan mar kale isku day.', 'Could not load store info. Please try again.'))), backgroundColor: Theme.of(context).colorScheme.error, behavior: SnackBarBehavior.floating)); }
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await _repo.updateStore(storeId: widget.profile.storeId, name: _name.text.trim(), phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(), address: _address.text.trim().isEmpty ? null : _address.text.trim());
      if (mounted) { ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(SnackBar(content: Text(context.tr('Dejinta dukaanka waa la kaydiyay.', 'Store settings saved.')), behavior: SnackBarBehavior.floating)); Navigator.of(context).pop(); }
    } catch (e) {
      if (mounted) { ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(SnackBar(content: Text(friendlyError(e, fallback: context.tr('Dejinta dukaanka lama kaydin karin. Fadlan mar kale isku day.', 'Could not save store settings. Please try again.'))), backgroundColor: Theme.of(context).colorScheme.error, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 5))); }
    } finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLanguage.instance,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(context.tr('Dejinta Dukaanka', 'Store Settings'))),
        body: _dataLoading ? const Center(child: CircularProgressIndicator()) : Form(key: _formKey, child: ListView(padding: const EdgeInsets.all(16), children: [
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [const Icon(Icons.info_outline, size: 18, color: Colors.black45), const SizedBox(width: 8), Expanded(child: Text(context.tr('Xogtan waxay ka muuqanaysaa rasiidhada la daabaco.', 'This information appears on printed receipts.'), style: const TextStyle(fontSize: 13, color: Colors.black54)))]))),
          const SizedBox(height: 16),
          TextFormField(controller: _name, textCapitalization: TextCapitalization.words, textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: context.tr('Magaca dukaanka *', 'Store name *'), prefixIcon: const Icon(Icons.storefront_outlined)), validator: (v) { if (v == null || v.trim().isEmpty) return context.tr('Magaca dukaanka waa loo baahan yahay', 'Store name is required'); if (v.trim().length < 2) return context.tr('Magacu ugu yaraan waa 2 xaraf', 'Name must be at least 2 characters'); return null; }),
          const SizedBox(height: 12),
          TextFormField(controller: _phone, keyboardType: TextInputType.phone, textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: context.tr('Telefoon (ikhtiyaari)', 'Phone (optional)'), prefixIcon: const Icon(Icons.phone_outlined), helperText: context.tr('Rasiidhada ayuu ka muuqanayaa', 'Shown on receipts'))),
          const SizedBox(height: 12),
          TextFormField(controller: _address, textCapitalization: TextCapitalization.sentences, textInputAction: TextInputAction.done, maxLines: 2, decoration: InputDecoration(labelText: context.tr('Cinwaan (ikhtiyaari)', 'Address (optional)'), prefixIcon: const Icon(Icons.location_on_outlined), alignLabelWithHint: true, helperText: context.tr('Rasiidhada ayuu ka muuqanayaa', 'Shown on receipts'))),
          const SizedBox(height: 24),
          FilledButton.icon(onPressed: _saving ? null : _save, icon: _saving ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save), label: Text(context.tr('Kaydi Dejinta', 'Save Settings'))),
        ])),
      ),
    );
  }
}

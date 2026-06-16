import 'package:flutter/material.dart';
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
  void initState() {
    super.initState();
    _loadStore();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _loadStore() async {
    setState(() => _dataLoading = true);
    try {
      final store = await _repo.fetchStore(widget.profile.storeId);
      if (mounted && store != null) {
        setState(() {
          _name.text = store['name'] as String? ?? '';
          _phone.text = store['phone'] as String? ?? '';
          _address.text = store['address'] as String? ?? '';
          _dataLoading = false;
        });
      } else if (mounted) {
        setState(() => _dataLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _dataLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(friendlyError(e, fallback: 'Could not load store info. Please try again.')),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await _repo.updateStore(
        storeId: widget.profile.storeId,
        name: _name.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        address: _address.text.trim().isEmpty ? null : _address.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(
            content: Text('Store settings saved.'),
            behavior: SnackBarBehavior.floating,
          ));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text(friendlyError(e, fallback: 'Could not save store settings. Please try again.')),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Store Settings')),
      body: _dataLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        const Icon(Icons.info_outline, size: 18, color: Colors.black45),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'This information appears on printed receipts.',
                            style: TextStyle(fontSize: 13, color: Colors.black54),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Store name *',
                      prefixIcon: Icon(Icons.storefront_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Store name is required';
                      if (v.trim().length < 2) return 'Name must be at least 2 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Phone (optional)',
                      prefixIcon: Icon(Icons.phone_outlined),
                      helperText: 'Shown on receipts',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _address,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Address (optional)',
                      prefixIcon: Icon(Icons.location_on_outlined),
                      alignLabelWithHint: true,
                      helperText: 'Shown on receipts',
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save),
                    label: const Text('Save Settings'),
                  ),
                ],
              ),
            ),
    );
  }
}

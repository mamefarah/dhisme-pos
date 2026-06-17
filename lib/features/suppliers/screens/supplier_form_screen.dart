import 'package:flutter/material.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/utils/errors.dart';
import '../data/supplier_repository.dart';
import '../models/supplier.dart';

class SupplierFormScreen extends StatefulWidget {
  const SupplierFormScreen({super.key, this.supplier});
  final Supplier? supplier;

  @override
  State<SupplierFormScreen> createState() => _SupplierFormScreenState();
}

class _SupplierFormScreenState extends State<SupplierFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = SupplierRepository();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _contact;
  late final TextEditingController _notes;
  late bool _isActive;
  bool _loading = false;
  bool get _isEditing => widget.supplier != null;

  @override
  void initState() {
    super.initState();
    final s = widget.supplier;
    _name = TextEditingController(text: s?.name ?? '');
    _phone = TextEditingController(text: s?.phone ?? '');
    _address = TextEditingController(text: s?.address ?? '');
    _contact = TextEditingController(text: s?.contactPerson ?? '');
    _notes = TextEditingController(text: s?.notes ?? '');
    _isActive = s?.isActive ?? true;
  }

  @override
  void dispose() { _name.dispose(); _phone.dispose(); _address.dispose(); _contact.dispose(); _notes.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      if (_isEditing) {
        await _repo.updateSupplier(id: widget.supplier!.id, name: _name.text, phone: _phone.text.isEmpty ? null : _phone.text, address: _address.text.isEmpty ? null : _address.text, contactPerson: _contact.text.isEmpty ? null : _contact.text, notes: _notes.text.isEmpty ? null : _notes.text, isActive: _isActive);
      } else {
        await _repo.addSupplier(name: _name.text, phone: _phone.text.isEmpty ? null : _phone.text, address: _address.text.isEmpty ? null : _address.text, contactPerson: _contact.text.isEmpty ? null : _contact.text, notes: _notes.text.isEmpty ? null : _notes.text);
      }
      if (mounted) {
        ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(SnackBar(content: Text(_isEditing ? context.tr('Alaab-qeybiye waa la cusboonaysiiyay.', 'Supplier updated.') : context.tr('Alaab-qeybiye waa lagu daray.', 'Supplier added.')), behavior: SnackBarBehavior.floating));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(SnackBar(content: Text(friendlyError(e, fallback: context.tr('Alaab-qeybiye lama kaydin karin. Fadlan mar kale isku day.', 'Could not save supplier. Please try again.'))), backgroundColor: Theme.of(context).colorScheme.error, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 5)));
      }
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLanguage.instance,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(_isEditing ? context.tr('Wax ka beddel Alaab-qeybiye', 'Edit Supplier') : context.tr('Alaab-qeybiye Cusub', 'New Supplier'))),
        body: Form(
          key: _formKey,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            TextFormField(controller: _name, textCapitalization: TextCapitalization.words, textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: context.tr('Magaca alaab-qeybiyaha *', 'Supplier name *'), prefixIcon: const Icon(Icons.business_outlined)), validator: (v) { if (v == null || v.trim().isEmpty) return context.tr('Magaca alaab-qeybiyaha waa loo baahan yahay', 'Supplier name is required'); if (v.trim().length < 2) return context.tr('Magacu ugu yaraan waa 2 xaraf', 'Name must be at least 2 characters'); return null; }),
            const SizedBox(height: 12),
            TextFormField(controller: _phone, keyboardType: TextInputType.phone, textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: context.tr('Telefoon (ikhtiyaari)', 'Phone (optional)'), prefixIcon: const Icon(Icons.phone_outlined))),
            const SizedBox(height: 12),
            TextFormField(controller: _contact, textCapitalization: TextCapitalization.words, textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: context.tr('Qofka lala xiriirayo (ikhtiyaari)', 'Contact person (optional)'), prefixIcon: const Icon(Icons.person_outlined))),
            const SizedBox(height: 12),
            TextFormField(controller: _address, textCapitalization: TextCapitalization.sentences, textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: context.tr('Cinwaan (ikhtiyaari)', 'Address (optional)'), prefixIcon: const Icon(Icons.location_on_outlined))),
            const SizedBox(height: 12),
            TextFormField(controller: _notes, textCapitalization: TextCapitalization.sentences, textInputAction: TextInputAction.done, maxLines: 3, decoration: InputDecoration(labelText: context.tr('Qoraal (ikhtiyaari)', 'Notes (optional)'), prefixIcon: const Icon(Icons.notes_outlined), alignLabelWithHint: true)),
            if (_isEditing) ...[
              const SizedBox(height: 16),
              SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(context.tr('Shaqaynaya', 'Active')), subtitle: Text(_isActive ? context.tr('Alaab-qeybiyahan iibsiyada waa loo isticmaali karaa.', 'Supplier is available for purchases.') : context.tr('Alaab-qeybiyahan form-yada iibsiga kama muuqanayo.', 'Supplier is hidden from purchase forms.')), value: _isActive, onChanged: (v) => setState(() => _isActive = v)),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(onPressed: _loading ? null : _save, icon: _loading ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save), label: Text(_isEditing ? context.tr('Kaydi Isbeddelka', 'Save Changes') : context.tr('Ku dar Alaab-qeybiye', 'Add Supplier'))),
          ]),
        ),
      ),
    );
  }
}

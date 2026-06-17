import 'package:flutter/material.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/utils/errors.dart';
import '../../auth/models/app_profile.dart';
import '../data/customer_repository.dart';
import '../models/customer.dart';

class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({super.key, required this.profile, this.customer});
  final AppProfile profile;
  final Customer? customer;

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = CustomerRepository();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _location = TextEditingController();
  final _notes = TextEditingController();
  final _creditLimit = TextEditingController();
  final _creditDays = TextEditingController();
  bool _isActive = true;
  bool _creditBlocked = false;
  bool _loading = false;
  bool get _isEdit => widget.customer != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final c = widget.customer!;
      _name.text = c.name;
      _phone.text = c.phone ?? '';
      _location.text = c.location ?? '';
      _notes.text = c.notes ?? '';
      _isActive = c.isActive;
      _creditLimit.text = c.creditLimit > 0 ? c.creditLimit.toStringAsFixed(0) : '';
      _creditDays.text = c.creditDays > 0 ? c.creditDays.toString() : '';
      _creditBlocked = c.creditBlocked;
    }
  }

  @override
  void dispose() { _name.dispose(); _phone.dispose(); _location.dispose(); _notes.dispose(); _creditLimit.dispose(); _creditDays.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      if (_isEdit) {
        await _repo.updateCustomer(id: widget.customer!.id, name: _name.text.trim(), phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(), location: _location.text.trim().isEmpty ? null : _location.text.trim(), notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(), isActive: _isActive, creditLimit: double.tryParse(_creditLimit.text.trim()) ?? 0, creditDays: int.tryParse(_creditDays.text.trim()) ?? 0, creditBlocked: _creditBlocked);
      } else {
        await _repo.addCustomer(storeId: widget.profile.storeId, name: _name.text.trim(), phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(), location: _location.text.trim().isEmpty ? null : _location.text.trim(), notes: _notes.text.trim().isEmpty ? null : _notes.text.trim());
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(SnackBar(content: Text(friendlyError(e, fallback: context.tr('Macmiilka lama kaydin karin. Hubi xogta oo mar kale isku day.', 'Could not save customer. Please check your information and try again.'))), backgroundColor: Theme.of(context).colorScheme.error, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 5)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLanguage.instance,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(_isEdit ? context.tr('Wax ka beddel Macmiil', 'Edit Customer') : context.tr('Ku dar Macmiil', 'Add Customer'))),
        body: Form(
          key: _formKey,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            TextFormField(controller: _name, textCapitalization: TextCapitalization.words, textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: context.tr('Magaca macmiilka *', 'Customer name *'), prefixIcon: const Icon(Icons.person_outline)), validator: (v) { if (v == null || v.trim().isEmpty) return context.tr('Magaca macmiilka waa loo baahan yahay', 'Customer name is required'); if (v.trim().length < 2) return context.tr('Magacu ugu yaraan waa 2 xaraf', 'Name must be at least 2 characters'); return null; }),
            const SizedBox(height: 12),
            TextFormField(controller: _phone, keyboardType: TextInputType.phone, textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: context.tr('Telefoon (ikhtiyaari)', 'Phone (optional)'), prefixIcon: const Icon(Icons.phone_outlined))),
            const SizedBox(height: 12),
            TextFormField(controller: _location, textCapitalization: TextCapitalization.sentences, textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: context.tr('Mashruuc / goob (ikhtiyaari)', 'Project / location (optional)'), prefixIcon: const Icon(Icons.location_on_outlined))),
            const SizedBox(height: 12),
            TextFormField(controller: _notes, textCapitalization: TextCapitalization.sentences, textInputAction: TextInputAction.done, maxLines: 2, decoration: InputDecoration(labelText: context.tr('Qoraal (ikhtiyaari)', 'Notes (optional)'), prefixIcon: const Icon(Icons.notes_outlined), alignLabelWithHint: true)),
            if (_isEdit && (widget.profile.isOwner || widget.profile.isManager)) ...[
              const SizedBox(height: 16),
              Text(context.tr('Dejinta Deynta', 'Credit Settings'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextFormField(controller: _creditLimit, keyboardType: const TextInputType.numberWithOptions(decimal: true), textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: context.tr('Xadka deynta (0 = ma jiro)', 'Credit limit (0 = none)'), prefixIcon: const Icon(Icons.account_balance_wallet_outlined), isDense: true), validator: (v) { if (v != null && v.trim().isNotEmpty) { final n = double.tryParse(v.trim()); if (n == null || n < 0) return context.tr('Geli lacag sax ah', 'Enter a valid amount'); } return null; })),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _creditDays, keyboardType: TextInputType.number, textInputAction: TextInputAction.done, decoration: InputDecoration(labelText: context.tr('Maalmaha ugu badan (0 = ma jiro)', 'Max days (0 = none)'), prefixIcon: const Icon(Icons.calendar_today_outlined), isDense: true), validator: (v) { if (v != null && v.trim().isNotEmpty) { final n = int.tryParse(v.trim()); if (n == null || n < 0) return context.tr('Geli tiro dhan', 'Enter a whole number'); } return null; })),
              ]),
              const SizedBox(height: 4),
              SwitchListTile(value: _creditBlocked, onChanged: (v) => setState(() => _creditBlocked = v), title: Text(context.tr('Xannib iibka deynta', 'Block credit sales')), subtitle: Text(_creditBlocked ? context.tr('Iib deyn cusub looma oggola macmiilkan.', 'No new credit sales allowed for this customer.') : context.tr('Iibka deynta waa la oggol yahay haddii xadka u oggolaado.', 'Credit sales are allowed (subject to limit).')), contentPadding: EdgeInsets.zero),
              const SizedBox(height: 4),
              SwitchListTile(value: _isActive, onChanged: (v) => setState(() => _isActive = v), title: Text(context.tr('Macmiil shaqaynaya', 'Active customer')), subtitle: Text(_isActive ? context.tr('Macmiilkan waa shaqaynayaa waxaana lagu dari karaa iibka.', 'This customer is active and can be assigned to sales.') : context.tr('Macaamiisha aan shaqayn lama tuso iib cusub.', 'Inactive customers are hidden from new sales.')), contentPadding: EdgeInsets.zero),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(onPressed: _loading ? null : _save, icon: _loading ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save), label: Text(_isEdit ? context.tr('Kaydi Isbeddelka', 'Save Changes') : context.tr('Ku dar Macmiil', 'Add Customer'))),
          ]),
        ),
      ),
    );
  }
}

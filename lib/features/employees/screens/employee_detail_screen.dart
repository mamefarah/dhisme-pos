import 'package:flutter/material.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/utils/errors.dart';
import '../data/employee_repository.dart';

class EmployeeDetailScreen extends StatefulWidget {
  const EmployeeDetailScreen({super.key, required this.employee, required this.currentUserId});
  final Map<String, dynamic> employee;
  final String currentUserId;

  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = EmployeeRepository();
  late final TextEditingController _fullName;
  late final TextEditingController _phone;
  late String _role;
  late bool _isActive;
  bool _loading = false;
  bool get _isEditingSelf => widget.employee['id'] == widget.currentUserId;
  bool get _isOwnerProfile => (widget.employee['role'] as String) == 'owner';

  @override
  void initState() { super.initState(); _fullName = TextEditingController(text: widget.employee['full_name'] as String); _phone = TextEditingController(text: widget.employee['phone'] as String? ?? ''); _role = widget.employee['role'] as String; _isActive = widget.employee['is_active'] as bool? ?? true; }
  @override
  void dispose() { _fullName.dispose(); _phone.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      await _repo.updateEmployee(id: widget.employee['id'] as String, fullName: _fullName.text.trim(), phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(), role: _role, isActive: _isActive);
      if (mounted) { ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(SnackBar(content: Text(context.tr('Shaqaale si guul leh ayaa loo cusboonaysiiyay.', 'Employee updated successfully.')), behavior: SnackBarBehavior.floating)); Navigator.of(context).pop(); }
    } catch (e) {
      if (mounted) { ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(SnackBar(content: Text(friendlyError(e, fallback: context.tr('Isbeddelka lama kaydin karin. Fadlan mar kale isku day.', 'Could not save changes. Please try again.'))), backgroundColor: Theme.of(context).colorScheme.error, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 5))); }
    } finally { if (mounted) setState(() => _loading = false); }
  }

  String _roleLabel(String role) { switch (role) { case 'seller': return context.tr('Iibiye', 'Seller'); case 'manager': return context.tr('Maamule', 'Manager'); case 'owner': return context.tr('Milkiile', 'Owner'); default: return role; } }

  @override
  Widget build(BuildContext context) {
    final name = widget.employee['full_name'] as String;
    return AnimatedBuilder(
      animation: AppLanguage.instance,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(name)),
        body: Form(key: _formKey, child: ListView(padding: const EdgeInsets.all(16), children: [
          if (_isEditingSelf) Card(color: Colors.amber.shade50, child: ListTile(leading: const Icon(Icons.info_outline, color: Colors.amber), title: Text(context.tr('Kani waa profile-kaaga.', 'This is your own profile.')), subtitle: Text(context.tr('Si aad magaca ama telefoonka u beddesho, isticmaal Settings.', 'To edit your name or phone, use Settings.')))),
          if (_isEditingSelf) const SizedBox(height: 12),
          TextFormField(controller: _fullName, enabled: !_isEditingSelf, textCapitalization: TextCapitalization.words, textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: context.tr('Magaca oo buuxa', 'Full name'), prefixIcon: const Icon(Icons.badge_outlined)), validator: (v) { if (v == null || v.trim().isEmpty) return context.tr('Magaca waa loo baahan yahay', 'Full name is required'); if (v.trim().length < 2) return context.tr('Magacu ugu yaraan waa 2 xaraf', 'Name must be at least 2 characters'); return null; }),
          const SizedBox(height: 12),
          TextFormField(controller: _phone, enabled: !_isEditingSelf, keyboardType: TextInputType.phone, textInputAction: TextInputAction.done, decoration: InputDecoration(labelText: context.tr('Telefoon (ikhtiyaari)', 'Phone (optional)'), prefixIcon: const Icon(Icons.phone_outlined))),
          const SizedBox(height: 16),
          if (_isOwnerProfile || _isEditingSelf)
            ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.admin_panel_settings_outlined), title: Text(context.tr('Doorka', 'Role')), subtitle: Text(_roleLabel(_role).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)), trailing: _isOwnerProfile ? Chip(label: Text(context.tr('Doorka milkiilaha wuu xiran yahay', 'Owner role is locked'))) : null)
          else
            DropdownButtonFormField<String>(value: _role, decoration: InputDecoration(labelText: context.tr('Doorka', 'Role'), prefixIcon: const Icon(Icons.admin_panel_settings_outlined)), items: [DropdownMenuItem(value: 'seller', child: Text(context.tr('Iibiye', 'Seller'))), DropdownMenuItem(value: 'manager', child: Text(context.tr('Maamule', 'Manager'))), DropdownMenuItem(value: 'owner', child: Text(context.tr('Milkiile', 'Owner')))], onChanged: (v) { if (v != null) setState(() => _role = v); }),
          const SizedBox(height: 16),
          if (!_isEditingSelf) SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(context.tr('Akoon shaqaynaya', 'Account active')), subtitle: Text(_isActive ? context.tr('Shaqaaluhu wuu soo geli karaa app-ka.', 'Employee can log in and use the app.') : context.tr('Shaqaaluhu ma soo geli karo. Xogtiisu way jiraysaa.', 'Employee cannot log in. Their data is preserved.')), value: _isActive, onChanged: (v) => setState(() => _isActive = v)),
          const SizedBox(height: 24),
          if (!_isEditingSelf) FilledButton.icon(onPressed: _loading ? null : _save, icon: _loading ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save), label: Text(context.tr('Kaydi Isbeddelka', 'Save Changes'))),
        ])),
      ),
    );
  }
}

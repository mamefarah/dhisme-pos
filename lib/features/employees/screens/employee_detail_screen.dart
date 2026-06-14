import 'package:flutter/material.dart';
import '../../../core/utils/errors.dart';
import '../data/employee_repository.dart';

class EmployeeDetailScreen extends StatefulWidget {
  const EmployeeDetailScreen({
    super.key,
    required this.employee,
    required this.currentUserId,
  });

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
  void initState() {
    super.initState();
    _fullName = TextEditingController(text: widget.employee['full_name'] as String);
    _phone = TextEditingController(text: widget.employee['phone'] as String? ?? '');
    _role = widget.employee['role'] as String;
    _isActive = widget.employee['is_active'] as bool? ?? true;
  }

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      await _repo.updateEmployee(
        id: widget.employee['id'] as String,
        fullName: _fullName.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        role: _role,
        isActive: _isActive,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(
            content: Text('Employee updated successfully.'),
            behavior: SnackBarBehavior.floating,
          ));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text(friendlyError(e,
                fallback: 'Could not save changes. Please try again.')),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.employee['full_name'] as String;

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_isEditingSelf)
              Card(
                color: Colors.amber.shade50,
                child: const ListTile(
                  leading: Icon(Icons.info_outline, color: Colors.amber),
                  title: Text('This is your own profile.'),
                  subtitle: Text('To edit your name or phone, use Settings.'),
                ),
              ),
            if (_isEditingSelf) const SizedBox(height: 12),

            TextFormField(
              controller: _fullName,
              enabled: !_isEditingSelf,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Full name is required';
                if (v.trim().length < 2) return 'Name must be at least 2 characters';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              enabled: !_isEditingSelf,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Phone (optional)',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 16),

            // Role — read-only for owner profiles and self
            if (_isOwnerProfile || _isEditingSelf)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: const Text('Role'),
                subtitle: Text(
                  _role.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: _isOwnerProfile
                    ? const Chip(label: Text('Owner role is locked'))
                    : null,
              )
            else
              DropdownButtonFormField<String>(
                value: _role,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'seller', child: Text('Seller')),
                  DropdownMenuItem(value: 'manager', child: Text('Manager')),
                  DropdownMenuItem(value: 'owner', child: Text('Owner')),
                ],
                onChanged: (v) { if (v != null) setState(() => _role = v); },
              ),

            const SizedBox(height: 16),

            // Active toggle — hidden for self (can't deactivate own account)
            if (!_isEditingSelf)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Account active'),
                subtitle: Text(
                  _isActive
                      ? 'Employee can log in and use the app.'
                      : 'Employee cannot log in. Their data is preserved.',
                ),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),

            const SizedBox(height: 24),

            if (!_isEditingSelf)
              FilledButton.icon(
                onPressed: _loading ? null : _save,
                icon: _loading
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save),
                label: const Text('Save Changes'),
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../auth/models/app_profile.dart';
import '../data/customer_repository.dart';

class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({super.key, required this.profile});
  final AppProfile profile;

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _repo = CustomerRepository();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _location = TextEditingController();
  bool _loading = false;

  @override
  void dispose() { _name.dispose(); _phone.dispose(); _location.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      await _repo.addCustomer(storeId: widget.profile.storeId, name: _name.text.trim(), phone: _phone.text.trim(), location: _location.text.trim());
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Add Customer')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      TextField(controller: _name, decoration: const InputDecoration(labelText: 'Customer name')),
      const SizedBox(height: 12),
      TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone')),
      const SizedBox(height: 12),
      TextField(controller: _location, decoration: const InputDecoration(labelText: 'Project/location')),
      const SizedBox(height: 20),
      FilledButton.icon(onPressed: _loading ? null : _save, icon: const Icon(Icons.save), label: const Text('Save')),
    ]),
  );
}

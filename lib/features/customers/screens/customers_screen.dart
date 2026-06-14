import 'package:flutter/material.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/models/app_profile.dart';
import '../data/customer_repository.dart';
import '../models/customer.dart';
import 'customer_form_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key, required this.profile});
  final AppProfile profile;

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _repo = CustomerRepository();
  late Future<List<Customer>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.listCustomers();
  }

  void _reload() => setState(() => _future = _repo.listCustomers());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customers & Debt'), actions: [
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () async {
            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CustomerFormScreen(profile: widget.profile)));
            _reload();
          },
        )
      ]),
      body: FutureBuilder<List<Customer>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final customers = snapshot.data!;
          if (customers.isEmpty) return const EmptyState(message: 'No customers yet. Add customers for credit sales.');
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: customers.length,
            itemBuilder: (context, index) {
              final c = customers[index];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                  title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${c.phone ?? '-'} • ${c.location ?? '-'}'),
                  trailing: Text(money(c.totalBalance), style: TextStyle(fontWeight: FontWeight.bold, color: c.totalBalance > 0 ? Colors.red : Colors.green)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

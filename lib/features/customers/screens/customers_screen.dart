import 'package:flutter/material.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/models/app_profile.dart';
import '../data/customer_repository.dart';
import '../models/customer.dart';
import 'customer_detail_screen.dart';
import 'customer_form_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key, required this.profile, this.initialDebtOnly = false});
  final AppProfile profile;
  final bool initialDebtOnly;

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _repo = CustomerRepository();
  final _search = TextEditingController();
  late Future<List<Customer>> _future;
  late bool _debtOnly;

  @override
  void initState() {
    super.initState();
    _debtOnly = widget.initialDebtOnly;
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = _repo.listCustomers(search: _search.text, debtOnly: _debtOnly);
    });
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = widget.profile.isOwner || widget.profile.isManager;
    return AnimatedBuilder(
      animation: AppLanguage.instance,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(context.tr('Macaamiisha & Deynta', 'Customers & Debt')),
          actions: [
            if (canEdit)
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: context.tr('Ku dar macmiil', 'Add customer'),
                onPressed: () async {
                  final added = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => CustomerFormScreen(profile: widget.profile)));
                  if (added == true) _reload();
                },
              ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  labelText: context.tr('Ku raadi magac ama telefoon', 'Search by name or phone'),
                  isDense: true,
                ),
                onChanged: (_) => _reload(),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _FilterChip(label: context.tr('Dhammaan', 'All'), selected: !_debtOnly, onTap: () => setState(() { _debtOnly = false; _reload(); })),
                  const SizedBox(width: 8),
                  _FilterChip(label: context.tr('Deyn leh', 'Has debt'), selected: _debtOnly, color: Colors.red, onTap: () => setState(() { _debtOnly = true; _reload(); })),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: FutureBuilder<List<Customer>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 12),
                          Text(friendlyError(snapshot.error!, fallback: 'Could not load customers.'), textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton.icon(onPressed: _reload, icon: const Icon(Icons.refresh), label: Text(context.tr('Mar kale isku day', 'Try Again'))),
                        ]),
                      ),
                    );
                  }
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final customers = snapshot.data!;
                  if (customers.isEmpty && _search.text.isEmpty && !_debtOnly) {
                    return EmptyState(message: canEdit ? context.tr('Weli macmiil ma jiro. Taabo + si aad macmiilka koowaad ugu darto.', 'No customers yet. Tap + to add your first customer.') : context.tr('Weli macmiil ma jiro.', 'No customers yet.'));
                  }
                  if (customers.isEmpty) return EmptyState(message: context.tr('Macmiil ku habboon raadinta lama helin.', 'No customers match your search.'));
                  return RefreshIndicator(
                    onRefresh: () async => _reload(),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: customers.length,
                      itemBuilder: (context, index) {
                        final c = customers[index];
                        return _CustomerTile(
                          customer: c,
                          onTap: () async {
                            final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => CustomerDetailScreen(customer: c, profile: widget.profile)));
                            if (changed == true) _reload();
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap, this.color});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? c : Colors.grey.shade300),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.bold : FontWeight.normal, color: selected ? c : Colors.black54)),
      ),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({required this.customer, required this.onTap});
  final Customer customer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = customer;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: c.hasDebt ? Colors.red.shade50 : Colors.green.shade50,
          child: Icon(Icons.person_outline, color: c.hasDebt ? Colors.red.shade700 : Colors.green.shade700),
        ),
        title: Row(children: [
          Expanded(child: Text(c.name, style: TextStyle(fontWeight: FontWeight.bold, color: c.isActive ? null : Colors.black45))),
          if (!c.isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
              child: Text(context.tr('Aan shaqayn', 'Inactive'), style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            ),
        ]),
        subtitle: Text(
          [if (c.phone != null) c.phone!, if (c.location != null) c.location!].join(' • ').let((s) => s.isNotEmpty ? s : context.tr('Xog xiriir ma jirto', 'No contact info')),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(money(c.totalBalance), style: TextStyle(fontWeight: FontWeight.bold, color: c.hasDebt ? Colors.red.shade700 : Colors.green.shade700)),
            const Icon(Icons.chevron_right, color: Colors.black26, size: 18),
          ],
        ),
      ),
    );
  }
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

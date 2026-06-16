import 'package:flutter/material.dart';
import '../../../core/utils/errors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/models/app_profile.dart';
import '../data/employee_repository.dart';
import 'create_invite_screen.dart';
import 'employee_detail_screen.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key, required this.profile});
  final AppProfile profile;

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  final _repo = EmployeeRepository();
  late Future<List<Map<String, dynamic>>> _future;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _future = _repo.listEmployees();
  }

  void _reload() => setState(() => _future = _repo.listEmployees());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employees'),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by name…',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 12),
                          Text(
                            friendlyError(snapshot.error!,
                                fallback: 'Could not load employees. Please try again.'),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _reload,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try Again'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final all = snapshot.data!;
                final employees = _search.isEmpty
                    ? all
                    : all
                        .where((e) =>
                            (e['full_name'] as String).toLowerCase().contains(_search))
                        .toList();

                if (all.isEmpty) {
                  return const EmptyState(
                    message: 'No employees yet. Tap + to create an invite code.',
                  );
                }
                if (employees.isEmpty) {
                  return const EmptyState(message: 'No employees match your search.');
                }

                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: employees.length,
                    itemBuilder: (context, i) => _EmployeeTile(
                      employee: employees[i],
                      currentUserId: widget.profile.id,
                      onTap: () async {
                        await Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => EmployeeDetailScreen(
                            employee: employees[i],
                            currentUserId: widget.profile.id,
                          ),
                        ));
                        _reload();
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreateInviteScreen()),
        ),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Invite'),
      ),
    );
  }
}

class _EmployeeTile extends StatelessWidget {
  const _EmployeeTile({
    required this.employee,
    required this.currentUserId,
    required this.onTap,
  });

  final Map<String, dynamic> employee;
  final String currentUserId;
  final VoidCallback onTap;

  Color _roleColor(BuildContext context, String role) {
    switch (role) {
      case 'owner':
        return Theme.of(context).colorScheme.primary;
      case 'manager':
        return Colors.indigo;
      default:
        return Colors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = employee['full_name'] as String;
    final role = employee['role'] as String;
    final phone = employee['phone'] as String?;
    final isActive = employee['is_active'] as bool? ?? true;
    final isCurrentUser = employee['id'] == currentUserId;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: _roleColor(context, role).withValues(alpha: 0.15),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(
              color: _roleColor(context, role),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '$name${isCurrentUser ? ' (you)' : ''}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isActive ? null : Colors.black38,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _roleColor(context, role).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                role.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _roleColor(context, role),
                ),
              ),
            ),
          ],
        ),
        subtitle: Row(
          children: [
            if (phone != null && phone.isNotEmpty) ...[
              const Icon(Icons.phone_outlined, size: 12, color: Colors.black45),
              const SizedBox(width: 4),
              Text(phone, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 12),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isActive ? 'Active' : 'Inactive',
                style: TextStyle(
                  fontSize: 11,
                  color: isActive ? Colors.green.shade700 : Colors.red.shade700,
                ),
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.black26),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../core/services/supabase_service.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/models/app_profile.dart';
import '../../employees/screens/employees_screen.dart';
import 'store_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.profile});
  final AppProfile profile;

  @override
  Widget build(BuildContext context) {
    final repo = AuthRepository();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile card
          Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Text(
                  profile.fullName.isNotEmpty ? profile.fullName[0].toUpperCase() : '?',
                ),
              ),
              title: Text(profile.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                '${_roleLabel(profile.role)} • ${profile.phone ?? 'No phone'}\n'
                'ID: ${sb.auth.currentUser?.id?.substring(0, 8) ?? ''}…',
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Owner/manager: Store settings
          if (profile.isOwner || profile.isManager) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.storefront_outlined),
                title: const Text('Store Settings'),
                subtitle: const Text('Name, phone, and address shown on receipts'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => StoreSettingsScreen(profile: profile),
                )),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Owner-only: Employee management
          if (profile.isOwner) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.group_outlined),
                title: const Text('Manage Employees'),
                subtitle: const Text('Add, edit, and deactivate team members'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => EmployeesScreen(profile: profile),
                )),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Logout
          FilledButton.icon(
            onPressed: () => _confirmLogout(context, repo),
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          ),

          const SizedBox(height: 24),
          Text(
            'Dhisme POS',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.black38),
          ),
        ],
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'owner':   return 'Owner';
      case 'manager': return 'Manager';
      default:        return 'Seller';
    }
  }

  Future<void> _confirmLogout(BuildContext context, AuthRepository repo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed == true) await repo.signOut();
  }
}

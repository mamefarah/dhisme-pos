import 'package:flutter/material.dart';
import '../../../core/services/supabase_service.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/models/app_profile.dart';

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
          Card(
            child: ListTile(
              leading: const Icon(Icons.person),
              title: Text(profile.fullName),
              subtitle: Text('${profile.role.toUpperCase()} • ${profile.phone ?? ''}\nUser ID: ${sb.auth.currentUser?.id ?? ''}'),
            ),
          ),
          const SizedBox(height: 12),
          if (profile.isOwner) const Card(
            child: ListTile(
              leading: Icon(Icons.group_add),
              title: Text('Employee management'),
              subtitle: Text('MVP note: create seller Auth users in Supabase Dashboard, then insert rows in profiles.'),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => repo.signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

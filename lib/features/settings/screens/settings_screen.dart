import 'package:flutter/material.dart';
import '../../../core/i18n/app_language.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/models/app_profile.dart';
import '../../employees/screens/employees_screen.dart';
import '../../expenses/screens/expenses_screen.dart';
import '../../products/screens/stock_reconciliation_screen.dart';
import '../../reports/screens/reports_screen.dart';
import 'store_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.profile});
  final AppProfile profile;

  @override
  Widget build(BuildContext context) {
    final repo = AuthRepository();
    final userId = repo.currentUserId ?? '';
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Dejinta', 'Settings'))),
      body: AnimatedBuilder(
        animation: AppLanguage.instance,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: CircleAvatar(child: Text(profile.fullName.isNotEmpty ? profile.fullName[0].toUpperCase() : '?')),
                title: Text(profile.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${_roleLabel(context, profile.role)} • ${profile.phone ?? context.tr('Telefoon ma jiro', 'No phone')}\nID: ${userId.substring(0, userId.length.clamp(0, 8))}…'),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: SwitchListTile(
                secondary: const Icon(Icons.language_outlined),
                title: Text(context.tr('Luuqadda app-ka', 'App language')),
                subtitle: Text(context.tr('Soomaali / English', 'English / Somali')),
                value: AppLanguage.instance.isSomali,
                onChanged: (v) => AppLanguage.instance.setLanguage(v ? 'so' : 'en'),
              ),
            ),
            const SizedBox(height: 12),
            if (profile.isOwner || profile.isManager) ...[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.storefront_outlined),
                  title: Text(context.tr('Dejinta Dukaanka', 'Store Settings')),
                  subtitle: Text(context.tr('Magaca, telefoonka iyo cinwaanka rasiidka', 'Name, phone, and address shown on receipts')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StoreSettingsScreen(profile: profile))),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.money_off_outlined),
                  title: Text(context.tr('Kharashaadka', 'Expenses')),
                  subtitle: Text(context.tr('Diiwaangeli kharashaadka dukaanka iyo warbixin maalmeed', 'Record store expenses and daily costs')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExpensesScreen())),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: Text(context.tr('Tirinta Kaydka', 'Stock Count')),
                  subtitle: Text(context.tr('Geli tirada dhabta ah si kaydka loo saxo', 'Enter physical counts to reconcile system stock')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StockReconciliationScreen(profile: profile))),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (profile.isOwner) ...[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.bar_chart_outlined),
                  title: Text(context.tr('Warbixinta Iibka', 'Sales Reports')),
                  subtitle: Text(context.tr('Dakhliga muddada iyo alaabta ugu iibka badan', 'Revenue by period and top-selling products')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReportsScreen(profile: profile))),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.group_outlined),
                  title: Text(context.tr('Maamul Shaqaalaha', 'Manage Employees')),
                  subtitle: Text(context.tr('Ku dar, wax ka beddel, ama dami shaqaalaha', 'Add, edit, and deactivate team members')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EmployeesScreen(profile: profile))),
                ),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: () => _confirmLogout(context, repo),
              icon: const Icon(Icons.logout),
              label: Text(context.tr('Ka bax', 'Logout')),
              style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 24),
            const Text('Dukaan Dhisme POS', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.black38)),
          ],
        ),
      ),
    );
  }

  String _roleLabel(BuildContext context, String role) {
    switch (role) {
      case 'owner': return context.tr('Milkiile', 'Owner');
      case 'manager': return context.tr('Maamule', 'Manager');
      default: return context.tr('Iibiye', 'Seller');
    }
  }

  Future<void> _confirmLogout(BuildContext context, AuthRepository repo) async {
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(context.tr('Ka bax', 'Logout')),
      content: Text(context.tr('Ma hubtaa inaad ka baxayso?', 'Are you sure you want to logout?')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('Jooji', 'Cancel'))),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.tr('Ka bax', 'Logout'))),
      ],
    ));
    if (confirmed == true) await repo.signOut();
  }
}

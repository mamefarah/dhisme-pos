import 'package:flutter/material.dart';
import '../../approvals/screens/approvals_screen.dart';
import '../../auth/models/app_profile.dart';
import '../../cash_closing/screens/owner_cash_closings_screen.dart';
import '../../customers/screens/customers_screen.dart';
import '../../products/screens/products_screen.dart';
import '../../sales/screens/sales_history_screen.dart';
import '../../settings/screens/settings_screen.dart';
import 'dashboard_screen.dart';

class OwnerHomeScreen extends StatefulWidget {
  const OwnerHomeScreen({super.key, required this.profile});
  final AppProfile profile;

  @override
  State<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends State<OwnerHomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(profile: widget.profile),
      SalesHistoryScreen(profile: widget.profile),
      ProductsScreen(profile: widget.profile),
      CustomersScreen(profile: widget.profile),
      ApprovalsScreen(profile: widget.profile),
      OwnerCashClosingsScreen(profile: widget.profile),
      SettingsScreen(profile: widget.profile),
    ];

    return Scaffold(
      body: screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_outlined),
            selectedIcon: Icon(Icons.receipt),
            label: 'Sales',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Products',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Clients',
          ),
          NavigationDestination(
            icon: Icon(Icons.approval_outlined),
            selectedIcon: Icon(Icons.approval),
            label: 'Approvals',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments),
            label: 'Closings',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

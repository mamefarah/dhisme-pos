import 'package:flutter/material.dart';
import '../../../core/i18n/app_language.dart';
import '../../auth/models/app_profile.dart';
import '../../customers/screens/customers_screen.dart';
import '../../products/screens/products_screen.dart';
import '../../sales/screens/pos_screen.dart';
import '../../sales/screens/sales_history_screen.dart';
import '../../settings/screens/settings_screen.dart';
import 'dashboard_screen.dart';

class ManagerHomeScreen extends StatefulWidget {
  const ManagerHomeScreen({super.key, required this.profile});
  final AppProfile profile;

  @override
  State<ManagerHomeScreen> createState() => _ManagerHomeScreenState();
}

class _ManagerHomeScreenState extends State<ManagerHomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(profile: widget.profile),
      PosScreen(profile: widget.profile),
      SalesHistoryScreen(profile: widget.profile),
      ProductsScreen(profile: widget.profile),
      CustomersScreen(profile: widget.profile),
      SettingsScreen(profile: widget.profile),
    ];

    return Scaffold(
      body: screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(icon: const Icon(Icons.dashboard_outlined), selectedIcon: const Icon(Icons.dashboard), label: context.tr('Hoy', 'Home')),
          const NavigationDestination(icon: Icon(Icons.point_of_sale_outlined), selectedIcon: Icon(Icons.point_of_sale), label: 'POS'),
          NavigationDestination(icon: const Icon(Icons.receipt_outlined), selectedIcon: const Icon(Icons.receipt), label: context.tr('Iib', 'Sales')),
          NavigationDestination(icon: const Icon(Icons.inventory_2_outlined), selectedIcon: const Icon(Icons.inventory_2), label: context.tr('Alaab', 'Products')),
          NavigationDestination(icon: const Icon(Icons.people_outline), selectedIcon: const Icon(Icons.people), label: context.tr('Macmiil', 'Clients')),
          NavigationDestination(icon: const Icon(Icons.settings_outlined), selectedIcon: const Icon(Icons.settings), label: context.tr('Dejin', 'Settings')),
        ],
      ),
    );
  }
}

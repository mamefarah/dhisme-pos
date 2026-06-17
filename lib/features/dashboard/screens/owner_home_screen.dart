import 'package:flutter/material.dart';
import '../../../core/i18n/app_language.dart';
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
        destinations: [
          NavigationDestination(icon: const Icon(Icons.dashboard_outlined), selectedIcon: const Icon(Icons.dashboard), label: context.tr('Hoy', 'Home')),
          NavigationDestination(icon: const Icon(Icons.receipt_outlined), selectedIcon: const Icon(Icons.receipt), label: context.tr('Iib', 'Sales')),
          NavigationDestination(icon: const Icon(Icons.inventory_2_outlined), selectedIcon: const Icon(Icons.inventory_2), label: context.tr('Alaab', 'Products')),
          NavigationDestination(icon: const Icon(Icons.people_outline), selectedIcon: const Icon(Icons.people), label: context.tr('Macmiil', 'Clients')),
          NavigationDestination(icon: const Icon(Icons.approval_outlined), selectedIcon: const Icon(Icons.approval), label: context.tr('Oggolaansho', 'Approvals')),
          NavigationDestination(icon: const Icon(Icons.payments_outlined), selectedIcon: const Icon(Icons.payments), label: context.tr('Xirid', 'Closings')),
          NavigationDestination(icon: const Icon(Icons.settings_outlined), selectedIcon: const Icon(Icons.settings), label: context.tr('Dejin', 'Settings')),
        ],
      ),
    );
  }
}

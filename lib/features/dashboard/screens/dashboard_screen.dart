import 'package:flutter/material.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/stat_card.dart';
import '../../approvals/screens/approvals_screen.dart';
import '../../auth/models/app_profile.dart';
import '../../customers/screens/customers_screen.dart';
import '../../products/screens/products_screen.dart';
import '../../sales/screens/sales_history_screen.dart';
import '../data/dashboard_repository.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.profile});
  final AppProfile profile;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _repo = DashboardRepository();
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.stats();
  }

  void _reload() => setState(() => _future = _repo.stats());

  void _goSales() => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SalesHistoryScreen(profile: widget.profile),
      ));

  void _goProducts({bool lowStock = false}) =>
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ProductsScreen(
          profile: widget.profile,
          initialFilter: lowStock ? StockFilter.lowStock : StockFilter.all,
        ),
      ));

  void _goCustomers({bool debtOnly = false}) =>
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CustomersScreen(
          profile: widget.profile,
          initialDebtOnly: debtOnly,
        ),
      ));

  @override
  Widget build(BuildContext context) {
    final isOwner = widget.profile.isOwner;

    return Scaffold(
      appBar: AppBar(
        title: Text(isOwner ? 'Owner Dashboard' : 'Dashboard'),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  const Text('Could not load dashboard.', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                  ),
                ]),
              ),
            );
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final s = snapshot.data!;
          final cross = MediaQuery.of(context).size.width > 700 ? 3 : 2;

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: GridView.count(
              crossAxisCount: cross,
              padding: const EdgeInsets.all(12),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: [
                StatCard(
                  title: 'Today Sales',
                  value: money(s['today_sales'] ?? 0),
                  icon: Icons.point_of_sale,
                  onTap: _goSales,
                ),
                StatCard(
                  title: 'Cash',
                  value: money(s['today_cash'] ?? 0),
                  icon: Icons.payments,
                  onTap: _goSales,
                ),
                StatCard(
                  title: 'Bank',
                  value: money(s['today_bank'] ?? 0),
                  icon: Icons.account_balance,
                  onTap: _goSales,
                ),
                StatCard(
                  title: 'Mobile Money',
                  value: money(s['today_mobile_money'] ?? 0),
                  icon: Icons.phone_android,
                  onTap: _goSales,
                ),
                StatCard(
                  title: 'Credit Sales',
                  value: money(s['today_credit'] ?? 0),
                  icon: Icons.credit_score,
                  onTap: _goSales,
                ),
                StatCard(
                  title: 'Pending Approvals',
                  value: '${s['pending_approvals'] ?? 0}',
                  icon: Icons.approval,
                  color: (s['pending_approvals'] ?? 0) > 0 ? Colors.orange : null,
                  onTap: isOwner
                      ? () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ApprovalsScreen(profile: widget.profile),
                          ))
                      : null,
                ),
                StatCard(
                  title: 'Low Stock Items',
                  value: '${s['low_stock_items'] ?? 0}',
                  icon: Icons.warning_amber,
                  color: (s['low_stock_items'] ?? 0) > 0 ? Colors.orange : null,
                  onTap: () => _goProducts(lowStock: true),
                ),
                StatCard(
                  title: 'Customer Debt',
                  value: money(s['customer_debt'] ?? 0),
                  icon: Icons.people,
                  color: (s['customer_debt'] ?? 0) > 0 ? Colors.red : null,
                  onTap: () => _goCustomers(debtOnly: true),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

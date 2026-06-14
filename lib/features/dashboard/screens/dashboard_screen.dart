import 'package:flutter/material.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/stat_card.dart';
import '../../auth/models/app_profile.dart';
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
  void initState() { super.initState(); _future = _repo.stats(); }
  void _reload() => setState(() => _future = _repo.stats());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.profile.isOwner ? 'Owner Dashboard' : 'Seller Dashboard'), actions: [IconButton(onPressed: _reload, icon: const Icon(Icons.refresh))]),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final s = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: GridView.count(
              crossAxisCount: MediaQuery.of(context).size.width > 700 ? 3 : 2,
              padding: const EdgeInsets.all(12),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: [
                StatCard(title: 'Today Sales', value: money(s['today_sales'] ?? 0), icon: Icons.point_of_sale),
                StatCard(title: 'Cash', value: money(s['today_cash'] ?? 0), icon: Icons.payments),
                StatCard(title: 'Bank', value: money(s['today_bank'] ?? 0), icon: Icons.account_balance),
                StatCard(title: 'Mobile Money', value: money(s['today_mobile_money'] ?? 0), icon: Icons.phone_android),
                StatCard(title: 'Credit Sales', value: money(s['today_credit'] ?? 0), icon: Icons.credit_score),
                StatCard(title: 'Pending Approvals', value: '${s['pending_approvals'] ?? 0}', icon: Icons.approval),
                StatCard(title: 'Low Stock Items', value: '${s['low_stock_items'] ?? 0}', icon: Icons.warning_amber),
                StatCard(title: 'Customer Debt', value: money(s['customer_debt'] ?? 0), icon: Icons.people),
              ],
            ),
          );
        },
      ),
    );
  }
}

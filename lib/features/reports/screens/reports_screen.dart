import 'package:flutter/material.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/money.dart';
import '../../auth/models/app_profile.dart';
import '../data/reports_repository.dart';

enum _Period { thisWeek, thisMonth, lastMonth, allTime }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.profile});
  final AppProfile profile;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _repo = ReportsRepository();
  _Period _period = _Period.thisMonth;
  late Future<(Map<String, dynamic>, List<Map<String, dynamic>>, Map<String, dynamic>)> _future;

  (DateTime?, DateTime?) get _dateRange {
    final now = DateTime.now();
    switch (_period) {
      case _Period.thisWeek:
        final start = DateTime(now.year, now.month, now.day - (now.weekday - 1));
        return (start, now.add(const Duration(days: 1)));
      case _Period.thisMonth:
        return (DateTime(now.year, now.month, 1), now.add(const Duration(days: 1)));
      case _Period.lastMonth:
        final firstOfThis = DateTime(now.year, now.month, 1);
        final firstOfLast = DateTime(now.year, now.month - 1, 1);
        return (firstOfLast, firstOfThis);
      case _Period.allTime:
        return (null, null);
    }
  }

  String get _periodLabel {
    switch (_period) {
      case _Period.thisWeek:    return 'This Week';
      case _Period.thisMonth:   return 'This Month';
      case _Period.lastMonth:   return 'Last Month';
      case _Period.allTime:     return 'All Time';
    }
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final (from, to) = _dateRange;
    setState(() {
      _future = Future.wait([
        _repo.salesSummary(from: from, to: to),
        _repo.topProducts(from: from, to: to),
        _repo.profitSummary(from: from, to: to),
      ]).then((r) => (
        r[0] as Map<String, dynamic>,
        r[1] as List<Map<String, dynamic>>,
        r[2] as Map<String, dynamic>,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Reports'),
        actions: [IconButton(onPressed: _reload, icon: const Icon(Icons.refresh))],
      ),
      body: Column(
        children: [
          // Period chips
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              children: [
                _Chip(
                  label: 'This Week',
                  selected: _period == _Period.thisWeek,
                  onTap: () { setState(() => _period = _Period.thisWeek); _reload(); },
                ),
                const SizedBox(width: 8),
                _Chip(
                  label: 'This Month',
                  selected: _period == _Period.thisMonth,
                  onTap: () { setState(() => _period = _Period.thisMonth); _reload(); },
                ),
                const SizedBox(width: 8),
                _Chip(
                  label: 'Last Month',
                  selected: _period == _Period.lastMonth,
                  onTap: () { setState(() => _period = _Period.lastMonth); _reload(); },
                ),
                const SizedBox(width: 8),
                _Chip(
                  label: 'All Time',
                  selected: _period == _Period.allTime,
                  onTap: () { setState(() => _period = _Period.allTime); _reload(); },
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<(Map<String, dynamic>, List<Map<String, dynamic>>, Map<String, dynamic>)>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(
                          friendlyError(snapshot.error!, fallback: 'Could not load reports. Please try again.'),
                          textAlign: TextAlign.center,
                        ),
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

                final (summary, products, profit) = snapshot.data!;
                final total = (summary['total'] as double?) ?? 0;
                final count = (summary['count'] as int?) ?? 0;

                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      // Revenue summary card
                      _SectionCard(
                        icon: Icons.bar_chart,
                        title: 'Revenue — $_periodLabel',
                        child: Column(
                          children: [
                            // Total + count
                            Row(children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      money(total),
                                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                    ),
                                    Text(
                                      '$count sale${count == 1 ? '' : 's'}',
                                      style: const TextStyle(color: Colors.black45, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ]),
                            if (total == 0)
                              const Padding(
                                padding: EdgeInsets.only(top: 12),
                                child: Text(
                                  'No completed sales in this period.',
                                  style: TextStyle(color: Colors.black45, fontSize: 13),
                                ),
                              )
                            else ...[
                              const SizedBox(height: 16),
                              _PaymentBar(
                                label: 'Cash',
                                amount: (summary['cash'] as double?) ?? 0,
                                total: total,
                                color: Colors.green.shade600,
                                icon: Icons.payments_outlined,
                              ),
                              _PaymentBar(
                                label: 'Bank',
                                amount: (summary['bank'] as double?) ?? 0,
                                total: total,
                                color: Colors.blue.shade600,
                                icon: Icons.account_balance_outlined,
                              ),
                              _PaymentBar(
                                label: 'Mobile Money',
                                amount: (summary['mobile_money'] as double?) ?? 0,
                                total: total,
                                color: Colors.purple.shade600,
                                icon: Icons.phone_android_outlined,
                              ),
                              _PaymentBar(
                                label: 'Credit',
                                amount: (summary['credit'] as double?) ?? 0,
                                total: total,
                                color: Colors.orange.shade600,
                                icon: Icons.credit_score_outlined,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Profit card (only shown when cost data is available)
                      if ((profit['has_cost_data'] as bool? ?? false)) ...[
                        _SectionCard(
                          icon: Icons.trending_up,
                          title: 'Gross Profit — $_periodLabel',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _ProfitRow(
                                label: 'Revenue',
                                amount: (profit['total_revenue'] as double?) ?? 0,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              _ProfitRow(
                                label: 'Cost of Goods',
                                amount: (profit['total_cost'] as double?) ?? 0,
                                color: Colors.orange.shade700,
                              ),
                              const Divider(height: 16),
                              _ProfitRow(
                                label: 'Gross Profit',
                                amount: (profit['gross_profit'] as double?) ?? 0,
                                color: Colors.green.shade700,
                                bold: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Top products card
                      _SectionCard(
                        icon: Icons.trending_up,
                        title: 'Top Products — $_periodLabel',
                        child: products.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  'No sales data for this period.',
                                  style: TextStyle(color: Colors.black45, fontSize: 13),
                                ),
                              )
                            : Column(
                                children: [
                                  for (int i = 0; i < products.length; i++)
                                    _ProductRow(
                                      rank: i + 1,
                                      data: products[i],
                                      topRevenue: (products[0]['total_revenue'] as double),
                                    ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.icon, required this.title, required this.child});
  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 18, color: Colors.black54),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

// ── Payment method bar ────────────────────────────────────────────────────────

class _PaymentBar extends StatelessWidget {
  const _PaymentBar({
    required this.label,
    required this.amount,
    required this.total,
    required this.color,
    required this.icon,
  });
  final String label;
  final double amount;
  final double total;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (amount == 0) return const SizedBox.shrink();
    final pct = total > 0 ? amount / total : 0.0;
    final pctLabel = '${(pct * 100).toStringAsFixed(0)}%';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
            Text(money(amount), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(width: 6),
            SizedBox(
              width: 36,
              child: Text(
                pctLabel,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 11, color: Colors.black45),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 5,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Product row ───────────────────────────────────────────────────────────────

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.rank, required this.data, required this.topRevenue});
  final int rank;
  final Map<String, dynamic> data;
  final double topRevenue;

  String _fmtQty(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final name    = data['product_name'] as String? ?? '—';
    final unit    = data['unit'] as String? ?? '';
    final qty     = (data['total_qty'] as double?) ?? 0;
    final revenue = (data['total_revenue'] as double?) ?? 0;
    final barPct  = topRevenue > 0 ? revenue / topRevenue : 0.0;
    final cs      = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rank badge
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: rank <= 3 ? cs.primary.withValues(alpha: 0.12) : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: rank <= 3 ? cs.primary : Colors.black45,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 2),
                Row(children: [
                  Text(
                    '${_fmtQty(qty)} $unit sold',
                    style: const TextStyle(fontSize: 11, color: Colors.black45),
                  ),
                  const Spacer(),
                  Text(
                    money(revenue),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ]),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: barPct,
                    minHeight: 3,
                    backgroundColor: cs.primary.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(cs.primary.withValues(alpha: 0.5)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Profit row ────────────────────────────────────────────────────────────────

class _ProfitRow extends StatelessWidget {
  const _ProfitRow({required this.label, required this.amount, required this.color, this.bold = false});
  final String label;
  final double amount;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: bold ? Colors.black87 : Colors.black54,
            ),
          ),
        ),
        Text(
          money(amount),
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            color: color,
          ),
        ),
      ]),
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.primary;
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
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? c : Colors.black54,
          ),
        ),
      ),
    );
  }
}

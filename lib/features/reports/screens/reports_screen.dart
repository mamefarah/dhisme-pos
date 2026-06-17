import 'package:flutter/material.dart';
import '../../../core/i18n/app_language.dart';
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

  @override
  void initState() { super.initState(); _reload(); }

  (DateTime?, DateTime?) get _range {
    final now = DateTime.now();
    switch (_period) {
      case _Period.thisWeek:
        final start = DateTime(now.year, now.month, now.day - (now.weekday - 1));
        return (start, now.add(const Duration(days: 1)));
      case _Period.thisMonth:
        return (DateTime(now.year, now.month, 1), now.add(const Duration(days: 1)));
      case _Period.lastMonth:
        return (DateTime(now.year, now.month - 1, 1), DateTime(now.year, now.month, 1));
      case _Period.allTime:
        return (null, null);
    }
  }

  void _reload() {
    final (from, to) = _range;
    setState(() {
      _future = Future.wait([_repo.salesSummary(from: from, to: to), _repo.topProducts(from: from, to: to), _repo.profitSummary(from: from, to: to)]).then((r) => (r[0] as Map<String, dynamic>, r[1] as List<Map<String, dynamic>>, r[2] as Map<String, dynamic>));
    });
  }

  String _periodName(BuildContext context) {
    switch (_period) {
      case _Period.thisWeek: return context.tr('Toddobaadkan', 'This Week');
      case _Period.thisMonth: return context.tr('Bishan', 'This Month');
      case _Period.lastMonth: return context.tr('Bishii hore', 'Last Month');
      case _Period.allTime: return context.tr('Dhammaan', 'All Time');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLanguage.instance,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(context.tr('Warbixinta Iibka', 'Sales Reports')), actions: [IconButton(onPressed: _reload, icon: const Icon(Icons.refresh), tooltip: context.tr('Cusboonaysii', 'Refresh'))]),
        body: Column(children: [
          SizedBox(height: 44, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), children: [
            _Chip(label: context.tr('Toddobaadkan', 'This Week'), selected: _period == _Period.thisWeek, onTap: () { setState(() => _period = _Period.thisWeek); _reload(); }),
            const SizedBox(width: 8),
            _Chip(label: context.tr('Bishan', 'This Month'), selected: _period == _Period.thisMonth, onTap: () { setState(() => _period = _Period.thisMonth); _reload(); }),
            const SizedBox(width: 8),
            _Chip(label: context.tr('Bishii hore', 'Last Month'), selected: _period == _Period.lastMonth, onTap: () { setState(() => _period = _Period.lastMonth); _reload(); }),
            const SizedBox(width: 8),
            _Chip(label: context.tr('Dhammaan', 'All Time'), selected: _period == _Period.allTime, onTap: () { setState(() => _period = _Period.allTime); _reload(); }),
          ])),
          Expanded(child: FutureBuilder<(Map<String, dynamic>, List<Map<String, dynamic>>, Map<String, dynamic>)>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.hasError) return _ErrorView(error: snapshot.error!, onRetry: _reload);
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final (summary, products, profit) = snapshot.data!;
              final total = ((summary['total'] as num?) ?? 0).toDouble();
              final count = (summary['count'] as int?) ?? 0;
              final titleSuffix = _periodName(context);
              return RefreshIndicator(onRefresh: () async => _reload(), child: ListView(padding: const EdgeInsets.all(12), children: [
                _SectionCard(icon: Icons.bar_chart, title: '${context.tr('Dakhliga', 'Revenue')} — $titleSuffix', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(money(total), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                  Text(context.tr('$count iib', '$count sale${count == 1 ? '' : 's'}'), style: const TextStyle(color: Colors.black45, fontSize: 13)),
                  const SizedBox(height: 12),
                  if (total == 0) Text(context.tr('Muddadan iib dhammaaday ma jiro.', 'No completed sales in this period.'), style: const TextStyle(color: Colors.black45, fontSize: 13)) else ...[
                    _PaymentRow(label: context.tr('Caddaan', 'Cash'), amount: ((summary['cash'] as num?) ?? 0).toDouble()),
                    _PaymentRow(label: context.tr('Bangiga', 'Bank'), amount: ((summary['bank'] as num?) ?? 0).toDouble()),
                    _PaymentRow(label: 'Mobile Money', amount: ((summary['mobile_money'] as num?) ?? 0).toDouble()),
                    _PaymentRow(label: context.tr('Deyn', 'Credit'), amount: ((summary['credit'] as num?) ?? 0).toDouble()),
                  ],
                ])),
                const SizedBox(height: 12),
                if ((profit['has_cost_data'] as bool? ?? false)) _SectionCard(icon: Icons.trending_up, title: '${context.tr('Faa’iidada Guud', 'Gross Profit')} — $titleSuffix', child: Column(children: [
                  _PaymentRow(label: context.tr('Dakhliga', 'Revenue'), amount: ((profit['total_revenue'] as num?) ?? 0).toDouble()),
                  _PaymentRow(label: context.tr('Qiimaha Alaabta', 'Cost of Goods'), amount: ((profit['total_cost'] as num?) ?? 0).toDouble()),
                  const Divider(height: 16),
                  _PaymentRow(label: context.tr('Faa’iidada Guud', 'Gross Profit'), amount: ((profit['gross_profit'] as num?) ?? 0).toDouble(), bold: true),
                ])),
                const SizedBox(height: 12),
                _SectionCard(icon: Icons.leaderboard_outlined, title: '${context.tr('Alaabta Ugu Iibka Badan', 'Top Products')} — $titleSuffix', child: products.isEmpty ? Text(context.tr('Muddadan xog iib ma jirto.', 'No sales data for this period.'), style: const TextStyle(color: Colors.black45, fontSize: 13)) : Column(children: [for (var i = 0; i < products.length; i++) _ProductRow(rank: i + 1, data: products[i])])),
              ]));
            },
          )),
        ]),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline, size: 48, color: Colors.red), const SizedBox(height: 12), Text(friendlyError(error, fallback: context.tr('Warbixinnada lama soo gelin karin. Fadlan mar kale isku day.', 'Could not load reports. Please try again.')), textAlign: TextAlign.center), const SizedBox(height: 12), FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: Text(context.tr('Mar kale isku day', 'Try Again')))])));
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.icon, required this.title, required this.child});
  final IconData icon;
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, size: 18, color: Colors.black54), const SizedBox(width: 8), Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)))]), const SizedBox(height: 12), child])));
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.label, required this.amount, this.bold = false});
  final String label;
  final double amount;
  final bool bold;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.normal))), Text(money(amount), style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.w600, color: bold ? Colors.green.shade700 : null))]));
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.rank, required this.data});
  final int rank;
  final Map<String, dynamic> data;
  String _fmt(double v) => v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
  @override
  Widget build(BuildContext context) {
    final name = data['product_name'] as String? ?? '—';
    final unit = data['unit'] as String? ?? '';
    final qty = ((data['total_qty'] as num?) ?? 0).toDouble();
    final revenue = ((data['total_revenue'] as num?) ?? 0).toDouble();
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [CircleAvatar(radius: 12, child: Text('$rank', style: const TextStyle(fontSize: 11))), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)), Text('${_fmt(qty)} $unit ${context.tr('la iibiyay', 'sold')}', style: const TextStyle(fontSize: 11, color: Colors.black45))])), Text(money(revenue), style: const TextStyle(fontWeight: FontWeight.w600))]));
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) { final c = Theme.of(context).colorScheme.primary; return GestureDetector(onTap: onTap, child: AnimatedContainer(duration: const Duration(milliseconds: 150), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(color: selected ? c.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20), border: Border.all(color: selected ? c : Colors.grey.shade300)), child: Text(label, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.bold : FontWeight.normal, color: selected ? c : Colors.black54)))); }
}

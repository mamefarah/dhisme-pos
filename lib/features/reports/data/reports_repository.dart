import '../../../core/services/supabase_service.dart';

class ReportsRepository {
  /// Aggregates completed sales in the given date range by payment type.
  Future<Map<String, dynamic>> salesSummary({DateTime? from, DateTime? to}) async {
    var query = sb
        .from('sales')
        .select('payment_method, sale_type, total_amount')
        .eq('status', 'completed');
    if (from != null) query = query.gte('created_at', from.toUtc().toIso8601String());
    if (to != null)   query = query.lte('created_at', to.toUtc().toIso8601String());

    final data = List<Map<String, dynamic>>.from(await query as List);

    double total = 0, cash = 0, bank = 0, mobile = 0, credit = 0;
    for (final s in data) {
      final amount = (s['total_amount'] as num?)?.toDouble() ?? 0;
      total += amount;
      final pay  = s['payment_method'] as String?;
      final type = s['sale_type'] as String?;
      if (type == 'credit') {
        credit += amount;
      } else if (pay == 'cash') {
        cash += amount;
      } else if (pay == 'bank') {
        bank += amount;
      } else if (pay == 'mobile_money') {
        mobile += amount;
      }
    }

    return {
      'total': total,
      'count': data.length,
      'cash': cash,
      'bank': bank,
      'mobile_money': mobile,
      'credit': credit,
    };
  }

  /// Returns the top [limit] products by revenue for the given period.
  /// Uses a two-step query: sale IDs first, then sale_items for those IDs.
  Future<List<Map<String, dynamic>>> topProducts({
    DateTime? from,
    DateTime? to,
    int limit = 10,
  }) async {
    var salesQuery = sb
        .from('sales')
        .select('id')
        .eq('status', 'completed');
    if (from != null) salesQuery = salesQuery.gte('created_at', from.toUtc().toIso8601String());
    if (to != null)   salesQuery = salesQuery.lte('created_at', to.toUtc().toIso8601String());

    final salesData = List<Map<String, dynamic>>.from(
      await salesQuery.limit(500) as List,
    );
    if (salesData.isEmpty) return [];

    final saleIds = salesData.map((s) => s['id'] as String).toList();

    final itemsData = List<Map<String, dynamic>>.from(
      await sb
          .from('sale_items')
          .select('product_name, unit, quantity, total_price')
          .inFilter('sale_id', saleIds) as List,
    );

    final Map<String, Map<String, dynamic>> agg = {};
    for (final item in itemsData) {
      final name    = (item['product_name'] as String?) ?? 'Unknown';
      final unit    = (item['unit'] as String?) ?? '';
      final qty     = (item['quantity'] as num?)?.toDouble() ?? 0;
      final revenue = (item['total_price'] as num?)?.toDouble() ?? 0;

      agg.putIfAbsent(name, () => {
        'product_name': name,
        'unit': unit,
        'total_qty': 0.0,
        'total_revenue': 0.0,
      });
      agg[name]!['total_qty']     = (agg[name]!['total_qty']     as double) + qty;
      agg[name]!['total_revenue'] = (agg[name]!['total_revenue'] as double) + revenue;
    }

    final result = agg.values.toList()
      ..sort((a, b) =>
          (b['total_revenue'] as double).compareTo(a['total_revenue'] as double));
    return result.take(limit).toList();
  }
}

import '../../../core/services/supabase_service.dart';

class CashClosingRepository {
  Future<String> submit({
    required String closingDate,
    required double actualCash,
    String? notes,
  }) async {
    final id = await sb.rpc('submit_daily_cash_closing', params: {
      'p_closing_date': closingDate,
      'p_actual_cash': actualCash,
      'p_notes': notes,
    });
    return id as String;
  }

  Future<List<Map<String, dynamic>>> listClosings({String? status}) async {
    var query = sb
        .from('daily_cash_closings')
        .select('*, profiles!seller_id(full_name)')
        .order('closing_date', ascending: false)
        .limit(100);
    if (status != null) query = query.eq('status', status);
    return List<Map<String, dynamic>>.from(await query as List);
  }

  Future<void> review(String id, String status) async {
    await sb.rpc('review_daily_cash_closing', params: {
      'p_closing_id': id,
      'p_status': status,
    });
  }

  /// Returns today's sales totals for the current user, grouped by payment type.
  /// Used to show the seller their expected figures before they count cash.
  Future<Map<String, double>> todayStats() async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day).toUtc().toIso8601String();
    final end = DateTime(today.year, today.month, today.day + 1).toUtc().toIso8601String();

    final data = List<Map<String, dynamic>>.from(
      await sb
          .from('sales')
          .select('sale_type, payment_method, total_amount, status')
          .gte('created_at', start)
          .lt('created_at', end) as List,
    );

    double cash = 0, bank = 0, mobileMoney = 0, credit = 0;
    for (final row in data) {
      final amount = (row['total_amount'] as num?)?.toDouble() ?? 0;
      final saleType = row['sale_type'] as String? ?? '';
      final payMethod = row['payment_method'] as String? ?? '';
      final rowStatus = row['status'] as String? ?? '';
      if (saleType == 'credit') {
        credit += amount;
      } else if (rowStatus == 'completed') {
        if (payMethod == 'cash') cash += amount;
        else if (payMethod == 'bank') bank += amount;
        else if (payMethod == 'mobile_money') mobileMoney += amount;
      }
    }

    return {'cash': cash, 'bank': bank, 'mobile_money': mobileMoney, 'credit': credit};
  }
}

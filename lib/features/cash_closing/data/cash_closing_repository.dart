import '../../../core/services/supabase_service.dart';
import '../../../core/utils/dates.dart';

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

  /// Returns this seller's closing row for today, or null if none exists yet.
  Future<Map<String, dynamic>?> todayClosing() async {
    final userId = sb.auth.currentUser?.id;
    if (userId == null) return null;
    return await sb
        .from('daily_cash_closings')
        .select()
        .eq('seller_id', userId)
        .eq('closing_date', todayIsoDate())
        .maybeSingle() as Map<String, dynamic>?;
  }

  /// Returns today's sales totals for the current user, grouped by payment type.
  /// Used to show the seller their expected figures before they count cash.
  Future<Map<String, double>> todayStats() async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day).toUtc().toIso8601String();
    final end = DateTime(today.year, today.month, today.day + 1).toUtc().toIso8601String();
    final userId = sb.auth.currentUser?.id;
    if (userId == null) return {'cash': 0, 'bank': 0, 'mobile_money': 0, 'credit': 0};

    // Query payments made by this seller today (cash/bank/mobile_money)
    final payments = List<Map<String, dynamic>>.from(
      await sb
          .from('payments')
          .select('payment_method, amount')
          .eq('seller_id', userId)
          .gte('created_at', start)
          .lt('created_at', end) as List,
    );

    // Query approved credit sales created by this seller today
    final creditSales = List<Map<String, dynamic>>.from(
      await sb
          .from('sales')
          .select('total_amount')
          .eq('seller_id', userId)
          .eq('sale_type', 'credit')
          .eq('status', 'completed')
          .gte('created_at', start)
          .lt('created_at', end) as List,
    );

    double cash = 0, bank = 0, mobileMoney = 0, credit = 0;
    for (final row in payments) {
      final amount = (row['amount'] as num?)?.toDouble() ?? 0;
      switch (row['payment_method'] as String?) {
        case 'cash': cash += amount; break;
        case 'bank': bank += amount; break;
        case 'mobile_money': mobileMoney += amount; break;
      }
    }
    for (final row in creditSales) {
      credit += (row['total_amount'] as num?)?.toDouble() ?? 0;
    }

    return {'cash': cash, 'bank': bank, 'mobile_money': mobileMoney, 'credit': credit};
  }
}

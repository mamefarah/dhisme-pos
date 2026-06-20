import '../../../core/services/supabase_service.dart';
import '../../../core/utils/dates.dart';

class CashClosingRepository {
  Future<String> submit({
    required String closingDate,
    required double actualCash,
    String? notes,
  }) async {
    final id = await sb.rpc('submit_daily_cash_closing_v2', params: {
      'p_closing_date': closingDate,
      'p_actual_cash': actualCash,
      'p_notes': notes,
    });
    return id as String;
  }

  Future<List<Map<String, dynamic>>> listClosings({String? status}) async {
    var query = sb
        .from('daily_cash_closings')
        .select('*, profiles!seller_id(full_name)');
    if (status != null) query = query.eq('status', status);
    return List<Map<String, dynamic>>.from(
      await query.order('closing_date', ascending: false).limit(100) as List,
    );
  }

  Future<void> review(String id, String status) async {
    await sb.rpc('review_daily_cash_closing', params: {
      'p_closing_id': id,
      'p_status': status,
    });
  }

  Future<Map<String, dynamic>?> todayClosing() async {
    final userId = sb.auth.currentUser?.id;
    if (userId == null) return null;
    return await sb
        .from('daily_cash_closings')
        .select()
        .eq('seller_id', userId)
        .eq('closing_date', todayIsoDate())
        .maybeSingle();
  }

  /// Net inflows/outflows by payment method, including sales, customer receipts,
  /// refunds, expenses, supplier payments, and cash adjustments.
  Future<Map<String, double>> todayStats() async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day).toUtc().toIso8601String();
    final end = DateTime(today.year, today.month, today.day + 1).toUtc().toIso8601String();
    final userId = sb.auth.currentUser?.id;
    if (userId == null) return {'cash': 0, 'bank': 0, 'mobile_money': 0, 'credit': 0};

    final ledger = List<Map<String, dynamic>>.from(
      await sb
          .from('cash_ledger')
          .select('direction, payment_method, amount')
          .eq('user_id', userId)
          .gte('occurred_at', start)
          .lt('occurred_at', end) as List,
    );

    final creditSales = List<Map<String, dynamic>>.from(
      await sb
          .from('sales')
          .select('total_amount, refunded_amount')
          .eq('seller_id', userId)
          .eq('sale_type', 'credit')
          .eq('status', 'completed')
          .gte('created_at', start)
          .lt('created_at', end) as List,
    );

    double cash = 0, bank = 0, mobileMoney = 0, credit = 0;
    for (final row in ledger) {
      final amount = (row['amount'] as num?)?.toDouble() ?? 0;
      final signed = row['direction'] == 'outflow' ? -amount : amount;
      switch (row['payment_method'] as String?) {
        case 'cash':
          cash += signed;
          break;
        case 'bank':
          bank += signed;
          break;
        case 'mobile_money':
          mobileMoney += signed;
          break;
      }
    }
    for (final row in creditSales) {
      final total = (row['total_amount'] as num?)?.toDouble() ?? 0;
      final refunded = (row['refunded_amount'] as num?)?.toDouble() ?? 0;
      credit += total - refunded;
    }

    return {
      'cash': cash,
      'bank': bank,
      'mobile_money': mobileMoney,
      'credit': credit,
    };
  }
}

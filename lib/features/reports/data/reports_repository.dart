import '../../../core/services/supabase_service.dart';

class ReportsRepository {
  Future<Map<String, dynamic>> salesSummary({DateTime? from, DateTime? to}) async {
    final result = await sb.rpc('sales_summary_v2', params: {
      'p_from': from?.toUtc().toIso8601String(),
      'p_to': to?.toUtc().toIso8601String(),
    });
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> profitSummary({DateTime? from, DateTime? to}) async {
    final result = await sb.rpc('profit_summary_v2', params: {
      'p_from': from?.toUtc().toIso8601String(),
      'p_to': to?.toUtc().toIso8601String(),
    });
    return Map<String, dynamic>.from(result as Map);
  }

  Future<List<Map<String, dynamic>>> topProducts({
    DateTime? from,
    DateTime? to,
    int limit = 10,
  }) async {
    final result = await sb.rpc('top_products_v2', params: {
      'p_from': from?.toUtc().toIso8601String(),
      'p_to': to?.toUtc().toIso8601String(),
      'p_limit': limit,
    });
    return List<Map<String, dynamic>>.from(result as List);
  }

  Future<Map<String, dynamic>> financialSummary({DateTime? from, DateTime? to}) async {
    final resolvedFrom = (from ?? DateTime(2000)).toUtc();
    final resolvedTo = (to ?? DateTime.now().add(const Duration(days: 1))).toUtc();
    final result = await sb.rpc('financial_summary_v2', params: {
      'p_from': resolvedFrom.toIso8601String(),
      'p_to': resolvedTo.toIso8601String(),
    });
    return Map<String, dynamic>.from(result as Map);
  }
}

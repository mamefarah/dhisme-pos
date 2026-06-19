import '../../../core/services/supabase_service.dart';
import '../../../core/utils/idempotency.dart';

class CashAdjustmentRepository {
  Future<List<Map<String, dynamic>>> listAdjustments({int limit = 100}) async {
    final rows = await sb
        .from('cash_adjustments')
        .select('*, profiles!created_by(full_name)')
        .order('adjustment_date', ascending: false)
        .order('created_at', ascending: false)
        .limit(limit) as List<dynamic>;
    return rows.cast<Map<String, dynamic>>();
  }

  Future<String> record({
    required String adjustmentType,
    required double amount,
    required DateTime adjustmentDate,
    String? referenceNo,
    String? notes,
    String? idempotencyKey,
  }) async {
    final result = await sb.rpc('record_cash_adjustment_v2', params: {
      'p_adjustment_type': adjustmentType,
      'p_amount': amount,
      'p_adjustment_date': _date(adjustmentDate),
      'p_reference_no': referenceNo,
      'p_notes': notes,
      'p_idempotency_key': idempotencyKey ?? newOperationKey('cash-adjustment'),
    });
    return result as String;
  }

  String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

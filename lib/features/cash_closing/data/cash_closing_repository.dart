import '../../../core/services/supabase_service.dart';

class CashClosingRepository {
  Future<String> submit({required String closingDate, required double actualCash, String? notes}) async {
    final id = await sb.rpc('submit_daily_cash_closing', params: {'p_closing_date': closingDate, 'p_actual_cash': actualCash, 'p_notes': notes});
    return id as String;
  }

  Future<List<Map<String, dynamic>>> listClosings() async {
    final data = await sb.from('daily_cash_closings').select('*, profiles!seller_id(full_name)').order('created_at', ascending: false).limit(100);
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<void> review(String id, String status) async {
    await sb.rpc('review_daily_cash_closing', params: {'p_closing_id': id, 'p_status': status});
  }
}

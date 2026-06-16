import '../../../core/services/supabase_service.dart';

class ApprovalRepository {
  Future<List<Map<String, dynamic>>> allApprovals({String? status}) async {
    var query = sb
        .from('approval_requests')
        .select(
          '*, '
          'profiles!approval_requests_requested_by_fkey(full_name), '
          'sales(invoice_no, total_amount, discount, '
          '  customers!customer_id(name), '
          '  sale_items(product_name, unit, quantity, unit_price, total_price)'
          ')',
        )
        .order('created_at', ascending: false)
        .limit(200);
    if (status != null) query = query.eq('status', status);
    return List<Map<String, dynamic>>.from(await query as List);
  }

  Future<void> decide(String requestId, String decision, {String? comment}) async {
    await sb.rpc('decide_approval_request', params: {
      'p_request_id': requestId,
      'p_decision': decision,
      'p_owner_comment': comment,
    });
  }
}

import '../../../core/services/supabase_service.dart';

class ApprovalRepository {
  Future<List<Map<String, dynamic>>> pendingApprovals() async {
    final data = await sb
      .from('approval_requests')
      .select('*, profiles!approval_requests_requested_by_fkey(full_name), sales(invoice_no, total_amount), customers: sales(customer_id, customers(name))')
      .eq('status', 'pending')
      .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<List<Map<String, dynamic>>> allApprovals() async {
    final data = await sb.from('approval_requests').select('*, profiles!approval_requests_requested_by_fkey(full_name)').order('created_at', ascending: false).limit(100);
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<void> decide(String requestId, String decision, {String? comment}) async {
    await sb.rpc('decide_approval_request', params: {'p_request_id': requestId, 'p_decision': decision, 'p_owner_comment': comment});
  }
}

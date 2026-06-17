import '../../../core/services/supabase_service.dart';

class ApprovalRepository {
  Future<List<Map<String, dynamic>>> allApprovals({String? status}) async {
    // Load approval rows first. Do not embed sales here because
    // approval_requests.reference_id is a generic UUID reference, not always a
    // declared foreign key to sales. Direct embedding can fail in PostgREST and
    // causes the owner Approvals screen to show "Could not load approvals.".
    var query = sb
        .from('approval_requests')
        .select('*, profiles!approval_requests_requested_by_fkey(full_name)');

    if (status != null) query = query.eq('status', status);

    final approvals = List<Map<String, dynamic>>.from(
      await query.order('created_at', ascending: false).limit(200) as List,
    );

    for (final approval in approvals) {
      final refId = approval['reference_id'] as String?;
      if (refId == null || refId.isEmpty) continue;

      try {
        final sale = await sb
            .from('sales')
            .select(
              'invoice_no, total_amount, discount, '
              'customers!customer_id(name), '
              'sale_items(product_name, unit, quantity, unit_price, total_price)',
            )
            .eq('id', refId)
            .maybeSingle();

        if (sale != null) {
          approval['sales'] = Map<String, dynamic>.from(sale as Map);
        }
      } catch (_) {
        // Keep the approval visible even if related sale details cannot be
        // loaded because of old data, missing FK metadata, or RLS restrictions.
        approval['sales'] = <String, dynamic>{};
      }
    }

    return approvals;
  }

  Future<void> decide(String requestId, String decision, {String? comment}) async {
    await sb.rpc('decide_approval_request', params: {
      'p_request_id': requestId,
      'p_decision': decision,
      'p_owner_comment': comment,
    });
  }
}

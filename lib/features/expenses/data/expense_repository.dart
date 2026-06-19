import '../../../core/services/supabase_service.dart';
import '../../../core/utils/idempotency.dart';

class ExpenseRepository {
  Future<List<Map<String, dynamic>>> listExpenses({DateTime? from, DateTime? to}) async {
    var query = sb.from('expenses').select('*, profiles!created_by(full_name)');
    if (from != null) query = query.gte('expense_date', _date(from));
    if (to != null) query = query.lte('expense_date', _date(to));
    final data = await query
        .order('expense_date', ascending: false)
        .order('created_at', ascending: false)
        .limit(300) as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  Future<String> recordExpense({
    required String category,
    required double amount,
    required String paymentMethod,
    required DateTime expenseDate,
    String? referenceNo,
    String? notes,
    String? idempotencyKey,
  }) async {
    final id = await sb.rpc('record_expense_v2', params: {
      'p_category': category,
      'p_amount': amount,
      'p_payment_method': paymentMethod,
      'p_expense_date': _date(expenseDate),
      'p_reference_no': referenceNo,
      'p_notes': notes,
      'p_idempotency_key': idempotencyKey ?? newOperationKey('expense'),
    });
    return id as String;
  }

  String _date(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

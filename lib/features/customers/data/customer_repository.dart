import '../../../core/services/supabase_service.dart';
import '../models/customer.dart';

class CustomerRepository {
  Future<List<Customer>> listCustomers({String search = '', bool debtOnly = false}) async {
    final data = await sb
        .from('customers')
        .select()
        .order('name') as List<dynamic>;

    var customers = data.map((e) => Customer.fromMap(e as Map<String, dynamic>)).toList();

    if (debtOnly) customers = customers.where((c) => c.hasDebt).toList();

    if (search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      customers = customers
          .where((c) =>
              c.name.toLowerCase().contains(q) ||
              (c.phone ?? '').toLowerCase().contains(q))
          .toList();
    }
    return customers;
  }

  Future<void> addCustomer({
    required String storeId,
    required String name,
    String? phone,
    String? location,
    String? notes,
  }) async {
    await sb.from('customers').insert({
      'store_id': storeId,
      'name': name.trim(),
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      if (location != null && location.trim().isNotEmpty) 'location': location.trim(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    });
  }

  Future<void> updateCustomer({
    required String id,
    required String name,
    String? phone,
    String? location,
    String? notes,
    required bool isActive,
    double creditLimit = 0,
    int creditDays = 0,
    bool creditBlocked = false,
  }) async {
    await sb.from('customers').update({
      'name': name.trim(),
      'phone': phone != null && phone.trim().isNotEmpty ? phone.trim() : null,
      'location': location != null && location.trim().isNotEmpty ? location.trim() : null,
      'notes': notes != null && notes.trim().isNotEmpty ? notes.trim() : null,
      'is_active': isActive,
      'credit_limit': creditLimit,
      'credit_days': creditDays,
      'credit_blocked': creditBlocked,
    }).eq('id', id);
  }

  Future<List<Map<String, dynamic>>> listCreditSales(String customerId) async {
    final data = await sb
        .from('sales')
        .select('id, invoice_no, total_amount, paid_amount, balance_amount, payment_status, created_at')
        .eq('customer_id', customerId)
        .eq('sale_type', 'credit')
        .order('created_at', ascending: false)
        .limit(30) as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> listPayments(String customerId) async {
    final data = await sb
        .from('customer_payments')
        .select('*, profiles!received_by(full_name)')
        .eq('customer_id', customerId)
        .order('created_at', ascending: false)
        .limit(30) as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  Future<String> recordPayment({
    required String customerId,
    required double amount,
    required String paymentMethod,
    String? referenceNo,
    String? notes,
  }) async {
    final result = await sb.rpc('record_customer_payment', params: {
      'p_customer_id': customerId,
      'p_amount': amount,
      'p_payment_method': paymentMethod,
      'p_reference_no': referenceNo,
      'p_notes': notes,
    });
    return result as String;
  }
}

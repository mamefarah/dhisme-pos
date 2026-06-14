import '../../../core/services/supabase_service.dart';

class SalesRepository {
  Future<String> createCashSale({
    required List<Map<String, dynamic>> items,
    String? customerId,
    required String paymentMethod,
    String? referenceNo,
    double discount = 0,
    String? notes,
  }) async {
    final saleId = await sb.rpc('create_cash_sale', params: {
      'p_customer_id': customerId,
      'p_items': items,
      'p_payment_method': paymentMethod,
      'p_reference_no': referenceNo,
      'p_discount': discount,
      'p_notes': notes,
    });
    return saleId as String;
  }

  Future<String> requestCreditSale({
    required List<Map<String, dynamic>> items,
    required String customerId,
    required String reason,
    double discount = 0,
    String? notes,
  }) async {
    final requestId = await sb.rpc('request_credit_sale', params: {
      'p_customer_id': customerId,
      'p_items': items,
      'p_reason': reason,
      'p_discount': discount,
      'p_notes': notes,
    });
    return requestId as String;
  }

  Future<List<Map<String, dynamic>>> recentSales() async {
    final data = await sb.from('sales').select('*, profiles(full_name), customers(name)').order('created_at', ascending: false).limit(25);
    return List<Map<String, dynamic>>.from(data as List);
  }
}

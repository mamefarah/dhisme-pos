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

  /// Returns up to [limit] recent sales for this store, newest first.
  Future<List<Map<String, dynamic>>> salesHistory({int limit = 50}) async {
    final data = await sb
        .from('sales')
        .select(
          'id, invoice_no, total_amount, subtotal, discount, '
          'sale_type, payment_status, status, created_at, '
          'profiles!seller_id(full_name), customers!customer_id(name)',
        )
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(data as List);
  }

  /// Fetches a single sale with its line items for the receipt.
  /// Returns null if the sale is not found (caller handles null).
  Future<Map<String, dynamic>?> fetchSaleDetails(String saleId) async {
    try {
      final data = await sb
          .from('sales')
          .select(
            '*, profiles!seller_id(full_name), customers!customer_id(name), '
            'sale_items(id, product_name, unit, quantity, unit_price, total_price)',
          )
          .eq('id', saleId)
          .maybeSingle();
      return data;
    } catch (_) {
      try {
        final data = await sb
            .from('sales')
            .select('*, profiles!seller_id(full_name), customers!customer_id(name)')
            .eq('id', saleId)
            .maybeSingle();
        return data;
      } catch (_) {
        return null;
      }
    }
  }

  /// Fetches store info for the receipt header. Returns null if unavailable.
  Future<Map<String, dynamic>?> fetchStore(String storeId) async {
    try {
      return await sb.from('stores').select().eq('id', storeId).maybeSingle();
    } catch (_) {
      return null;
    }
  }
}

import '../../../core/services/supabase_service.dart';
import '../../../core/utils/idempotency.dart';

class SalesRepository {
  Future<String> createCashSale({
    required List<Map<String, dynamic>> items,
    required List<Map<String, dynamic>> payments,
    String? customerId,
    double discount = 0,
    String? notes,
    String? idempotencyKey,
  }) async {
    final saleId = await sb.rpc('create_cash_sale_v2', params: {
      'p_customer_id': customerId,
      'p_items': items,
      'p_payments': payments,
      'p_discount': discount,
      'p_notes': notes,
      'p_idempotency_key': idempotencyKey ?? newOperationKey('sale'),
    });
    return saleId as String;
  }

  Future<String> requestCreditSale({
    required List<Map<String, dynamic>> items,
    required String customerId,
    required String reason,
    double discount = 0,
    String? notes,
    String? idempotencyKey,
  }) async {
    final requestId = await sb.rpc('request_credit_sale_v2', params: {
      'p_customer_id': customerId,
      'p_items': items,
      'p_reason': reason,
      'p_discount': discount,
      'p_notes': notes,
      'p_idempotency_key': idempotencyKey ?? newOperationKey('credit-request'),
    });
    return requestId as String;
  }

  Future<String> recordReturn({
    required String saleId,
    required List<Map<String, dynamic>> items,
    required String refundMethod,
    required String reason,
    String? idempotencyKey,
  }) async {
    final returnId = await sb.rpc('record_return_v2', params: {
      'p_sale_id': saleId,
      'p_items': items,
      'p_refund_method': refundMethod,
      'p_reason': reason,
      'p_idempotency_key': idempotencyKey ?? newOperationKey('return'),
    });
    return returnId as String;
  }

  /// Returns the amount already refunded for each sale-item line.
  ///
  /// Return items are created only inside the completed-return transaction, so
  /// summing them is the exact source of truth used by `record_return_v2`.
  Future<Map<String, double>> returnedRefundTotals(
    List<String> saleItemIds,
  ) async {
    if (saleItemIds.isEmpty) return const {};

    final rows = List<Map<String, dynamic>>.from(
      await sb
          .from('return_items')
          .select('sale_item_id, total_price')
          .inFilter('sale_item_id', saleItemIds) as List,
    );

    final totals = <String, double>{};
    for (final row in rows) {
      final saleItemId = row['sale_item_id'] as String?;
      if (saleItemId == null) continue;
      totals.update(
        saleItemId,
        (value) => value + ((row['total_price'] as num?)?.toDouble() ?? 0),
        ifAbsent: () => ((row['total_price'] as num?)?.toDouble() ?? 0),
      );
    }
    return totals;
  }

  Future<List<Map<String, dynamic>>> salesHistory({
    int limit = 200,
    DateTime? from,
    DateTime? to,
  }) async {
    var query = sb
        .from('sales')
        .select(
          'id, invoice_no, total_amount, refunded_amount, subtotal, discount, '
          'sale_type, payment_method, payment_status, status, created_at, '
          'profiles!seller_id(full_name), customers!customer_id(name)',
        );

    if (from != null) query = query.gte('created_at', from.toUtc().toIso8601String());
    if (to != null) query = query.lte('created_at', to.toUtc().toIso8601String());

    return List<Map<String, dynamic>>.from(
      await query.order('created_at', ascending: false).limit(limit) as List,
    );
  }

  Future<Map<String, dynamic>?> fetchSaleDetails(String saleId) async {
    try {
      final data = await sb
          .from('sales')
          .select(
            '*, profiles!seller_id(full_name), customers!customer_id(name), '
            'sale_items(id, product_id, product_name, unit, quantity, returned_quantity, unit_price, total_price)',
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

  Future<Map<String, dynamic>?> fetchStore(String storeId) async {
    try {
      return await sb.from('stores').select().eq('id', storeId).maybeSingle();
    } catch (_) {
      return null;
    }
  }
}

import '../../../core/services/supabase_service.dart';
import '../models/purchase.dart';

class PurchaseRepository {
  Future<List<Purchase>> listPurchases() async {
    final data = await sb
        .from('purchases')
        .select('*, suppliers(name), profiles!recorded_by(full_name)')
        .order('purchase_date', ascending: false)
        .order('created_at', ascending: false) as List<dynamic>;
    return data.map((e) => Purchase.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<List<PurchaseItem>> getPurchaseItems(String purchaseId) async {
    final data = await sb
        .from('purchase_items')
        .select()
        .eq('purchase_id', purchaseId)
        .order('product_name') as List<dynamic>;
    return data.map((e) => PurchaseItem.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<String> recordPurchase({
    required List<Map<String, dynamic>> items,
    String? supplierId,
    String? invoiceRef,
    required DateTime purchaseDate,
    required String paymentStatus,
    String? notes,
  }) async {
    final result = await sb.rpc('record_purchase', params: {
      'p_items': items,
      'p_supplier_id': supplierId,
      'p_invoice_ref': invoiceRef,
      'p_purchase_date': purchaseDate.toIso8601String().substring(0, 10),
      'p_payment_status': paymentStatus,
      'p_notes': notes,
    });
    return result as String;
  }
}

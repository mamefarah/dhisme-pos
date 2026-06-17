import '../../../core/services/supabase_service.dart';
import '../models/supplier.dart';

class SupplierRepository {
  Future<List<Supplier>> listSuppliers({String search = '', bool activeOnly = false}) async {
    var query = sb.from('suppliers').select();
    if (activeOnly) query = query.eq('is_active', true);
    final data = await query.order('name') as List<dynamic>;
    final suppliers = data.map((e) => Supplier.fromMap(e as Map<String, dynamic>)).toList();

    if (search.isEmpty) return suppliers;
    final q = search.toLowerCase();
    return suppliers
        .where((s) =>
            s.name.toLowerCase().contains(q) ||
            (s.phone ?? '').toLowerCase().contains(q) ||
            (s.contactPerson ?? '').toLowerCase().contains(q))
        .toList();
  }

  Future<void> addSupplier({
    required String name,
    String? phone,
    String? address,
    String? contactPerson,
    String? notes,
  }) async {
    await sb.from('suppliers').insert({
      'name': name.trim(),
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      if (address != null && address.trim().isNotEmpty) 'address': address.trim(),
      if (contactPerson != null && contactPerson.trim().isNotEmpty)
        'contact_person': contactPerson.trim(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    });
  }

  Future<void> updateSupplier({
    required String id,
    required String name,
    String? phone,
    String? address,
    String? contactPerson,
    String? notes,
    required bool isActive,
  }) async {
    await sb.from('suppliers').update({
      'name': name.trim(),
      'phone': phone != null && phone.trim().isNotEmpty ? phone.trim() : null,
      'address': address != null && address.trim().isNotEmpty ? address.trim() : null,
      'contact_person': contactPerson != null && contactPerson.trim().isNotEmpty ? contactPerson.trim() : null,
      'notes': notes != null && notes.trim().isNotEmpty ? notes.trim() : null,
      'is_active': isActive,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<List<Map<String, dynamic>>> listPurchases(String supplierId) async {
    final data = await sb
        .from('purchases')
        .select('id, invoice_ref, purchase_date, total_amount, paid_amount, balance_amount, payment_status, notes, created_at')
        .eq('supplier_id', supplierId)
        .order('purchase_date', ascending: false)
        .limit(100) as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> listPayments(String supplierId) async {
    final data = await sb
        .from('supplier_payments')
        .select('*, profiles!paid_by(full_name)')
        .eq('supplier_id', supplierId)
        .order('created_at', ascending: false)
        .limit(100) as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  Future<String> recordPayment({
    required String supplierId,
    required double amount,
    required String paymentMethod,
    String? referenceNo,
    String? notes,
  }) async {
    final id = await sb.rpc('record_supplier_payment', params: {
      'p_supplier_id': supplierId,
      'p_amount': amount,
      'p_payment_method': paymentMethod,
      'p_reference_no': referenceNo,
      'p_notes': notes,
    });
    return id as String;
  }
}

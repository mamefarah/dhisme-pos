import '../../../core/services/supabase_service.dart';

class StoreRepository {
  Future<Map<String, dynamic>?> fetchStore(String storeId) async {
    return await sb.from('stores').select().eq('id', storeId).maybeSingle();
  }

  Future<void> updateStore({
    required String storeId,
    required String name,
    String? phone,
    String? address,
  }) async {
    await sb.from('stores').update({
      'name': name.trim(),
      'phone': phone != null && phone.trim().isNotEmpty ? phone.trim() : null,
      'address': address != null && address.trim().isNotEmpty ? address.trim() : null,
    }).eq('id', storeId);
  }
}

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
    final updated = await sb.from('stores').update({
      'name': name.trim(),
      'phone': phone != null && phone.trim().isNotEmpty ? phone.trim() : null,
      'address': address != null && address.trim().isNotEmpty ? address.trim() : null,
    }).eq('id', storeId).select('id');
    assertUpdateApplied(updated);
  }

  /// RLS scopes `stores` UPDATE to the owner of that store; a zero-row
  /// result means permission was denied or the store id didn't match, not
  /// that the save succeeded. Exposed as a static method so the zero-row
  /// check can be unit-tested without a live Supabase client.
  static void assertUpdateApplied(List<dynamic> updatedRows) {
    if (updatedRows.isEmpty) {
      throw Exception('Store update was not applied. You may not have permission to change store settings, or the store could not be found.');
    }
  }
}

import '../../../core/services/supabase_service.dart';

class EmployeeRepository {
  /// Returns all profiles in the current user's store, newest first.
  /// RLS on profiles ensures only same-store rows are returned.
  Future<List<Map<String, dynamic>>> listEmployees() async {
    final data = await sb
        .from('profiles')
        .select()
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(data as List);
  }

  /// Updates an employee's editable fields.
  /// The owner update RLS policy enforces store scope.
  Future<void> updateEmployee({
    required String id,
    required String fullName,
    String? phone,
    required String role,
    required bool isActive,
  }) async {
    await sb.from('profiles').update({
      'full_name': fullName.trim(),
      'phone': phone == null || phone.trim().isEmpty ? null : phone.trim(),
      'role': role,
      'is_active': isActive,
    }).eq('id', id);
  }

  /// Calls the create_store_invite RPC; returns the generated 8-char code.
  Future<String> createInvite(String role) async {
    final code = await sb.rpc('create_store_invite', params: {'p_role': role});
    return code as String;
  }

  /// Returns active (unused, not-expired) invite codes for this store.
  Future<List<Map<String, dynamic>>> listActiveInvites() async {
    final data = await sb
        .from('store_invites')
        .select('id, code, role, created_at, expires_at, used_at, profiles!created_by(full_name)')
        .isFilter('used_at', null)
        .order('created_at', ascending: false)
        .limit(20);
    return List<Map<String, dynamic>>.from(data as List);
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../models/app_profile.dart';

class AuthRepository {
  Future<void> signIn(String email, String password) async {
    await sb.auth.signInWithPassword(email: email.trim(), password: password);
  }

  Future<void> signOut() => sb.auth.signOut();

  Future<AppProfile?> currentProfile() async {
    if (sb.auth.currentUser == null) return null;
    final result = await sb.rpc('get_my_profile_v2');
    if (result == null) return null;
    return AppProfile.fromMap(Map<String, dynamic>.from(result as Map));
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String storeName,
    String? phone,
    String? storePhone,
    String? storeAddress,
  }) =>
      sb.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'full_name': fullName.trim(),
          'store_name': storeName.trim(),
          if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
          if (storePhone != null && storePhone.trim().isNotEmpty) 'store_phone': storePhone.trim(),
          if (storeAddress != null && storeAddress.trim().isNotEmpty) 'store_address': storeAddress.trim(),
          'signup_type': 'owner',
        },
      );

  Future<void> registerOwner({
    required String fullName,
    required String storeName,
    String? phone,
    String? storePhone,
    String? storeAddress,
  }) =>
      sb.rpc('register_owner', params: {
        'p_full_name': fullName,
        'p_store_name': storeName,
        'p_phone': phone,
        'p_store_phone': storePhone,
        'p_store_address': storeAddress,
      });

  Future<AuthResponse> signUpEmployee({
    required String email,
    required String password,
    required String fullName,
    required String inviteCode,
    String? phone,
  }) =>
      sb.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'full_name': fullName.trim(),
          'invite_code': inviteCode.trim().toUpperCase(),
          if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
          'signup_type': 'employee',
        },
      );

  Future<void> registerWithInvite({
    required String fullName,
    required String inviteCode,
    String? phone,
  }) =>
      sb.rpc('register_with_invite', params: {
        'p_full_name': fullName,
        'p_invite_code': inviteCode,
        'p_phone': phone,
      });
}

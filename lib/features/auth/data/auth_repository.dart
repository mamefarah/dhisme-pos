import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../models/app_profile.dart';

class AuthRepository {
  Future<void> signIn(String email, String password) async {
    await sb.auth.signInWithPassword(email: email.trim(), password: password);
  }

  Future<void> signOut() => sb.auth.signOut();

  Future<AppProfile?> currentProfile() async {
    final user = sb.auth.currentUser;
    if (user == null) return null;
    final data = await sb.from('profiles').select().eq('id', user.id).maybeSingle();
    if (data == null) return null;
    return AppProfile.fromMap(data);
  }

  /// Creates a Supabase auth user. Stores owner registration data in user
  /// metadata so it survives an email-confirmation round-trip.
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

  /// Creates the store and owner profile rows via a SECURITY DEFINER RPC.
  /// Safe to call only when the user is authenticated.
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

  /// Creates a Supabase auth user for an employee joining via invite code.
  /// Stores the invite code and name in metadata so registration can complete
  /// after an email-confirmation round-trip.
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

  /// Creates the employee profile row by validating the stored invite code.
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

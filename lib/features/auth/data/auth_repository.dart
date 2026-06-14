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
}

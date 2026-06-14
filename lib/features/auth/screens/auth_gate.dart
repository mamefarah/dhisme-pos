import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../dashboard/screens/owner_home_screen.dart';
import '../../dashboard/screens/seller_home_screen.dart';
import '../data/auth_repository.dart';
import '../models/app_profile.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _repo = AuthRepository();
  late Future<AppProfile?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _repo.currentProfile();
    sb.auth.onAuthStateChange.listen((AuthState state) {
      if (mounted) setState(() => _profileFuture = _repo.currentProfile());
    });
  }

  @override
  Widget build(BuildContext context) {
    if (sb.auth.currentSession == null) return const LoginScreen();

    return FutureBuilder<AppProfile?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final profile = snapshot.data;
        if (profile == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Profile missing')),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('This login has no row in the profiles table.'),
                  const SizedBox(height: 12),
                  const Text('Create a profiles row in Supabase using this Auth user ID:'),
                  const SizedBox(height: 8),
                  SelectableText(sb.auth.currentUser?.id ?? ''),
                  const Spacer(),
                  FilledButton(onPressed: () => _repo.signOut(), child: const Text('Logout')),
                ],
              ),
            ),
          );
        }
        if (profile.isOwner) return OwnerHomeScreen(profile: profile);
        return SellerHomeScreen(profile: profile);
      },
    );
  }
}

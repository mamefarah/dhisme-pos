import 'dart:async';
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
  StreamSubscription<AuthState>? _authSub;

  bool _loading = true;
  AppProfile? _profile;
  String? _profileError;

  @override
  void initState() {
    super.initState();
    _authSub = sb.auth.onAuthStateChange.listen(_handleAuthChange);
    _loadProfile();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  void _handleAuthChange(AuthState state) {
    if (!mounted) return;
    final event = state.event;
    if (event == AuthChangeEvent.signedIn ||
        event == AuthChangeEvent.tokenRefreshed ||
        event == AuthChangeEvent.userUpdated) {
      _loadProfile();
    } else if (event == AuthChangeEvent.signedOut) {
      setState(() {
        _profile = null;
        _profileError = null;
        _loading = false;
      });
    }
  }

  Future<void> _loadProfile() async {
    if (sb.auth.currentSession == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _profile = null;
          _profileError = null;
        });
      }
      return;
    }

    if (mounted) setState(() { _loading = true; _profileError = null; });

    try {
      final profile = await _repo.currentProfile();
      if (mounted) setState(() { _profile = profile; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() { _loading = false; _profileError = _describeProfileError(e); });
      }
    }
  }

  String _describeProfileError(Object error) {
    final msg = error.toString().toLowerCase();
    if (msg.contains('row-level security') ||
        msg.contains('permission denied') ||
        msg.contains('42501')) {
      return 'Access denied loading your profile.\n'
          'Your account may lack the required database permissions.\n'
          'Contact the store owner to verify your profile setup.';
    }
    if (msg.contains('does not exist') || msg.contains('42p01')) {
      return 'The profiles table does not exist in the database.\n'
          'Please complete the Supabase database setup.';
    }
    if (msg.contains('socketexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('network is unreachable')) {
      return 'Cannot connect to the server.\n'
          'Please check your internet connection and try again.';
    }
    if (msg.contains('timed out') || msg.contains('deadline exceeded')) {
      return 'Connection timed out. Please check your connection and try again.';
    }
    return 'Failed to load your profile. Please try again or contact the administrator.';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (sb.auth.currentSession == null) {
      return const LoginScreen();
    }

    if (_profileError != null) {
      return _ProfileErrorScreen(
        message: _profileError!,
        onRetry: _loadProfile,
        onLogout: _repo.signOut,
      );
    }

    if (_profile == null) {
      return _ProfileMissingScreen(
        userId: sb.auth.currentUser?.id ?? '',
        onLogout: _repo.signOut,
      );
    }

    if (_profile!.isOwner) return OwnerHomeScreen(profile: _profile!);
    return SellerHomeScreen(profile: _profile!);
  }
}

class _ProfileErrorScreen extends StatelessWidget {
  const _ProfileErrorScreen({
    required this.message,
    required this.onRetry,
    required this.onLogout,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Sign-in Error')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.cloud_off_outlined, size: 64, color: cs.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileMissingScreen extends StatelessWidget {
  const _ProfileMissingScreen({required this.userId, required this.onLogout});

  final String userId;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile Not Found')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.person_off_outlined, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              'Your login is authenticated but no profile exists in the database for this account.',
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ask the store owner to add your profile in Supabase using this user ID:',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SelectableText(
                userId,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}

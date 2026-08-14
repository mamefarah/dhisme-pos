import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../dashboard/screens/manager_home_screen.dart';
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
  bool _registering = false;

  @override
  void initState() {
    super.initState();
    _authSub = _repo.authStateChanges.listen(_handleAuthChange);
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
    if (!_repo.hasSession) {
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

      // Profile exists — normal login path.
      if (profile != null) {
        if (mounted) setState(() { _profile = profile; _loading = false; });
        return;
      }

      // Profile is null. Check if this user signed up and needs profile creation.
      final meta = _repo.currentUserMetadata;
      final signupType = meta?['signup_type'] as String?;

      if (signupType == 'owner' || signupType == 'employee') {
        if (mounted) setState(() => _registering = true);
        try {
          if (signupType == 'owner') {
            await _repo.registerOwner(
              fullName: (meta!['full_name'] as String?) ?? '',
              storeName: (meta['store_name'] as String?) ?? '',
              phone: meta['phone'] as String?,
              storePhone: meta['store_phone'] as String?,
              storeAddress: meta['store_address'] as String?,
            );
          } else {
            await _repo.registerWithInvite(
              fullName: (meta!['full_name'] as String?) ?? '',
              inviteCode: (meta['invite_code'] as String?) ?? '',
              phone: meta['phone'] as String?,
            );
          }
          final created = await _repo.currentProfile();
          if (mounted) setState(() { _profile = created; _loading = false; _registering = false; });
        } catch (e) {
          final existing = await _repo.currentProfile();
          if (existing != null) {
            if (mounted) setState(() { _profile = existing; _loading = false; _registering = false; });
          } else {
            if (mounted) {
              setState(() {
                _loading = false;
                _registering = false;
                _profileError = _describeRegistrationError(e, signupType!);
              });
            }
          }
        }
        return;
      }

      // Profile truly missing for a non-signup user (e.g. employee with no profile row).
      if (mounted) setState(() { _profile = null; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() { _loading = false; _profileError = _describeProfileError(e); });
      }
    }
  }

  String _describeRegistrationError(Object error, String signupType) {
    final msg = error.toString().toLowerCase();
    if (signupType == 'employee') {
      if (msg.contains('invalid or has expired')) {
        return 'The invite code is invalid or has expired.\n'
            'Ask the store owner to generate a new invite code and try again.';
      }
      if (msg.contains('already exists')) {
        return 'An account profile already exists for this login.\nTry logging in directly.';
      }
      return 'Could not join the store. Please tap Try Again, or ask the store owner for help.';
    }
    return 'Could not finish creating your account. '
        'Please tap Try Again, or contact support if this keeps happening.';
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
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              if (_registering) ...[
                const SizedBox(height: 16),
                const Text('Setting up your store…', style: TextStyle(color: Colors.black54)),
              ],
            ],
          ),
        ),
      );
    }

    if (!_repo.hasSession) {
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
        userId: _repo.currentUserId ?? '',
        onLogout: _repo.signOut,
      );
    }

    if (!_profile!.isActive) {
      return _AccountDeactivatedScreen(onLogout: _repo.signOut);
    }

    if (_profile!.isOwner) return OwnerHomeScreen(profile: _profile!);
    if (_profile!.isManager) return ManagerHomeScreen(profile: _profile!);
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

class _AccountDeactivatedScreen extends StatelessWidget {
  const _AccountDeactivatedScreen({required this.onLogout});
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.block_outlined, size: 72, color: Colors.red),
            const SizedBox(height: 24),
            const Text(
              'Account Deactivated',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your account has been deactivated by the store owner.\n'
              'Contact the store owner to restore access.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 40),
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

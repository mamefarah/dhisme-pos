import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/errors.dart';
import '../data/auth_repository.dart';

class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = AuthRepository();

  final _inviteCode = TextEditingController();
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _emailSent = false;

  @override
  void dispose() {
    _inviteCode.dispose();
    _fullName.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);
    try {
      final response = await _repo.signUpEmployee(
        email: _email.text.trim(),
        password: _password.text,
        fullName: _fullName.text.trim(),
        inviteCode: _inviteCode.text.trim().toUpperCase(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      );

      if (!mounted) return;

      if (response.session != null) {
        // Auto-confirmed — AuthGate will call register_with_invite() via metadata.
      } else {
        setState(() => _emailSent = true);
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      _showError(_friendlyAuthError(e));
    } catch (e) {
      if (!mounted) return;
      _showError(friendlyError(e, fallback: 'Could not create account. Please try again.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyAuthError(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('already registered') || msg.contains('already exists')) {
      return 'An account with this email already exists. Try logging in instead.';
    }
    if (msg.contains('password') && msg.contains('weak')) {
      return 'Password is too weak. Use at least 8 characters.';
    }
    if (msg.contains('invalid email')) {
      return 'Please enter a valid email address.';
    }
    return 'Could not create account: ${e.message}';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ));
  }

  @override
  Widget build(BuildContext context) {
    if (_emailSent) {
      return Scaffold(
        appBar: AppBar(title: const Text('Check Your Email')),
        body: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.mark_email_unread_outlined, size: 72, color: Colors.blue),
              const SizedBox(height: 24),
              const Text(
                'Confirm your email address',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'We sent a confirmation link to:\n${_email.text.trim()}\n\n'
                'Open your email app, click the link, then come back and log in.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                icon: const Icon(Icons.login),
                label: const Text('Go to Login'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Join a Store')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Invite code ──────────────────────────────────────
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.vpn_key_outlined,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text('Invite code',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              )),
                        ]),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _inviteCode,
                          textCapitalization: TextCapitalization.characters,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          style: const TextStyle(
                              letterSpacing: 4, fontWeight: FontWeight.bold, fontSize: 18),
                          decoration: const InputDecoration(
                            hintText: 'XXXXXXXX',
                            filled: true,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Invite code is required';
                            if (v.trim().length < 6) return 'Enter the full invite code';
                            return null;
                          },
                          onChanged: (v) {
                            _inviteCode.value = _inviteCode.value.copyWith(
                              text: v.toUpperCase(),
                              selection: _inviteCode.selection,
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Get this 8-character code from your store owner.',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Your details ──────────────────────────────────────
                const _SectionLabel(icon: Icons.person_outline, title: 'Your details'),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _fullName,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Full name is required';
                    if (v.trim().length < 2) return 'Name must be at least 2 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Phone (optional)',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Login credentials ─────────────────────────────────
                const _SectionLabel(icon: Icons.lock_outline, title: 'Login credentials'),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email is required';
                    if (!v.trim().contains('@') || !v.trim().contains('.')) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 8) return 'Password must be at least 8 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmPassword,
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Confirm password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Please confirm your password';
                    if (v != _password.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                FilledButton.icon(
                  onPressed: _loading ? null : _submit,
                  icon: _loading
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.group_add_outlined),
                  label: const Text('Join Store'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: cs.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: cs.primary.withValues(alpha: 0.3))),
      ],
    );
  }
}

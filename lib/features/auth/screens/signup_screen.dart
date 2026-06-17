import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/utils/errors.dart';
import '../data/auth_repository.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = AuthRepository();

  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _storeName = TextEditingController();
  final _storePhone = TextEditingController();
  final _storeAddress = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _emailSent = false;

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _storeName.dispose();
    _storePhone.dispose();
    _storeAddress.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      final response = await _repo.signUp(
        email: _email.text.trim(),
        password: _password.text,
        fullName: _fullName.text.trim(),
        storeName: _storeName.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        storePhone: _storePhone.text.trim().isEmpty ? null : _storePhone.text.trim(),
        storeAddress: _storeAddress.text.trim().isEmpty ? null : _storeAddress.text.trim(),
      );
      if (!mounted) return;
      if (response.session == null) setState(() => _emailSent = true);
    } on AuthException catch (e) {
      if (!mounted) return;
      _showError(_friendlyAuthError(e));
    } catch (e) {
      if (!mounted) return;
      _showError(friendlyError(e, fallback: context.tr('Akoonka lama samayn karin. Fadlan mar kale isku day.', 'Could not create account. Please try again.')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyAuthError(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('already registered') || msg.contains('already exists') || msg.contains('email address is already')) {
      return context.tr('Email-kan akoon ayaa hore ugu diiwaangashan. Soo gal halkii aad akoon cusub samayn lahayd.', 'An account with this email already exists. Try logging in instead.');
    }
    if (msg.contains('password') && msg.contains('weak')) {
      return context.tr('Furaha sirta waa daciif. Isticmaal ugu yaraan 8 xaraf.', 'Password is too weak. Use at least 8 characters.');
    }
    if (msg.contains('invalid email')) {
      return context.tr('Fadlan geli email sax ah.', 'Please enter a valid email address.');
    }
    if (msg.contains('network') || msg.contains('connection')) {
      return context.tr('Server-ka lama xiriiri karo. Hubi internet-kaaga.', 'Cannot connect to the server. Check your internet connection.');
    }
    return context.tr('Akoonka lama samayn karin: ${e.message}', 'Could not create account: ${e.message}');
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
    final cs = Theme.of(context).colorScheme;
    if (_emailSent) return _EmailSentScreen(email: _email.text.trim());

    return AnimatedBuilder(
      animation: AppLanguage.instance,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(context.tr('Samee Akoon Cusub', 'Create New Account')),
          actions: [
            TextButton(
              onPressed: AppLanguage.instance.toggle,
              child: Text(AppLanguage.instance.isSomali ? 'English' : 'Soomaali'),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionHeader(icon: Icons.person_outline, title: context.tr('Macluumaadkaaga', 'Your details')),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _fullName,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(labelText: context.tr('Magaca oo buuxa', 'Full name'), prefixIcon: const Icon(Icons.badge_outlined)),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return context.tr('Magaca waa loo baahan yahay', 'Full name is required');
                      if (v.trim().length < 2) return context.tr('Magacu waa inuu ka badnaadaa 2 xaraf', 'Name must be at least 2 characters');
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(labelText: context.tr('Telefoonkaaga (ikhtiyaari)', 'Your phone (optional)'), prefixIcon: const Icon(Icons.phone_outlined)),
                  ),
                  const SizedBox(height: 20),
                  _SectionHeader(icon: Icons.lock_outline, title: context.tr('Macluumaadka soo gelidda', 'Login credentials')),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: InputDecoration(labelText: context.tr('Email', 'Email address'), prefixIcon: const Icon(Icons.email_outlined)),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return context.tr('Email waa loo baahan yahay', 'Email is required');
                      if (!v.trim().contains('@') || !v.trim().contains('.')) return context.tr('Geli email sax ah', 'Enter a valid email address');
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: context.tr('Furaha sirta', 'Password'),
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        tooltip: _obscurePassword ? context.tr('Muuji furaha', 'Show password') : context.tr('Qari furaha', 'Hide password'),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return context.tr('Furaha sirta waa loo baahan yahay', 'Password is required');
                      if (v.length < 8) return context.tr('Furaha sirta ugu yaraan waa 8 xaraf', 'Password must be at least 8 characters');
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmPassword,
                    obscureText: _obscureConfirm,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: context.tr('Xaqiiji furaha sirta', 'Confirm password'),
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        tooltip: _obscureConfirm ? context.tr('Muuji furaha', 'Show password') : context.tr('Qari furaha', 'Hide password'),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return context.tr('Fadlan xaqiiji furaha sirta', 'Please confirm your password');
                      if (v != _password.text) return context.tr('Furayaasha sirta isma waafaqsana', 'Passwords do not match');
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  _SectionHeader(icon: Icons.storefront_outlined, title: context.tr('Macluumaadka dukaanka', 'Store details')),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _storeName,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(labelText: context.tr('Magaca dukaanka', 'Store name'), prefixIcon: const Icon(Icons.store_outlined)),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return context.tr('Magaca dukaanka waa loo baahan yahay', 'Store name is required');
                      if (v.trim().length < 2) return context.tr('Magaca dukaanku waa inuu ka badnaadaa 2 xaraf', 'Store name must be at least 2 characters');
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _storePhone,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(labelText: context.tr('Telefoonka dukaanka (ikhtiyaari)', 'Store phone (optional)'), prefixIcon: const Icon(Icons.phone_outlined)),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _storeAddress,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    minLines: 2,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: context.tr('Cinwaanka dukaanka (ikhtiyaari)', 'Store address (optional)'),
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: _loading ? null : _submit,
                    icon: _loading ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.how_to_reg_outlined),
                    label: Text(context.tr('Samee Akoon', 'Create Account')),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.tr('Markaad akoon samayso, xogtaada waxaa si ammaan ah loogu kaydinayaa Supabase.', 'By creating an account you agree that your data is stored securely in Supabase.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5)),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmailSentScreen extends StatelessWidget {
  const _EmailSentScreen({required this.email});
  final String email;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Hubi Email-kaaga', 'Check Your Email'))),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.mark_email_unread_outlined, size: 72, color: Colors.blue),
            const SizedBox(height: 24),
            Text(context.tr('Xaqiiji email-kaaga', 'Confirm your email address'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              context.tr('Waxaan link xaqiijin ah u dirnay:\n$email\n\nFur email-kaaga, guji link-ga, kadib halkan ku soo noqo oo soo gal.', 'We sent a confirmation link to:\n$email\n\nOpen your email app, click the link, then come back here and log in.'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              icon: const Icon(Icons.login),
              label: Text(context.tr('Tag Soo-gelidda', 'Go to Login')),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      Icon(icon, size: 18, color: cs.primary),
      const SizedBox(width: 6),
      Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.primary, letterSpacing: 0.3)),
      const SizedBox(width: 8),
      Expanded(child: Divider(color: cs.primary.withValues(alpha: 0.3))),
    ]);
  }
}

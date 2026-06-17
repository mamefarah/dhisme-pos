import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/i18n/app_language.dart';
import '../data/auth_repository.dart';
import 'join_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _repo = AuthRepository();
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String _friendlyError(BuildContext context, Object error) {
    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('invalid login credentials') ||
          msg.contains('invalid email or password') ||
          msg.contains('email not found') ||
          msg.contains('wrong password')) {
        return context.tr('Email-ka ama furaha sirta waa khaldan yahay. Fadlan hubi oo isku day mar kale.', 'Incorrect email or password. Please check and try again.');
      }
      if (msg.contains('email not confirmed')) {
        return context.tr('Fadlan xaqiiji email-kaaga ka hor intaadan soo gelin.', 'Please confirm your email address before logging in.');
      }
      if (msg.contains('too many requests') || error.statusCode == '429') {
        return context.tr('Isku dayo badan ayaa dhacay. Sug dhowr daqiiqo kadib mar kale isku day.', 'Too many failed attempts. Please wait a few minutes and try again.');
      }
      if (msg.contains('network') || msg.contains('connection')) {
        return context.tr('Server-ka lama xiriiri karo. Hubi internet-kaaga.', 'Cannot connect to the server. Check your internet connection.');
      }
      return context.tr('Soo geliddu way fashilantay: ${error.message}', 'Login failed: ${error.message}');
    }
    final str = error.toString().toLowerCase();
    if (str.contains('socketexception') || str.contains('failed host lookup') || str.contains('network is unreachable')) {
      return context.tr('Server-ka lama xiriiri karo. Hubi internet-kaaga.', 'Cannot connect to the server. Check your internet connection.');
    }
    if (str.contains('timed out') || str.contains('deadline exceeded')) {
      return context.tr('Xiriirku wuu daahay. Fadlan mar kale isku day.', 'Connection timed out. Please try again.');
    }
    return context.tr('Khalad lama filaan ah ayaa dhacay. Fadlan mar kale isku day.', 'An unexpected error occurred. Please try again.');
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      await _repo.signIn(_emailCtrl.text.trim(), _passwordCtrl.text);
    } on AuthException catch (e) {
      if (!mounted) return;
      _showError(_friendlyError(context, e));
    } catch (e) {
      if (!mounted) return;
      _showError(_friendlyError(context, e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
    return AnimatedBuilder(
      animation: AppLanguage.instance,
      builder: (context, _) => Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: AppLanguage.instance.toggle,
                        icon: const Icon(Icons.language_outlined, size: 18),
                        label: Text(AppLanguage.instance.isSomali ? 'English' : 'Soomaali'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Icon(Icons.storefront, size: 72, color: cs.primary),
                    const SizedBox(height: 16),
                    Text(
                      'Dukaan Dhisme POS',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('App-ka iibka, kaydka, deynta iyo xisaabta dukaanka qalabka dhismaha', 'Sales, stock, credit, and accounting app for construction materials stores'),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return context.tr('Email waa loo baahan yahay', 'Email is required');
                        if (!v.trim().contains('@')) return context.tr('Geli email sax ah', 'Enter a valid email address');
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: context.tr('Furaha sirta', 'Password'),
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          tooltip: _obscurePassword ? context.tr('Muuji furaha', 'Show password') : context.tr('Qari furaha', 'Hide password'),
                        ),
                      ),
                      validator: (v) => v == null || v.isEmpty ? context.tr('Furaha sirta waa loo baahan yahay', 'Password is required') : null,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _loading ? null : _submit,
                      icon: _loading
                          ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.login),
                      label: Text(context.tr('Soo gal', 'Login')),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _loading ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignupScreen())),
                      child: Text(context.tr('Akoon ma lihid? Samee akoon cusub', "Don't have an account? Create one")),
                    ),
                    TextButton(
                      onPressed: _loading ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const JoinScreen())),
                      child: Text(context.tr('Ku biir dukaan adigoo isticmaalaya invite code', 'Join a store with invite code')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

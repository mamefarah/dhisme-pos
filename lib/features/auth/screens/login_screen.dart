import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  String _friendlyError(Object error) {
    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('invalid login credentials') ||
          msg.contains('invalid email or password') ||
          msg.contains('email not found') ||
          msg.contains('wrong password')) {
        return 'Email-ka ama furaha sirta waa khaldan yahay. Fadlan hubi oo isku day mar kale.';
      }
      if (msg.contains('email not confirmed')) {
        return 'Fadlan xaqiiji email-kaaga ka hor intaadan soo gelin.';
      }
      if (msg.contains('too many requests') || error.statusCode == '429') {
        return 'Isku dayo badan ayaa dhacay. Sug dhowr daqiiqo kadib mar kale isku day.';
      }
      if (msg.contains('network') || msg.contains('connection')) {
        return 'Server-ka lama xiriiri karo. Hubi internet-kaaga.';
      }
      return 'Soo geliddu way fashilantay: ${error.message}';
    }
    final str = error.toString().toLowerCase();
    if (str.contains('socketexception') ||
        str.contains('failed host lookup') ||
        str.contains('network is unreachable')) {
      return 'Server-ka lama xiriiri karo. Hubi internet-kaaga.';
    }
    if (str.contains('timed out') || str.contains('deadline exceeded')) {
      return 'Xiriirku wuu daahay. Fadlan mar kale isku day.';
    }
    return 'Khalad lama filaan ah ayaa dhacay. Fadlan mar kale isku day.';
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);
    try {
      await _repo.signIn(_emailCtrl.text.trim(), _passwordCtrl.text);
    } on AuthException catch (e) {
      if (!mounted) return;
      _showError(_friendlyError(e));
    } catch (e) {
      if (!mounted) return;
      _showError(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
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
                  Icon(Icons.storefront, size: 72, color: cs.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Dukaan Dhisme POS',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'App-ka iibka, kaydka, deynta iyo xisaabta dukaanka qalabka dhismaha',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Email waa loo baahan yahay';
                      }
                      if (!v.trim().contains('@')) {
                        return 'Geli email sax ah';
                      }
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
                      labelText: 'Furaha sirta',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        tooltip: _obscurePassword ? 'Muuji furaha' : 'Qari furaha',
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Furaha sirta waa loo baahan yahay';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _loading ? null : _submit,
                    icon: _loading
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.login),
                    label: const Text('Soo gal'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const SignupScreen()),
                            ),
                    child: const Text('Akoon ma lihid? Samee akoon cusub'),
                  ),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const JoinScreen()),
                            ),
                    child: const Text('Ku biir dukaan adigoo isticmaalaya invite code'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

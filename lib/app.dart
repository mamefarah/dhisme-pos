import 'package:flutter/material.dart';
import 'core/i18n/app_language.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/auth_gate.dart';
import 'features/auth/screens/config_missing_screen.dart';

class DhismePosApp extends StatefulWidget {
  const DhismePosApp({super.key, required this.isConfigured});

  final bool isConfigured;

  @override
  State<DhismePosApp> createState() => _DhismePosAppState();
}

class _DhismePosAppState extends State<DhismePosApp> {
  @override
  void initState() {
    super.initState();
    AppLanguage.instance.load();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLanguage.instance,
      builder: (context, _) => MaterialApp(
        title: 'Dukaan Dhisme POS',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: widget.isConfigured ? const AuthGate() : const ConfigMissingScreen(),
      ),
    );
  }
}

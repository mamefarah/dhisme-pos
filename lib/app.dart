import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/auth_gate.dart';
import 'features/auth/screens/config_missing_screen.dart';

class DhismePosApp extends StatelessWidget {
  const DhismePosApp({super.key, required this.isConfigured});

  final bool isConfigured;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dukaan Dhisme POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: isConfigured ? const AuthGate() : const ConfigMissingScreen(),
    );
  }
}

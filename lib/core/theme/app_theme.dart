import 'package:flutter/material.dart';

class AppTheme {
  static const navy = Color(0xFF0B1F3A);
  static const orange = Color(0xFFF58220);
  static const bg = Color(0xFFF5F6FA);

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(seedColor: navy, primary: navy, secondary: orange);
    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(centerTitle: false, backgroundColor: navy, foregroundColor: Colors.white),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }
}

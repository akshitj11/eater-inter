import 'package:flutter/material.dart';

class AppTheme {
  static const saffron = Color(0xFFFF7A1A);
  static const chili = Color(0xFFE8432E);
  static const ink = Color(0xFF1D1B18);
  static const muted = Color(0xFF7A746E);
  static const line = Color(0xFFEDE7E1);
  static const surface = Color(0xFFFFFCF8);
  static const success = Color(0xFF138A55);

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: saffron,
        primary: saffron,
        secondary: chili,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: surface,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        fontFamily: 'Avenir',
        bodyColor: ink,
        displayColor: ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: saffron,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: saffron, width: 1.4),
        ),
      ),
    );
  }
}

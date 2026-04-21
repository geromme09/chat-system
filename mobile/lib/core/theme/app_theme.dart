import 'package:flutter/material.dart';

class AppTheme {
  static const Color ink = Color(0xFF111111);
  static const Color slate = Color(0xFF6B7280);
  static const Color paper = Color(0xFFF6F4EF);
  static const Color card = Color(0xFFFFFCF6);
  static const Color line = Color(0xFFE7E2D8);
  static const Color lime = Color(0xFFD7FF64);
  static const Color blush = Color(0xFFFFE3D8);

  static ThemeData light() {
    final base = ThemeData(useMaterial3: true);
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: ink,
      onPrimary: Colors.white,
      secondary: lime,
      onSecondary: ink,
      error: Color(0xFFB42318),
      onError: Colors.white,
      surface: card,
      onSurface: ink,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: paper,
      textTheme: base.textTheme.copyWith(
        displaySmall: const TextStyle(
          fontSize: 42,
          height: 0.98,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.4,
          color: ink,
        ),
        headlineMedium: const TextStyle(
          fontSize: 30,
          height: 1.05,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
          color: ink,
        ),
        titleLarge: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          color: ink,
        ),
        bodyLarge: const TextStyle(
          fontSize: 16,
          height: 1.45,
          color: ink,
        ),
        bodyMedium: const TextStyle(
          fontSize: 14,
          height: 1.45,
          color: ink,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: ink, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(58),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          side: const BorderSide(color: line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          foregroundColor: ink,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: line),
        ),
      ),
      dividerColor: line,
    );
  }
}

import 'package:flutter/material.dart';

/// =======================
/// DESIGN TOKENS
/// =======================

class AppColors {
  // Base
  static const background = Color(0xFFF7F8FB);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSoft = Color(0xFFF9FAFC);

  // Text
  static const textPrimary = Color(0xFF111111);
  static const textSecondary = Color(0xFF6B7280);
  static const textTertiary = Color(0xFF9CA3AF);

  // Primary (Purple)
  static const primary = Color(0xFF6366F1);
  static const primaryLight = Color(0xFFDCDDFF);
  static const primarySoft = Color(0xFFEFF0FF);
  static const primaryPressed = Color(0xFF4F46E5);

  // Accent (Peach)
  static const accent = Color(0xFFFFB4A2);
  static const accentSoft = Color(0xFFFFF1EC);
  static const accentStrong = Color(0xFFFF8A65);

  // Borders
  static const border = Color(0xFFE8EBF2);
  static const borderFocus = Color(0xFF6366F1);

  // States
  static const error = Color(0xFFB42318);

  // Effects
  static const primaryGlow = Color(0x336366F1);
  static const shadowSoft = Color(0x0F111827);
}

class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

class AppRadius {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
}

/// =======================
/// THEME
/// =======================

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(useMaterial3: true);

    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      onSecondary: AppColors.textPrimary,
      error: AppColors.error,
      onError: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,

      /// =======================
      /// TYPOGRAPHY
      /// =======================
      textTheme: base.textTheme.copyWith(
        displaySmall: const TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.0,
          color: AppColors.textPrimary,
        ),
        headlineMedium: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: AppColors.textPrimary,
        ),
        titleMedium: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        titleLarge: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyLarge: const TextStyle(
          fontSize: 16,
          height: 1.5,
          color: AppColors.textPrimary,
        ),
        bodyMedium: const TextStyle(
          fontSize: 14,
          height: 1.5,
          color: AppColors.textSecondary,
        ),
        bodySmall: const TextStyle(
          fontSize: 13,
          height: 1.4,
          color: AppColors.textTertiary,
        ),
      ),

      /// =======================
      /// INPUTS
      /// =======================
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border, width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 1.2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),

      /// =======================
      /// BUTTONS
      /// =======================
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          foregroundColor: AppColors.textPrimary,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      /// =======================
      /// CARDS
      /// =======================
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.border),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? AppColors.primary : AppColors.textTertiary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? AppColors.primary : AppColors.textTertiary,
          );
        }),
      ),

      /// =======================
      /// DIVIDER
      /// =======================
      dividerColor: AppColors.border,

      /// =======================
      /// INTERACTION FEEL
      /// =======================
      splashFactory: InkRipple.splashFactory,
    );
  }
}

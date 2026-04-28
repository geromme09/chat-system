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
  static const like = Color(0xFFEC4899);
  static const accepted = Color(0xFF22C55E);
  static const mentioned = Color(0xFFF59E0B);
  static const shared = Color(0xFF2563EB);

  // Accent (Peach)
  static const accent = Color(0xFFFFB4A2);
  static const accentSoft = Color(0xFFFFF1EC);
  static const accentStrong = Color(0xFFFF8A65);

  // Borders
  static const border = Color(0xFFE5E7EB);
  static const borderStrong = Color(0xFFD1D5DB);
  static const borderFocus = Color(0xFF6366F1);

  // States
  static const error = Color(0xFFB42318);
  static const success = Color(0xFF16A34A);

  // Effects
  static const primaryGlow = Color(0x336366F1);
  static const shadowSoft = Color(0x0F111827);
  static const shadowMedium = Color(0x1F000000);
  static const avatarIcon = Color(0xFF424666);
}

class AppOpacity {
  static const disabled = 0.45;
  static const focusGlow = 0.12;
  static const navSurface = 0.98;
  static const navBorder = 0.45;
  static const notificationUnread = 0.52;
  static const notificationBorder = 0.72;
  static const notificationAvatarImage = 0.12;
  static const composerShadow = 0.28;
  static const composerExpandedShadow = 0.5;
}

class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const compact = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const page = 24.0;
  static const authTitleTop = 32.0;
  static const authFormTop = 32.0;
  static const checkboxTop = 24.0;
  static const inputHeight = 58.0;
  static const inputIconGap = 8.0;
  static const buttonHeight = 58.0;
  static const navHorizontalPadding = 8.0;
  static const navVerticalPadding = 0.0;
  static const navIconLabelGap = 3.0;
}

class AppRadius {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const button = 14.0;
  static const pill = 999.0;
}

class AppSizes {
  static const border = 1.0;
  static const inputThemeBorder = 0.8;
  static const inputThemeFocusBorder = 1.2;
  static const focusBorder = 1.5;
  static const backButton = 48.0;
  static const themeButtonHeight = 52.0;
  static const navigationIcon = 24.0;
  static const welcomeImageHeightFactor = 0.38;
  static const successPillShadowBlur = 16.0;
  static const successPillShadowOffsetY = 8.0;
  static const successPillHiddenOffsetX = 0.15;
  static const successPillHiddenOffsetY = -0.2;
  static const bottomNavHeight = 48.0;
  static const bottomNavMinItemWidth = 64.0;
  static const bottomNavIcon = 22.0;
  static const bottomNavActiveIcon = 23.0;
  static const bottomNavIndicatorWidth = 16.0;
  static const bottomNavIndicatorHeight = 3.0;
  static const bottomNavIndicatorHiddenHeight = 0.0;
  static const bottomNavPressedScale = 0.97;
  static const notificationIconButton = 48.0;
  static const notificationAvatar = 56.0;
  static const notificationUnreadDot = 9.0;
  static const composerAvatar = 40.0;
  static const composerInputHeight = 48.0;
  static const composerChipMinHeight = 40.0;
  static const composerChipIcon = 18.0;
  static const composerChipPressedScale = 0.98;
  static const stepPillHeight = 36.0;
  static const progressBarHeight = 5.0;
  static const progressHorizontalInset = 32.0;
  static const icon = 23.0;
  static const checkbox = 22.0;
  static const checkboxRadius = 5.0;
  static const checkboxInsetTop = 2.0;
  static const checkboxBorder = 1.5;
  static const avatar = 122.0;
  static const avatarInset = 6.0;
  static const avatarAction = 38.0;
  static const avatarActionRight = -2.0;
  static const avatarActionBottom = 8.0;
  static const avatarActionBorder = 3.0;
  static const avatarIcon = 38.0;
  static const avatarActionIcon = 26.0;
  static const bioHeight = 142.0;
  static const inputTextOffset = AppSpacing.md + icon + AppSpacing.inputIconGap;
}

class AppMotion {
  static const quick = Duration(milliseconds: 150);
  static const fast = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 220);
  static const page = Duration(milliseconds: 320);
}

class AppTypography {
  static const display = 36.0;
  static const loginTitle = 34.0;
  static const onboardingTitle = 32.0;
  static const headline = 28.0;
  static const title = 20.0;
  static const titleSmall = 18.0;
  static const body = 16.0;
  static const footer = 15.0;
  static const label = 12.0;
  static const navLabel = 11.5;
  static const helper = 13.0;
  static const caption = 14.0;
  static const displayLetterSpacing = -1.0;
  static const headlineLetterSpacing = -0.5;
  static const heroLineHeight = 1.08;
  static const compactLineHeight = 1.12;
  static const titleLineHeight = 1.15;
  static const bodyLineHeight = 1.45;
  static const paragraphLineHeight = 1.5;
  static const helperLineHeight = 1.35;
  static const smallLineHeight = 1.4;
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
          fontSize: AppTypography.display,
          fontWeight: FontWeight.w700,
          letterSpacing: AppTypography.displayLetterSpacing,
          color: AppColors.textPrimary,
        ),
        headlineMedium: const TextStyle(
          fontSize: AppTypography.headline,
          fontWeight: FontWeight.w700,
          letterSpacing: AppTypography.headlineLetterSpacing,
          color: AppColors.textPrimary,
        ),
        titleMedium: const TextStyle(
          fontSize: AppTypography.titleSmall,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        titleLarge: const TextStyle(
          fontSize: AppTypography.title,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyLarge: const TextStyle(
          fontSize: AppTypography.body,
          height: AppTypography.paragraphLineHeight,
          color: AppColors.textPrimary,
        ),
        bodyMedium: const TextStyle(
          fontSize: AppTypography.caption,
          height: AppTypography.paragraphLineHeight,
          color: AppColors.textSecondary,
        ),
        bodySmall: const TextStyle(
          fontSize: AppTypography.helper,
          height: AppTypography.smallLineHeight,
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
          borderSide: const BorderSide(
            color: AppColors.border,
            width: AppSizes.inputThemeBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: AppSizes.inputThemeFocusBorder,
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
          minimumSize: const Size.fromHeight(AppSizes.themeButtonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          textStyle: const TextStyle(
            fontSize: AppTypography.body,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSizes.themeButtonHeight),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          foregroundColor: AppColors.textPrimary,
          textStyle: const TextStyle(
            fontSize: AppTypography.footer,
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
            fontSize: AppTypography.helper,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? AppColors.primary : AppColors.textTertiary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: AppSizes.navigationIcon,
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

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_text_styles.dart';

abstract final class AppTheme {
  // This is the repository's default visual system. New UI should inherit
  // the karaoke neon direction unless a later requirement explicitly overrides it.
  static ThemeData dark() {
    const colorScheme = ColorScheme.dark(
      primary: AppColors.green,
      secondary: AppColors.blue,
      surface: AppColors.panel,
      onPrimary: AppColors.background,
      onSecondary: AppColors.textPrimary,
      onSurface: AppColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: colorScheme,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      textTheme: const TextTheme(
        displaySmall: AppTextStyles.display,
        headlineMedium: AppTextStyles.heading,
        titleLarge: AppTextStyles.title,
        titleMedium: AppTextStyles.subtitle,
        bodyMedium: AppTextStyles.body,
        labelLarge: AppTextStyles.label,
        labelMedium: AppTextStyles.navLabel,
        bodySmall: AppTextStyles.caption,
      ),
      cardTheme: CardThemeData(
        color: AppColors.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: AppColors.panelBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.panelStrong,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          borderSide: const BorderSide(color: AppColors.panelBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          borderSide: const BorderSide(color: AppColors.panelBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          borderSide: const BorderSide(color: AppColors.green, width: 1.5),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Type scale for karaoke screens. These are large-display targets; individual
/// widgets may clamp or scale down for smaller Android car screens.
abstract final class AppTextStyles {
  static const TextStyle display = TextStyle(
    fontSize: 60,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: 0.5,
    height: 1.1,
  );

  static const TextStyle heading = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.15,
  );

  /// Panel headers such as "GỢI Ý CHO BẠN".
  static const TextStyle title = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: 0.6,
  );

  /// Song titles in list rows.
  static const TextStyle subtitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.25,
  );

  static const TextStyle body = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  static const TextStyle label = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
  );

  /// Uppercase navigation labels under the top bar icons.
  static const TextStyle navLabel = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: 0.8,
  );

  /// Virtual keyboard key caps.
  static const TextStyle keyCap = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// Karaoke lyric overlay on the preview player.
  static const TextStyle lyric = TextStyle(
    fontSize: 42,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    fontStyle: FontStyle.italic,
    height: 1.2,
  );
}

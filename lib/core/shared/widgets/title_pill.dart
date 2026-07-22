import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_glows.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import 'liquid_glass.dart';

/// Small filled label used next to the brand wordmark to name the current
/// screen — "Karaoke" on the browser, "ĐÃ CHỌN" on the queue screen.
class TitlePill extends StatelessWidget {
  const TitlePill({
    super.key,
    required this.label,
    this.color = AppColors.green,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: AppGlows.control(color, focused: true),
      ),
      child: LiquidGlass(
        capsule: true,
        detail: LiquidGlassDetail.simple,
        lifted: false,
        tint: color,
        tintStrength: 0.92,
        opacity: 0.95,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 7,
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

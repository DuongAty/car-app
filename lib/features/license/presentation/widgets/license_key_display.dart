import 'package:flutter/material.dart';

import '../../../../core/shared/widgets/liquid_glass.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_spacing.dart';

/// Read-only pill showing the license key typed so far on the on-screen
/// keyboard (mirrors `SearchInputShell`'s look without the mic button).
class LicenseKeyDisplay extends StatelessWidget {
  const LicenseKeyDisplay({
    super.key,
    required this.value,
    required this.placeholder,
  });

  final String value;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final isEmpty = value.isEmpty;

    return LiquidGlass(
      capsule: true,
      opacity: 0.40,
      tint: isEmpty ? null : AppColors.green,
      tintStrength: 0.12,
      rimWidth: isEmpty ? 1 : 1.5,
      rimColor: isEmpty ? AppColors.glassBorder : AppColors.green,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(AppIcons.key, color: AppColors.textSecondary, size: 26),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              isEmpty ? placeholder : value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: isEmpty ? AppColors.textMuted : AppColors.textPrimary,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

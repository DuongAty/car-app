import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import 'liquid_glass.dart';

/// Pill-shaped search field. It displays the query built by the on-screen
/// keyboard rather than hosting a native text input.
class SearchInputShell extends StatelessWidget {
  const SearchInputShell({
    super.key,
    required this.value,
    required this.placeholder,
    required this.onMicTap,
    required this.onTap,
    this.isFocused = false,
  });

  final String value;
  final String placeholder;
  final VoidCallback onMicTap;
  final VoidCallback onTap;
  final bool isFocused;

  @override
  Widget build(BuildContext context) {
    final isEmpty = value.isEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: LiquidGlass(
        capsule: true,
        opacity: 0.40,
        tint: isFocused ? AppColors.green : null,
        tintStrength: 0.12,
        rimWidth: isFocused ? 1.5 : 1,
        rimColor: isFocused ? AppColors.green : AppColors.glassBorder,
        padding: const EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.sm,
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: AppColors.textSecondary, size: 26),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                isEmpty ? placeholder : value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isEmpty ? AppColors.textMuted : AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            InkWell(
              onTap: onMicTap,
              customBorder: const CircleBorder(),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.white10),
                ),
                child: const Icon(
                  Icons.mic_none_rounded,
                  color: AppColors.textSecondary,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

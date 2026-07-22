import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_glows.dart';
import '../../theme/app_radius.dart';
import 'liquid_glass.dart';

/// VI/EN switch. The full form shows both chips side by side (source picker);
/// the compact form shows only the active language (song browser).
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({
    super.key,
    required this.isVietnamese,
    required this.onToggle,
    this.compact = false,
  });

  final bool isVietnamese;
  final VoidCallback onToggle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: _Chip(label: isVietnamese ? 'VI' : 'EN', active: true),
      );
    }

    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: LiquidGlass(
        capsule: true,
        opacity: 0.42,
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Chip(label: 'VI', active: isVietnamese),
            _Chip(label: 'EN', active: !isVietnamese),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final text = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 9),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: active ? AppColors.textPrimary : AppColors.textSecondary,
          height: 1.2,
        ),
      ),
    );

    if (!active) {
      return text;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: AppGlows.control(AppColors.green, focused: true),
      ),
      child: LiquidGlass(
        capsule: true,
        detail: LiquidGlassDetail.simple,
        lifted: false,
        tint: AppColors.greenDeep,
        tintStrength: 0.92,
        opacity: 0.95,
        child: text,
      ),
    );
  }
}

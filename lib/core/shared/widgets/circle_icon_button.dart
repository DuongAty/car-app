import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_glows.dart';
import 'focusable_tile.dart';
import 'liquid_glass.dart';

/// Round liquid-glass button used for the globe switch, the player's transport
/// controls, and the add-to-queue affordance.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 52,
    this.iconSize = 24,
    this.tint,
    this.color = AppColors.textPrimary,
    this.opacity = 0.42,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final double iconSize;

  /// Accent mixed into the glass, e.g. green for the play button.
  final Color? tint;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return FocusableTile(
      onPressed: onPressed,
      builder: (context, focused) {
        final accent = tint ?? AppColors.green;

        return AnimatedScale(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          scale: focused ? 1.08 : 1,
          child: SizedBox(
            width: size,
            height: size,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: AppGlows.control(
                  accent,
                  focused: focused || tint != null,
                ),
              ),
              child: LiquidGlass(
                capsule: true,
                detail: LiquidGlassDetail.simple,
                lifted: false,
                tint: tint ?? (focused ? AppColors.green : null),
                tintStrength: tint != null ? 0.9 : 0.3,
                opacity: tint != null ? 0.95 : opacity,
                rimWidth: focused ? 1.6 : 1,
                rimColor: focused ? AppColors.green : null,
                child: Center(
                  child: Icon(icon, size: iconSize, color: color),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

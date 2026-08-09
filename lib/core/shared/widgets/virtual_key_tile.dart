import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_glows.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radius.dart';
import 'focusable_tile.dart';
import 'liquid_glass.dart';

/// Single key on the on-screen keyboard. Renders either a caption or an icon
/// (backspace), and can be filled with the primary accent for the search key.
class VirtualKeyTile extends StatelessWidget {
  const VirtualKeyTile({
    super.key,
    required this.onPressed,
    this.label,
    this.icon,
    this.filled = false,
    this.onLongPress,
    this.fontSize,
    this.iconSize,
  }) : assert(
         (label == null) != (icon == null),
         'Provide exactly one of label or icon',
       );

  final VoidCallback onPressed;
  final String? label;
  final IconData? icon;
  final bool filled;
  final VoidCallback? onLongPress;
  final double? fontSize;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    return FocusableTile(
      onPressed: onPressed,
      onLongPress: onLongPress,
      builder: (context, focused) {
        return AnimatedScale(
          duration: AppMotion.focus,
          curve: Curves.easeOut,
          scale: focused ? 1.06 : 1,
          child: AnimatedContainer(
            duration: AppMotion.focus,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              boxShadow: AppGlows.control(AppColors.green, focused: focused),
            ),
            child: LiquidGlass(
              radius: AppRadius.sm,
              // Keys appear forty at a time, so they skip the blurred edge
              // passes the larger surfaces can afford.
              detail: LiquidGlassDetail.simple,
              lifted: false,
              tint: filled || focused ? AppColors.green : null,
              tintStrength: filled ? 0.92 : 0.28,
              opacity: filled ? 0.95 : 0.42,
              rimWidth: focused ? 1.6 : 1,
              rimColor: focused || filled ? AppColors.green : null,
              child: Center(
                child: icon != null
                    ? Icon(
                        icon,
                        size: iconSize ?? 24,
                        color: AppColors.textPrimary,
                      )
                    : Text(
                        label!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontSize: fontSize ?? 22,
                              fontWeight: filled
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

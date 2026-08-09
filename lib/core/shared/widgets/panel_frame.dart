import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import 'liquid_glass.dart';
import 'surface_scope.dart';

/// Floating dark panel with a header row, used for the side columns and the
/// search area on the song browser.
class PanelFrame extends StatelessWidget {
  const PanelFrame({
    super.key,
    required this.child,
    this.title,
    this.leadingIcon,
    this.leadingIconColor,
    this.trailingText,
    this.trailing,
    this.opacity = 0.52,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  final Widget child;
  final String? title;
  final IconData? leadingIcon;
  final Color? leadingIconColor;
  final String? trailingText;
  final Widget? trailing;
  final double opacity;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Row(
            children: [
              if (leadingIcon != null) ...[
                Icon(
                  leadingIcon,
                  size: 22,
                  color: leadingIconColor ?? AppColors.fire,
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              Expanded(
                child: Text(
                  title!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleLarge,
                ),
              ),
              if (trailingText != null)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm),
                  child: Text(trailingText!, style: textTheme.bodySmall),
                ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Expanded(child: child),
      ],
    );

    if (SurfaceScope.of(context)) {
      // An ancestor slab already paints the surface; keep only the padding it
      // would otherwise have supplied.
      return Padding(padding: padding, child: content);
    }

    return LiquidGlass(
      radius: AppRadius.md,
      padding: padding,
      opacity: opacity,
      child: content,
    );
  }
}

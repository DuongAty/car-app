import 'package:flutter/material.dart';

import '../../models/nav_action_item.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_glows.dart';
import '../../theme/app_layout.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import 'focusable_tile.dart';
import 'liquid_glass.dart';

/// How the top bar renders its entries.
enum TopNavStyle {
  /// Standalone actions: icon inside a dark rounded box, caption underneath.
  /// Used on the source picker.
  boxed,

  /// Tab-like entries: icon over caption, the active one filled with a green
  /// plate. Used on the song browser.
  tabbed,
}

class AppTopNav extends StatelessWidget {
  const AppTopNav({
    super.key,
    required this.actions,
    required this.onSelected,
    this.selectedIndex,
    this.style = TopNavStyle.tabbed,
    this.spacing = AppSpacing.lg,
  });

  final List<NavActionItem> actions;
  final ValueChanged<int> onSelected;

  /// `null` when no entry should read as active, which is the case for the
  /// source picker where every entry is a one-off action.
  final int? selectedIndex;
  final TopNavStyle style;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < actions.length; index++) ...[
          if (index > 0) SizedBox(width: spacing),
          _TopNavEntry(
            item: actions[index],
            isSelected: index == selectedIndex,
            style: style,
            onTap: () => onSelected(index),
          ),
        ],
      ],
    );
  }
}

class _TopNavEntry extends StatelessWidget {
  const _TopNavEntry({
    required this.item,
    required this.isSelected,
    required this.style,
    required this.onTap,
  });

  final NavActionItem item;
  final bool isSelected;
  final TopNavStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FocusableTile(
      onPressed: onTap,
      builder: (context, focused) {
        final active = isSelected || focused;

        return switch (style) {
          TopNavStyle.boxed => _BoxedEntry(item: item, active: active),
          TopNavStyle.tabbed => _TabbedEntry(item: item, active: active),
        };
      },
    );
  }
}

class _BoxedEntry extends StatelessWidget {
  const _BoxedEntry({required this.item, required this.active});

  final NavActionItem item;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Fixed slot so the captions, which are wider than the icon box, keep a
      // gap between neighbouring actions.
      width: AppLayout.topIconSlotWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: AppLayout.topIconBoxSize,
            height: AppLayout.topIconBoxSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              boxShadow: AppGlows.control(AppColors.green, focused: active),
            ),
            child: LiquidGlass(
              radius: AppRadius.sm,
              opacity: 0.45,
              tint: active ? AppColors.green : null,
              tintStrength: 0.34,
              rimColor: active ? AppColors.green : AppColors.glassBorder,
              child: Center(
                child: Icon(
                  item.icon,
                  size: 28,
                  color: active ? AppColors.green : AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontSize: 14,
              color: active ? AppColors.green : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabbedEntry extends StatelessWidget {
  const _TabbedEntry({required this.item, required this.active});

  final NavActionItem item;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.green : AppColors.textPrimary;
    const padding = EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.xs,
    );

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 32,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(item.icon, size: 28, color: color),
              if (item.badgeCount case final count?)
                Positioned(
                  top: -3,
                  right: -15,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.greenDeep,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          item.label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(fontSize: 15, color: color),
        ),
      ],
    );

    if (!active) {
      return Padding(padding: padding, child: content);
    }

    return LiquidGlass(
      radius: AppRadius.sm,
      detail: LiquidGlassDetail.simple,
      lifted: false,
      tint: AppColors.green,
      tintStrength: 0.34,
      opacity: 0.5,
      rimColor: AppColors.green,
      rimWidth: 1.4,
      padding: padding,
      child: content,
    );
  }
}

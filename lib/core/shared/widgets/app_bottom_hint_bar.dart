import 'package:flutter/material.dart';

import '../../models/bottom_hint_item.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_glows.dart';
import '../../theme/app_layout.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import 'liquid_glass.dart';

/// Floating remote-control legend pinned to the bottom of every screen.
///
/// [items] sit on the left (after the optional [leading] widget) and
/// [trailingItems] are pushed to the right edge, matching the two hint clusters
/// in the karaoke design.
class AppBottomHintBar extends StatelessWidget {
  const AppBottomHintBar({
    super.key,
    required this.items,
    this.trailingItems = const [],
    this.leading,
    this.center,
    this.compactLabels = false,
    this.onItemTap,
  });

  final List<BottomHintItem> items;
  final List<BottomHintItem> trailingItems;
  final Widget? leading;
  final Widget? center;
  final bool compactLabels;
  final ValueChanged<BottomHintItem>? onItemTap;

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      radius: AppRadius.md,
      opacity: 0.58,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: SizedBox(
        height: AppLayout.bottomBarHeight,
        // The two clusters scale down rather than overflow: the browser packs
        // six groups in here, and Vietnamese and English labels differ enough
        // in length that a fixed layout would clip one of them.
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: AppSpacing.xl),
            ],
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: _HintCluster(
                  items: items,
                  compactLabels: compactLabels,
                  onTap: onItemTap,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xl),
            if (center != null) ...[
              Expanded(flex: 2, child: center!),
              const SizedBox(width: AppSpacing.xl),
            ],
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: _HintCluster(
                    items: trailingItems,
                    compactLabels: compactLabels,
                    onTap: onItemTap,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HintCluster extends StatelessWidget {
  const _HintCluster({
    required this.items,
    required this.compactLabels,
    this.onTap,
  });

  final List<BottomHintItem> items;
  final bool compactLabels;
  final ValueChanged<BottomHintItem>? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < items.length; index++) ...[
          if (index > 0) const SizedBox(width: AppSpacing.xl),
          _HintEntry(
            item: items[index],
            compactLabel: compactLabels,
            onTap: onTap,
          ),
        ],
      ],
    );
  }
}

class _HintEntry extends StatelessWidget {
  const _HintEntry({
    required this.item,
    required this.compactLabel,
    this.onTap,
  });

  final BottomHintItem item;
  final bool compactLabel;
  final ValueChanged<BottomHintItem>? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap == null ? null : () => onTap!(item),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxs,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _HintBadge(item: item),
            if (!compactLabel) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(item.label, style: Theme.of(context).textTheme.labelLarge),
            ],
          ],
        ),
      ),
    );
  }
}

class _HintBadge extends StatelessWidget {
  const _HintBadge({required this.item});

  final BottomHintItem item;

  @override
  Widget build(BuildContext context) {
    final fill = item.accentColor ?? AppColors.keyFill;
    if (item.badgeIcon != null) {
      return SizedBox(
        width: 36,
        height: 36,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: AppGlows.control(fill, focused: true),
          ),
          child: LiquidGlass(
            capsule: true,
            detail: LiquidGlassDetail.simple,
            lifted: false,
            tint: null,
            opacity: 0.42,
            rimColor: fill,
            rimWidth: 1.25,
            child: Center(
              child: Icon(
                item.badgeIcon,
                size: 30,
                color: AppColors.textPrimary,
                shadows: [
                  Shadow(color: fill.withValues(alpha: 0.62), blurRadius: 10),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Yellow badges need dark glyphs to stay legible; the darker accents and
    // the neutral badge keep white ones.
    final onFill = fill.computeLuminance() > 0.5
        ? AppColors.background
        : AppColors.textPrimary;

    return SizedBox(
      width: 36,
      height: 36,
      child: LiquidGlass(
        capsule: true,
        detail: LiquidGlassDetail.simple,
        lifted: false,
        tint: fill,
        tintStrength: 0.92,
        opacity: 0.95,
        child: Center(
          child: Text(
            item.badgeText!,
            style: TextStyle(
              fontSize: item.badgeText!.length > 1 ? 13 : 16,
              fontWeight: FontWeight.w700,
              color: onFill,
              height: 1.1,
            ),
          ),
        ),
      ),
    );
  }
}

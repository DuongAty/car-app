import 'package:flutter/material.dart';

import '../../models/nav_rail_item.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_glows.dart';
import '../../theme/app_layout.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import 'focusable_tile.dart';
import 'liquid_glass.dart';

/// Vertical navigation rail pinned to the left edge of every karaoke screen.
///
/// It replaced the old top nav + bottom hint bar so the body keeps the full
/// screen height for the video stage, which is the whole point on a car head
/// unit: horizontal space is cheap there, vertical space is not.
///
/// Presentation only — it knows nothing about routes or providers. See
/// `MainNavRail` for the wired version every page actually uses.
class AppNavRail extends StatelessWidget {
  const AppNavRail({
    super.key,
    required this.items,
    required this.onSelected,
    this.selectedId,
    this.header,
    this.footer,
  });

  final List<NavRailItem> items;
  final ValueChanged<String> onSelected;

  /// `null` when no destination should read as active, e.g. on the source
  /// picker where the rail is pure navigation.
  final String? selectedId;

  /// Brand mark above the destinations.
  final Widget? header;

  /// Everything pinned below the destinations: the now-playing block, the
  /// language switch, and the volume control.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    // No surface of its own: no glass panel, no rim, no separators. The rail
    // reads as part of the background so every pixel of width it does not
    // strictly need belongs to the content beside it.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null) ...[
          Center(child: header!),
          const SizedBox(height: AppSpacing.sm),
        ],
        // Scrollable so a short head-unit display (768 logical px) degrades
        // by scrolling the destinations instead of overflowing them.
        Expanded(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final item in items)
                  _RailEntry(
                    item: item,
                    selected: item.id == selectedId,
                    onPressed: () => onSelected(item.id),
                  ),
              ],
            ),
          ),
        ),
        if (footer != null) ...[const SizedBox(height: AppSpacing.xs), footer!],
      ],
    );
  }
}

class _RailEntry extends StatelessWidget {
  const _RailEntry({
    required this.item,
    required this.selected,
    required this.onPressed,
  });

  final NavRailItem item;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FocusableTile(
      onPressed: onPressed,
      builder: (context, focused) {
        final accent = item.accentColor ?? AppColors.green;
        final active = selected || focused;
        final color = active ? accent : AppColors.textSecondary;

        final content = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _RailIcon(item: item, color: color, accent: accent),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontSize: 13,
                  letterSpacing: 0.2,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  color: active ? AppColors.textPrimary : color,
                ),
              ),
            ),
          ],
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
          child: SizedBox(
            height: AppLayout.navRailItemHeight,
            child: Stack(
              children: [
                // Instant, not tweened: a tweened blurred shadow re-blurs every
                // frame, and the rail is on screen at all times.
                if (active)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        boxShadow: AppGlows.control(accent, focused: true),
                      ),
                      child: LiquidGlass(
                        radius: AppRadius.sm,
                        detail: LiquidGlassDetail.simple,
                        lifted: false,
                        tint: accent,
                        tintStrength: 0.3,
                        opacity: 0.44,
                        rimColor: accent,
                        rimWidth: focused ? 1.6 : 1.1,
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                Positioned.fill(child: content),
                // Neon spine on the active destination — the one cue that
                // still reads from across a room at rail width.
                if (selected)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: AppLayout.navRailIndicatorWidth,
                      height: AppLayout.navRailIndicatorHeight,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.6),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RailIcon extends StatelessWidget {
  const _RailIcon({
    required this.item,
    required this.color,
    required this.accent,
  });

  final NavRailItem item;
  final Color color;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(item.icon, size: AppLayout.navRailIconSize, color: color);
    final count = item.badgeCount;
    if (count == null) {
      return icon;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          top: -6,
          right: -14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.greenDeep,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

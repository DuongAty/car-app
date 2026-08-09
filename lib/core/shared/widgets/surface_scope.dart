import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import 'liquid_glass.dart';

/// Marks a subtree as already sitting on a painted surface.
///
/// Widgets that normally draw their own [LiquidGlass] — the search field, the
/// player, [PanelFrame] — look this up and render bare when they find it, so a
/// screen reads as one continuous slab instead of a set of floating tiles.
///
/// It carries no data; its presence is the whole signal. Screens that never
/// insert one behave exactly as before.
class SurfaceScope extends InheritedWidget {
  const SurfaceScope({super.key, required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SurfaceScope>() != null;

  // Nothing to compare: the widget holds no state. Adding or removing it from
  // the tree already rebuilds dependents through the normal element machinery.
  @override
  bool updateShouldNotify(SurfaceScope oldWidget) => false;
}

/// One continuous surface for a screen's content area.
///
/// Pairs the outer [LiquidGlass] with a [SurfaceScope] so the two can never be
/// used apart: a scope without a slab would strip descendants' surfaces with
/// nothing painting one in their place.
class ContentSlab extends StatelessWidget {
  const ContentSlab({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      radius: AppRadius.md,
      opacity: 0.5,
      padding: const EdgeInsets.all(1),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md - 1),
        child: SurfaceScope(child: child),
      ),
    );
  }
}

/// Hairline between two regions of a [ContentSlab], replacing the gap and rim
/// that separated them when each was its own panel.
class SurfaceDivider extends StatelessWidget {
  const SurfaceDivider({super.key, this.axis = Axis.horizontal});

  final Axis axis;

  @override
  Widget build(BuildContext context) {
    return axis == Axis.horizontal
        ? Container(height: 1, color: AppColors.panelBorderSoft)
        : Container(width: 1, color: AppColors.panelBorderSoft);
  }
}

import 'package:flutter/material.dart';

/// Animates a child's slot down to zero along one axis without squashing it.
///
/// The child keeps its full [extent] inside an [OverflowBox] while the outer
/// slot animates, so a shrinking panel slides out of view instead of trying to
/// relayout its contents into a few pixels and overflowing on the way.
///
/// While collapsed the subtree is removed from focus traversal and hit testing,
/// otherwise D-pad navigation would walk into panels the user cannot see.
class CollapsibleAxis extends StatelessWidget {
  const CollapsibleAxis({
    super.key,
    required this.axis,
    required this.extent,
    required this.collapsed,
    required this.child,
    this.alignment = Alignment.topLeft,
    // Instant by default: on the 2GB/1-core box the expand/collapse slide was
    // a per-frame relayout of whole panels, and the product direction is no
    // theater-mode transition. Pass a non-zero duration to opt back in.
    this.duration = Duration.zero,
  });

  final Axis axis;

  /// Size of the slot along [axis] when open.
  final double extent;
  final bool collapsed;
  final Widget child;
  final Alignment alignment;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final isHorizontal = axis == Axis.horizontal;
    final open = collapsed ? 0.0 : extent;

    return ClipRect(
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeInOut,
        width: isHorizontal ? open : null,
        height: isHorizontal ? null : open,
        child: OverflowBox(
          alignment: alignment,
          minWidth: isHorizontal ? extent : null,
          maxWidth: isHorizontal ? extent : null,
          minHeight: isHorizontal ? null : extent,
          maxHeight: isHorizontal ? null : extent,
          child: ExcludeFocus(
            excluding: collapsed,
            child: IgnorePointer(ignoring: collapsed, child: child),
          ),
        ),
      ),
    );
  }
}

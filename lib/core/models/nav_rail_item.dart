import 'package:flutter/widgets.dart';

/// One destination in the left navigation rail.
///
/// Identified by [id] rather than by index: the rail is app-wide and every
/// page names its own active destination, so a positional selection would
/// break the moment a destination is inserted or hidden.
@immutable
class NavRailItem {
  const NavRailItem({
    required this.id,
    required this.label,
    required this.icon,
    this.badgeCount,
    this.accentColor,
  });

  final String id;
  final String label;
  final IconData icon;

  /// Small count chip on the icon (queue length). Null hides the chip.
  final int? badgeCount;

  /// Overrides the rail's default green for destructive/secondary entries.
  final Color? accentColor;
}

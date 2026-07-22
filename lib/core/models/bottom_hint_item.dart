import 'package:flutter/material.dart';

/// One remote-control hint in the bottom bar, e.g. a green `OK` badge next to
/// "Chọn". The badge shows either a short key label or an icon, never both.
class BottomHintItem {
  const BottomHintItem({
    required this.id,
    required this.label,
    this.badgeText,
    this.badgeIcon,
    this.accentColor,
  }) : assert(
         (badgeText == null) != (badgeIcon == null),
         'Provide exactly one of badgeText or badgeIcon',
       );

  final String id;
  final String label;
  final String? badgeText;
  final IconData? badgeIcon;

  /// Fill color of the badge. `null` renders the neutral dark badge used for
  /// navigation hints such as back or menu.
  final Color? accentColor;
}

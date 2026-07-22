import 'package:flutter/material.dart';

class NavActionItem {
  const NavActionItem({
    required this.label,
    required this.icon,
    this.badgeCount,
    this.isHighlighted = false,
  });

  final String label;
  final IconData icon;
  final int? badgeCount;
  final bool isHighlighted;
}

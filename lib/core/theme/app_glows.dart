import 'package:flutter/material.dart';

abstract final class AppGlows {
  /// Outer bloom around the large source cards.
  static List<BoxShadow> card(Color color, {bool focused = false}) {
    if (!focused) {
      return [BoxShadow(color: color.withValues(alpha: 0.10), blurRadius: 26)];
    }

    return [
      BoxShadow(
        color: color.withValues(alpha: 0.55),
        blurRadius: 34,
        spreadRadius: 1,
      ),
      BoxShadow(color: color.withValues(alpha: 0.22), blurRadius: 90),
    ];
  }

  /// Focus/active bloom for smaller controls, tiles, and list rows.
  static List<BoxShadow> control(Color color, {bool focused = false}) {
    if (!focused) {
      return const [];
    }

    return [BoxShadow(color: color.withValues(alpha: 0.32), blurRadius: 18)];
  }

  /// Short accent bar rendered under each source card.
  static List<BoxShadow> bar(Color color) {
    return [
      BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 14),
      BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 28),
    ];
  }
}

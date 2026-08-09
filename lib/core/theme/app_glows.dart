import 'package:flutter/material.dart';

abstract final class AppGlows {
  /// Outer bloom around the large source cards.
  static List<BoxShadow> card(Color color, {bool focused = false}) {
    if (!focused) {
      return [BoxShadow(color: color.withValues(alpha: 0.07), blurRadius: 14)];
    }

    // Single, modest-radius bloom. A large second pass (blurRadius 38) was
    // dropped: on a 2GB/1-core box a wide gaussian shadow is costly to
    // rasterize, and it is redundant once the card sits on its own layer.
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.42),
        blurRadius: 16,
        spreadRadius: 1,
      ),
    ];
  }

  /// Focus/active bloom for smaller controls, tiles, and list rows.
  static List<BoxShadow> control(Color color, {bool focused = false}) {
    if (!focused) {
      return const [];
    }

    return [BoxShadow(color: color.withValues(alpha: 0.24), blurRadius: 10)];
  }

  /// Short accent bar rendered under each source card.
  static List<BoxShadow> bar(Color color) {
    return [
      BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8),
      BoxShadow(color: color.withValues(alpha: 0.22), blurRadius: 14),
    ];
  }
}

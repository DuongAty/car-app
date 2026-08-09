import 'package:flutter/widgets.dart';

abstract final class AppMotion {
  static const Duration instant = Duration.zero;
  static const Duration focus = Duration(milliseconds: 140);
  static const Duration control = Duration(milliseconds: 160);
  static const Duration panel = Duration(milliseconds: 220);
  static const Duration standard = Duration(milliseconds: 300);

  /// Page/route transition duration. A light 220ms fade — no slide, so no
  /// full-screen relayout — kept short for the 2GB box.
  static const Duration route = Duration(milliseconds: 220);

  static const Curve standardCurve = Curves.easeOutCubic;
}

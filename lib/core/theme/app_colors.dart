import 'package:flutter/material.dart';

abstract final class AppColors {
  // Surfaces. The reference design uses a neutral near-black stack, not a
  // blue-tinted navy, so panels read as floating dark glass over pure black.
  static const Color background = Color(0xFF050506);
  static const Color backgroundSecondary = Color(0xFF0A0A0C);
  static const Color panel = Color(0xFF0E0F11);
  static const Color panelStrong = Color(0xFF141518);
  static const Color panelBorder = Color(0xFF212227);
  static const Color panelBorderSoft = Color(0xFF1A1B1F);
  static const Color keyFill = Color(0xFF2A2B2F);

  // Text.
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9BA1A8);
  static const Color textMuted = Color(0xFF6B7076);

  // Brand accents.
  static const Color green = Color(0xFF22C55E);
  static const Color greenDeep = Color(0xFF16A34A);
  static const Color greenSoft = Color(0xFF0E2A18);
  static const Color red = Color(0xFFE11D2E);
  static const Color youtubeRed = Color(0xFFFF0033);
  static const Color orange = Color(0xFFFF5500);
  static const Color fire = Color(0xFFFF7A18);
  static const Color purple = Color(0xFFA855F7);
  static const Color blue = Color(0xFF3B82F6);
  static const Color yellow = Color(0xFFFACC15);

  // Glass surfaces. Panels are translucent tinted glass rather than solid
  // fills, so the background aurora reads through them.
  static const Color glassBorder = Color(0x24FFFFFF);
  static const Color glassBorderStrong = Color(0x3DFFFFFF);
  static const Color glassHighlight = Color(0x59FFFFFF);

  // Overlays.
  static const Color white08 = Color(0x14FFFFFF);
  static const Color white10 = Color(0x1AFFFFFF);
  static const Color white20 = Color(0x33FFFFFF);
  static const Color black40 = Color(0x66000000);
  static const Color black70 = Color(0xB3000000);
}

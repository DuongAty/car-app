import 'dart:math' as math;

///
/// Layout metrics for the karaoke neon screens.
///
/// Values are upper-bound targets for large landscape displays. Screens should
/// derive final dimensions from their own constraints and clamp toward these
/// targets instead of assuming one fixed display size.
abstract final class AppLayout {
  static const double referenceWidth = 1920;
  static const double referenceHeight = 1080;
  static const double designWidth = referenceWidth;
  static const double designHeight = referenceHeight;

  // The UI is primarily used in landscape. Below these logical dimensions we
  // keep a complete landscape canvas and scale it into the available display
  // instead of letting individual fixed-size controls overflow.
  static const double minimumLandscapeWidth = 1366;
  static const double minimumLandscapeHeight = 768;

  static const double shellPaddingHorizontal = 56;
  static const double shellPaddingTop = 30;
  static const double shellPaddingBottom = 26;
  static const double shellBodyGap = 24;
  static const double shellBottomGap = 20;
  static const double bottomBarHeight = 86;

  // Source selection.
  static const double sourceCardWidth = 460;
  static const double sourceCardHeight = 520;
  static const double sourceRowGap = 44;
  static const double sourceHeadlineTopSpace = 66;
  static const double sourceHeadlineGap = 14;
  static const double sourceCardsTopGap = 48;
  static const double sourceAccentBarGap = 22;
  static const double sourceAccentBarWidth = 44;
  static const double sourceAccentBarHeight = 5;

  // Song browser.
  static const double browserLeftPanelWidth = 390;
  static const double browserRightPanelWidth = 540;
  static const double browserSuggestionTileHeight = 90;
  static const double browserResultTileHeight = 88;
  static const double browserColumnGap = 32;
  static const double browserPreviewHeight = 440;
  static const double browserPreviewControlsHeight = 86;
  static const double browserSectionGap = 20;
  static const double browserInputPanelHeight = 320;
  static const double browserSearchHeight = 72;
  static const double browserKeyRowGap = 10;
  static const double browserKeyHeight = 53;
  static const double browserKeyGap = 8;

  // Top navigation.
  static const double topIconBoxSize = 62;
  static const double topIconSlotWidth = 112;
  static const double topNavItemHeight = 78;

  static double shellHorizontalPaddingFor(double width) =>
      math.max(16, math.min(shellPaddingHorizontal, width * 0.035));

  static double shellTopPaddingFor(double height) =>
      math.max(10, math.min(shellPaddingTop, height * 0.035));

  static double shellBottomPaddingFor(double height) =>
      math.max(10, math.min(shellPaddingBottom, height * 0.03));

  static double shellBodyGapFor(double height) =>
      math.max(10, math.min(shellBodyGap, height * 0.025));

  static double shellBottomGapFor(double height) =>
      math.max(8, math.min(shellBottomGap, height * 0.02));
}

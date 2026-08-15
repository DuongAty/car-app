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

  // Left navigation rail. The rail replaced the old top nav + bottom hint bar
  // so the body — and therefore the video stage — keeps the full screen height.
  // Width is deliberately narrow: on a car screen every pixel it takes is a
  // pixel the video loses. It is sized to the longest destination label plus a
  // small gutter — measured on device, the widest is EN "CATEGORIES" at ~80 —
  // NOT to a round number. Growing it wastes stage width; shrinking it below
  // ~92 starts ellipsizing that label. This is the rail's own width: the gaps
  // around it are [navRailInset] and sit outside it.
  static const double navRailWidth = 104;
  static const double navRailItemHeight = 64;

  /// The one gap on screen when the rail is up. It is the shell's margin on all
  /// four sides AND the gap between the rail and the body, so the selected
  /// destination's plate is framed by the same hairline everywhere. Deliberately
  /// small — just enough to read as a gap, not enough to cost the stage width.
  ///
  /// There is no second, rail-local inset: change this and every margin moves
  /// together.
  static const double navRailInset = 10;
  static const double navRailIconSize = 26;

  /// Height of the vertical track in the rail's volume popup. It floats over
  /// the content rather than sitting in the rail, so it is free to be long
  /// enough to drag precisely.
  static const double navRailVolumeTrackHeight = 150;
  static const double navRailIndicatorWidth = 4;
  static const double navRailIndicatorHeight = 26;

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

  static double shellHorizontalPaddingFor(double width) =>
      math.max(16, math.min(shellPaddingHorizontal, width * 0.035));

  static double shellTopPaddingFor(double height) =>
      math.max(10, math.min(shellPaddingTop, height * 0.035));

  static double shellBottomPaddingFor(double height) =>
      math.max(10, math.min(shellPaddingBottom, height * 0.03));

  /// Rail width for the available shell width. It gives up a little of its
  /// width on narrow head units rather than squeezing the stage further, and
  /// never grows past [navRailWidth] on a large TV — extra width there belongs
  /// to the stage, not to seven short labels.
  static double navRailWidthFor(double width) =>
      math.max(96, math.min(navRailWidth, width * 0.08));
}

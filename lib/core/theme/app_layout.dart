/// Layout metrics for the karaoke neon screens.
///
/// The screens are composed against a fixed 1920x1080 design canvas and scaled
/// to fit the device in [KaraokeShell], so these values are absolute design
/// pixels rather than device pixels.
abstract final class AppLayout {
  static const double designWidth = 1920;
  static const double designHeight = 1080;

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
  static const double browserPreviewControlsHeight = 96;
  static const double browserSectionGap = 20;
  static const double browserInputPanelHeight = 360;
  static const double browserSearchHeight = 72;
  static const double browserKeyRowGap = 10;
  static const double browserKeyHeight = 53;
  static const double browserKeyGap = 8;

  // Top navigation.
  static const double topIconBoxSize = 62;
  static const double topIconSlotWidth = 112;
  static const double topNavItemHeight = 78;
}

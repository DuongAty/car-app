import 'package:viet_ktv/l10n/app_localizations.dart';

import '../../../../core/models/nav_action_item.dart';
import '../../../../core/theme/app_icons.dart';
import '../models/song_item.dart';

abstract final class SongBrowserMockData {
  // Non-character keys carry a token instead of the glyph they type.
  static const String keyBackspace = 'BACK';
  static const String keySearch = 'TIM';
  static const String keySpace = 'SPACE';
  static const String keyClear = 'CLEAR';
  static const String keyNumbers = '123';

  /// Position of "TRANG CHỦ" in [topActions] — tapping it returns to the
  /// source-selection home screen instead of toggling a tab.
  static const int homeTabIndex = 0;

  /// Position of "TÌM BÀI" in [topActions] — the default active tab showing
  /// search + keyboard.
  static const int searchTabIndex = 1;

  /// Position of "DANH MỤC" in [topActions] — swaps the left column to
  /// a category browser and hides the on-screen keyboard.
  static const int categoryTabIndex = 2;

  /// Position of "ĐÃ CHỌN" in [topActions] — tapping it navigates to the
  /// queue screen instead of just toggling the highlighted tab.
  static const int selectedTabIndex = 3;

  /// Position of "CÀI ĐẶT" in [topActions] — tapping it navigates to the
  /// settings screen instead of just toggling the highlighted tab.
  static const int settingsTabIndex = 4;

  /// Position of "THOÁT" in [topActions] — tapping it closes the app.
  static const int exitTabIndex = 5;

  static List<NavActionItem> topActions(
    AppLocalizations l10n,
    int queueCount,
  ) => [
    NavActionItem(label: l10n.topHome, icon: AppIcons.home),
    NavActionItem(label: l10n.songSearch, icon: AppIcons.search),
    NavActionItem(label: l10n.songList, icon: AppIcons.categoryGrid),
    NavActionItem(
      label: l10n.songSelected,
      icon: AppIcons.selectedQueue,
      badgeCount: queueCount > 0 ? queueCount : null,
    ),
    NavActionItem(label: l10n.topSettings, icon: AppIcons.settings),
    NavActionItem(label: l10n.topExit, icon: AppIcons.power),
  ];

  static List<SongItem> searchResults(AppLocalizations l10n) => [
    SongItem(
      id: '9',
      title: 'Lạc Trôi - Sơn Tùng M-TP (Karaoke)',
      subtitle: l10n.mockYoutubeChannel,
      duration: '4:32',
      thumbnailSeed: 9,
      badge: null,
    ),
    SongItem(
      id: '10',
      title: 'Lạc Trôi - Sơn Tùng M-TP (Official MV)',
      subtitle: l10n.mockOfficialChannel,
      duration: '4:35',
      thumbnailSeed: 10,
      badge: null,
    ),
    SongItem(
      id: '11',
      title: 'Lạc Trôi - Sơn Tùng M-TP | Beat Chuẩn',
      subtitle: l10n.mockBeatChannel,
      duration: '4:31',
      thumbnailSeed: 11,
      badge: null,
    ),
    SongItem(
      id: '12',
      title: 'Lạc Trôi - Sơn Tùng M-TP (Tone Nam)',
      subtitle: l10n.mockToneNam,
      duration: '4:29',
      thumbnailSeed: 12,
      badge: null,
    ),
    SongItem(
      id: '13',
      title: 'Lạc Trôi - Sơn Tùng M-TP (Đại Mèo Remix)',
      subtitle: l10n.mockDjRemix,
      duration: '5:18',
      thumbnailSeed: 13,
      badge: null,
    ),
    SongItem(
      id: '14',
      title: 'Lạc Trôi - Sơn Tùng M-TP (Acoustic)',
      subtitle: l10n.mockAcoustic,
      duration: '4:40',
      thumbnailSeed: 14,
      badge: null,
    ),
    SongItem(
      id: '15',
      title: 'Lạc Trôi - Sơn Tùng M-TP (Live)',
      subtitle: l10n.mockLive,
      duration: '4:50',
      thumbnailSeed: 15,
      badge: null,
    ),
    SongItem(
      id: '16',
      title: 'Lạc Trôi - Sơn Tùng M-TP (Piano Ver.)',
      subtitle: l10n.mockPiano,
      duration: '4:12',
      thumbnailSeed: 16,
      badge: null,
    ),
  ];

  static const List<List<String>> keyboardRows = [
    [
      'A',
      'B',
      'C',
      'D',
      'E',
      'F',
      'G',
      'H',
      'I',
      'J',
      'K',
      'L',
      'M',
      keyBackspace,
    ],
    ['N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'],
    ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0', keySearch],
    [keySpace, keyClear, keyNumbers],
  ];

  static String keyboardLabel(AppLocalizations l10n, String key) {
    return switch (key) {
      keySearch => l10n.keyboardSearch,
      keyClear => l10n.keyboardClear,
      keySpace => l10n.keyboardSpace,
      keyNumbers => l10n.keyboardNumberMode,
      _ => key,
    };
  }
}

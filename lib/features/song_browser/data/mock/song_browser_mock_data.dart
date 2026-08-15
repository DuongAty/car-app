import 'package:viet_ktv/l10n/app_localizations.dart';

import '../models/song_item.dart';

abstract final class SongBrowserMockData {
  // Non-character keys carry a token instead of the glyph they type.
  static const String keyBackspace = 'BACK';
  static const String keySearch = 'TIM';
  static const String keySpace = 'SPACE';
  static const String keyClear = 'CLEAR';
  static const String keyNumbers = '123';

  /// Index of the search tab in the song browser's own tab state — the rail's
  /// "TÌM BÀI" destination selects it.
  static const int searchTabIndex = 1;

  /// Index of the category tab, selected by the rail's "DANH MỤC".
  static const int categoryTabIndex = 2;

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

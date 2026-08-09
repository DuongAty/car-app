import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/core/services/music_sdk_platform.dart';
import 'package:viet_ktv/core/theme/app_colors.dart';
import 'package:viet_ktv/features/playback/data/audio_track_player.dart';
import 'package:viet_ktv/features/song_browser/presentation/pages/song_browser_page.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/music_sdk_repository_provider.dart';
import 'package:viet_ktv/features/song_browser/presentation/widgets/category_grid_panel.dart';
import 'package:viet_ktv/features/song_browser/presentation/widgets/preview_player.dart';
import 'package:viet_ktv/features/source_selection/data/models/music_source.dart';
import 'package:viet_ktv/l10n/app_localizations.dart';
import 'package:viet_ktv/routes/app_router.dart';

import 'support/fake_audio_track_player.dart';
import 'support/fake_local_storage_service.dart';
import 'support/fake_music_sdk_platform.dart';
import 'support/fake_video_player_platform.dart';

const _source = MusicSource(
  id: 'youtube',
  subtitle: 'Kho nhạc & Video\nkhổng lồ',
  accentColor: AppColors.red,
  logoStyle: MusicSourceLogoStyle.youtube,
);

Future<void> _pumpBrowser(
  WidgetTester tester, {
  MusicSdkPlatform? platform,
}) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        musicSdkPlatformProvider.overrideWithValue(
          platform ?? FakeMusicSdkPlatform(),
        ),
        audioTrackPlayerFactoryProvider.overrideWithValue(
          FakeAudioTrackPlayer.new,
        ),
        localStorageServiceProvider.overrideWithValue(
          FakeLocalStorageService(),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('vi'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: const SongBrowserPage(source: _source),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    VideoPlayerPlatform.instance = FakeVideoPlayerPlatform();
  });

  testWidgets('danh_sach_tab_shows_categories_instead_of_search_panel', (
    tester,
  ) async {
    await _pumpBrowser(tester);

    expect(find.byType(CategoryGridPanel), findsNothing);

    await tester.tap(find.text('DANH MỤC'));
    await tester.pumpAndSettle();

    expect(find.byType(CategoryGridPanel), findsOneWidget);
    expect(find.byType(PreviewPlayer), findsNothing);
    expect(find.text('Thể loại'), findsOneWidget);
    expect(find.text('Nghệ sĩ'), findsOneWidget);
  });

  testWidgets('danh_sach_tab_from_selected_queue_opens_category_browser', (
    tester,
  ) async {
    await _pumpBrowser(tester);

    await tester.tap(find.text('ĐÃ CHỌN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DANH MỤC'));
    await tester.pumpAndSettle();

    expect(find.byType(CategoryGridPanel), findsOneWidget);
    expect(find.byType(PreviewPlayer), findsNothing);
  });

  testWidgets('tapping_a_category_runs_a_search_for_it', (tester) async {
    final platform = FakeMusicSdkPlatform();
    await _pumpBrowser(tester, platform: platform);

    await tester.tap(find.text('DANH MỤC'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bolero / Trữ tình'));
    await tester.pumpAndSettle();

    expect(platform.lastSearchQuery, 'bolero trữ tình');
  });

  testWidgets('artist_tabs_search_songs_by_selected_artist', (tester) async {
    final platform = FakeMusicSdkPlatform();
    await _pumpBrowser(tester, platform: platform);

    await tester.tap(find.text('DANH MỤC'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nghệ sĩ'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sơn Tùng M-TP'));
    await tester.pumpAndSettle();
    expect(platform.lastSearchQuery, 'Sơn Tùng M-TP');

    await tester.tap(find.text('Nước ngoài'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Taylor Swift'));
    await tester.pumpAndSettle();
    expect(platform.lastSearchQuery, 'Taylor Swift');
  });
}

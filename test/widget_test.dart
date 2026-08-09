import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/core/services/local_storage_service.dart';
import 'package:viet_ktv/core/theme/app_icons.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:viet_ktv/app.dart';
import 'package:viet_ktv/core/services/music_sdk_platform.dart';
import 'package:viet_ktv/core/shared/widgets/neon_skeleton.dart';
import 'package:viet_ktv/core/theme/app_colors.dart';
import 'package:viet_ktv/features/license/data/models/license_rpc_result.dart';
import 'package:viet_ktv/features/license/presentation/providers/license_controller.dart';
import 'package:viet_ktv/features/playback/data/audio_track_player.dart';
import 'package:viet_ktv/features/settings/data/models/app_settings.dart';
import 'package:viet_ktv/features/song_browser/data/models/song_item.dart';
import 'package:viet_ktv/features/song_browser/presentation/pages/song_browser_page.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/music_sdk_repository_provider.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/song_browser_provider.dart';
import 'package:viet_ktv/features/song_browser/presentation/widgets/preview_player.dart';
import 'package:viet_ktv/features/song_browser/presentation/widgets/search_result_tile.dart';
import 'package:viet_ktv/features/song_browser/presentation/widgets/search_results_panel.dart';
import 'package:viet_ktv/features/source_selection/data/models/music_source.dart';
import 'package:viet_ktv/l10n/app_localizations.dart';

import 'support/fake_license_repository.dart';
import 'support/fake_music_sdk_platform.dart';
import 'support/fake_audio_track_player.dart';
import 'support/fake_local_storage_service.dart';
import 'support/fake_video_player_platform.dart';

/// A device that already has a valid, server-confirmed key bound to it, so
/// the license gate unlocks immediately instead of showing the key input
/// screen — used by tests that only care about what's past the gate.
List<Override> _unlockedLicenseOverrides() {
  final storage = FakeLocalStorageService()
    ..store['license_key_code_v1'] = 'TEST-KEY-0000';
  return [
    localStorageServiceProvider.overrideWithValue(storage),
    licenseRepositoryProvider.overrideWithValue(
      FakeLicenseRepository(checkResult: LicenseRpcResult.activeSelf),
    ),
  ];
}

const _source = MusicSource(
  id: 'youtube',
  subtitle: 'Kho nhạc & Video\nkhổng lồ',
  accentColor: AppColors.red,
  logoStyle: MusicSourceLogoStyle.youtube,
);

const _soundCloudSource = MusicSource(
  id: 'soundcloud',
  subtitle: 'Nháº¡c audio\nremix',
  accentColor: AppColors.orange,
  logoStyle: MusicSourceLogoStyle.soundcloud,
);

Future<void> _pumpSongBrowser(
  WidgetTester tester, {
  MusicSdkPlatform? musicSdkPlatform,
  MusicSource source = _source,
  AudioTrackPlayerFactory audioPlayerFactory = FakeAudioTrackPlayer.new,
  LocalStorageService? localStorage,
  Size viewport = const Size(1920, 1080),
}) async {
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        musicSdkPlatformProvider.overrideWithValue(
          musicSdkPlatform ?? FakeMusicSdkPlatform(),
        ),
        audioTrackPlayerFactoryProvider.overrideWithValue(audioPlayerFactory),
        localStorageServiceProvider.overrideWithValue(
          localStorage ?? FakeLocalStorageService(),
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
        home: SongBrowserPage(source: source),
      ),
    ),
  );
  // Recommendations kick off a real search as soon as the controller is
  // constructed; let that resolve so tests see a stable state instead of
  // racing a bare pumpWidget against it.
  await tester.pumpAndSettle();
}

/// Types into the native Android field, then sends its search/Enter action.
Future<void> _search(WidgetTester tester, String query) async {
  await tester.enterText(
    find.byKey(const ValueKey('songBrowserNativeSearchField')),
    query,
  );
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pumpAndSettle();
}

/// Two taps close enough together to register as a double tap: past
/// [kDoubleTapMinTime] but within [kDoubleTapTimeout].
Future<void> _doubleTapAt(WidgetTester tester, Offset position) async {
  await tester.tapAt(position);
  await tester.pump(const Duration(milliseconds: 60));
  await tester.tapAt(position);
  await tester.pumpAndSettle();
}

/// A point inside the picture, clear of the badge in the top-right corner and
/// the lyrics along the bottom.
Offset _videoPoint(WidgetTester tester) {
  final player = tester.getRect(find.byType(PreviewPlayer));
  return Offset(player.center.dx, player.top + 60);
}

void main() {
  setUpAll(() {
    VideoPlayerPlatform.instance = FakeVideoPlayerPlatform();
  });

  testWidgets('shows_both_music_sources', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: _unlockedLicenseOverrides(),
        child: const VietKtvApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    await tester.pump();

    expect(find.text('YouTube'), findsOneWidget);
    expect(find.text('SOUNDCLOUD'), findsOneWidget);
  });

  testWidgets('shows_native_search_field_at_rest', (tester) async {
    await _pumpSongBrowser(tester);

    expect(
      find.byKey(const ValueKey('songBrowserNativeSearchField')),
      findsOneWidget,
    );
    expect(find.text('DẤU CÁCH'), findsNothing);
  });

  testWidgets('shows_idle_prompt_before_any_search', (tester) async {
    await _pumpSongBrowser(tester);

    expect(find.text('Nhập từ khóa rồi bấm TÌM để tìm kiếm'), findsOneWidget);
  });

  testWidgets('searches_the_real_api_when_tim_is_pressed', (tester) async {
    final platform = FakeMusicSdkPlatform();
    await _pumpSongBrowser(tester, musicSdkPlatform: platform);

    await _search(tester, 'OFFICIAL');

    expect(platform.lastSearchQuery, 'OFFICIAL');
    expect(find.text('1 kết quả'), findsOneWidget);
    expect(find.text('Lạc Trôi - Sơn Tùng M-TP (Official MV)'), findsOneWidget);
  });

  testWidgets('shows_no_results_message_for_an_unmatched_query', (
    tester,
  ) async {
    await _pumpSongBrowser(tester);

    await _search(tester, 'Z');

    expect(find.text('0 kết quả'), findsOneWidget);
    expect(find.text('Không có kết quả phù hợp'), findsOneWidget);
  });

  testWidgets('clearing_the_query_returns_to_the_idle_prompt', (tester) async {
    await _pumpSongBrowser(tester);

    await _search(tester, 'Z');
    expect(find.text('0 kết quả'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('songBrowserNativeSearchField')),
      '',
    );
    await tester.pumpAndSettle();

    expect(find.text('Nhập từ khóa rồi bấm TÌM để tìm kiếm'), findsOneWidget);
  });

  testWidgets('clearing_the_native_field_returns_to_the_idle_prompt', (
    tester,
  ) async {
    await _pumpSongBrowser(tester);

    await _search(tester, 'AB');
    await tester.enterText(
      find.byKey(const ValueKey('songBrowserNativeSearchField')),
      '',
    );
    await tester.pumpAndSettle();

    expect(find.text('Tìm bài hát, ca sĩ hoặc từ khóa...'), findsOneWidget);
  });

  testWidgets('shows_an_error_message_when_the_search_call_fails', (
    tester,
  ) async {
    await _pumpSongBrowser(
      tester,
      musicSdkPlatform: FakeMusicSdkPlatform(failSearch: true),
    );

    await _search(tester, 'OFFICIAL');

    expect(find.text('Không tải được kết quả. Thử lại.'), findsOneWidget);
  });

  testWidgets('renders_network_thumbnail_for_search_results_with_image_url', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(
            FakeLocalStorageService(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SearchResultTile(
              item: const SongItem(
                id: 'yt-1',
                title: 'Có Chắc Yêu Là Đây',
                subtitle: 'YouTube',
                duration: '03:55',
                thumbnailSeed: 1,
                imageUrl: 'https://img.example/yt-1.jpg',
                badge: null,
              ),
              selected: false,
              onPressed: () {},
              onAdd: () {},
              source: MusicSourceLogoStyle.youtube,
            ),
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final resized = image.image as ResizeImage;
    final networkImage = resized.imageProvider as NetworkImage;

    expect(image.image, isA<ResizeImage>());
    expect(networkImage.url, 'https://img.example/yt-1.jpg');
  });

  testWidgets('tapping_the_heart_toggles_favorite_icon', (tester) async {
    // The heart now reads/writes the shared favorites controller rather than
    // local widget state, so the tile only needs a ProviderScope around it.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(
            FakeLocalStorageService(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SearchResultTile(
              item: const SongItem(
                id: 'yt-1',
                title: 'Có Chắc Yêu Là Đây',
                subtitle: 'YouTube',
                duration: '03:55',
                thumbnailSeed: 1,
                badge: null,
              ),
              selected: false,
              onPressed: () {},
              onAdd: () {},
              source: MusicSourceLogoStyle.youtube,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(AppIcons.favoriteOutline), findsOneWidget);

    await tester.tap(find.byIcon(AppIcons.favoriteOutline));
    await tester.pump();

    expect(find.byIcon(AppIcons.favorite), findsOneWidget);
  });

  testWidgets('centers_search_loading_state_inside_results_panel', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('vi'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 520,
              child: SearchResultsPanel(
                search: const SearchLoading(),
                selectedIndex: 0,
                onSelected: (_) {},
                onPlay: (_) {},
                onAdd: (_) {},
                source: MusicSourceLogoStyle.youtube,
              ),
            ),
          ),
        ),
      ),
    );

    final panel = tester.getRect(find.byType(SearchResultsPanel));
    final loader = tester.getRect(find.byType(NeonSkeletonList));
    final label = tester.getRect(find.text('Đang tìm kiếm...'));

    expect(loader.center.dx, closeTo(panel.center.dx, 1));
    expect(label.center.dx, closeTo(panel.center.dx, 1));
  });

  testWidgets('resolves_a_playable_link_when_a_search_result_is_played', (
    tester,
  ) async {
    final platform = FakeMusicSdkPlatform();
    await _pumpSongBrowser(tester, musicSdkPlatform: platform);

    expect(find.text('Chọn một bài hát để bắt đầu'), findsOneWidget);

    await _search(tester, 'OFFICIAL');
    await tester.tap(find.text('Lạc Trôi - Sơn Tùng M-TP (Official MV)'));
    // Not pumpAndSettle: once the fake video starts "playing", VideoPlayer's
    // own 100ms position timer runs indefinitely and would time it out.
    // A few bounded pumps are enough to walk the request through
    // getPlayableLink -> VideoPlayerController.initialize() -> first frame.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(platform.lastPlayableLinkTrackId, '10');
    final player = tester.widget<VideoPlayer>(find.byType(VideoPlayer));
    expect(player.controller.videoPlayerOptions?.mixWithOthers, isFalse);
    expect(tester.takeException(), isNull);

    // A playing video keeps a 100ms position Timer alive; unmount the tree so
    // PreviewPlayer disposes its controller and cancels it before the test
    // ends, or flutter_test fails on a pending timer.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('soundcloud_playback_displays_looping_visualizer_asset', (
    tester,
  ) async {
    final platform = FakeMusicSdkPlatform();
    final storage = FakeLocalStorageService()
      ..store['app_settings_v1'] = const AppSettings(
        visualizerEnabled: true,
      ).encode();
    await _pumpSongBrowser(
      tester,
      musicSdkPlatform: platform,
      source: _soundCloudSource,
      localStorage: storage,
    );

    await _search(tester, 'KARAOKE');
    await tester.tap(find.text('Lạc Trôi - Sơn Tùng M-TP (Karaoke)'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(platform.lastPlayableLinkTrackId, '9');
    final player = tester.widget<VideoPlayer>(find.byType(VideoPlayer));
    expect(
      player.controller.dataSource,
      startsWith('assets/visualizer_light/'),
    );
    expect(player.controller.value.isLooping, isTrue);
    expect(player.controller.videoPlayerOptions?.mixWithOthers, isTrue);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('disabled_visualizer_does_not_create_audio_source_video', (
    tester,
  ) async {
    final storage = FakeLocalStorageService()
      ..store['app_settings_v1'] = const AppSettings(
        visualizerEnabled: false,
      ).encode();
    await _pumpSongBrowser(
      tester,
      musicSdkPlatform: FakeMusicSdkPlatform(),
      source: _soundCloudSource,
      localStorage: storage,
    );

    await _search(tester, 'KARAOKE');
    await tester.tap(find.text('Lạc Trôi - Sơn Tùng M-TP (Karaoke)'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(find.byType(VideoPlayer), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('soundcloud_audio_starts_when_visualizer_asset_is_slow', (
    tester,
  ) async {
    VideoPlayerPlatform.instance = FakeVideoPlayerPlatform(
      hangAssetInitialization: true,
    );
    addTearDown(() {
      VideoPlayerPlatform.instance = FakeVideoPlayerPlatform();
    });

    final platform = FakeMusicSdkPlatform();
    final storage = FakeLocalStorageService()
      ..store['app_settings_v1'] = const AppSettings(
        visualizerEnabled: true,
      ).encode();
    await _pumpSongBrowser(
      tester,
      musicSdkPlatform: platform,
      source: _soundCloudSource,
      localStorage: storage,
    );

    await _search(tester, 'KARAOKE');
    await tester.tap(find.text('Lạc Trôi - Sơn Tùng M-TP (Karaoke)'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(platform.lastPlayableLinkTrackId, '9');
    expect(find.text('Đang tải video...'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('in_app_transport_controls_audio_and_visualizer_together', (
    tester,
  ) async {
    final videoPlatform = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = videoPlatform;
    addTearDown(() {
      VideoPlayerPlatform.instance = FakeVideoPlayerPlatform();
    });

    late FakeAudioTrackPlayer audioPlayer;
    final storage = FakeLocalStorageService()
      ..store['app_settings_v1'] = const AppSettings(
        visualizerEnabled: true,
      ).encode();
    await _pumpSongBrowser(
      tester,
      musicSdkPlatform: FakeMusicSdkPlatform(),
      source: _soundCloudSource,
      audioPlayerFactory: () => audioPlayer = FakeAudioTrackPlayer(),
      localStorage: storage,
    );

    await _search(tester, 'KARAOKE');
    await tester.tap(find.text('Lạc Trôi - Sơn Tùng M-TP (Karaoke)'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(audioPlayer.playCallCount, 1);
    expect(videoPlatform.playCallCount, 1);

    final videoPauseCount = videoPlatform.pauseCallCount;
    await tester.tap(find.byIcon(AppIcons.pause));
    await tester.pump();

    expect(audioPlayer.pauseCallCount, 1);
    expect(videoPlatform.pauseCallCount, videoPauseCount + 1);

    final videoPlayCount = videoPlatform.playCallCount;
    await tester.tap(find.byIcon(AppIcons.play));
    await tester.pump();

    expect(audioPlayer.playCallCount, 2);
    expect(videoPlatform.playCallCount, videoPlayCount + 1);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('shows_an_error_message_when_the_link_lookup_fails', (
    tester,
  ) async {
    await _pumpSongBrowser(
      tester,
      musicSdkPlatform: FakeMusicSdkPlatform(failLink: true),
    );

    await _search(tester, 'OFFICIAL');
    await tester.tap(find.text('Lạc Trôi - Sơn Tùng M-TP (Official MV)'));
    await tester.pumpAndSettle();

    expect(find.text('Không phát được video này.'), findsOneWidget);
  });

  testWidgets('rewind_button_seeks_the_video_back_ten_seconds', (tester) async {
    final videoPlatform = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = videoPlatform;
    addTearDown(() {
      VideoPlayerPlatform.instance = FakeVideoPlayerPlatform();
    });

    await _pumpSongBrowser(tester);

    await _search(tester, 'OFFICIAL');
    await tester.tap(find.text('Lạc Trôi - Sơn Tùng M-TP (Official MV)'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    await tester.tap(find.byIcon(AppIcons.rewind));
    await tester.pump();

    expect(videoPlatform.lastSeekPosition, isNotNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('adding_to_queue_does_not_also_trigger_playback', (tester) async {
    final platform = FakeMusicSdkPlatform();
    await _pumpSongBrowser(tester, musicSdkPlatform: platform);
    await _search(tester, 'OFFICIAL');

    await tester.tap(find.byIcon(AppIcons.add));
    await tester.pumpAndSettle();

    expect(platform.lastPlayableLinkTrackId, isNull);
    expect(find.text('Chọn một bài hát để bắt đầu'), findsOneWidget);
  });

  testWidgets('keeps_native_search_field_visible', (tester) async {
    await _pumpSongBrowser(tester);

    final field = tester.getRect(
      find.byKey(const ValueKey('songBrowserNativeSearchField')),
    );
    expect(field.width, greaterThan(0));
    expect(field.height, greaterThan(0));
  });

  testWidgets('keeps_layout_within_bounds_on_small_viewport', (tester) async {
    tester.view.physicalSize = const Size(720, 405);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: _unlockedLicenseOverrides(),
        child: const VietKtvApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('expands_player_over_the_search_panel', (tester) async {
    await _pumpSongBrowser(tester);

    final collapsedPlayer = tester.getRect(find.byType(PreviewPlayer));

    await tester.tap(find.byIcon(AppIcons.fullscreen));
    await tester.pumpAndSettle();

    final expandedPlayer = tester.getRect(find.byType(PreviewPlayer));
    expect(expandedPlayer.width, greaterThan(collapsedPlayer.width));
    expect(find.byIcon(AppIcons.fullscreenExit), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('toggles_expanded_on_double_tap_over_video', (tester) async {
    await _pumpSongBrowser(tester);

    final collapsed = tester.getRect(find.byType(PreviewPlayer));

    await _doubleTapAt(tester, _videoPoint(tester));
    expect(
      tester.getRect(find.byType(PreviewPlayer)).width,
      greaterThan(collapsed.width),
    );

    await _doubleTapAt(tester, _videoPoint(tester));
    expect(tester.getRect(find.byType(PreviewPlayer)), collapsed);
  });

  testWidgets('ignores_double_tap_on_transport_controls', (tester) async {
    await _pumpSongBrowser(tester);

    final collapsed = tester.getRect(find.byType(PreviewPlayer));

    // Double-tapping a control must not resize the screen underneath.
    await _doubleTapAt(tester, tester.getCenter(find.byIcon(AppIcons.rewind)));

    expect(tester.getRect(find.byType(PreviewPlayer)), collapsed);
  });

  testWidgets('collapses_without_overflow_mid_animation', (tester) async {
    await _pumpSongBrowser(tester);

    await tester.tap(find.byIcon(AppIcons.fullscreen));
    await tester.pump();

    // Step through the collapse. Panels shrink to zero here, so a naive
    // implementation would squash its contents and overflow along the way.
    for (var elapsed = 0; elapsed < 300; elapsed += 30) {
      await tester.pump(const Duration(milliseconds: 30));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('restores_panels_when_leaving_expanded_mode', (tester) async {
    await _pumpSongBrowser(tester);

    final original = tester.getRect(find.byType(PreviewPlayer));

    await tester.tap(find.byIcon(AppIcons.fullscreen));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(AppIcons.fullscreenExit));
    await tester.pumpAndSettle();

    expect(tester.getRect(find.byType(PreviewPlayer)), original);
  });

  testWidgets('keeps_hidden_panels_out_of_focus_when_expanded', (tester) async {
    await _pumpSongBrowser(tester);

    await tester.tap(find.byIcon(AppIcons.fullscreen));
    await tester.pumpAndSettle();

    // Collapsed panels stay in the tree, so they must be excluded from D-pad
    // traversal or focus would walk into rows the user cannot see.
    for (final panel in [find.byType(SearchResultsPanel)]) {
      final guard = tester.widget<ExcludeFocus>(
        find.ancestor(of: panel, matching: find.byType(ExcludeFocus)).first,
      );
      expect(guard.excluding, isTrue);
    }
  });

  testWidgets('keeps_song_browser_within_bounds', (tester) async {
    // The browser packs three columns plus a keyboard into the design canvas,
    // so it is the layout most likely to overflow when chrome grows.
    await _pumpSongBrowser(tester);

    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the song browser visible across display ratios', (
    tester,
  ) async {
    const viewports = [
      Size(1920, 1080),
      Size(1280, 720),
      Size(1024, 600),
      Size(2560, 720),
      Size(800, 1280),
    ];

    for (final viewport in viewports) {
      await _pumpSongBrowser(tester, viewport: viewport);

      expect(
        tester.takeException(),
        isNull,
        reason: 'overflow at ${viewport.width}x${viewport.height}',
      );

      final screen = Offset.zero & viewport;
      for (final finder in [
        find.byType(PreviewPlayer),
        find.byType(SearchResultsPanel),
      ]) {
        final rect = tester.getRect(finder.first);
        expect(screen.overlaps(rect), isTrue);
      }
    }
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:viet_ktv/app.dart';
import 'package:viet_ktv/core/services/music_sdk_platform.dart';
import 'package:viet_ktv/core/shared/widgets/search_input_shell.dart';
import 'package:viet_ktv/core/shared/widgets/virtual_key_tile.dart';
import 'package:viet_ktv/core/theme/app_colors.dart';
import 'package:viet_ktv/features/playback/data/audio_track_player.dart';
import 'package:viet_ktv/features/song_browser/data/models/song_item.dart';
import 'package:viet_ktv/features/song_browser/presentation/pages/song_browser_page.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/music_sdk_repository_provider.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/song_browser_provider.dart';
import 'package:viet_ktv/features/song_browser/presentation/widgets/preview_player.dart';
import 'package:viet_ktv/features/song_browser/presentation/widgets/search_keyboard_panel.dart';
import 'package:viet_ktv/features/song_browser/presentation/widgets/search_result_tile.dart';
import 'package:viet_ktv/features/song_browser/presentation/widgets/search_results_panel.dart';
import 'package:viet_ktv/features/song_browser/presentation/widgets/suggestions_panel.dart';
import 'package:viet_ktv/features/source_selection/data/models/music_source.dart';
import 'package:viet_ktv/l10n/app_localizations.dart';

import 'support/fake_music_sdk_platform.dart';
import 'support/fake_audio_track_player.dart';
import 'support/fake_video_player_platform.dart';

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
}) async {
  tester.view.physicalSize = const Size(1920, 1080);
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

/// Types [query] on the on-screen keyboard, one character at a time, then
/// presses TÌM to submit it as a real search.
///
/// Taps are scoped to [VirtualKeyTile] because some letters (e.g. "C") also
/// appear as standalone badge text in the bottom hint bar, which would
/// otherwise make `find.text(char)` ambiguous.
Future<void> _search(WidgetTester tester, String query) async {
  for (final char in query.split('')) {
    await tester.tap(find.widgetWithText(VirtualKeyTile, char));
    await tester.pump();
  }
  await tester.tap(find.widgetWithText(VirtualKeyTile, 'TÌM'));
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

  testWidgets('shows_all_three_music_sources', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: VietKtvApp()));

    expect(find.text('YouTube'), findsOneWidget);
    expect(find.text('SOUNDCLOUD'), findsOneWidget);
    expect(find.text('M—XCLOUD'), findsOneWidget);
  });

  testWidgets('shows_virtual_keyboard_at_rest', (tester) async {
    await _pumpSongBrowser(tester);

    // The karaoke layout keeps the keyboard on screen instead of revealing it
    // after the search field is focused.
    expect(find.text('DẤU CÁCH'), findsOneWidget);
    expect(find.text('XÓA'), findsOneWidget);
    expect(find.text('TÌM'), findsOneWidget);
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

    await tester.tap(find.text('XÓA'));
    await tester.pumpAndSettle();

    expect(find.text('Nhập từ khóa rồi bấm TÌM để tìm kiếm'), findsOneWidget);
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
      MaterialApp(
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
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));

    expect(image.image, isA<NetworkImage>());
    expect((image.image as NetworkImage).url, 'https://img.example/yt-1.jpg');
  });

  testWidgets('centers_search_loading_state_inside_results_panel', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
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
            ),
          ),
        ),
      ),
    );

    final panel = tester.getRect(find.byType(SearchResultsPanel));
    final loader = tester.getRect(find.byType(CircularProgressIndicator));
    final label = tester.getRect(find.text('Đang tìm kiếm...'));

    expect(loader.center.dx, closeTo(panel.center.dx, 1));
    expect(label.center.dx, closeTo(panel.center.dx, 1));
  });

  testWidgets('resolves_a_playable_link_when_a_suggestion_is_played', (
    tester,
  ) async {
    final platform = FakeMusicSdkPlatform();
    await _pumpSongBrowser(tester, musicSdkPlatform: platform);

    expect(find.text('Chọn một bài hát để bắt đầu'), findsOneWidget);

    await tester.tap(find.text('Lạc Trôi'));
    // Not pumpAndSettle: once the fake video starts "playing", VideoPlayer's
    // own 100ms position timer runs indefinitely and would time it out.
    // A few bounded pumps are enough to walk the request through
    // getPlayableLink -> VideoPlayerController.initialize() -> first frame.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(platform.lastPlayableLinkTrackId, '1');
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
    await _pumpSongBrowser(
      tester,
      musicSdkPlatform: platform,
      source: _soundCloudSource,
    );

    await _search(tester, 'KARAOKE');
    await tester.tap(find.text('Lạc Trôi - Sơn Tùng M-TP (Karaoke)'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(platform.lastPlayableLinkTrackId, '9');
    final player = tester.widget<VideoPlayer>(find.byType(VideoPlayer));
    expect(player.controller.dataSource, startsWith('assets/visualizer/'));
    expect(player.controller.value.isLooping, isTrue);
    expect(player.controller.videoPlayerOptions?.mixWithOthers, isTrue);

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
    await _pumpSongBrowser(
      tester,
      musicSdkPlatform: platform,
      source: _soundCloudSource,
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
    await _pumpSongBrowser(
      tester,
      musicSdkPlatform: FakeMusicSdkPlatform(),
      source: _soundCloudSource,
      audioPlayerFactory: () => audioPlayer = FakeAudioTrackPlayer(),
    );

    await _search(tester, 'KARAOKE');
    await tester.tap(find.text('Lạc Trôi - Sơn Tùng M-TP (Karaoke)'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(audioPlayer.playCallCount, 1);
    expect(videoPlatform.playCallCount, 1);

    final videoPauseCount = videoPlatform.pauseCallCount;
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();

    expect(audioPlayer.pauseCallCount, 1);
    expect(videoPlatform.pauseCallCount, videoPauseCount + 1);

    final videoPlayCount = videoPlatform.playCallCount;
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
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

    await tester.tap(find.text('Lạc Trôi'));
    await tester.pumpAndSettle();

    expect(find.text('Không phát được video này.'), findsOneWidget);
  });

  testWidgets('adding_to_queue_does_not_also_trigger_playback', (tester) async {
    final platform = FakeMusicSdkPlatform();
    await _pumpSongBrowser(tester, musicSdkPlatform: platform);
    await _search(tester, 'OFFICIAL');

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(platform.lastPlayableLinkTrackId, isNull);
    expect(find.text('Chọn một bài hát để bắt đầu'), findsOneWidget);
  });

  testWidgets('centers_search_field_contents_vertically', (tester) async {
    await _pumpSongBrowser(tester);

    final field = tester.getRect(find.byType(SearchInputShell));
    final icon = tester.getRect(
      find.descendant(
        of: find.byType(SearchInputShell),
        matching: find.byIcon(Icons.search),
      ),
    );

    expect(icon.center.dy, closeTo(field.center.dy, 0.5));
  });

  testWidgets('aligns_search_field_with_keyboard_edges', (tester) async {
    await _pumpSongBrowser(tester);

    final field = tester.getRect(find.byType(SearchInputShell));
    final firstKey = tester.getRect(find.byType(VirtualKeyTile).first);

    expect(field.left, closeTo(firstKey.left, 0.5));
  });

  testWidgets('keeps_layout_within_bounds_on_small_viewport', (tester) async {
    tester.view.physicalSize = const Size(720, 405);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: VietKtvApp()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('expands_player_over_panels_and_keyboard', (tester) async {
    await _pumpSongBrowser(tester);

    final collapsedPlayer = tester.getRect(find.byType(PreviewPlayer));

    await tester.tap(find.byIcon(Icons.fullscreen_rounded));
    await tester.pumpAndSettle();

    final expandedPlayer = tester.getRect(find.byType(PreviewPlayer));
    expect(expandedPlayer.width, greaterThan(collapsedPlayer.width));
    expect(expandedPlayer.height, greaterThan(collapsedPlayer.height));
    expect(find.byIcon(Icons.fullscreen_exit_rounded), findsOneWidget);
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
    await _doubleTapAt(
      tester,
      tester.getCenter(find.byIcon(Icons.fast_rewind_rounded)),
    );

    expect(tester.getRect(find.byType(PreviewPlayer)), collapsed);
  });

  testWidgets('collapses_without_overflow_mid_animation', (tester) async {
    await _pumpSongBrowser(tester);

    await tester.tap(find.byIcon(Icons.fullscreen_rounded));
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

    await tester.tap(find.byIcon(Icons.fullscreen_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.fullscreen_exit_rounded));
    await tester.pumpAndSettle();

    expect(tester.getRect(find.byType(PreviewPlayer)), original);
  });

  testWidgets('keeps_hidden_panels_out_of_focus_when_expanded', (tester) async {
    await _pumpSongBrowser(tester);

    await tester.tap(find.byIcon(Icons.fullscreen_rounded));
    await tester.pumpAndSettle();

    // Collapsed panels stay in the tree, so they must be excluded from D-pad
    // traversal or focus would walk into rows the user cannot see.
    for (final panel in [
      find.byType(SearchKeyboardPanel),
      find.byType(SuggestionsPanel),
      find.byType(SearchResultsPanel),
    ]) {
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
}

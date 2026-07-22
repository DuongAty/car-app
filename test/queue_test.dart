import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:viet_ktv/core/services/music_sdk_platform.dart';
import 'package:viet_ktv/core/shared/widgets/liquid_glass.dart';
import 'package:viet_ktv/core/shared/widgets/virtual_key_tile.dart';
import 'package:viet_ktv/core/theme/app_colors.dart';
import 'package:viet_ktv/features/playback/data/audio_track_player.dart';
import 'package:viet_ktv/features/playback/presentation/providers/now_playing_controller.dart';
import 'package:viet_ktv/features/queue/presentation/pages/selected_queue_page.dart';
import 'package:viet_ktv/features/queue/presentation/providers/queue_playback_controller.dart';
import 'package:viet_ktv/features/queue/presentation/providers/queue_provider.dart';
import 'package:viet_ktv/features/queue/presentation/widgets/queued_song_tile.dart';
import 'package:viet_ktv/features/song_browser/data/models/song_item.dart';
import 'package:viet_ktv/features/song_browser/data/music_sdk_song_repository.dart';
import 'package:viet_ktv/features/song_browser/presentation/pages/song_browser_page.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/music_sdk_repository_provider.dart';
import 'package:viet_ktv/features/source_selection/data/models/music_source.dart';
import 'package:viet_ktv/l10n/app_localizations.dart';
import 'package:viet_ktv/routes/app_router.dart';

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

late FakeVideoPlayerPlatform _videoPlatform;

Future<void> _pumpBrowser(
  WidgetTester tester, {
  required MusicSdkPlatform platform,
}) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        musicSdkPlatformProvider.overrideWithValue(platform),
        audioTrackPlayerFactoryProvider.overrideWithValue(
          FakeAudioTrackPlayer.new,
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
        // The real router, not just `home:` — this is what makes tapping
        // "ĐÃ CHỌN" a genuine test of AppRouter.selectedQueue rather than a
        // widget built directly in the test.
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: SongBrowserPage(source: _source),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Types [query], submits it, then adds the single matching result to the
/// queue via the search result's "+".
Future<void> _searchAndAddToQueue(WidgetTester tester, String query) async {
  for (final char in query.split('')) {
    await tester.tap(find.widgetWithText(VirtualKeyTile, char));
    await tester.pump();
  }
  await tester.tap(find.widgetWithText(VirtualKeyTile, 'TÌM'));
  await tester.pumpAndSettle();

  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();
}

Future<void> _openQueueScreen(WidgetTester tester) async {
  await tester.tap(find.text('ĐÃ CHỌN'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    _videoPlatform = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = _videoPlatform;
  });

  testWidgets('adding_a_search_result_shows_up_on_the_queue_screen', (
    tester,
  ) async {
    await _pumpBrowser(tester, platform: FakeMusicSdkPlatform());

    await _searchAndAddToQueue(tester, 'OFFICIAL');
    await _openQueueScreen(tester);

    expect(find.text('Lạc Trôi - Sơn Tùng M-TP (Official MV)'), findsOneWidget);
    expect(find.text('1 bài'), findsOneWidget);
  });

  testWidgets('bottom_queue_hint_opens_drawer_without_navigating', (
    tester,
  ) async {
    await _pumpBrowser(tester, platform: FakeMusicSdkPlatform());

    await _searchAndAddToQueue(tester, 'OFFICIAL');
    await tester.tap(find.textContaining('Xem danh'));
    await tester.pumpAndSettle();

    final drawer = find.byKey(const ValueKey('selectedQueueDrawer'));
    expect(drawer, findsOneWidget);
    final drawerSurface = tester.widget<LiquidGlass>(
      find.descendant(of: drawer, matching: find.byType(LiquidGlass)).first,
    );
    expect(drawerSurface.opacity, greaterThanOrEqualTo(0.82));
    expect(find.byType(SelectedQueuePage), findsNothing);
    expect(
      find.descendant(of: drawer, matching: find.byType(QueuedSongTile)),
      findsOneWidget,
    );
    expect(find.text('1 bài'), findsOneWidget);
  });

  testWidgets('removing_a_queued_song_returns_to_the_empty_state', (
    tester,
  ) async {
    await _pumpBrowser(tester, platform: FakeMusicSdkPlatform());

    await _searchAndAddToQueue(tester, 'OFFICIAL');
    await _openQueueScreen(tester);
    expect(find.text('1 bài'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('0 bài'), findsOneWidget);
    expect(find.textContaining('Chưa có bài hát nào'), findsOneWidget);
  });

  testWidgets('clear_hint_empties_the_whole_queue', (tester) async {
    await _pumpBrowser(tester, platform: FakeMusicSdkPlatform());

    await _searchAndAddToQueue(tester, 'OFFICIAL');
    await _openQueueScreen(tester);
    expect(find.text('1 bài'), findsOneWidget);

    await tester.tap(find.text('Xóa tất cả hàng chờ'));
    await tester.pumpAndSettle();

    expect(find.text('0 bài'), findsOneWidget);
  });

  testWidgets('playing_a_queued_song_resolves_its_playable_link', (
    tester,
  ) async {
    final platform = FakeMusicSdkPlatform();
    await _pumpBrowser(tester, platform: platform);

    await _searchAndAddToQueue(tester, 'OFFICIAL');
    await _openQueueScreen(tester);

    await tester.tap(find.text('Lạc Trôi - Sơn Tùng M-TP (Official MV)'));
    // Not pumpAndSettle: a playing video keeps a 100ms position Timer alive.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(platform.lastPlayableLinkTrackId, '10');
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('next_button_starts_queue_then_advances_through_queue', (
    tester,
  ) async {
    final platform = FakeMusicSdkPlatform();
    await _pumpBrowser(tester, platform: platform);

    for (final char in 'KARAOKE'.split('')) {
      await tester.tap(find.widgetWithText(VirtualKeyTile, char));
      await tester.pump();
    }
    await tester.tap(find.widgetWithText(VirtualKeyTile, 'TÌM'));
    await tester.pumpAndSettle();

    final addButtons = find.byIcon(Icons.add);
    await tester.tap(addButtons.at(0));
    await tester.pumpAndSettle();
    await tester.tap(addButtons.at(1));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Xem danh'));
    await tester.pumpAndSettle();
    var drawer = find.byKey(const ValueKey('selectedQueueDrawer'));
    expect(
      find.descendant(of: drawer, matching: find.byType(QueuedSongTile)),
      findsNWidgets(2),
    );
    await tester.tap(
      find
          .descendant(of: drawer, matching: find.byIcon(Icons.close_rounded))
          .first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lạc Trôi - Sơn Tùng M-TP (Karaoke)'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(platform.lastPlayableLinkTrackId, '9');

    await tester.tap(find.byIcon(Icons.skip_next_rounded));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(platform.lastPlayableLinkTrackId, '1');

    await tester.tap(find.textContaining('Xem danh'));
    await tester.pumpAndSettle();
    drawer = find.byKey(const ValueKey('selectedQueueDrawer'));
    expect(
      find.descendant(of: drawer, matching: find.byType(QueuedSongTile)),
      findsOneWidget,
    );
    await tester.tap(
      find
          .descendant(of: drawer, matching: find.byIcon(Icons.close_rounded))
          .first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.skip_next_rounded));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(platform.lastPlayableLinkTrackId, '9');

    await tester.tap(find.textContaining('Xem danh'));
    await tester.pumpAndSettle();
    drawer = find.byKey(const ValueKey('selectedQueueDrawer'));
    expect(
      find.descendant(of: drawer, matching: find.byType(QueuedSongTile)),
      findsNothing,
    );
    await tester.tap(
      find
          .descendant(of: drawer, matching: find.byIcon(Icons.close_rounded))
          .first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.skip_previous_rounded));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(platform.lastPlayableLinkTrackId, '1');

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('completed_video_automatically_plays_next_queued_song', (
    tester,
  ) async {
    final platform = FakeMusicSdkPlatform();
    await _pumpBrowser(tester, platform: platform);

    for (final char in 'KARAOKE'.split('')) {
      await tester.tap(find.widgetWithText(VirtualKeyTile, char));
      await tester.pump();
    }
    await tester.tap(find.widgetWithText(VirtualKeyTile, 'TÌM'));
    await tester.pumpAndSettle();

    final addButtons = find.byIcon(Icons.add);
    await tester.tap(addButtons.at(0));
    await tester.pumpAndSettle();
    await tester.tap(addButtons.at(1));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.skip_next_rounded));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(platform.lastPlayableLinkTrackId, '1');

    _videoPlatform.completeLatestVideo();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(platform.lastPlayableLinkTrackId, '9');

    await tester.tap(find.textContaining('Xem danh'));
    await tester.pumpAndSettle();
    final drawer = find.byKey(const ValueKey('selectedQueueDrawer'));
    expect(
      find.descendant(of: drawer, matching: find.byType(QueuedSongTile)),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox());
  });

  test(
    'completed_soundcloud_audio_automatically_plays_next_queued_song',
    () async {
      final platform = FakeMusicSdkPlatform();
      FakeAudioTrackPlayer? latestAudioPlayer;
      final nowPlaying = NowPlayingController(
        MusicSdkSongRepository(platform),
        () => latestAudioPlayer = FakeAudioTrackPlayer(),
      );
      final queue = QueueController()
        ..add(
          const SongItem(
            id: 'sc-1',
            title: 'SoundCloud 1',
            subtitle: 'SoundCloud',
            duration: '30:00',
            thumbnailSeed: 1,
            badge: null,
          ),
          _soundCloudSource,
        )
        ..add(
          const SongItem(
            id: 'sc-2',
            title: 'SoundCloud 2',
            subtitle: 'SoundCloud',
            duration: '28:00',
            thumbnailSeed: 2,
            badge: null,
          ),
          _soundCloudSource,
        );
      final queuePlayback = QueuePlaybackController(queue, nowPlaying);
      nowPlaying.setOnCompleted(queuePlayback.playNext);

      await queuePlayback.playNext();
      expect(platform.lastPlayableLinkTrackId, 'sc-1');
      expect(queue.state.length, 1);

      latestAudioPlayer!.complete();
      await Future<void>.delayed(Duration.zero);

      expect(platform.lastPlayableLinkTrackId, 'sc-2');
      expect(queue.state, isEmpty);

      nowPlaying.dispose();
      queuePlayback.dispose();
    },
  );

  testWidgets(
    'keeps_playing_the_same_video_when_switching_to_the_queue_screen',
    (tester) async {
      final platform = FakeMusicSdkPlatform();
      await _pumpBrowser(tester, platform: platform);

      // Play a result directly from the browser (not "+" — this is real
      // playback, not queuing).
      for (final char in 'OFFICIAL'.split('')) {
        await tester.tap(find.widgetWithText(VirtualKeyTile, char));
        await tester.pump();
      }
      await tester.tap(find.widgetWithText(VirtualKeyTile, 'TÌM'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lạc Trôi - Sơn Tùng M-TP (Official MV)'));
      // Not pumpAndSettle: a playing video keeps a 100ms position Timer alive.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(platform.lastPlayableLinkTrackId, '10');

      // Not _openQueueScreen (pumpAndSettle): the video is actively playing
      // at this point, so its 100ms position Timer never lets frames settle.
      // Bounded pumps covering both the page-push transition and the new
      // page's first frame.
      await tester.tap(find.text('ĐÃ CHỌN'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      // Still showing the same video, not reset to the idle prompt — that is
      // the whole point of sharing nowPlayingProvider across both screens.
      final queuePlayer = find.descendant(
        of: find.byType(SelectedQueuePage),
        matching: find.byType(VideoPlayer),
      );
      expect(queuePlayer, findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SelectedQueuePage),
          matching: find.text('Chọn một bài hát để bắt đầu'),
        ),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('moving_a_queued_song_down_changes_its_order', (tester) async {
    await _pumpBrowser(tester, platform: FakeMusicSdkPlatform());

    // "KARAOKE" matches both the seed track (id '1', subtitle carries the
    // recommendations seed phrase) and the Karaoke search result (id '9'),
    // giving two distinct rows to reorder.
    for (final char in 'KARAOKE'.split('')) {
      await tester.tap(find.widgetWithText(VirtualKeyTile, char));
      await tester.pump();
    }
    await tester.tap(find.widgetWithText(VirtualKeyTile, 'TÌM'));
    await tester.pumpAndSettle();

    final addButtons = find.byIcon(Icons.add);
    expect(addButtons, findsNWidgets(2));
    await tester.tap(addButtons.at(0));
    await tester.pumpAndSettle();
    await tester.tap(addButtons.at(1));
    await tester.pumpAndSettle();

    await _openQueueScreen(tester);

    final firstTitle = find.text('Lạc Trôi');
    final secondTitle = find.text('Lạc Trôi - Sơn Tùng M-TP (Karaoke)');
    expect(
      tester.getCenter(firstTitle).dy,
      lessThan(tester.getCenter(secondTitle).dy),
    );

    final firstTile = find.ancestor(
      of: firstTitle,
      matching: find.byType(QueuedSongTile),
    );
    final moveDown = find.descendant(
      of: firstTile,
      matching: find.byIcon(Icons.keyboard_arrow_down_rounded),
    );
    await tester.tap(moveDown);
    await tester.pumpAndSettle();

    expect(
      tester.getCenter(firstTitle).dy,
      greaterThan(tester.getCenter(secondTitle).dy),
    );
  });
}

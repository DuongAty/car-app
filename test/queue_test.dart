import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/theme/app_icons.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/core/services/music_sdk_platform.dart';
import 'package:viet_ktv/core/shared/widgets/liquid_glass.dart';
import 'package:viet_ktv/core/theme/app_colors.dart';
import 'package:viet_ktv/features/playback/data/audio_track_player.dart';
import 'package:viet_ktv/features/playback/presentation/providers/now_playing_controller.dart';
import 'package:viet_ktv/features/queue/presentation/pages/selected_queue_page.dart';
import 'package:viet_ktv/features/queue/presentation/providers/queue_playback_controller.dart';
import 'package:viet_ktv/features/queue/presentation/providers/queue_provider.dart';
import 'package:viet_ktv/features/queue/presentation/widgets/queued_song_tile.dart';
import 'package:viet_ktv/features/queue/presentation/widgets/selected_queue_panel.dart';
import 'package:viet_ktv/features/song_browser/data/models/song_item.dart';
import 'package:viet_ktv/features/song_browser/data/music_sdk_song_repository.dart';
import 'package:viet_ktv/features/song_browser/presentation/pages/song_browser_page.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/music_sdk_repository_provider.dart';
import 'package:viet_ktv/features/source_selection/data/models/music_source.dart';
import 'package:viet_ktv/l10n/app_localizations.dart';
import 'package:viet_ktv/routes/app_router.dart';

import 'support/fake_music_sdk_platform.dart';
import 'support/fake_audio_track_player.dart';
import 'support/fake_local_storage_service.dart';
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
  await _submitSearch(tester, query);

  await tester.tap(find.byIcon(AppIcons.add));
  await tester.pumpAndSettle();
}

Future<void> _submitSearch(WidgetTester tester, String query) async {
  await tester.enterText(
    find.byKey(const ValueKey('songBrowserNativeSearchField')),
    query,
  );
  await tester.testTextInput.receiveAction(TextInputAction.search);
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

    await tester.tap(find.byIcon(AppIcons.close));
    await tester.pumpAndSettle();

    expect(find.text('0 bài'), findsOneWidget);
    expect(find.textContaining('Chưa có bài hát nào'), findsOneWidget);
  });

  testWidgets('undo_restores_a_removed_queue_song', (tester) async {
    await _pumpBrowser(tester, platform: FakeMusicSdkPlatform());

    await _searchAndAddToQueue(tester, 'OFFICIAL');
    await _openQueueScreen(tester);

    await tester.tap(find.byIcon(AppIcons.close));
    // The remove handler hides any current snack bar (the "added" one) before
    // showing this one, so the new snack bar appears after that hide-out — pump
    // past it rather than assuming it shows in a single frame.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Đã xóa khỏi hàng chờ'), findsOneWidget);

    final action = find.widgetWithText(SnackBarAction, 'Hoàn tác');
    expect(action, findsOneWidget);

    tester.widget<SnackBarAction>(action).onPressed();
    await tester.pumpAndSettle();

    expect(find.text('1 bài'), findsOneWidget);
    expect(find.byType(QueuedSongTile), findsOneWidget);
  });

  testWidgets('clear_button_empties_the_whole_queue', (tester) async {
    await _pumpBrowser(tester, platform: FakeMusicSdkPlatform());

    await _searchAndAddToQueue(tester, 'OFFICIAL');
    await _openQueueScreen(tester);
    expect(find.text('1 bài'), findsOneWidget);

    await tester.tap(find.byIcon(AppIcons.clearAll));
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

    // 'Lạc Trôi' matches all three catalog entries (ids 1, 9, 10); the first
    // two results queued below are still ids 1 and 9, same as the retired
    // 'KARAOKE' query used to produce.
    await _submitSearch(tester, 'Lạc Trôi');

    final addButtons = find.byIcon(AppIcons.add);
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
      find.descendant(of: drawer, matching: find.byIcon(AppIcons.close)).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lạc Trôi - Sơn Tùng M-TP (Karaoke)'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(platform.lastPlayableLinkTrackId, '9');

    await tester.tap(find.byIcon(AppIcons.next));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(platform.lastPlayableLinkTrackId, '1');

    await tester.tap(find.textContaining('Xem danh'));
    await tester.pumpAndSettle();
    drawer = find.byKey(const ValueKey('selectedQueueDrawer'));
    expect(
      find.descendant(of: drawer, matching: find.byType(QueuedSongTile)),
      findsNWidgets(2),
    );
    await tester.tap(
      find.descendant(of: drawer, matching: find.byIcon(AppIcons.close)).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(AppIcons.next));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    // Track 9 is still within the playable-link cache TTL from its earlier
    // play, so wrapping back to it replays from cache without re-resolving.
    // Verify the current track from the now-playing state, not a fresh resolve.
    final playback = ProviderScope.containerOf(
      tester.element(find.byType(SongBrowserPage)),
    ).read(nowPlayingProvider).playback;
    expect(playback, isA<PlaybackReady>());
    expect((playback as PlaybackReady).song.id, '9');

    await tester.tap(find.textContaining('Xem danh'));
    await tester.pumpAndSettle();
    drawer = find.byKey(const ValueKey('selectedQueueDrawer'));
    expect(
      find.descendant(of: drawer, matching: find.byType(QueuedSongTile)),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(of: drawer, matching: find.byIcon(AppIcons.close)).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(AppIcons.previous));
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

    // 'Lạc Trôi' matches all three catalog entries (ids 1, 9, 10); the first
    // two results queued below are still ids 1 and 9, same as the retired
    // 'KARAOKE' query used to produce.
    await _submitSearch(tester, 'Lạc Trôi');

    final addButtons = find.byIcon(AppIcons.add);
    await tester.tap(addButtons.at(0));
    await tester.pumpAndSettle();
    await tester.tap(addButtons.at(1));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(AppIcons.next));
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
      findsOneWidget,
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
      expect(queue.state.items, hasLength(2));

      latestAudioPlayer!.complete();
      await Future<void>.delayed(Duration.zero);

      expect(platform.lastPlayableLinkTrackId, 'sc-2');
      expect(queue.state.items, hasLength(1));

      nowPlaying.dispose();
      queuePlayback.dispose();
    },
  );

  test('non_loop_removes_a_song_only_after_the_next_song_starts', () async {
    final platform = FakeMusicSdkPlatform();
    final nowPlaying = NowPlayingController(
      MusicSdkSongRepository(platform),
      FakeAudioTrackPlayer.new,
    );
    final queue = QueueController()
      ..add(
        const SongItem(
          id: 'first',
          title: 'Bài đầu',
          subtitle: 'SoundCloud',
          duration: '03:00',
          thumbnailSeed: 1,
          badge: null,
        ),
        _soundCloudSource,
      )
      ..add(
        const SongItem(
          id: 'second',
          title: 'Bài sau',
          subtitle: 'SoundCloud',
          duration: '04:00',
          thumbnailSeed: 2,
          badge: null,
        ),
        _soundCloudSource,
      );
    final playback = QueuePlaybackController(queue, nowPlaying);

    await playback.playNext();
    expect(queue.state.items.map((item) => item.song.id), ['first', 'second']);

    await playback.playNext();
    expect(platform.lastPlayableLinkTrackId, 'second');
    expect(queue.state.items.map((item) => item.song.id), ['second']);

    await playback.playNext();
    expect(queue.state.items.map((item) => item.song.id), ['second']);

    nowPlaying.dispose();
    playback.dispose();
  });

  testWidgets(
    'keeps_playing_the_same_video_when_switching_to_the_queue_screen',
    (tester) async {
      final platform = FakeMusicSdkPlatform();
      await _pumpBrowser(tester, platform: platform);

      // Play a result directly from the browser (not "+" — this is real
      // playback, not queuing).
      await _submitSearch(tester, 'OFFICIAL');

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

  test('drag_reorder_changes_the_next_playback_order', () {
    final queue = QueueController()
      ..add(
        const SongItem(
          id: 'first',
          title: 'Bài đầu',
          subtitle: 'YouTube',
          duration: '03:00',
          thumbnailSeed: 1,
          badge: null,
        ),
        _source,
      )
      ..add(
        const SongItem(
          id: 'second',
          title: 'Bài sau',
          subtitle: 'YouTube',
          duration: '04:00',
          thumbnailSeed: 2,
          badge: null,
        ),
        _source,
      );

    queue.moveToSlot(0, 2);

    expect(queue.state.items.map((item) => item.song.id), ['second', 'first']);
  });

  test('repeat_one_replays_the_same_song_without_removing_it', () async {
    final platform = FakeMusicSdkPlatform();
    final nowPlaying = NowPlayingController(
      MusicSdkSongRepository(platform),
      FakeAudioTrackPlayer.new,
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
      ..setQueueRepeatMode(QueueRepeatMode.one);
    final queuePlayback = QueuePlaybackController(queue, nowPlaying);

    await queuePlayback.playNext();
    expect(platform.lastPlayableLinkTrackId, 'sc-1');
    expect(queue.state.items, hasLength(1));

    await queuePlayback.playNext();
    expect(platform.lastPlayableLinkTrackId, 'sc-1');

    nowPlaying.dispose();
    queuePlayback.dispose();
  });

  test(
    'repeat_one_replays_a_directly_played_song_with_an_empty_queue',
    () async {
      final platform = FakeMusicSdkPlatform();
      final createdPlayers = <FakeAudioTrackPlayer>[];
      final nowPlaying = NowPlayingController(
        MusicSdkSongRepository(platform),
        () {
          final player = FakeAudioTrackPlayer();
          createdPlayers.add(player);
          return player;
        },
      );
      final queue = QueueController()..setQueueRepeatMode(QueueRepeatMode.one);
      final queuePlayback = QueuePlaybackController(queue, nowPlaying);
      nowPlaying.setOnCompleted(queuePlayback.playNext);

      // Reproduces the bug report: play a song directly (e.g. from search
      // results), never touching the queue, so it stays empty.
      const song = SongItem(
        id: 'direct-1',
        title: 'Direct Play',
        subtitle: 'SoundCloud',
        duration: '30:00',
        thumbnailSeed: 1,
        badge: null,
      );
      await nowPlaying.play(song, MusicSourceLogoStyle.soundcloud);
      expect(queue.state.items, isEmpty);
      expect(createdPlayers, hasLength(1));

      createdPlayers.single.complete();
      await Future<void>.delayed(Duration.zero);

      // A genuine replay tears down the old player and creates a fresh one
      // via nowPlaying.play(); if repeat-one silently no-ops (the bug), no
      // second player is ever created and playback stays paused.
      expect(createdPlayers, hasLength(2));
      expect(platform.lastPlayableLinkTrackId, 'direct-1');
      expect(nowPlaying.state.playback, isA<PlaybackReady>());

      nowPlaying.dispose();
      queuePlayback.dispose();
    },
  );

  test(
    'repeat_one_with_continuous_playback_off_does_nothing_on_completion',
    () async {
      final platform = FakeMusicSdkPlatform();
      final nowPlaying = NowPlayingController(
        MusicSdkSongRepository(platform),
        FakeAudioTrackPlayer.new,
      );
      final queue = QueueController()..setQueueRepeatMode(QueueRepeatMode.one);
      final queuePlayback = QueuePlaybackController(queue, nowPlaying);
      queuePlayback.setContinuousPlayback(false);
      nowPlaying.setOnCompleted(queuePlayback.playNext);

      const song = SongItem(
        id: 'direct-2',
        title: 'Direct Play 2',
        subtitle: 'SoundCloud',
        duration: '30:00',
        thumbnailSeed: 1,
        badge: null,
      );
      await nowPlaying.play(song, MusicSourceLogoStyle.soundcloud);

      final audioPlayer = nowPlaying.state.audioPlayer as FakeAudioTrackPlayer;
      expect(audioPlayer.playCallCount, 1);

      audioPlayer.complete();
      await Future<void>.delayed(Duration.zero);

      // Continuous playback is off, so completion must not replay — the
      // player is not asked to play again.
      expect(audioPlayer.playCallCount, 1);

      nowPlaying.dispose();
      queuePlayback.dispose();
    },
  );

  test('repeat_one_with_nothing_playing_is_a_safe_no_op', () async {
    final platform = FakeMusicSdkPlatform();
    final nowPlaying = NowPlayingController(
      MusicSdkSongRepository(platform),
      FakeAudioTrackPlayer.new,
    );
    final queue = QueueController()..setQueueRepeatMode(QueueRepeatMode.one);
    final queuePlayback = QueuePlaybackController(queue, nowPlaying);

    await queuePlayback.playNext();

    expect(platform.lastPlayableLinkTrackId, isNull);
    expect(nowPlaying.state.playback, isA<PlaybackIdle>());

    nowPlaying.dispose();
    queuePlayback.dispose();
  });

  test('repeat_all_keeps_the_playlist_when_looping', () async {
    final platform = FakeMusicSdkPlatform();
    final nowPlaying = NowPlayingController(
      MusicSdkSongRepository(platform),
      FakeAudioTrackPlayer.new,
    );
    const song = SongItem(
      id: 'sc-1',
      title: 'SoundCloud 1',
      subtitle: 'SoundCloud',
      duration: '30:00',
      thumbnailSeed: 1,
      badge: null,
    );
    final queue = QueueController()
      ..add(song, _soundCloudSource)
      ..setQueueRepeatMode(QueueRepeatMode.all);
    final queuePlayback = QueuePlaybackController(queue, nowPlaying);

    await queuePlayback.playNext();
    expect(platform.lastPlayableLinkTrackId, 'sc-1');
    expect(queue.state.items, hasLength(1));

    await queuePlayback.playNext();
    expect(platform.lastPlayableLinkTrackId, 'sc-1');
    expect(queue.state.items, hasLength(1));

    nowPlaying.dispose();
    queuePlayback.dispose();
  });

  test(
    'shuffle_picks_from_the_current_queue_rather_than_always_the_first',
    () async {
      final platform = FakeMusicSdkPlatform();
      final nowPlaying = NowPlayingController(
        MusicSdkSongRepository(platform),
        FakeAudioTrackPlayer.new,
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
        )
        ..toggleShuffle();
      // Seeded so the pick is deterministic for this test.
      final queuePlayback = QueuePlaybackController(
        queue,
        nowPlaying,
        random: math.Random(0),
      );

      await queuePlayback.playNext();

      expect(platform.lastPlayableLinkTrackId, 'sc-2');
      expect(queue.state.items, hasLength(2));

      nowPlaying.dispose();
      queuePlayback.dispose();
    },
  );

  testWidgets('repeat_button_cycles_through_modes', (tester) async {
    await _pumpBrowser(tester, platform: FakeMusicSdkPlatform());
    await _openQueueScreen(tester);

    Finder repeatButton() => find.descendant(
      of: find.byType(SelectedQueuePanel),
      matching: find.byIcon(AppIcons.repeat),
    );
    Finder repeatOneButton() => find.descendant(
      of: find.byType(SelectedQueuePanel),
      matching: find.byIcon(AppIcons.repeatOne),
    );

    expect(repeatButton(), findsOneWidget);

    await tester.tap(repeatButton());
    await tester.pump();
    expect(repeatButton(), findsOneWidget); // now "all"

    await tester.tap(repeatButton());
    await tester.pump();
    expect(repeatOneButton(), findsOneWidget); // "one"

    await tester.tap(repeatOneButton());
    await tester.pump();
    expect(repeatButton(), findsOneWidget); // back to "off"
  });

  testWidgets('shuffle_button_toggles_active_tint', (tester) async {
    await _pumpBrowser(tester, platform: FakeMusicSdkPlatform());
    await _openQueueScreen(tester);

    final shuffleButton = find.byIcon(AppIcons.shuffle);
    expect(shuffleButton, findsOneWidget);

    await tester.tap(shuffleButton);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}

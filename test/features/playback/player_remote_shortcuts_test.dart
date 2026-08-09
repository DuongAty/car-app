import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/core/theme/app_colors.dart';
import 'package:viet_ktv/features/playback/data/audio_track_player.dart';
import 'package:viet_ktv/features/playback/presentation/providers/now_playing_controller.dart';
import 'package:viet_ktv/features/song_browser/data/models/song_item.dart';
import 'package:viet_ktv/features/song_browser/presentation/pages/song_browser_page.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/music_sdk_repository_provider.dart';
import 'package:viet_ktv/features/source_selection/data/models/music_source.dart';
import 'package:viet_ktv/l10n/app_localizations.dart';

import '../../support/fake_audio_track_player.dart';
import '../../support/fake_local_storage_service.dart';
import '../../support/fake_music_sdk_platform.dart';

const _source = MusicSource(
  id: 'youtube',
  subtitle: 'Kho nhạc & Video\nkhổng lồ',
  accentColor: AppColors.red,
  logoStyle: MusicSourceLogoStyle.youtube,
);

const _song = SongItem(
  id: 'track-1',
  title: 'Test Song',
  subtitle: 'SoundCloud',
  duration: '00:30',
  thumbnailSeed: 1,
  badge: null,
);

/// One entry per audio player the controller has built. A replay tears the
/// current player down and builds a fresh one, so the length of this list is
/// how many times playback has been started from scratch.
final List<FakeAudioTrackPlayer> _players = <FakeAudioTrackPlayer>[];

Future<ProviderContainer> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  _players.clear();
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(FakeLocalStorageService()),
      musicSdkPlatformProvider.overrideWithValue(FakeMusicSdkPlatform()),
      audioTrackPlayerFactoryProvider.overrideWithValue(() {
        final player = FakeAudioTrackPlayer();
        _players.add(player);
        return player;
      }),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('vi'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const SongBrowserPage(source: _source),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// Starts a song on the audio path, which [FakeAudioTrackPlayer] stands in for.
Future<void> _startPlayback(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await container
      .read(nowPlayingProvider.notifier)
      .play(_song, MusicSourceLogoStyle.soundcloud);
  await tester.pumpAndSettle();
}

/// The player wrapper's own focus node — the one that owns the remote
/// shortcuts and sits above every transport button.
FocusNode _playerWrapperNode(WidgetTester tester) => tester
    .widgetList<Focus>(find.byType(Focus, skipOffstage: false))
    .map((focus) => focus.focusNode)
    .whereType<FocusNode>()
    .firstWhere((node) => node.debugLabel == 'previewPlayer');

/// Moves focus onto the player the way a user does — by traversing — rather
/// than with an explicit `requestFocus`, which lands on a node even when
/// traversal cannot reach it and so would not exercise the defect at all.
Future<void> _traverseToPlayer(WidgetTester tester) async {
  var landed = false;
  for (var press = 0; press < 80 && !landed; press++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    landed = primaryFocus?.debugLabel == 'previewPlayer';
  }
  expect(landed, isTrue, reason: 'traversal must be able to reach the player');
}

void main() {
  testWidgets('player_wrapper_is_traversable_outside_fullscreen', (
    tester,
  ) async {
    // The shortcuts are gated on the wrapper holding primary focus. Skipping
    // it in traversal outside fullscreen means nothing can ever put focus
    // there — `didUpdateWidget` and `_claimFocusAfterHide` are the only
    // explicit requests and both are fullscreen-only — so the gate is closed
    // forever and every shortcut on this player is dead in `normal`/`wide`.
    final container = await _pump(tester);
    expect(container.read(nowPlayingProvider).mode, PlayerViewMode.normal);

    final wrapper = _playerWrapperNode(tester);

    expect(
      wrapper.enclosingScope?.traversalDescendants,
      contains(wrapper),
      reason: 'focus traversal must be able to land on the player',
    );
  });

  testWidgets('holding_enter_replays_the_song_in_normal_mode', (tester) async {
    // Hold-Enter-to-restart has no other trigger anywhere in the UI — no
    // button, no gesture — so if the wrapper cannot hold focus in `normal` the
    // feature is simply gone for a karaoke singer who never goes fullscreen.
    final container = await _pump(tester);
    await _startPlayback(tester, container);
    expect(_players, hasLength(1));

    await _traverseToPlayer(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(
      _players,
      hasLength(2),
      reason: 'the hold must restart the song from the top',
    );
  });

  testWidgets('a_short_enter_toggles_play_pause_in_normal_mode', (
    tester,
  ) async {
    // The other half of the same gate: a tap of Enter must still be
    // play/pause, not a replay.
    final container = await _pump(tester);
    await _startPlayback(tester, container);
    final player = _players.single;
    expect(player.pauseCallCount, 0);

    await _traverseToPlayer(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(player.pauseCallCount, 1);
    expect(_players, hasLength(1), reason: 'a short press must not replay');
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/core/theme/app_colors.dart';
import 'package:viet_ktv/core/theme/app_icons.dart';
import 'package:viet_ktv/features/playback/data/audio_track_player.dart';
import 'package:viet_ktv/features/playback/presentation/providers/now_playing_controller.dart';
import 'package:viet_ktv/features/song_browser/data/models/song_item.dart';
import 'package:viet_ktv/features/song_browser/presentation/pages/song_browser_page.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/music_sdk_repository_provider.dart';
import 'package:viet_ktv/features/song_browser/presentation/widgets/preview_player.dart';
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

/// Builds the browser page with a fake player wired in but nothing playing
/// yet. Shared by [_pump] and the nothing-playing coverage below, which
/// deliberately must not start playback.
Future<({ProviderContainer container, FakeAudioTrackPlayer player})> _pumpPage(
  WidgetTester tester,
) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final player = FakeAudioTrackPlayer();
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(FakeLocalStorageService()),
      musicSdkPlatformProvider.overrideWithValue(FakeMusicSdkPlatform()),
      audioTrackPlayerFactoryProvider.overrideWithValue(() => player),
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

  return (container: container, player: player);
}

/// Pumps the browser page with a live audio player so play/pause has something
/// to act on. SoundCloud takes the just_audio path, which the fake stands in
/// for — the YouTube path needs a real video decoder.
Future<({ProviderContainer container, FakeAudioTrackPlayer player})> _pump(
  WidgetTester tester,
) async {
  final harness = await _pumpPage(tester);

  await harness.container
      .read(nowPlayingProvider.notifier)
      .play(_song, MusicSourceLogoStyle.soundcloud);
  await tester.pumpAndSettle();
  expect(
    harness.container.read(nowPlayingProvider).audioPlayer,
    isNotNull,
    reason: 'setup must leave a live player, or play/pause has nothing to do',
  );

  return harness;
}

/// Taps the picture once. The extra pump past the double-tap window is what
/// lets onTap win the arena — without it the tap is still pending.
Future<void> _tapPicture(WidgetTester tester) async {
  final rect = tester.getRect(find.byType(PreviewPlayer));
  await tester.tapAt(
    Offset(rect.left + rect.width * 0.5, rect.top + rect.height * 0.3),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

/// The point [_tapPicture] and the two-finger tests below land on.
Offset _picturePoint(WidgetTester tester) {
  final rect = tester.getRect(find.byType(PreviewPlayer));
  return Offset(rect.left + rect.width * 0.5, rect.top + rect.height * 0.3);
}

/// A second point far enough from [_picturePoint] to be a distinct finger,
/// still on the picture so it also lands on the hidden controls.
Offset _secondPicturePoint(WidgetTester tester) {
  final rect = tester.getRect(find.byType(PreviewPlayer));
  return Offset(rect.left + rect.width * 0.7, rect.top + rect.height * 0.3);
}

Future<void> _doubleTapPicture(WidgetTester tester, double fraction) async {
  final rect = tester.getRect(find.byType(PreviewPlayer));
  final point = Offset(
    rect.left + rect.width * fraction,
    rect.top + rect.height * 0.3,
  );
  await tester.tapAt(point);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tapAt(point);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tap_toggles_playback_in_normal_mode', (tester) async {
    final harness = await _pump(tester);
    final pausesBefore = harness.player.pauseCallCount;

    await _tapPicture(tester);

    expect(harness.player.pauseCallCount, pausesBefore + 1);
  });

  testWidgets('tap_toggles_playback_in_wide_mode', (tester) async {
    final harness = await _pump(tester);
    harness.container.read(nowPlayingProvider.notifier).toggleWide();
    await tester.pumpAndSettle();
    final pausesBefore = harness.player.pauseCallCount;

    await _tapPicture(tester);

    expect(harness.player.pauseCallCount, pausesBefore + 1);
  });

  testWidgets('tap_on_hidden_controls_only_reveals_them', (tester) async {
    // Glancing at the progress bar must not stop the song. This is the
    // behaviour the pointer-down capture exists for.
    final harness = await _pump(tester);
    harness.container.read(nowPlayingProvider.notifier).enterFullscreen();
    await tester.pumpAndSettle();
    await tester.pump(kControlsAutoHideDelay + const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byIcon(AppIcons.fullscreenExit), findsNothing);
    final pausesBefore = harness.player.pauseCallCount;

    await _tapPicture(tester);

    expect(find.byIcon(AppIcons.fullscreenExit), findsOneWidget);
    expect(
      harness.player.pauseCallCount,
      pausesBefore,
      reason: 'the reveal tap must not touch playback',
    );
  });

  testWidgets('tap_with_controls_already_visible_toggles_playback', (
    tester,
  ) async {
    final harness = await _pump(tester);
    harness.container.read(nowPlayingProvider.notifier).enterFullscreen();
    await tester.pumpAndSettle();
    expect(find.byIcon(AppIcons.fullscreenExit), findsOneWidget);
    final pausesBefore = harness.player.pauseCallCount;

    await _tapPicture(tester);

    expect(harness.player.pauseCallCount, pausesBefore + 1);
  });

  testWidgets('double_tap_does_not_also_toggle_playback', (tester) async {
    final harness = await _pump(tester);
    final pausesBefore = harness.player.pauseCallCount;
    final playsBefore = harness.player.playCallCount;

    await _doubleTapPicture(tester, 0.5);

    expect(
      harness.container.read(nowPlayingProvider).mode,
      PlayerViewMode.fullscreen,
    );
    expect(harness.player.pauseCallCount, pausesBefore);
    expect(harness.player.playCallCount, playsBefore);
  });

  testWidgets('second_finger_during_pending_tap_does_not_defeat_reveal', (
    tester,
  ) async {
    // Finger A lands on hidden controls first and should own the tap. Finger
    // B lands on top while A is still down and must not overwrite what A's
    // tap will read — otherwise A's release reads "controls were visible"
    // and pauses playback instead of merely revealing the controls.
    final harness = await _pump(tester);
    harness.container.read(nowPlayingProvider.notifier).enterFullscreen();
    await tester.pumpAndSettle();
    await tester.pump(kControlsAutoHideDelay + const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byIcon(AppIcons.fullscreenExit), findsNothing);
    final pausesBefore = harness.player.pauseCallCount;

    final fingerA = await tester.startGesture(_picturePoint(tester));
    await tester.pump(const Duration(milliseconds: 20));
    final fingerB = await tester.startGesture(_secondPicturePoint(tester));
    await tester.pump(const Duration(milliseconds: 20));
    await fingerA.up();
    await tester.pump(const Duration(milliseconds: 400));
    await fingerB.up();
    await tester.pumpAndSettle();

    expect(find.byIcon(AppIcons.fullscreenExit), findsOneWidget);
    expect(
      harness.player.pauseCallCount,
      pausesBefore,
      reason: 'a second finger landing mid-tap must not defeat the reveal',
    );
  });

  testWidgets('cancelled_press_does_not_wedge_the_capture', (tester) async {
    // A cancelled press (e.g. the gesture arena resolving elsewhere) must
    // release the capture, or every later tap reads the stale
    // controls-were-hidden flag from the cancelled press forever, and a
    // normal tap on visible controls would wrongly stop being able to
    // toggle playback at all.
    final harness = await _pump(tester);
    harness.container.read(nowPlayingProvider.notifier).enterFullscreen();
    await tester.pumpAndSettle();
    await tester.pump(kControlsAutoHideDelay + const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byIcon(AppIcons.fullscreenExit), findsNothing);

    final cancelled = await tester.startGesture(_picturePoint(tester));
    await tester.pump(const Duration(milliseconds: 20));
    await cancelled.cancel();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // The cancelled press's pointer-down already revealed the controls (the
    // overlay's own reveal is unconditional), and they haven't had time to
    // auto-hide again — so this next tap lands with controls visible and
    // must behave like any other tap-with-controls-visible: it toggles
    // playback. If the capture were left wedged to the cancelled pointer,
    // this tap's onPointerDown would be skipped entirely and it would keep
    // reading the stale "hidden" snapshot from the cancelled press, so it
    // would wrongly only re-reveal instead of toggling.
    expect(find.byIcon(AppIcons.fullscreenExit), findsOneWidget);
    final pausesBefore = harness.player.pauseCallCount;

    await _tapPicture(tester);

    expect(
      harness.player.pauseCallCount,
      pausesBefore + 1,
      reason:
          'the cancelled press must not wedge the capture and block a '
          'normal tap from toggling playback while controls are visible',
    );
  });

  testWidgets('tap_with_nothing_playing_changes_nothing', (tester) async {
    // Spec Testing bullet: a tap with nothing playing changes nothing.
    // togglePlayPause already no-ops with neither an audioPlayer nor an
    // initialised videoController; this is coverage, not a new behaviour.
    final harness = await _pumpPage(tester);
    expect(harness.container.read(nowPlayingProvider).audioPlayer, isNull);
    expect(harness.container.read(nowPlayingProvider).videoController, isNull);

    await _tapPicture(tester);

    expect(harness.player.playCallCount, 0);
    expect(harness.player.pauseCallCount, 0);
  });
}

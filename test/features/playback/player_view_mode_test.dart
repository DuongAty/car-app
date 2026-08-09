import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/features/playback/data/audio_track_player.dart';
import 'package:viet_ktv/features/playback/presentation/providers/now_playing_controller.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/music_sdk_repository_provider.dart';

import '../../support/fake_audio_track_player.dart';
import '../../support/fake_local_storage_service.dart';
import '../../support/fake_music_sdk_platform.dart';

ProviderContainer _container() {
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(FakeLocalStorageService()),
      musicSdkPlatformProvider.overrideWithValue(FakeMusicSdkPlatform()),
      audioTrackPlayerFactoryProvider.overrideWithValue(
        FakeAudioTrackPlayer.new,
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('starts_in_normal_mode', () {
    final container = _container();

    expect(container.read(nowPlayingProvider).mode, PlayerViewMode.normal);
  });

  test('toggle_wide_switches_between_normal_and_wide', () {
    final container = _container();
    final controller = container.read(nowPlayingProvider.notifier);

    controller.toggleWide();
    expect(container.read(nowPlayingProvider).mode, PlayerViewMode.wide);

    controller.toggleWide();
    expect(container.read(nowPlayingProvider).mode, PlayerViewMode.normal);
  });

  test('exiting_fullscreen_returns_to_normal_when_entered_from_normal', () {
    final container = _container();
    final controller = container.read(nowPlayingProvider.notifier);

    controller.enterFullscreen();
    expect(container.read(nowPlayingProvider).mode, PlayerViewMode.fullscreen);

    controller.exitFullscreen();
    expect(container.read(nowPlayingProvider).mode, PlayerViewMode.normal);
  });

  test('exiting_fullscreen_returns_to_wide_when_entered_from_wide', () {
    // The user widened the player deliberately; dropping them back to the
    // narrow layout on exit would silently undo that.
    final container = _container();
    final controller = container.read(nowPlayingProvider.notifier);
    controller.toggleWide();

    controller.enterFullscreen();
    controller.exitFullscreen();

    expect(container.read(nowPlayingProvider).mode, PlayerViewMode.wide);
  });

  test('entering_fullscreen_twice_does_not_lose_the_origin_mode', () {
    final container = _container();
    final controller = container.read(nowPlayingProvider.notifier);
    controller.toggleWide();

    controller.enterFullscreen();
    controller.enterFullscreen();
    controller.exitFullscreen();

    expect(container.read(nowPlayingProvider).mode, PlayerViewMode.wide);
  });

  test('exiting_fullscreen_when_not_fullscreen_is_a_no_op', () {
    final container = _container();
    final controller = container.read(nowPlayingProvider.notifier);
    controller.toggleWide();

    controller.exitFullscreen();

    expect(container.read(nowPlayingProvider).mode, PlayerViewMode.wide);
  });

  test('toggle_wide_from_fullscreen_leaves_fullscreen_for_normal', () {
    // Reaching the wide button at all means the controls are visible, so this
    // is a deliberate press and should be honoured rather than ignored.
    //
    // It lands in `normal`, not `wide`: in fullscreen the button shows the
    // "open the panel" icon, and `wide` still has the panel collapsed, so
    // `wide` would contradict the icon the user pressed.
    final container = _container();
    final controller = container.read(nowPlayingProvider.notifier);
    controller.enterFullscreen();

    controller.toggleWide();

    expect(container.read(nowPlayingProvider).mode, PlayerViewMode.normal);
  });
}

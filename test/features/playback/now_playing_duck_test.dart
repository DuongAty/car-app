import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/features/playback/data/audio_track_player.dart';
import 'package:viet_ktv/features/playback/presentation/providers/now_playing_controller.dart';
import 'package:viet_ktv/features/song_browser/data/models/song_item.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/music_sdk_repository_provider.dart';
import 'package:viet_ktv/features/source_selection/data/models/music_source.dart';

import '../../support/fake_audio_track_player.dart';
import '../../support/fake_local_storage_service.dart';
import '../../support/fake_music_sdk_platform.dart';

const _song = SongItem(
  id: 'track-1',
  title: 'Test Song',
  subtitle: 'SoundCloud',
  duration: '00:30',
  thumbnailSeed: 1,
  badge: null,
);

ProviderContainer _container(FakeAudioTrackPlayer player) {
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(FakeLocalStorageService()),
      musicSdkPlatformProvider.overrideWithValue(FakeMusicSdkPlatform()),
      audioTrackPlayerFactoryProvider.overrideWithValue(() => player),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('ducking_scales_the_current_user_volume', () async {
    final player = FakeAudioTrackPlayer();
    final container = _container(player);
    final controller = container.read(nowPlayingProvider.notifier);
    controller.setPlaybackVolume(0.8);
    await controller.play(_song, MusicSourceLogoStyle.soundcloud);

    controller.setDuckFactor(0.2);

    expect(player.lastVolume, closeTo(0.16, 1e-9));
  });

  test('releasing_the_duck_restores_the_user_volume', () async {
    final player = FakeAudioTrackPlayer();
    final container = _container(player);
    final controller = container.read(nowPlayingProvider.notifier);
    controller.setPlaybackVolume(0.8);
    await controller.play(_song, MusicSourceLogoStyle.soundcloud);

    controller.setDuckFactor(0.2);
    controller.setDuckFactor(1);

    expect(player.lastVolume, closeTo(0.8, 1e-9));
  });

  test('volume_changed_while_ducked_keeps_the_duck', () async {
    // Dragging the volume slider during a navigation prompt must not cancel
    // the duck, and must not be forgotten once the prompt ends.
    final player = FakeAudioTrackPlayer();
    final container = _container(player);
    final controller = container.read(nowPlayingProvider.notifier);
    controller.setPlaybackVolume(0.8);
    await controller.play(_song, MusicSourceLogoStyle.soundcloud);

    controller.setDuckFactor(0.2);
    controller.setPlaybackVolume(0.5);

    expect(player.lastVolume, closeTo(0.1, 1e-9));

    controller.setDuckFactor(1);

    expect(player.lastVolume, closeTo(0.5, 1e-9));
  });

  test('ducking_with_nothing_playing_is_a_no_op', () async {
    final player = FakeAudioTrackPlayer();
    final container = _container(player);
    final controller = container.read(nowPlayingProvider.notifier);

    controller.setDuckFactor(0.2);

    expect(player.lastVolume, isNull);
  });

  test('pausePlayback_on_already_paused_playback_is_a_no_op', () async {
    final player = FakeAudioTrackPlayer();
    final container = _container(player);
    final controller = container.read(nowPlayingProvider.notifier);
    await controller.play(_song, MusicSourceLogoStyle.soundcloud);
    await pumpEventQueue();

    controller.pausePlayback();
    await pumpEventQueue();
    expect(player.pauseCallCount, 1);
    expect(container.read(nowPlayingProvider).audioIsPlaying, isFalse);

    // Already paused: calling again must not pause a second time.
    controller.pausePlayback();
    await pumpEventQueue();

    expect(player.pauseCallCount, 1);
  });

  test('resumePlayback_on_already_playing_playback_is_a_no_op', () async {
    final player = FakeAudioTrackPlayer();
    final container = _container(player);
    final controller = container.read(nowPlayingProvider.notifier);
    await controller.play(_song, MusicSourceLogoStyle.soundcloud);
    await pumpEventQueue();

    expect(player.playCallCount, 1);
    expect(container.read(nowPlayingProvider).audioIsPlaying, isTrue);

    // Already playing: must not call play() again.
    controller.resumePlayback();
    await pumpEventQueue();

    expect(player.playCallCount, 1);
  });
}

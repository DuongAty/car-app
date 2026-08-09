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

Future<NowPlayingController> _playing(
  ProviderContainer container,
  FakeAudioTrackPlayer player,
) async {
  final controller = container.read(nowPlayingProvider.notifier);
  // SoundCloud takes the just_audio path, which the fake stands in for.
  await controller.play(_song, MusicSourceLogoStyle.soundcloud);
  // NowPlayingController subscribes to durationStream only after `setUrl`
  // resolves. Real just_audio's duration/position streams are backed by
  // rxdart BehaviorSubjects, which replay their latest value to a new
  // subscriber asynchronously (a beat after `listen()` returns, not during
  // it) — FakeAudioTrackPlayer matches that. Let the event loop turn so
  // that replay (and the resulting state update) lands before assertions
  // read `state.audioDuration`.
  await pumpEventQueue();
  return controller;
}

void main() {
  test('seeks_to_the_requested_position_on_the_audio_path', () async {
    final player = FakeAudioTrackPlayer();
    final container = _container(player);
    final controller = await _playing(container, player);

    controller.seekTo(const Duration(seconds: 12));

    expect(player.lastSeek, const Duration(seconds: 12));
  });

  test('clamps_a_negative_seek_to_zero', () async {
    final player = FakeAudioTrackPlayer();
    final container = _container(player);
    final controller = await _playing(container, player);

    controller.seekTo(const Duration(seconds: -5));

    expect(player.lastSeek, Duration.zero);
  });

  test('clamps_a_seek_past_the_end_to_the_duration', () async {
    final player = FakeAudioTrackPlayer();
    final container = _container(player);
    final controller = await _playing(container, player);
    // FakeAudioTrackPlayer.setUrl reports a 30s duration.

    controller.seekTo(const Duration(seconds: 99));

    expect(player.lastSeek, const Duration(seconds: 30));
  });

  test('seek_to_fraction_maps_onto_the_same_clamped_path', () async {
    final player = FakeAudioTrackPlayer();
    final container = _container(player);
    final controller = await _playing(container, player);

    controller.seekToFraction(0.5);

    expect(player.lastSeek, const Duration(seconds: 15));
  });

  test('seeking_with_nothing_playing_is_a_no_op', () async {
    final player = FakeAudioTrackPlayer();
    final container = _container(player);
    final controller = container.read(nowPlayingProvider.notifier);

    controller.seekTo(const Duration(seconds: 5));

    expect(player.lastSeek, isNull);
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/core/services/music_sdk_platform.dart';
import 'package:viet_ktv/features/playback/data/audio_track_player.dart';
import 'package:viet_ktv/features/playback/presentation/providers/now_playing_controller.dart';
import 'package:viet_ktv/features/settings/presentation/providers/settings_controller.dart';
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

const _otherSong = SongItem(
  id: 'track-2',
  title: 'Second Song',
  subtitle: 'SoundCloud',
  duration: '00:30',
  thumbnailSeed: 2,
  badge: null,
);

/// Link resolution that can be switched on and off mid-test, standing in for
/// a CDN link that has expired.
class _ToggleableLinkPlatform implements MusicSdkPlatform {
  _ToggleableLinkPlatform({this.failLink = false});

  final FakeMusicSdkPlatform _delegate = FakeMusicSdkPlatform();
  bool failLink;

  @override
  Future<void> initialize(String licenseKey) =>
      _delegate.initialize(licenseKey);

  @override
  Future<List<MusicSdkTrack>> search({
    required MusicSourceLogoStyle source,
    required String query,
  }) => _delegate.search(source: source, query: query);

  @override
  Future<String> getPlayableLink({
    required MusicSourceLogoStyle source,
    required String trackId,
  }) async {
    if (failLink) {
      throw StateError('link_failed');
    }
    return _delegate.getPlayableLink(source: source, trackId: trackId);
  }
}

ProviderContainer _container({MusicSdkPlatform? platform}) {
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(FakeLocalStorageService()),
      musicSdkPlatformProvider.overrideWithValue(
        platform ?? FakeMusicSdkPlatform(),
      ),
      audioTrackPlayerFactoryProvider.overrideWithValue(
        FakeAudioTrackPlayer.new,
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  // Regression guard: seeding the controller's settings with `ref.watch` made
  // nowPlayingProvider a dependency of those settings, so changing them (e.g.
  // dragging the volume slider mid-song) disposed and recreated the controller,
  // tearing down the live video decoder and stopping playback. Settings must be
  // applied in place, keeping the same controller instance.
  test(
    'changing music volume does not recreate the now-playing controller',
    () {
      final container = _container();
      final before = container.read(nowPlayingProvider.notifier);

      container.read(settingsControllerProvider.notifier).setMusicVolume(0.5);

      final after = container.read(nowPlayingProvider.notifier);
      expect(identical(before, after), isTrue);
    },
  );

  test(
    'toggling the visualizer does not recreate the now-playing controller',
    () {
      final container = _container();
      final before = container.read(nowPlayingProvider.notifier);

      container
          .read(settingsControllerProvider.notifier)
          .setVisualizerEnabled(true);

      final after = container.read(nowPlayingProvider.notifier);
      expect(identical(before, after), isTrue);
    },
  );

  group('a background playback failure must not end the session', () {
    test('a terminal failure advances the queue', () async {
      // Driving with the screen off, one track's link has expired. Without
      // this, music stopped permanently: `_onCompleted` was only reached from
      // `_handleTick`'s completion branch and the audio `completedStream`, so
      // `continuousPlayback` never advanced past a failure.
      final container = _container(
        platform: _ToggleableLinkPlatform(failLink: true),
      );
      final controller = container.read(nowPlayingProvider.notifier);
      var advances = 0;
      controller.setOnCompleted(({bool fromCompletion = false}) {
        advances++;
      });

      await controller.play(_song, MusicSourceLogoStyle.soundcloud);
      await pumpEventQueue();

      expect(
        container.read(nowPlayingProvider).playback,
        isA<PlaybackFailed>(),
      );
      expect(advances, 1);
    });

    test('consecutive failures stop advancing at the cap', () async {
      // A queue whose links have all expired must not be burned through in a
      // tight failure→advance→failure loop.
      final container = _container(
        platform: _ToggleableLinkPlatform(failLink: true),
      );
      final controller = container.read(nowPlayingProvider.notifier);
      var advances = 0;
      controller.setOnCompleted(({bool fromCompletion = false}) {
        advances++;
      });

      for (var i = 0; i < 6; i++) {
        await controller.play(_song, MusicSourceLogoStyle.soundcloud);
        await pumpEventQueue();
      }

      expect(advances, 3);
    });

    test('a successful start resets the failure budget', () async {
      final platform = _ToggleableLinkPlatform(failLink: true);
      final container = _container(platform: platform);
      final controller = container.read(nowPlayingProvider.notifier);
      var advances = 0;
      controller.setOnCompleted(({bool fromCompletion = false}) {
        advances++;
      });

      for (var i = 0; i < 4; i++) {
        await controller.play(_song, MusicSourceLogoStyle.soundcloud);
        await pumpEventQueue();
      }
      expect(advances, 3);

      platform.failLink = false;
      await controller.play(_song, MusicSourceLogoStyle.soundcloud);
      await pumpEventQueue();
      expect(container.read(nowPlayingProvider).playback, isA<PlaybackReady>());

      // A different song, because the successful resolution above is now in
      // the controller's 90s link cache and would replay straight from it.
      platform.failLink = true;
      await controller.play(_otherSong, MusicSourceLogoStyle.soundcloud);
      await pumpEventQueue();

      expect(advances, 4);
    });
  });
}

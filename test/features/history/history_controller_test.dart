import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/features/history/presentation/providers/history_controller.dart';
import 'package:viet_ktv/features/playback/data/audio_track_player.dart';
import 'package:viet_ktv/features/playback/presentation/providers/now_playing_controller.dart';
import 'package:viet_ktv/features/song_browser/data/models/song_item.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/music_sdk_repository_provider.dart';
import 'package:viet_ktv/features/source_selection/data/models/music_source.dart';

import '../../support/fake_audio_track_player.dart';
import '../../support/fake_local_storage_service.dart';
import '../../support/fake_music_sdk_platform.dart';

// Audio (SoundCloud), not YouTube video: a plain `test()` has no
// VideoPlayerPlatform registered, so playing a video source here would
// resolve to PlaybackFailed instead of PlaybackReady. `queue_test.dart`'s
// non-widget test uses the same trick.
const _source = MusicSourceLogoStyle.soundcloud;

void main() {
  test('recording_a_play_adds_it_to_history', () async {
    final platform = FakeMusicSdkPlatform();
    final container = ProviderContainer(
      overrides: [
        musicSdkPlatformProvider.overrideWithValue(platform),
        audioTrackPlayerFactoryProvider.overrideWithValue(
          FakeAudioTrackPlayer.new,
        ),
        localStorageServiceProvider.overrideWithValue(
          FakeLocalStorageService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    // Keeps the recorder alive, mirroring how app.dart watches it at launch.
    container.listen(historyControllerProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);

    await container
        .read(nowPlayingProvider.notifier)
        .play(
          const SongItem(
            id: '9',
            title: 'Lạc Trôi - Sơn Tùng M-TP (Karaoke)',
            subtitle: 'Karaoke 4 You',
            duration: '4:32',
            thumbnailSeed: 9,
            badge: null,
          ),
          _source,
        );
    await Future<void>.delayed(Duration.zero);

    final history = container.read(historyControllerProvider);
    expect(history, hasLength(1));
    expect(history.first.song.id, '9');
    expect(history.first.source, _source);
  });

  test(
    'replaying_the_same_song_immediately_does_not_duplicate_the_entry',
    () async {
      final platform = FakeMusicSdkPlatform();
      final container = ProviderContainer(
        overrides: [
          musicSdkPlatformProvider.overrideWithValue(platform),
          audioTrackPlayerFactoryProvider.overrideWithValue(
            FakeAudioTrackPlayer.new,
          ),
          localStorageServiceProvider.overrideWithValue(
            FakeLocalStorageService(),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(historyControllerProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);

      const song = SongItem(
        id: '9',
        title: 'Lạc Trôi - Sơn Tùng M-TP (Karaoke)',
        subtitle: 'Karaoke 4 You',
        duration: '4:32',
        thumbnailSeed: 9,
        badge: null,
      );
      final nowPlaying = container.read(nowPlayingProvider.notifier);

      await nowPlaying.play(song, _source);
      await Future<void>.delayed(Duration.zero);
      await nowPlaying.play(song, _source);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(historyControllerProvider), hasLength(1));
    },
  );

  test(
    'history_persists_across_a_fresh_controller_reading_the_same_storage',
    () async {
      final storage = FakeLocalStorageService();
      final platform = FakeMusicSdkPlatform();

      final container1 = ProviderContainer(
        overrides: [
          musicSdkPlatformProvider.overrideWithValue(platform),
          audioTrackPlayerFactoryProvider.overrideWithValue(
            FakeAudioTrackPlayer.new,
          ),
          localStorageServiceProvider.overrideWithValue(storage),
        ],
      );
      container1.listen(historyControllerProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      await container1
          .read(nowPlayingProvider.notifier)
          .play(
            const SongItem(
              id: '9',
              title: 'Karaoke',
              subtitle: 'Sub',
              duration: '4:00',
              thumbnailSeed: 9,
              badge: null,
            ),
            _source,
          );
      await Future<void>.delayed(Duration.zero);
      container1.dispose();

      final container2 = ProviderContainer(
        overrides: [localStorageServiceProvider.overrideWithValue(storage)],
      );
      addTearDown(container2.dispose);
      container2.read(historyControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);

      expect(container2.read(historyControllerProvider), hasLength(1));
    },
  );
}

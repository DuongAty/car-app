import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/services/music_sdk_platform.dart';
import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/features/playback/data/audio_track_player.dart';
import 'package:viet_ktv/features/playback/data/karaoke_audio_handler.dart';
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
  imageUrl: 'https://example.com/art.jpg',
  badge: null,
);

const _otherSong = SongItem(
  id: 'track-2',
  title: 'Second Song',
  subtitle: 'SoundCloud',
  duration: '00:30',
  thumbnailSeed: 2,
  imageUrl: 'https://example.com/art-2.jpg',
  badge: null,
);

/// Like [FakeMusicSdkPlatform] but with link resolution that can be switched
/// on and off mid-test, and that counts resolutions.
class ToggleableLinkPlatform implements MusicSdkPlatform {
  ToggleableLinkPlatform({this.failLink = false});

  final FakeMusicSdkPlatform _delegate = FakeMusicSdkPlatform();
  bool failLink;
  int linkCallCount = 0;

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
    linkCallCount++;
    if (failLink) {
      throw StateError('link_failed');
    }
    return _delegate.getPlayableLink(source: source, trackId: trackId);
  }
}

ProviderContainer _containerWith({
  required AudioTrackPlayerFactory playerFactory,
  MusicSdkPlatform? platform,
}) {
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(FakeLocalStorageService()),
      musicSdkPlatformProvider.overrideWithValue(
        platform ?? FakeMusicSdkPlatform(),
      ),
      audioTrackPlayerFactoryProvider.overrideWithValue(playerFactory),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

ProviderContainer _container(FakeAudioTrackPlayer player) =>
    _containerWith(playerFactory: () => player);

void main() {
  test('pause_from_the_notification_pauses_playback', () async {
    final player = FakeAudioTrackPlayer();
    final container = _container(player);
    final handler = KaraokeAudioHandler(container);
    await container
        .read(nowPlayingProvider.notifier)
        .play(_song, MusicSourceLogoStyle.soundcloud);

    await handler.pause();

    expect(player.pauseCallCount, 1);
  });

  test('play_from_the_notification_resumes_playback', () async {
    final player = FakeAudioTrackPlayer();
    final container = _container(player);
    final handler = KaraokeAudioHandler(container);
    await container
        .read(nowPlayingProvider.notifier)
        .play(_song, MusicSourceLogoStyle.soundcloud);
    await handler.pause();

    await handler.play();

    expect(player.playCallCount, 2);
  });

  test('seek_from_the_notification_seeks_the_player', () async {
    final player = FakeAudioTrackPlayer();
    final container = _container(player);
    final handler = KaraokeAudioHandler(container);
    await container
        .read(nowPlayingProvider.notifier)
        .play(_song, MusicSourceLogoStyle.soundcloud);

    await handler.seek(const Duration(seconds: 9));

    expect(player.lastSeek, const Duration(seconds: 9));
  });

  test('stop_from_the_notification_returns_playback_to_idle', () async {
    final player = FakeAudioTrackPlayer();
    final container = _container(player);
    final handler = KaraokeAudioHandler(container);
    await container
        .read(nowPlayingProvider.notifier)
        .play(_song, MusicSourceLogoStyle.soundcloud);

    await handler.stop();

    expect(container.read(nowPlayingProvider).playback, isA<PlaybackIdle>());
  });

  test('commands_with_nothing_playing_are_no_ops', () async {
    // A steering-wheel button pressed before any song was chosen must not throw.
    final player = FakeAudioTrackPlayer();
    final container = _container(player);
    final handler = KaraokeAudioHandler(container);

    await handler.play();
    await handler.pause();
    await handler.seek(const Duration(seconds: 3));
    await handler.skipToNext();
    await handler.skipToPrevious();
    await handler.stop();

    expect(player.playCallCount, 0);
    expect(player.pauseCallCount, 0);
  });

  test('publishes_the_current_song_as_a_media_item', () async {
    final player = FakeAudioTrackPlayer();
    final container = _container(player);
    final handler = KaraokeAudioHandler(container);

    await container
        .read(nowPlayingProvider.notifier)
        .play(_song, MusicSourceLogoStyle.soundcloud);
    handler.syncFromPlayback();

    expect(handler.mediaItem.value?.id, 'track-1');
    expect(handler.mediaItem.value?.title, 'Test Song');
    expect(
      handler.mediaItem.value?.artUri,
      Uri.parse('https://example.com/art.jpg'),
    );
  });

  test('republishes_the_media_item_only_when_the_track_changes', () async {
    // syncFromPlayback is driven by nowPlayingProvider, which ticks once a
    // second. Every mediaItem emission crosses to AudioServicePlugin's
    // setMediaItem, which builds a new single-thread executor, re-sets the
    // media-session metadata and re-posts the notification — once a second
    // that is ~3600 thread creations per playback hour and it makes AVRCP
    // displays on car head units restart their title scroll continuously.
    final container = _containerWith(playerFactory: FakeAudioTrackPlayer.new);
    final handler = KaraokeAudioHandler(container);
    final nowPlaying = container.read(nowPlayingProvider.notifier);
    await nowPlaying.play(_song, MusicSourceLogoStyle.soundcloud);

    final emitted = <MediaItem?>[];
    final subscription = handler.mediaItem.listen(emitted.add);
    addTearDown(subscription.cancel);
    await pumpEventQueue();
    // BehaviorSubject replays its (unset) current value to a new listener.
    final baseline = emitted.length;

    handler.syncFromPlayback();
    handler.syncFromPlayback();
    handler.syncFromPlayback();
    await pumpEventQueue();

    expect(
      emitted.length - baseline,
      1,
      reason: 'unchanged metadata must be published exactly once',
    );
    expect(emitted.last?.id, 'track-1');

    await nowPlaying.play(_otherSong, MusicSourceLogoStyle.soundcloud);
    handler.syncFromPlayback();
    handler.syncFromPlayback();
    await pumpEventQueue();

    expect(emitted.length - baseline, 2);
    expect(emitted.last?.id, 'track-2');
  });

  test('play_retries_a_failed_track_instead_of_no_opping', () async {
    // Both players are disposed on a terminal PlaybackFailed, so `_hasPlayback`
    // is false and the notification's play button used to be dead — leaving a
    // driver with no way to recover the session without picking up the head
    // unit.
    final platform = ToggleableLinkPlatform(failLink: true);
    final container = _containerWith(
      playerFactory: FakeAudioTrackPlayer.new,
      platform: platform,
    );
    final handler = KaraokeAudioHandler(container);
    await container
        .read(nowPlayingProvider.notifier)
        .play(_song, MusicSourceLogoStyle.soundcloud);
    expect(container.read(nowPlayingProvider).playback, isA<PlaybackFailed>());
    final failedCallCount = platform.linkCallCount;

    platform.failLink = false;
    await handler.play();
    await pumpEventQueue();

    expect(platform.linkCallCount, greaterThan(failedCallCount));
    expect(container.read(nowPlayingProvider).playback, isA<PlaybackReady>());
  });
}

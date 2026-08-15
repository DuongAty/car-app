import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remote_protocol/remote_protocol.dart';
import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/core/providers/volume_provider.dart';
import 'package:viet_ktv/features/playback/data/audio_track_player.dart';
import 'package:viet_ktv/features/playback/presentation/providers/now_playing_controller.dart';
import 'package:viet_ktv/features/queue/presentation/providers/queue_playback_controller.dart';
import 'package:viet_ktv/features/queue/presentation/providers/queue_provider.dart';
import 'package:viet_ktv/features/remote/data/remote_mappers.dart';
import 'package:viet_ktv/features/remote/presentation/providers/remote_session_provider.dart';
import 'package:viet_ktv/features/settings/presentation/providers/settings_controller.dart';
import 'package:viet_ktv/features/song_browser/data/models/song_item.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/music_sdk_repository_provider.dart';
import 'package:viet_ktv/features/source_selection/data/models/music_source.dart';

import '../../support/fake_audio_track_player.dart';
import '../../support/fake_local_storage_service.dart';
import '../../support/fake_music_sdk_platform.dart';
import '../../support/fake_remote_channel.dart';
import '../../support/fake_volume_service.dart';

const _pairingId = 'pairing-secret';

const _songA = SongItem(
  id: 'track-a',
  title: 'Bài A',
  subtitle: 'Ca sĩ A',
  duration: '00:30',
  thumbnailSeed: 1,
  badge: null,
);

const _songB = SongItem(
  id: 'track-b',
  title: 'Bài B',
  subtitle: 'Ca sĩ B',
  duration: '00:30',
  thumbnailSeed: 2,
  badge: null,
);

const _snapshot = SongSnapshot(
  id: 'track-c',
  title: 'Bài C',
  artist: 'Ca sĩ C',
  source: RemoteSource.soundcloud,
  durationLabel: '03:00',
);

MusicSource get _soundcloud =>
    RemoteMappers.musicSourceOf(RemoteSource.soundcloud);

/// Builds a container with a paired box and a fake channel, then waits until
/// the session has opened it. Everything downstream is the real thing.
Future<(ProviderContainer, FakeRemoteChannel)> _pairedSession() async {
  final channel = FakeRemoteChannel();
  final storage = FakeLocalStorageService()
    ..store[remotePairingIdStorageKey] = _pairingId;
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(storage),
      musicSdkPlatformProvider.overrideWithValue(FakeMusicSdkPlatform()),
      audioTrackPlayerFactoryProvider.overrideWithValue(
        FakeAudioTrackPlayer.new,
      ),
      volumeServiceProvider.overrideWithValue(FakeVolumeService()),
      remoteChannelProvider.overrideWithValue(channel),
    ],
  );
  addTearDown(container.dispose);

  container.read(remoteSessionProvider);
  await container.read(remotePairingIdProvider.notifier).loaded;
  await pumpEventQueue();
  return (container, channel);
}

void main() {
  test('a saved pairing id opens the channel', () async {
    final (_, channel) = await _pairedSession();

    expect(channel.connectedTo, [_pairingId]);
  });

  test('playPause pauses live playback', () async {
    final (container, channel) = await _pairedSession();
    await container
        .read(nowPlayingProvider.notifier)
        .play(_songA, MusicSourceLogoStyle.soundcloud);
    await pumpEventQueue();
    expect(container.read(nowPlayingProvider).audioIsPlaying, isTrue);

    channel.emitCommand(const PlayPauseCommand());
    await pumpEventQueue();

    expect(container.read(nowPlayingProvider).audioIsPlaying, isFalse);
  });

  test('next starts the first queued song', () async {
    final (container, channel) = await _pairedSession();
    container.read(queueProvider.notifier)
      ..add(_songA, _soundcloud)
      ..add(_songB, _soundcloud);

    channel.emitCommand(const NextCommand());
    await pumpEventQueue();

    expect(
      container.read(queuePlaybackControllerProvider).currentItem?.song.id,
      _songA.id,
    );
    // Real state, not a spy on the link resolver: a cached link would let a
    // replay pass that assertion without anything actually playing.
    final playback = container.read(nowPlayingProvider).playback;
    expect(playback, isA<PlaybackReady>());
    expect((playback as PlaybackReady).song.id, _songA.id);
  });

  test('addToQueue appends the song the phone sent', () async {
    final (container, channel) = await _pairedSession();

    channel.emitCommand(const AddToQueueCommand(_snapshot));
    await pumpEventQueue();

    final items = container.read(queueProvider).items;
    expect(items, hasLength(1));
    expect(items.single.song.id, _snapshot.id);
    expect(items.single.song.title, _snapshot.title);
    expect(items.single.source.logoStyle, MusicSourceLogoStyle.soundcloud);
    expect(RemoteMappers.entryId(items.single), 'soundcloud/track-c');
  });

  test('removeFromQueue deletes the row with that entry id', () async {
    final (container, channel) = await _pairedSession();
    container.read(queueProvider.notifier)
      ..add(_songA, _soundcloud)
      ..add(_songB, _soundcloud);

    channel.emitCommand(
      RemoveFromQueueCommand(
        RemoteMappers.entryIdFor(MusicSourceLogoStyle.soundcloud, _songA.id),
      ),
    );
    await pumpEventQueue();

    expect(container.read(queueProvider).items.map((item) => item.song.id), [
      _songB.id,
    ]);
  });

  test('removeFromQueue for an unknown entry id changes nothing', () async {
    final (container, channel) = await _pairedSession();
    container.read(queueProvider.notifier).add(_songA, _soundcloud);

    channel.emitCommand(const RemoveFromQueueCommand('soundcloud/gone'));
    await pumpEventQueue();

    expect(container.read(queueProvider).items, hasLength(1));
  });

  test('reorderQueue moves the row named by entry id', () async {
    final (container, channel) = await _pairedSession();
    container.read(queueProvider.notifier)
      ..add(_songA, _soundcloud)
      ..add(_songB, _soundcloud);

    channel.emitCommand(
      ReorderQueueCommand(
        entryId: RemoteMappers.entryIdFor(
          MusicSourceLogoStyle.soundcloud,
          _songA.id,
        ),
        toIndex: 1,
      ),
    );
    await pumpEventQueue();

    expect(container.read(queueProvider).items.map((item) => item.song.id), [
      _songB.id,
      _songA.id,
    ]);
  });

  test('clearQueue empties the queue', () async {
    final (container, channel) = await _pairedSession();
    container.read(queueProvider.notifier).add(_songA, _soundcloud);

    channel.emitCommand(const ClearQueueCommand());
    await pumpEventQueue();

    expect(container.read(queueProvider).items, isEmpty);
  });

  test('setVolume goes through settings so the level is persisted', () async {
    final (container, channel) = await _pairedSession();

    channel.emitCommand(const SetVolumeCommand(0.4));
    await pumpEventQueue();

    expect(container.read(settingsControllerProvider).masterVolume, 0.4);
    expect(container.read(volumeProvider).level, 0.4);
  });

  test('search answers with results tagged by the request id', () async {
    final (_, channel) = await _pairedSession();

    channel.emitCommand(
      const SearchCommand(query: 'Lạc Trôi', source: RemoteSource.youtube),
      id: 'req-42',
    );
    await pumpEventQueue();

    final payload = channel.sentSearchResults.single;
    expect(payload.requestId, 'req-42');
    expect(payload.isError, isFalse);
    expect(payload.results, isNotEmpty);
    expect(payload.results.first.source, RemoteSource.youtube);
  });

  test('a failing search answers with an error, not silence', () async {
    final channel = FakeRemoteChannel();
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(
          FakeLocalStorageService()
            ..store[remotePairingIdStorageKey] = _pairingId,
        ),
        musicSdkPlatformProvider.overrideWithValue(
          FakeMusicSdkPlatform(failSearch: true),
        ),
        audioTrackPlayerFactoryProvider.overrideWithValue(
          FakeAudioTrackPlayer.new,
        ),
        volumeServiceProvider.overrideWithValue(FakeVolumeService()),
        remoteChannelProvider.overrideWithValue(channel),
      ],
    );
    addTearDown(container.dispose);
    container.read(remoteSessionProvider);
    await container.read(remotePairingIdProvider.notifier).loaded;
    await pumpEventQueue();

    channel.emitCommand(
      const SearchCommand(query: 'gì đó', source: RemoteSource.youtube),
      id: 'req-7',
    );
    await pumpEventQueue();

    final payload = channel.sentSearchResults.single;
    expect(payload.requestId, 'req-7');
    expect(payload.isError, isTrue);
  });
}

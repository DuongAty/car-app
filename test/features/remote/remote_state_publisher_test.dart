import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remote_protocol/remote_protocol.dart';
import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/core/providers/volume_provider.dart';
import 'package:viet_ktv/features/playback/data/audio_track_player.dart';
import 'package:viet_ktv/features/playback/presentation/providers/now_playing_controller.dart';
import 'package:viet_ktv/features/queue/presentation/providers/queue_provider.dart';
import 'package:viet_ktv/features/remote/data/remote_mappers.dart';
import 'package:viet_ktv/features/remote/presentation/providers/remote_session_provider.dart';
import 'package:viet_ktv/features/remote/presentation/providers/remote_state_publisher.dart';
import 'package:viet_ktv/features/song_browser/data/models/song_item.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/music_sdk_repository_provider.dart';
import 'package:viet_ktv/features/source_selection/data/models/music_source.dart';

import '../../support/fake_audio_track_player.dart';
import '../../support/fake_local_storage_service.dart';
import '../../support/fake_music_sdk_platform.dart';
import '../../support/fake_remote_channel.dart';
import '../../support/fake_volume_service.dart';

const _pairingId = 'pairing-secret';

const _song = SongItem(
  id: 'track-a',
  title: 'Bài A',
  subtitle: 'Ca sĩ A',
  duration: '00:30',
  thumbnailSeed: 1,
  badge: null,
);

const _otherSong = SongItem(
  id: 'track-b',
  title: 'Bài B',
  subtitle: 'Ca sĩ B',
  duration: '00:30',
  thumbnailSeed: 2,
  badge: null,
);

MusicSource get _soundcloud =>
    RemoteMappers.musicSourceOf(RemoteSource.soundcloud);

ProviderContainer _container(FakeRemoteChannel channel, {bool paired = true}) {
  final storage = FakeLocalStorageService();
  if (paired) {
    storage.store[remotePairingIdStorageKey] = _pairingId;
  }
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
  return container;
}

/// Publisher wired by hand so the timings can be short enough to assert on.
/// Production always uses the 300ms/5s defaults.
Future<RemoteStatePublisher> _startPublisher(
  ProviderContainer container,
  FakeRemoteChannel channel, {
  Duration throttle = const Duration(milliseconds: 10),
  Duration heartbeat = const Duration(hours: 1),
}) async {
  final publisher = container.read(remoteStatePublisherProvider);
  publisher.bind(send: channel.send, carLabel: 'Xe thử');
  publisher.start(throttle: throttle, heartbeat: heartbeat);
  addTearDown(publisher.stop);
  // Let the asynchronous volume read land, so its (legitimate) publish is not
  // mistaken for one triggered by whatever the test does next.
  await pumpEventQueue();
  await Future<void>.delayed(const Duration(milliseconds: 40));
  return publisher;
}

void main() {
  test('an unpaired box publishes nothing and opens no channel', () async {
    final channel = FakeRemoteChannel();
    final container = _container(channel, paired: false);

    container.read(remoteSessionProvider);
    await container.read(remotePairingIdProvider.notifier).loaded;
    await pumpEventQueue();

    // The queue changing must not wake anything up: with no pairing id there
    // is no publisher to wake.
    container.read(queueProvider.notifier).add(_song, _soundcloud);
    await pumpEventQueue();

    expect(channel.connectedTo, isEmpty);
    expect(channel.sent, isEmpty);
  });

  test('a position-only change is not published', () async {
    final channel = FakeRemoteChannel();
    final container = _container(channel);
    await container
        .read(nowPlayingProvider.notifier)
        .play(_song, MusicSourceLogoStyle.soundcloud);
    await pumpEventQueue();

    await _startPublisher(container, channel);
    final before = channel.sentStates.length;

    // Moving the playhead is the once-a-second event the head unit generates
    // all day. It must not become a message.
    final player =
        container.read(nowPlayingProvider).audioPlayer! as FakeAudioTrackPlayer;
    await player.seek(const Duration(seconds: 7));
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(container.read(nowPlayingProvider).audioPosition.inSeconds, 7);
    expect(channel.sentStates.length, before);
  });

  test('a queue change is published', () async {
    final channel = FakeRemoteChannel();
    final container = _container(channel);
    await _startPublisher(container, channel);
    final before = channel.sentStates.length;

    container.read(queueProvider.notifier).add(_song, _soundcloud);
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(channel.sentStates.length, greaterThan(before));
    final latest = channel.sentStates.last;
    expect(latest.queue.single.entryId, 'soundcloud/${_song.id}');
    expect(latest.carLabel, 'Xe thử');
  });

  test('a track change and a pause are published', () async {
    final channel = FakeRemoteChannel();
    final container = _container(channel);
    await _startPublisher(container, channel);

    await container
        .read(nowPlayingProvider.notifier)
        .play(_otherSong, MusicSourceLogoStyle.soundcloud);
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(channel.sentStates.last.current?.id, _otherSong.id);
    expect(channel.sentStates.last.isPlaying, isTrue);

    final afterPlay = channel.sentStates.length;
    container.read(nowPlayingProvider.notifier).togglePlayPause();
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(channel.sentStates.length, greaterThan(afterPlay));
    expect(channel.sentStates.last.isPlaying, isFalse);
  });

  test('the heartbeat keeps publishing while nothing changes', () async {
    final channel = FakeRemoteChannel();
    final container = _container(channel);
    await _startPublisher(
      container,
      channel,
      heartbeat: const Duration(milliseconds: 30),
    );
    final before = channel.sentStates.length;

    await Future<void>.delayed(const Duration(milliseconds: 130));

    expect(channel.sentStates.length, greaterThanOrEqualTo(before + 3));
  });

  test('requestState publishes immediately', () async {
    final channel = FakeRemoteChannel();
    final container = _container(channel);

    container.read(remoteSessionProvider);
    await container.read(remotePairingIdProvider.notifier).loaded;
    await pumpEventQueue();
    final before = channel.sentStates.length;

    channel.emitCommand(const RequestStateCommand());
    await pumpEventQueue();

    expect(channel.sentStates.length, greaterThan(before));
  });
}

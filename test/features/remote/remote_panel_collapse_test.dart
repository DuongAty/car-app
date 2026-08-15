import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/core/providers/volume_provider.dart';
import 'package:viet_ktv/features/playback/data/audio_track_player.dart';
import 'package:viet_ktv/features/playback/presentation/providers/now_playing_controller.dart';
import 'package:viet_ktv/features/remote/presentation/providers/remote_session_provider.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/music_sdk_repository_provider.dart';

import '../../support/fake_audio_track_player.dart';
import '../../support/fake_local_storage_service.dart';
import '../../support/fake_music_sdk_platform.dart';
import '../../support/fake_remote_channel.dart';
import '../../support/fake_volume_service.dart';

const _pairingId = 'pairing-secret';

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

PlayerViewMode _mode(ProviderContainer container) =>
    container.read(nowPlayingProvider).mode;

/// Brings up the session for a paired box and waits for the channel to attach.
Future<void> _startSession(ProviderContainer container) async {
  container.read(remoteSessionProvider);
  await container.read(remotePairingIdProvider.notifier).loaded;
  await pumpEventQueue();
}

void main() {
  group('the search column collapses while a phone is driving', () {
    test('a phone joining collapses it', () async {
      final channel = FakeRemoteChannel();
      final container = _container(channel);
      await _startSession(container);
      expect(_mode(container), PlayerViewMode.normal);

      channel.emitPhoneOnline(true);
      await pumpEventQueue();

      expect(_mode(container), PlayerViewMode.wide);
    });

    test('the phone leaving gives it back', () async {
      final channel = FakeRemoteChannel();
      final container = _container(channel);
      await _startSession(container);

      channel.emitPhoneOnline(true);
      await pumpEventQueue();
      channel.emitPhoneOnline(false);
      await pumpEventQueue();

      expect(_mode(container), PlayerViewMode.normal);
    });

    test(
      'fullscreen is left alone — the phone does not pull the user out of it',
      () async {
        final channel = FakeRemoteChannel();
        final container = _container(channel);
        await _startSession(container);
        container.read(nowPlayingProvider.notifier).enterFullscreen();
        expect(_mode(container), PlayerViewMode.fullscreen);

        channel.emitPhoneOnline(true);
        await pumpEventQueue();

        expect(_mode(container), PlayerViewMode.fullscreen);
      },
    );

    test(
      'a layout the user chose by hand is not undone when the phone leaves',
      () async {
        final channel = FakeRemoteChannel();
        final container = _container(channel);
        await _startSession(container);

        channel.emitPhoneOnline(true);
        await pumpEventQueue();
        expect(_mode(container), PlayerViewMode.wide);

        // The user opens the column back up while the phone is still connected…
        container.read(nowPlayingProvider.notifier).toggleWide();
        expect(_mode(container), PlayerViewMode.normal);
        // …then collapses it again themselves.
        container.read(nowPlayingProvider.notifier).toggleWide();
        expect(_mode(container), PlayerViewMode.wide);

        channel.emitPhoneOnline(false);
        await pumpEventQueue();

        // Still collapsed: that was the user's press, not the phone's doing.
        expect(_mode(container), PlayerViewMode.wide);
      },
    );

    test('an unpaired box never changes layout', () async {
      final channel = FakeRemoteChannel();
      final container = _container(channel, paired: false);
      await _startSession(container);

      channel.emitPhoneOnline(true);
      await pumpEventQueue();

      expect(_mode(container), PlayerViewMode.normal);
      expect(channel.connectedTo, isEmpty);
    });
  });
}

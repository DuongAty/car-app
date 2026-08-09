import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

final audioTrackPlayerFactoryProvider = Provider<AudioTrackPlayerFactory>(
  (ref) => JustAudioTrackPlayer.new,
);

typedef AudioTrackPlayerFactory = AudioTrackPlayer Function();

abstract interface class AudioTrackPlayer {
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<bool> get playingStream;
  Stream<void> get completedStream;

  Future<void> setUrl(String url);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Future<void> dispose();
}

class JustAudioTrackPlayer implements AudioTrackPlayer {
  JustAudioTrackPlayer() {
    _completionSubscription = _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _completedController.add(null);
      }
    });
  }

  // just_audio's built-in interruption handling pauses on a duck event unless
  // usage is `game`, which is wrong for a car head unit — a navigation prompt
  // should lower the music, not stop it. PlaybackInterruptionHandler takes
  // over instead.
  final AudioPlayer _player = AudioPlayer(handleInterruptions: false);
  final StreamController<void> _completedController =
      StreamController<void>.broadcast();
  late final StreamSubscription<ProcessingState> _completionSubscription;

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Stream<bool> get playingStream => _player.playingStream;

  @override
  Stream<void> get completedStream => _completedController.stream;

  @override
  Future<void> setUrl(String url) => _player.setUrl(url);

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> dispose() async {
    await _completionSubscription.cancel();
    await _completedController.close();
    await _player.dispose();
  }
}

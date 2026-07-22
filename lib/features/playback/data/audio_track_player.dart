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

  final AudioPlayer _player = AudioPlayer();
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
  Future<void> dispose() async {
    await _completionSubscription.cancel();
    await _completedController.close();
    await _player.dispose();
  }
}

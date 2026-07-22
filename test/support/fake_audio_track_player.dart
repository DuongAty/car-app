import 'dart:async';

import 'package:viet_ktv/features/playback/data/audio_track_player.dart';

class FakeAudioTrackPlayer implements AudioTrackPlayer {
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durationController =
      StreamController<Duration?>.broadcast();
  final StreamController<bool> _playingController =
      StreamController<bool>.broadcast();
  final StreamController<void> _completedController =
      StreamController<void>.broadcast();

  String? url;
  Completer<void>? _playCompleter;
  int playCallCount = 0;
  int pauseCallCount = 0;

  /// Mirrors just_audio: firing `completed` also resolves the pending
  /// `play()` future, since real playback stops there too.
  void complete() {
    _completedController.add(null);
    _playCompleter?.complete();
    _playCompleter = null;
  }

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration?> get durationStream => _durationController.stream;

  @override
  Stream<bool> get playingStream => _playingController.stream;

  @override
  Stream<void> get completedStream => _completedController.stream;

  @override
  Future<void> setUrl(String url) async {
    this.url = url;
    _durationController.add(const Duration(seconds: 30));
    _positionController.add(Duration.zero);
  }

  @override
  Future<void> play() {
    playCallCount++;
    _playingController.add(true);
    // Real just_audio does not complete `play()` until playback stops,
    // pauses, or finishes — a naive `async {}` fake hides bugs where
    // production code mistakenly awaits it expecting an immediate return.
    final completer = Completer<void>();
    _playCompleter = completer;
    return completer.future;
  }

  @override
  Future<void> pause() async {
    pauseCallCount++;
    _playingController.add(false);
    _playCompleter?.complete();
    _playCompleter = null;
  }

  @override
  Future<void> dispose() async {
    await _positionController.close();
    await _durationController.close();
    await _playingController.close();
    await _completedController.close();
  }
}

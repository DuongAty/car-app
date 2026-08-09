import 'dart:async';

import 'package:viet_ktv/features/playback/data/audio_track_player.dart';

class FakeAudioTrackPlayer implements AudioTrackPlayer {
  // Real just_audio's position/duration/playing streams are backed by rxdart
  // BehaviorSubjects, which replay their latest value to any new subscriber —
  // see `durationStream` at just_audio.dart:480, which exposes that subject's
  // stream. `_durationSubject` (:137) and `_playingSubject` (:145) are seeded
  // (null / false); `_positionSubject` (:176, created at :695) is NOT seeded,
  // so it replays only once something has been emitted. Production code
  // (`_playAudioSource`) awaits
  // `setUrl` before subscribing, so it relies on that replay to see the
  // duration/position emitted during `setUrl`. A plain broadcast controller
  // drops those events for late subscribers, so we replay the last value
  // ourselves on `onListen` to match real just_audio. As with the real
  // BehaviorSubject-backed streams, this replay is asynchronous (delivered
  // a beat after `listen()` returns, not during it) — callers that need to
  // observe it must let the event loop turn once, e.g. via `pumpEventQueue`.
  late final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast(
        onListen: () {
          if (_lastPosition case final position?) {
            _positionController.add(position);
          }
        },
      );
  late final StreamController<Duration?> _durationController =
      StreamController<Duration?>.broadcast(
        onListen: () => _durationController.add(_lastDuration),
      );
  late final StreamController<bool> _playingController =
      StreamController<bool>.broadcast(
        onListen: () => _playingController.add(_lastPlaying),
      );
  final StreamController<void> _completedController =
      StreamController<void>.broadcast();

  // `_lastDuration`/`_lastPlaying` mirror just_audio's seeds (null / false).
  // `_lastPosition` starts at Duration.zero purely so the fake has a sane
  // resting position; real just_audio's position subject is unseeded, so do
  // not read fidelity into this particular value.
  Duration? _lastPosition = Duration.zero;
  Duration? _lastDuration;
  bool _lastPlaying = false;

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

  void _setPosition(Duration position) {
    _lastPosition = position;
    _positionController.add(position);
  }

  void _setDuration(Duration? duration) {
    _lastDuration = duration;
    _durationController.add(duration);
  }

  void _setPlaying(bool playing) {
    _lastPlaying = playing;
    _playingController.add(playing);
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
    _setDuration(const Duration(seconds: 30));
    _setPosition(Duration.zero);
  }

  @override
  Future<void> play() {
    playCallCount++;
    _setPlaying(true);
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
    _setPlaying(false);
    _playCompleter?.complete();
    _playCompleter = null;
  }

  Duration? lastSeek;
  double? lastVolume;

  @override
  Future<void> seek(Duration position) async {
    lastSeek = position;
    _setPosition(position);
  }

  @override
  Future<void> setVolume(double volume) async {
    lastVolume = volume;
  }

  @override
  Future<void> dispose() async {
    await _positionController.close();
    await _durationController.close();
    await _playingController.close();
    await _completedController.close();
  }
}

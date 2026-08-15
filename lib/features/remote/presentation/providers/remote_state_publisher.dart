import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remote_protocol/remote_protocol.dart';

import '../../../../core/providers/volume_provider.dart';
import '../../../playback/presentation/providers/now_playing_controller.dart';
import '../../../queue/presentation/providers/queue_playback_controller.dart';
import '../../../queue/presentation/providers/queue_provider.dart';
import '../../data/remote_mappers.dart';

/// Lives outside the widget tree; only created once a pairing id exists.
///
/// Reading this provider is what brings the publisher into being, so an
/// unpaired box never allocates it — no listeners, no timers, no cost.
final remoteStatePublisherProvider = Provider<RemoteStatePublisher>(
  (ref) => RemoteStatePublisher(ref),
);

/// Broadcasts [RemoteState] snapshots to the paired phone.
///
/// Three rules this class exists to enforce:
///
/// 1. It only ever `ref.listen`s. Making `nowPlayingProvider` depend on
///    anything volatile disposes and recreates it — that is what tore down the
///    live video decoder when the volume slider moved, and it must not come
///    back through this door.
/// 2. It never rebuilds head-unit UI, and it never publishes on the ~1s
///    playback tick: a snapshot that differs only in `positionMs` is dropped
///    (`RemoteState.equalsIgnoringPosition`). The phone interpolates its own
///    clock from `envelope.ts`.
/// 3. Sends are throttled, so a burst of changes (play → queue → buffering,
///    all within a frame) becomes one message rather than a storm.
class RemoteStatePublisher {
  RemoteStatePublisher(this._ref);

  static const Duration defaultThrottle = Duration(milliseconds: 300);

  /// Keeps a phone that joined mid-session, or missed a message on a flaky
  /// link, from showing a frozen player.
  static const Duration defaultHeartbeat = Duration(seconds: 5);

  final Ref _ref;

  Future<void> Function(RemoteEnvelope envelope)? _send;
  String? _carLabel;

  final List<ProviderSubscription<Object?>> _subscriptions = [];
  Timer? _throttleTimer;
  Timer? _heartbeatTimer;
  DateTime? _lastSentAt;
  RemoteState? _lastSent;
  bool _running = false;

  Duration _throttle = defaultThrottle;

  void bind({
    required Future<void> Function(RemoteEnvelope envelope) send,
    String? carLabel,
  }) {
    _send = send;
    _carLabel = carLabel;
  }

  bool get isRunning => _running;

  /// [throttle] and [heartbeat] are parameters only so tests can run on short
  /// timings; production always uses the defaults.
  void start({
    Duration throttle = defaultThrottle,
    Duration heartbeat = defaultHeartbeat,
  }) {
    if (_running) {
      return;
    }
    _running = true;
    _throttle = throttle;

    _subscriptions
      ..add(
        _ref.listen<NowPlayingState>(nowPlayingProvider, (_, _) => _schedule()),
      )
      ..add(_ref.listen<QueueState>(queueProvider, (_, _) => _schedule()))
      ..add(
        _ref.listen<QueuePlaybackState>(
          queuePlaybackControllerProvider,
          (_, _) => _schedule(),
        ),
      )
      ..add(_ref.listen<VolumeState>(volumeProvider, (_, _) => _schedule()));

    _heartbeatTimer = Timer.periodic(heartbeat, (_) => _publish(force: true));
    publishNow();
  }

  /// Answers `RequestStateCommand` — a phone that just joined should not have
  /// to wait for the next heartbeat to see anything.
  void publishNow() => _publish(force: true);

  void stop() {
    _running = false;
    _throttleTimer?.cancel();
    _throttleTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    for (final subscription in _subscriptions) {
      subscription.close();
    }
    _subscriptions.clear();
    _lastSent = null;
    _lastSentAt = null;
    _send = null;
  }

  void _schedule() {
    if (!_running || _throttleTimer != null) {
      return;
    }
    final lastSentAt = _lastSentAt;
    final elapsed = lastSentAt == null
        ? _throttle
        : DateTime.now().difference(lastSentAt);
    if (elapsed >= _throttle) {
      _publish();
      return;
    }
    _throttleTimer = Timer(_throttle - elapsed, () {
      _throttleTimer = null;
      _publish();
    });
  }

  void _publish({bool force = false}) {
    if (!_running) {
      return;
    }
    final send = _send;
    if (send == null) {
      return;
    }
    final snapshot = buildSnapshot();
    final previous = _lastSent;
    if (!force &&
        previous != null &&
        previous.equalsIgnoringPosition(snapshot)) {
      return;
    }
    _lastSent = snapshot;
    _lastSentAt = DateTime.now();
    unawaited(send(RemoteEnvelope.state(snapshot)));
  }

  /// Reads the current truth off the existing controllers. Public so a test
  /// can assert on the mapping without a channel.
  RemoteState buildSnapshot() {
    final now = _ref.read(nowPlayingProvider);
    final queue = _ref.read(queueProvider);
    final playback = _ref.read(queuePlaybackControllerProvider);
    final volume = _ref.read(volumeProvider);

    // The video branch keeps position/duration/playing inside the platform
    // controller's value; the audio branch mirrors them onto the state. Read
    // whichever one is live, exactly as `RailMiniPlayer` does.
    final video = now.videoController;
    final videoReady = video != null && video.value.isInitialized;
    final position = videoReady ? video.value.position : now.audioPosition;
    final duration = videoReady ? video.value.duration : now.audioDuration;
    final isPlaying = videoReady ? video.value.isPlaying : now.audioIsPlaying;

    final currentSong = switch (now.playback) {
      PlaybackLoading(:final song) => song,
      PlaybackReady(:final song) => song,
      PlaybackFailed(:final song) => song,
      PlaybackIdle() => null,
    };
    final durationMs = duration.inMilliseconds;

    final currentEntryId = playback.currentItem == null
        ? null
        : RemoteMappers.entryId(playback.currentItem!);

    return RemoteState(
      current: currentSong == null
          ? null
          : RemoteMappers.songSnapshot(
              currentSong,
              now.activeSource,
              durationMs: durationMs > 0 ? durationMs : null,
            ),
      isPlaying: isPlaying,
      isBuffering:
          now.playback is PlaybackLoading ||
          (videoReady && video.value.isBuffering),
      positionMs: position.inMilliseconds,
      durationMs: durationMs,
      volume: volume.level,
      volumeAvailable: volume.isAvailable,
      queue: [
        for (final item in queue.items)
          QueueEntrySnapshot(
            entryId: RemoteMappers.entryId(item),
            song: RemoteMappers.songSnapshot(item.song, item.source.logoStyle),
            isCurrent: RemoteMappers.entryId(item) == currentEntryId,
          ),
      ],
      repeatMode: RemoteMappers.repeatModeOf(queue.repeatMode),
      shuffle: queue.shuffle,
      carLabel: _carLabel,
    );
  }
}

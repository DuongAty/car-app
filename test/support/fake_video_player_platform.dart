import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// Minimal fake platform so `VideoPlayerController.initialize()` resolves
/// instead of throwing `MissingPluginException` (there is no real decoder in
/// the widget-test host) or hanging `pumpAndSettle()` while it retries.
class FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  FakeVideoPlayerPlatform({this.hangAssetInitialization = false});

  final bool hangAssetInitialization;
  final _eventControllers = <int, StreamController<VideoEvent>>{};
  final _assetPlayers = <int>{};
  int _nextPlayerId = 0;
  int? latestPlayerId;
  int playCallCount = 0;
  int pauseCallCount = 0;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    latestPlayerId = _nextPlayerId++;
    if (options.dataSource.sourceType == DataSourceType.asset) {
      _assetPlayers.add(latestPlayerId!);
    }
    return latestPlayerId;
  }

  void completeLatestVideo() {
    final playerId = latestPlayerId;
    if (playerId == null) {
      return;
    }
    _eventControllers[playerId]?.add(
      VideoEvent(eventType: VideoEventType.completed),
    );
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    // `VideoPlayerController.initialize()` awaits several platform calls
    // (createWithOptions, setPreventsDisplaySleepDuringVideoPlayback, ...)
    // before it ever calls `.listen()` here — several microtask turns after
    // createWithOptions returns. Firing the "initialized" event eagerly (e.g.
    // via scheduleMicrotask at creation time) loses the race: a broadcast
    // stream drops events emitted before anyone is subscribed, so
    // initialize()'s completer never resolves and the controller sits in
    // PlaybackLoading forever. Firing from `onListen` instead guarantees a
    // listener is already attached at the moment the event goes out.
    final controller = StreamController<VideoEvent>();
    controller.onListen = () {
      if (hangAssetInitialization && _assetPlayers.contains(playerId)) {
        return;
      }
      controller.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(seconds: 30),
          size: const Size(640, 360),
        ),
      );
    };
    _eventControllers[playerId] = controller;
    return controller.stream;
  }

  @override
  Future<void> dispose(int playerId) async {
    await _eventControllers.remove(playerId)?.close();
  }

  @override
  Future<void> setPreventsDisplaySleepDuringVideoPlayback(
    int playerId,
    bool value,
  ) async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> play(int playerId) async {
    playCallCount++;
  }

  @override
  Future<void> pause(int playerId) async {
    pauseCallCount++;
  }

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Widget buildView(int playerId) => const SizedBox.shrink();
}

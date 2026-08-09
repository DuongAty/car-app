import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/app_system_service.dart';
import '../../data/karaoke_audio_handler.dart';
import '../../data/playback_interruption_handler.dart';
import '../../data/video_track_selector.dart';
import 'now_playing_controller.dart';
import 'playback_lifecycle_observer.dart';

/// Set from `main()` once `AudioService.init` has returned.
KaraokeAudioHandler? audioHandler;

/// Keeps the notification in sync and runs the background behaviours.
///
/// Watched once from the app root so it lives for the whole app lifetime,
/// matching how `historyControllerProvider` is kept alive.
final backgroundPlaybackProvider = Provider<void>((ref) {
  final handler = audioHandler;
  final nowPlaying = ref.read(nowPlayingProvider.notifier);

  // Either path counts as playing. Used for non-resumable interruptions only —
  // see `PlaybackInterruptionHandler`'s field docs for why the video path is
  // excluded from the resumable (focus) ones.
  bool isAnythingPlaying() {
    final state = ref.read(nowPlayingProvider);
    return state.audioIsPlaying ||
        (state.videoController?.value.isPlaying ?? false);
  }

  final interruptions = PlaybackInterruptionHandler(
    source: AudioSessionInterruptionSource(),
    setDuckFactor: nowPlaying.setDuckFactor,
    pausePlayback: nowPlaying.pausePlayback,
    resumePlayback: nowPlaying.resumePlayback,
    isPlaying: () => ref.read(nowPlayingProvider).audioIsPlaying,
    isAnythingPlaying: isAnythingPlaying,
  );
  unawaited(interruptions.start());

  final observer = PlaybackLifecycleObserver(
    trackSelector: ref.read(videoTrackSelectorProvider),
    // `VideoPlayerController.playerId` is annotated `@visibleForTesting` by
    // the plugin, but it is the only way to reach `VideoPlayerPlatform`'s
    // untyped `getVideoTracks`/`selectVideoTrack` for the controller that is
    // actually playing — see the rationale on `VideoTrackSelector` in
    // `video_track_selector.dart`, which this reads for.
    // ignore: invalid_use_of_visible_for_testing_member
    videoPlayerId: () => ref.read(nowPlayingProvider).videoController?.playerId,
    pauseVisualizer: nowPlaying.pauseVisualizer,
    resumeVisualizer: nowPlaying.resumeVisualizer,
    isPlaying: isAnythingPlaying,
  );

  // One listener drives both the notification sync and the observer's
  // player-change hook, so the once-per-second tick is only walked once.
  ref.listen<NowPlayingState>(nowPlayingProvider, (previous, next) {
    handler?.syncFromPlayback();
    // ignore: invalid_use_of_visible_for_testing_member
    final previousPlayerId = previous?.videoController?.playerId;
    // ignore: invalid_use_of_visible_for_testing_member
    final nextPlayerId = next.videoController?.playerId;
    if (previousPlayerId != nextPlayerId) {
      // Auto-advance / steering-wheel Next created a new controller. If that
      // happened while backgrounded it still needs downscaling; the observer
      // ignores this while foregrounded.
      unawaited(observer.onPlayerChanged());
    }
  }, fireImmediately: true);

  final lifecycle = AppLifecycleListener(
    onPause: () => unawaited(observer.didBackground()),
    onResume: () => unawaited(observer.didForeground()),
  );

  unawaited(const AppSystemService().requestNotificationPermission());

  ref.onDispose(() {
    lifecycle.dispose();
    unawaited(interruptions.dispose());
  });
});

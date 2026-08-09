// prefer_initializing_formals fires on this constructor and is a false
// positive here: it suggests `this._trackSelector`, but a named parameter
// cannot be private — the analyzer's own fix produces `No named parameter
// with the name '_trackSelector'`. Private fields plus public named
// parameters is the only shape that compiles, so the lint is disabled for
// this file rather than the fields being renamed or made public. See
// `lib/features/playback/data/playback_interruption_handler.dart` for the
// same precedent.
// ignore_for_file: prefer_initializing_formals

import '../../data/video_track_selector.dart';

/// Reacts to the app moving between foreground and background.
///
/// It must never pause the primary player — keeping that running in the
/// background is the whole point of the feature. It only removes work nobody
/// can see: the video track is dropped to its smallest rendition and the
/// decorative visualizer is stopped.
class PlaybackLifecycleObserver {
  PlaybackLifecycleObserver({
    required VideoTrackSelector trackSelector,
    required int? Function() videoPlayerId,
    required void Function() pauseVisualizer,
    required void Function() resumeVisualizer,
    required bool Function() isPlaying,
  }) : _trackSelector = trackSelector,
       _videoPlayerId = videoPlayerId,
       _pauseVisualizer = pauseVisualizer,
       _resumeVisualizer = resumeVisualizer,
       _isPlaying = isPlaying;

  final VideoTrackSelector _trackSelector;
  final int? Function() _videoPlayerId;
  final void Function() _pauseVisualizer;
  final void Function() _resumeVisualizer;
  final bool Function() _isPlaying;

  int? _downscaledPlayerId;

  /// Set synchronously at the top of [didBackground] / [didForeground],
  /// *before* any await. `_downscaledPlayerId` cannot be used for this: it is
  /// only assigned after the platform round-trip in `downscaleToSmallest`
  /// returns, so a fast background→foreground bounce (recents swipe and back,
  /// a transient system dialog, a full-screen navigation prompt — all routine
  /// in a car) used to find it still null, return without restoring, and leave
  /// the foregrounded app showing a 144p stream until the next full cycle.
  bool _isBackgrounded = false;

  Future<void> didBackground() async {
    _isBackgrounded = true;
    _pauseVisualizer();
    await _downscaleActivePlayer();
  }

  /// Call when the active video player changes — the queue auto-advancing or a
  /// steering-wheel Next disposes the old controller and creates a new one.
  ///
  /// [didBackground] only fires on the `AppLifecycleState.paused` transition,
  /// so without this a player created *after* that never gets downscaled and
  /// song #2 onward would play at full adaptive quality with the screen off.
  /// A no-op while foregrounded.
  Future<void> onPlayerChanged() async {
    if (!_isBackgrounded) {
      return;
    }
    // The recorded downscale belongs to a player that no longer exists.
    _downscaledPlayerId = null;
    await _downscaleActivePlayer();
  }

  Future<void> _downscaleActivePlayer() async {
    // Loops rather than returns so that a lifecycle change landing inside one
    // of the platform round-trips below is acted on by the same chain, instead
    // of racing a concurrently started one and leaving the last write to
    // whichever call happens to resolve second.
    while (true) {
      final playerId = _videoPlayerId();
      if (playerId == null) {
        return;
      }
      final didDownscale = await _trackSelector.downscaleToSmallest(playerId);
      if (_videoPlayerId() != playerId) {
        // The track advanced while this call was in flight. A newer
        // `_downscaleActivePlayer` owns `_downscaledPlayerId` now, and the id
        // we are holding belongs to a disposed controller — writing it back
        // would make didForeground see a mismatch and never restore, leaving
        // the next song at its smallest rendition for its whole duration.
        return;
      }
      if (_isBackgrounded) {
        _downscaledPlayerId = didDownscale ? playerId : null;
        return;
      }
      // The app came back while the platform call was in flight, so
      // didForeground already ran and found nothing recorded to restore.
      // Undo the downscale now rather than leaving a blurry foreground video.
      _downscaledPlayerId = null;
      if (!didDownscale) {
        return;
      }
      await _trackSelector.restoreAdaptive(playerId);
      if (!_isBackgrounded || _videoPlayerId() != playerId) {
        return;
      }
      // The app went back to the background inside that restore round-trip, so
      // full quality is now being decoded where nobody can see it. Take it
      // down again.
    }
  }

  Future<void> didForeground() async {
    _isBackgrounded = false;
    if (_isPlaying()) {
      _resumeVisualizer();
    }
    // Restoring a quality we never lowered would override a pinned setting.
    final downscaledPlayerId = _downscaledPlayerId;
    if (downscaledPlayerId == null) {
      return;
    }
    final playerId = _videoPlayerId();
    _downscaledPlayerId = null;
    // The player identity changed while backgrounded (e.g. auto-advance to
    // the next queued song disposed the old controller) — the downscale we
    // recorded no longer applies to the current player, so do nothing rather
    // than restoring quality on a player we never touched.
    if (playerId == null || playerId != downscaledPlayerId) {
      return;
    }
    await _trackSelector.restoreAdaptive(playerId);
  }
}

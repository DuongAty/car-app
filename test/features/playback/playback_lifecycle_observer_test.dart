import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/features/playback/data/video_track_selector.dart';
import 'package:viet_ktv/features/playback/presentation/providers/playback_lifecycle_observer.dart';

class FakeVideoTrackSelector implements VideoTrackSelector {
  final List<int> downscaled = [];
  final List<int> restored = [];
  bool downscaleResult = true;

  /// When set, every `downscaleToSmallest` stalls on it — standing in for the
  /// platform round-trip so a test can interleave a foreground event with a
  /// downscale that is still in flight.
  Completer<void>? downscaleGate;

  /// Per-player gates, checked before [downscaleGate]. A single shared gate
  /// forces every in-flight downscale to complete in call order, which hides
  /// out-of-order platform responses; these let a test resolve a *newer*
  /// player's call before an older one's.
  final Map<int, Completer<void>> downscaleGates = {};

  /// Same idea for the restore round-trip, so a test can background the app
  /// while a restore is still in flight.
  Completer<void>? restoreGate;

  @override
  Future<bool> downscaleToSmallest(int playerId) async {
    downscaled.add(playerId);
    final gate = downscaleGates[playerId] ?? downscaleGate;
    if (gate != null) {
      await gate.future;
    }
    return downscaleResult;
  }

  @override
  Future<void> restoreAdaptive(int playerId) async {
    restored.add(playerId);
    final gate = restoreGate;
    if (gate != null) {
      await gate.future;
    }
  }
}

class _Harness {
  _Harness({this.playerId});

  final selector = FakeVideoTrackSelector();
  int? playerId;
  bool playing = true;
  int pauseVisualizerCallCount = 0;
  int resumeVisualizerCallCount = 0;

  late final PlaybackLifecycleObserver observer = PlaybackLifecycleObserver(
    trackSelector: selector,
    videoPlayerId: () => playerId,
    pauseVisualizer: () => pauseVisualizerCallCount++,
    resumeVisualizer: () => resumeVisualizerCallCount++,
    isPlaying: () => playing,
  );
}

void main() {
  test('backgrounding_downscales_the_active_video_track', () async {
    final harness = _Harness(playerId: 3);

    await harness.observer.didBackground();

    expect(harness.selector.downscaled, [3]);
  });

  test('returning_to_the_foreground_restores_adaptive_quality', () async {
    final harness = _Harness(playerId: 3);

    await harness.observer.didBackground();
    await harness.observer.didForeground();

    expect(harness.selector.restored, [3]);
  });

  test('does_not_restore_quality_it_never_downscaled', () async {
    // Nothing was changed on the way out, so nothing should be reset on the
    // way back in — that would override a quality the user pinned.
    final harness = _Harness(playerId: 3);
    harness.selector.downscaleResult = false;

    await harness.observer.didBackground();
    await harness.observer.didForeground();

    expect(harness.selector.restored, isEmpty);
  });

  test(
    'does_not_restore_quality_when_player_identity_changed_while_backgrounded',
    () async {
      // Auto-advance to the next queued song disposes the old
      // VideoPlayerController and creates a new one with a new playerId
      // while the app is backgrounded. Restoring on that new player would
      // override a quality the user may have pinned for it.
      final harness = _Harness(playerId: 3);

      await harness.observer.didBackground();
      harness.playerId = 7;
      await harness.observer.didForeground();

      expect(harness.selector.restored, isEmpty);
    },
  );

  test('backgrounding_pauses_the_visualizer', () async {
    // The visualizer is decorative; decoding it unseen wastes CPU on a 2GB box.
    final harness = _Harness(playerId: 3);

    await harness.observer.didBackground();

    expect(harness.pauseVisualizerCallCount, 1);
  });

  test('resumes_the_visualizer_only_when_audio_is_still_playing', () async {
    final harness = _Harness(playerId: 3);
    await harness.observer.didBackground();
    harness.playing = false;

    await harness.observer.didForeground();

    expect(harness.resumeVisualizerCallCount, 0);

    harness.playing = true;
    await harness.observer.didForeground();

    expect(harness.resumeVisualizerCallCount, 1);
  });

  test('downscales_a_player_created_while_backgrounded', () async {
    // didBackground only fires on the paused transition. When the queue
    // auto-advances (or the steering-wheel Next is pressed) with the screen
    // off, the new controller must be downscaled too — otherwise song #2
    // onward plays at full adaptive quality and the feature holds for exactly
    // one track.
    final harness = _Harness(playerId: 3);
    await harness.observer.didBackground();

    harness.playerId = 7;
    await harness.observer.onPlayerChanged();

    expect(harness.selector.downscaled, [3, 7]);
  });

  test('restores_the_player_that_was_downscaled_after_an_advance', () async {
    final harness = _Harness(playerId: 3);
    await harness.observer.didBackground();
    harness.playerId = 7;
    await harness.observer.onPlayerChanged();

    await harness.observer.didForeground();

    expect(harness.selector.restored, [7]);
  });

  test('a_player_change_while_foregrounded_is_a_no_op', () async {
    final harness = _Harness(playerId: 3);

    harness.playerId = 7;
    await harness.observer.onPlayerChanged();

    expect(harness.selector.downscaled, isEmpty);
    expect(harness.selector.restored, isEmpty);
  });

  test('a_fast_background_foreground_bounce_still_restores_quality', () async {
    // Recents swipe and back, a transient system dialog, a full-screen
    // navigation prompt — all routine in a car. didForeground runs while the
    // downscale round-trip is still in flight, so it finds nothing recorded to
    // restore. The downscale must undo itself rather than leaving the
    // foregrounded app displaying 144p until the next full cycle.
    final harness = _Harness(playerId: 3);
    final gate = Completer<void>();
    harness.selector.downscaleGate = gate;

    final backgrounding = harness.observer.didBackground();
    await harness.observer.didForeground();
    gate.complete();
    await backgrounding;

    expect(harness.selector.downscaled, [3]);
    expect(harness.selector.restored, [3]);
  });

  test('a_bounce_does_not_restore_a_downscale_that_never_happened', () async {
    final harness = _Harness(playerId: 3);
    harness.selector.downscaleResult = false;
    final gate = Completer<void>();
    harness.selector.downscaleGate = gate;

    final backgrounding = harness.observer.didBackground();
    await harness.observer.didForeground();
    gate.complete();
    await backgrounding;

    expect(harness.selector.restored, isEmpty);
  });

  test('a_late_downscale_response_does_not_overwrite_a_newer_player', () async {
    // The queue advances while the first downscale is still in flight and the
    // newer player's call resolves first. The older call's late return used to
    // write the disposed player's id into `_downscaledPlayerId`, so
    // didForeground saw a mismatch and never restored — the next song then
    // played its whole duration at the smallest rendition.
    final harness = _Harness(playerId: 3);
    final oldGate = Completer<void>();
    final newGate = Completer<void>();
    harness.selector.downscaleGates[3] = oldGate;
    harness.selector.downscaleGates[7] = newGate;

    final backgrounding = harness.observer.didBackground();
    await pumpEventQueue();

    harness.playerId = 7;
    final advancing = harness.observer.onPlayerChanged();
    await pumpEventQueue();

    // The newer player's platform call comes back first...
    newGate.complete();
    await advancing;
    // ...and the older, now-disposed player's call lands afterwards.
    oldGate.complete();
    await backgrounding;

    await harness.observer.didForeground();

    expect(harness.selector.downscaled, [3, 7]);
    expect(harness.selector.restored, [7]);
  });

  test('a_background_landing_inside_a_restore_re_downscales', () async {
    // Bounce out and back: the undo restore is in flight when the app is
    // backgrounded again. Checking `_isBackgrounded` only once before the
    // restore leaves full quality being decoded with the screen off, and the
    // late `_downscaledPlayerId = null` clobbers the new downscale's record so
    // the next foreground never restores either.
    final harness = _Harness(playerId: 3);
    final downGate = Completer<void>();
    final restoreDone = Completer<void>();
    harness.selector.downscaleGates[3] = downGate;
    harness.selector.restoreGate = restoreDone;

    final backgrounding = harness.observer.didBackground();
    await harness.observer.didForeground();
    // The downscale returns after the app is already visible, so it undoes
    // itself — and that restore stalls on `restoreDone`.
    downGate.complete();
    await pumpEventQueue();
    expect(harness.selector.restored, [3]);

    // Backgrounded again while the restore is still in flight.
    harness.selector.downscaleGates.remove(3);
    final rebackgrounding = harness.observer.didBackground();
    restoreDone.complete();
    await backgrounding;
    await rebackgrounding;

    // Three downscales: the original, the re-background's, and the re-apply
    // that follows the late restore.
    expect(harness.selector.downscaled, [3, 3, 3]);

    await harness.observer.didForeground();
    expect(harness.selector.restored, [3, 3]);
  });

  test('audio_only_playback_touches_no_video_track', () async {
    final harness = _Harness();

    await harness.observer.didBackground();
    await harness.observer.didForeground();

    expect(harness.selector.downscaled, isEmpty);
    expect(harness.selector.restored, isEmpty);
    expect(harness.pauseVisualizerCallCount, 1);
  });
}

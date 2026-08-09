// prefer_initializing_formals fires on this file's constructors and is a false
// positive here: it suggests `this._source`, but a named parameter cannot be
// private — the analyzer's own fix produces `No named parameter with the name
// '_source'`. Private fields plus public named parameters is the only shape
// that compiles, so the lint is disabled for this file rather than the fields
// being renamed or made public.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

/// Volume multiplier applied while another app holds transient focus, such as
/// a navigation prompt.
const double kDuckFactor = 0.2;

enum PlaybackInterruption { duck, pause }

class InterruptionSignal {
  const InterruptionSignal({
    required this.type,
    required this.begin,
    this.resumable = true,
  });

  final PlaybackInterruption type;
  final bool begin;

  /// Whether focus is expected to come back, making an automatic resume
  /// correct once the interruption ends.
  ///
  /// False means "pause, and never auto-resume". A becoming-noisy event
  /// (headphones unplugged, Bluetooth link dropped) is the case: no matching
  /// end event ever arrives because focus was never lost, and resuming later
  /// would blast the box speaker.
  final bool resumable;
}

/// Port over `audio_session` so the handler is testable without a platform.
abstract interface class AudioInterruptionSource {
  Stream<InterruptionSignal> get signals;
  Future<void> configure();
  Future<void> dispose();
}

/// Maps an `audio_session` interruption event onto an [InterruptionSignal].
///
/// Extracted from the stream subscription so the mapping — in particular which
/// events are [InterruptionSignal.resumable] — is testable without a platform.
@visibleForTesting
InterruptionSignal interruptionSignalFrom(AudioInterruptionEvent event) {
  return InterruptionSignal(
    // `duck` is the only genuinely transient type; `pause` and `unknown`
    // both mean the audio must actually stop.
    type: event.type == AudioInterruptionType.duck
        ? PlaybackInterruption.duck
        : PlaybackInterruption.pause,
    begin: event.begin,
    // On Android a *permanent* focus loss (`AndroidAudioFocus.loss`) arrives as
    // `unknown` with `begin: true`, and no matching end event ever follows —
    // only `AndroidAudioFocus.gain` produces `begin: false`
    // (audio_session-0.2.4/lib/src/core.dart:255-267). Marking it resumable
    // would arm the auto-resume forever, so an unrelated app taking and
    // releasing transient focus much later would restart karaoke by itself.
    resumable: event.type != AudioInterruptionType.unknown,
  );
}

class AudioSessionInterruptionSource implements AudioInterruptionSource {
  @override
  Stream<InterruptionSignal> get signals => _controller.stream;

  final StreamController<InterruptionSignal> _controller =
      StreamController<InterruptionSignal>.broadcast();
  StreamSubscription<AudioInterruptionEvent>? _subscription;
  StreamSubscription<void>? _becomingNoisySubscription;

  @override
  Future<void> configure() async {
    if (_subscription != null) return;
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    // just_audio normally wires this itself, but only when
    // `handleInterruptions` is true (just_audio-0.10.6/lib/just_audio.dart:
    // 370-375) — and that flag is off here because the same switch also makes
    // it pause on duck events. Becoming-noisy must still be honoured: without
    // it, unplugging headphones or dropping the Bluetooth link keeps playing
    // and blasts the box speaker.
    _becomingNoisySubscription = session.becomingNoisyEventStream.listen((_) {
      _controller.add(
        const InterruptionSignal(
          type: PlaybackInterruption.pause,
          begin: true,
          // The output route is gone for good; focus never returns, so there
          // must be no auto-resume.
          resumable: false,
        ),
      );
    });
    _subscription = session.interruptionEventStream.listen((event) {
      _controller.add(interruptionSignalFrom(event));
    });
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _becomingNoisySubscription?.cancel();
    _becomingNoisySubscription = null;
    await _controller.close();
  }
}

/// Applies audio focus interruptions to the just_audio path only.
///
/// The video path is deliberately excluded: ExoPlayer requests focus itself
/// there and already ducks and pauses correctly, so a second layer would act
/// twice.
class PlaybackInterruptionHandler {
  PlaybackInterruptionHandler({
    required AudioInterruptionSource source,
    required void Function(double factor) setDuckFactor,
    required void Function() pausePlayback,
    required void Function() resumePlayback,
    required bool Function() isPlaying,
    required bool Function() isAnythingPlaying,
  }) : _source = source,
       _setDuckFactor = setDuckFactor,
       _pausePlayback = pausePlayback,
       _resumePlayback = resumePlayback,
       _isPlaying = isPlaying,
       _isAnythingPlaying = isAnythingPlaying;

  final AudioInterruptionSource _source;
  final void Function(double factor) _setDuckFactor;
  final void Function() _pausePlayback;
  final void Function() _resumePlayback;

  /// True while the just_audio path is playing.
  ///
  /// Used for *resumable* signals only: the video path is deliberately left to
  /// ExoPlayer's own focus handling, so a transient focus loss must not make
  /// this handler pause the video as well.
  final bool Function() _isPlaying;

  /// True while *either* path is playing.
  ///
  /// Used for non-resumable signals (becoming noisy). Those are not focus
  /// events at all — the output route is simply gone — so nobody else handles
  /// them: `video_player_android` never calls
  /// `setHandleAudioBecomingNoisy(true)` and ExoPlayer defaults it off. Without
  /// this the Bluetooth link dropping mid-song would dump YouTube audio into
  /// the head-unit speaker at full volume.
  final bool Function() _isAnythingPlaying;

  StreamSubscription<InterruptionSignal>? _subscription;
  bool _pausedByInterruption = false;

  Future<void> start() async {
    if (_subscription != null) return;
    await _source.configure();
    _subscription = _source.signals.listen(_handle);
  }

  void _handle(InterruptionSignal signal) {
    switch (signal.type) {
      case PlaybackInterruption.duck:
        _setDuckFactor(signal.begin ? kDuckFactor : 1.0);
      case PlaybackInterruption.pause:
        if (signal.begin) {
          // A non-resumable signal (becoming noisy, permanent focus loss)
          // disarms the auto-resume unconditionally — even when playback is
          // already paused. Otherwise unplugging the headphones *during* a
          // navigation prompt leaves the flag armed from the prompt, and the
          // prompt ending resumes into the box speaker.
          if (!signal.resumable) {
            _pausedByInterruption = false;
          }
          // Only remember the pause if we were the ones who stopped playback,
          // so that regaining focus never starts music the user had paused.
          if (signal.resumable ? _isPlaying() : _isAnythingPlaying()) {
            _pausedByInterruption = signal.resumable;
            _pausePlayback();
          }
        } else if (_pausedByInterruption) {
          _pausedByInterruption = false;
          _resumePlayback();
        }
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _source.dispose();
  }
}

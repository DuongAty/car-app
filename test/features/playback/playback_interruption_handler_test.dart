import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/features/playback/data/audio_track_player.dart';
import 'package:viet_ktv/features/playback/data/playback_interruption_handler.dart';
import 'package:viet_ktv/features/playback/presentation/providers/now_playing_controller.dart';
import 'package:viet_ktv/features/song_browser/data/models/song_item.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/music_sdk_repository_provider.dart';
import 'package:viet_ktv/features/source_selection/data/models/music_source.dart';

import '../../support/fake_audio_track_player.dart';
import '../../support/fake_local_storage_service.dart';
import '../../support/fake_music_sdk_platform.dart';

class FakeInterruptionSource implements AudioInterruptionSource {
  FakeInterruptionSource({this.closeControllerOnDispose = true});

  /// When false, `dispose()` records the call but leaves [_controller] open,
  /// so tests can push a signal through the stream after disposal to prove
  /// the *handler* (not the source) is what stops reacting.
  final bool closeControllerOnDispose;

  final StreamController<InterruptionSignal> _controller =
      StreamController<InterruptionSignal>.broadcast();
  int configureCallCount = 0;
  int disposeCallCount = 0;

  void emit(
    PlaybackInterruption type, {
    required bool begin,
    bool resumable = true,
  }) {
    if (_controller.isClosed) return;
    _controller.add(
      InterruptionSignal(type: type, begin: begin, resumable: resumable),
    );
  }

  /// What `AudioSessionInterruptionSource` publishes for a becoming-noisy
  /// event: headphones unplugged or the Bluetooth link dropped.
  void emitBecomingNoisy() =>
      emit(PlaybackInterruption.pause, begin: true, resumable: false);

  @override
  Stream<InterruptionSignal> get signals => _controller.stream;

  @override
  Future<void> configure() async => configureCallCount++;

  @override
  Future<void> dispose() async {
    disposeCallCount++;
    if (closeControllerOnDispose) {
      await _controller.close();
    }
  }
}

class _Harness {
  _Harness({
    this.playing = true,
    this.videoPlaying = false,
    FakeInterruptionSource? source,
  }) : source = source ?? FakeInterruptionSource();

  final FakeInterruptionSource source;
  final ducks = <double>[];
  int pauseCallCount = 0;
  int resumeCallCount = 0;

  /// The just_audio path — what `NowPlayingState.audioIsPlaying` reports.
  bool playing;

  /// The YouTube `VideoPlayerController` path, which `audioIsPlaying` never
  /// reflects.
  bool videoPlaying;

  late final PlaybackInterruptionHandler handler = PlaybackInterruptionHandler(
    source: source,
    setDuckFactor: ducks.add,
    pausePlayback: () {
      pauseCallCount++;
      playing = false;
      videoPlaying = false;
    },
    resumePlayback: () {
      resumeCallCount++;
      playing = true;
    },
    isPlaying: () => playing,
    isAnythingPlaying: () => playing || videoPlaying,
  );

  Future<void> start() async {
    await handler.start();
  }

  /// Signals travel through a broadcast stream, so give the microtask queue a
  /// turn before asserting.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  Future<void> close() async {
    await handler.dispose();
  }
}

void main() {
  test('configures_the_audio_session_on_start', () async {
    final harness = _Harness();
    await harness.start();
    addTearDown(harness.close);

    expect(harness.source.configureCallCount, 1);
  });

  test('ducks_instead_of_pausing_for_a_transient_interruption', () async {
    // A navigation prompt must lower the music, not stop it.
    final harness = _Harness();
    await harness.start();
    addTearDown(harness.close);

    harness.source.emit(PlaybackInterruption.duck, begin: true);
    await harness.settle();

    expect(harness.ducks, [kDuckFactor]);
    expect(harness.pauseCallCount, 0);
  });

  test('restores_full_volume_when_the_duck_ends', () async {
    final harness = _Harness();
    await harness.start();
    addTearDown(harness.close);

    harness.source.emit(PlaybackInterruption.duck, begin: true);
    harness.source.emit(PlaybackInterruption.duck, begin: false);
    await harness.settle();

    expect(harness.ducks, [kDuckFactor, 1.0]);
  });

  test('pauses_on_real_focus_loss_and_resumes_afterwards', () async {
    final harness = _Harness();
    await harness.start();
    addTearDown(harness.close);

    harness.source.emit(PlaybackInterruption.pause, begin: true);
    await harness.settle();
    expect(harness.pauseCallCount, 1);

    harness.source.emit(PlaybackInterruption.pause, begin: false);
    await harness.settle();
    expect(harness.resumeCallCount, 1);
  });

  test('does_not_resume_playback_that_was_already_paused', () async {
    // The user paused before the call arrived; hanging up must not start music.
    final harness = _Harness(playing: false);
    await harness.start();
    addTearDown(harness.close);

    harness.source.emit(PlaybackInterruption.pause, begin: true);
    harness.source.emit(PlaybackInterruption.pause, begin: false);
    await harness.settle();

    expect(harness.pauseCallCount, 0);
    expect(harness.resumeCallCount, 0);
  });

  test('pauses_when_the_audio_output_becomes_noisy', () async {
    // Task 4 set `AudioPlayer(handleInterruptions: false)` to stop just_audio
    // pausing on duck events, but the same flag also gates just_audio's
    // becoming-noisy handling (just_audio-0.10.6/lib/just_audio.dart:370-375).
    // Without this, unplugging headphones or dropping the Bluetooth link keeps
    // playing and blasts the box speaker.
    final harness = _Harness();
    await harness.start();
    addTearDown(harness.close);

    harness.source.emitBecomingNoisy();
    await harness.settle();

    expect(harness.pauseCallCount, 1);
    expect(harness.ducks, isEmpty);
  });

  test('never_auto_resumes_after_becoming_noisy', () async {
    // Focus was never lost, so no matching "end" event is coming — and if an
    // unrelated focus return arrives later, resuming would play out of the
    // wrong speaker.
    final harness = _Harness();
    await harness.start();
    addTearDown(harness.close);

    harness.source.emitBecomingNoisy();
    await harness.settle();
    expect(harness.pauseCallCount, 1);

    harness.source.emit(PlaybackInterruption.pause, begin: false);
    await harness.settle();

    expect(harness.resumeCallCount, 0);
  });

  test('pauses_the_video_path_when_the_audio_output_becomes_noisy', () async {
    // `audioIsPlaying` is only ever set on the just_audio path, so during
    // YouTube playback the audio-only predicate is false. Nothing else handles
    // becoming-noisy for the video path — `video_player_android` never calls
    // `setHandleAudioBecomingNoisy(true)` and ExoPlayer defaults it off — so
    // dropping the Bluetooth link mid-song used to blast the head-unit speaker.
    final harness = _Harness(playing: false, videoPlaying: true);
    await harness.start();
    addTearDown(harness.close);

    harness.source.emitBecomingNoisy();
    await harness.settle();

    expect(harness.pauseCallCount, 1);
    expect(harness.ducks, isEmpty);
  });

  test('a_transient_focus_loss_leaves_the_video_path_to_exoplayer', () async {
    // The mirror of the test above: resumable (focus) signals must keep using
    // the audio-only predicate. ExoPlayer requests and handles focus itself for
    // the video path, so pausing here too would double-handle it.
    final harness = _Harness(playing: false, videoPlaying: true);
    await harness.start();
    addTearDown(harness.close);

    harness.source.emit(PlaybackInterruption.pause, begin: true);
    await harness.settle();

    expect(harness.pauseCallCount, 0);
  });

  test('a_non_resumable_signal_disarms_an_armed_resume', () async {
    // Headphones unplugged *during* a navigation prompt. The prompt armed
    // `_pausedByInterruption`; playback is already paused so the becoming-noisy
    // signal pauses nothing — but it must still disarm, or the prompt ending
    // resumes into the box speaker.
    final harness = _Harness();
    await harness.start();
    addTearDown(harness.close);

    harness.source.emit(PlaybackInterruption.pause, begin: true);
    await harness.settle();
    expect(harness.pauseCallCount, 1);
    expect(harness.playing, isFalse);

    harness.source.emitBecomingNoisy();
    await harness.settle();

    harness.source.emit(PlaybackInterruption.pause, begin: false);
    await harness.settle();

    expect(harness.resumeCallCount, 0);
  });

  group('mapping audio_session events', () {
    test('a_permanent_focus_loss_is_not_resumable', () async {
      // On Android `AndroidAudioFocus.loss` arrives as `unknown` with
      // `begin: true` and no matching end event ever follows — only `gain`
      // produces `begin: false` (audio_session-0.2.4/lib/src/core.dart:
      // 255-267). Marked resumable, `_pausedByInterruption` stays armed
      // forever and an unrelated app's transient focus release restarts
      // karaoke by itself.
      final signal = interruptionSignalFrom(
        AudioInterruptionEvent(true, AudioInterruptionType.unknown),
      );

      expect(signal.type, PlaybackInterruption.pause);
      expect(signal.begin, isTrue);
      expect(signal.resumable, isFalse);
    });

    test('a_transient_focus_loss_stays_resumable', () async {
      final signal = interruptionSignalFrom(
        AudioInterruptionEvent(true, AudioInterruptionType.pause),
      );

      expect(signal.type, PlaybackInterruption.pause);
      expect(signal.resumable, isTrue);
    });

    test('a_duck_maps_to_a_resumable_duck', () async {
      final signal = interruptionSignalFrom(
        AudioInterruptionEvent(true, AudioInterruptionType.duck),
      );

      expect(signal.type, PlaybackInterruption.duck);
      expect(signal.resumable, isTrue);
    });
  });

  test('dispose_cancels_the_handlers_own_subscription', () async {
    // Keep the source's controller open across dispose so a post-dispose
    // signal genuinely reaches the stream. This isolates whether the
    // *handler* cancelled its own subscription, independent of the source
    // cascading its own shutdown (covered by
    // disposing_the_handler_also_disposes_its_source below).
    final harness = _Harness(
      source: FakeInterruptionSource(closeControllerOnDispose: false),
    );
    await harness.start();
    await harness.handler.dispose();

    harness.source.emit(PlaybackInterruption.duck, begin: true);
    await harness.settle();

    expect(harness.ducks, isEmpty);
  });

  test('disposing_the_handler_also_disposes_its_source', () async {
    final harness = _Harness();
    await harness.start();

    await harness.handler.dispose();

    expect(harness.source.disposeCallCount, 1);
  });

  test('starting_twice_does_not_duplicate_the_subscription', () async {
    final harness = _Harness();
    await harness.start();
    await harness.start();
    addTearDown(harness.close);

    harness.source.emit(PlaybackInterruption.duck, begin: true);
    await harness.settle();

    expect(harness.ducks, [kDuckFactor]);
  });

  group('regression: resuming after playback was restored by other means', () {
    // Reproduces the real bug: `pausePlayback`/`resumePlayback` used to both
    // be wired to `NowPlayingController.togglePlayPause` in
    // background_playback_provider.dart. Sequence: focus is lost (handler
    // pauses and remembers `_pausedByInterruption = true`), the user resumes
    // playback themselves (steering wheel / notification) while focus is
    // still lost, then focus returns and the handler still thinks it owes a
    // resume. With toggle-based wiring that flips already-playing music back
    // to paused — exactly backwards. With NowPlayingController's explicit,
    // idempotent `pausePlayback`/`resumePlayback` (mirroring
    // `togglePlayPause`'s per-path handling but only acting when it changes
    // the state), the stray resume call is a no-op and playback stays
    // playing.
    const song = SongItem(
      id: 'track-1',
      title: 'Test Song',
      subtitle: 'SoundCloud',
      duration: '00:30',
      thumbnailSeed: 1,
      badge: null,
    );

    ProviderContainer buildContainer(FakeAudioTrackPlayer player) {
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(
            FakeLocalStorageService(),
          ),
          musicSdkPlatformProvider.overrideWithValue(FakeMusicSdkPlatform()),
          audioTrackPlayerFactoryProvider.overrideWithValue(() => player),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('ends up playing, not paused, after focus returns', () async {
      final player = FakeAudioTrackPlayer();
      final container = buildContainer(player);
      final controller = container.read(nowPlayingProvider.notifier);
      await controller.play(song, MusicSourceLogoStyle.soundcloud);
      await pumpEventQueue();

      final source = FakeInterruptionSource();
      final handler = PlaybackInterruptionHandler(
        source: source,
        setDuckFactor: controller.setDuckFactor,
        // The fix: explicit, idempotent intent methods rather than
        // `controller.togglePlayPause` for both.
        pausePlayback: controller.pausePlayback,
        resumePlayback: controller.resumePlayback,
        isPlaying: () => container.read(nowPlayingProvider).audioIsPlaying,
        isAnythingPlaying: () =>
            container.read(nowPlayingProvider).audioIsPlaying,
      );
      await handler.start();
      addTearDown(handler.dispose);

      // 1. Navigation prompt takes focus: handler pauses playback.
      source.emit(PlaybackInterruption.pause, begin: true);
      await pumpEventQueue();
      expect(container.read(nowPlayingProvider).audioIsPlaying, isFalse);

      // 2. User resumes playback by other means (steering wheel button /
      // notification) while focus is still lost. `_pausedByInterruption`
      // inside the handler is left `true` — nothing clears it.
      controller.togglePlayPause();
      await pumpEventQueue();
      expect(container.read(nowPlayingProvider).audioIsPlaying, isTrue);

      // 3. Focus returns: handler still thinks it owes a resume.
      source.emit(PlaybackInterruption.pause, begin: false);
      await pumpEventQueue();

      expect(container.read(nowPlayingProvider).audioIsPlaying, isTrue);
    });
  });
}

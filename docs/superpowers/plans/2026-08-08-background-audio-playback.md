# Background Audio Playback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep karaoke audio playing when the app is backgrounded, under a
foreground service with a full media notification, ducking for navigation
prompts, and with backgrounded video decode cut to near zero.

**Architecture:** `audio_service` supplies the foreground service, notification,
and `MediaSession`; a `BaseAudioHandler` delegates to the existing
`NowPlayingController` and `QueuePlaybackController` through a `ProviderContainer`
built in `main()`. Audio focus is handled asymmetrically on purpose — ExoPlayer
already does the right thing on the video path, so only the `just_audio` path
gets explicit interruption handling. An app-lifecycle observer downscales the
video track and pauses the visualizer while backgrounded.

**Tech Stack:** Flutter, Riverpod (`StateNotifier`), `audio_service`,
`audio_session`, `just_audio`, `video_player` + `video_player_platform_interface`.

**Spec:** `docs/superpowers/specs/2026-08-08-background-audio-playback-design.md`

## Global Constraints

- **Do not run any git write command.** No `git add`, `git commit`, `git push`.
  The user manages git themselves. This overrides the usual per-task commit
  step; every task ends at "tests pass".
- `AndroidManifest.xml` and `MainActivity.kt` carry uncommitted local edits.
  All changes to them must be **additive**. Read the current file first; never
  overwrite the working tree.
- Android 10 (API 29) minimum. Primary targets: 2GB RAM Android TV/karaoke
  boxes and car head units.
- `flutter analyze` must be clean and `dart format .` must be run before any
  task is considered done.
- Never `ref.watch` a volatile setting inside `nowPlayingProvider`'s create body
  — it disposes the live decoder. Seed with `ref.read`, apply changes via
  `ref.listen`.
- Tests that build `songBrowserProvider` must override
  `localStorageServiceProvider` with `FakeLocalStorageService`, or
  `pumpAndSettle` times out.
- Test names are snake_case behavioural names, matching `test/volume_test.dart`.
- Do not add a `permission_handler` dependency; reuse the existing
  `viet_ktv/system` method channel.

---

### Task 1: Video track selector seam

Wraps `VideoPlayerPlatform.instance` track selection behind a narrow port.
`VideoPlayerController` does not expose these methods, so this is the one place
that reaches past it. Ports are plain typedefs so tests need no platform mock
and no `plugin_platform_interface` dependency.

Note for later tasks: `test/support/fake_video_player_platform.dart` already
exists and is installed by assigning `VideoPlayerPlatform.instance`. It does
**not** override `getVideoTracks`, `selectVideoTrack`, or
`isVideoTrackSupportAvailable`, so those fall through to the base class, where
the first two throw `UnimplementedError` and the third returns `false`. The
selector treats all three outcomes as a silent no-op, so existing tests stay
green untouched. Only add overrides to that fake if you later want integration
coverage of the video path.

**Files:**
- Create: `lib/features/playback/data/video_track_selector.dart`
- Test: `test/features/playback/video_track_selector_test.dart`
- Modify: `car-app/pubspec.yaml` — move `video_player_platform_interface` from
  `dev_dependencies` to `dependencies`. It was listed as a dev dependency, but
  `lib/` now imports it, which trips `depend_on_referenced_packages`. **Done
  during execution.**

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `abstract interface class VideoTrackSelector` with
    `Future<bool> downscaleToSmallest(int playerId)` and
    `Future<void> restoreAdaptive(int playerId)`.
  - `class PlatformVideoTrackSelector implements VideoTrackSelector` with named
    constructor params `isSupported`, `readTracks`, `writeTrack`, all defaulted
    to `VideoPlayerPlatform.instance`.
  - `final videoTrackSelectorProvider = Provider<VideoTrackSelector>(...)`.

- [ ] **Step 1: Write the failing test**

Create `test/features/playback/video_track_selector_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:viet_ktv/features/playback/data/video_track_selector.dart';

VideoTrack _track(String id, int? height) =>
    VideoTrack(id: id, isSelected: false, height: height);

PlatformVideoTrackSelector _selector({
  required List<VideoTrack> tracks,
  bool supported = true,
  List<VideoTrack?>? written,
  Object? readThrows,
}) {
  return PlatformVideoTrackSelector(
    isSupported: () => supported,
    readTracks: (_) async {
      if (readThrows != null) {
        throw readThrows;
      }
      return tracks;
    },
    writeTrack: (_, track) async => written?.add(track),
  );
}

void main() {
  test('selects_the_smallest_track_when_several_are_available', () async {
    final written = <VideoTrack?>[];
    final selector = _selector(
      tracks: [_track('0_0', 720), _track('0_1', 144), _track('0_2', 480)],
      written: written,
    );

    final didDownscale = await selector.downscaleToSmallest(7);

    expect(didDownscale, isTrue);
    expect(written.single?.id, '0_1');
  });

  test('ignores_tracks_with_unknown_height', () async {
    // VideoTrack.height is nullable; a null must never be treated as smallest.
    final written = <VideoTrack?>[];
    final selector = _selector(
      tracks: [_track('0_0', null), _track('0_1', 360)],
      written: written,
    );

    final didDownscale = await selector.downscaleToSmallest(7);

    expect(didDownscale, isTrue);
    expect(written.single?.id, '0_1');
  });

  test('does_nothing_when_only_one_track_is_available', () async {
    // A pinned VideoQuality narrows the URL to a single rendition, so there is
    // nothing smaller to pick and switching would be pointless churn.
    final written = <VideoTrack?>[];
    final selector = _selector(tracks: [_track('0_0', 720)], written: written);

    expect(await selector.downscaleToSmallest(7), isFalse);
    expect(written, isEmpty);
  });

  test('does_nothing_when_no_track_has_a_known_height', () async {
    final written = <VideoTrack?>[];
    final selector = _selector(
      tracks: [_track('0_0', null), _track('0_1', null)],
      written: written,
    );

    expect(await selector.downscaleToSmallest(7), isFalse);
    expect(written, isEmpty);
  });

  test('does_nothing_when_the_platform_lacks_track_support', () async {
    final written = <VideoTrack?>[];
    final selector = _selector(
      tracks: [_track('0_0', 720), _track('0_1', 144)],
      supported: false,
      written: written,
    );

    expect(await selector.downscaleToSmallest(7), isFalse);
    expect(written, isEmpty);
  });

  test('reports_no_downscale_when_the_platform_throws', () async {
    final selector = _selector(tracks: const [], readThrows: StateError('boom'));

    expect(await selector.downscaleToSmallest(7), isFalse);
  });

  test('restore_passes_null_to_re_enable_adaptive_selection', () async {
    final written = <VideoTrack?>[];
    final selector = _selector(tracks: const [], written: written);

    await selector.restoreAdaptive(7);

    expect(written, [isNull]);
  });

  test('restore_is_silent_when_the_platform_lacks_track_support', () async {
    final written = <VideoTrack?>[];
    final selector = _selector(
      tracks: const [],
      supported: false,
      written: written,
    );

    await selector.restoreAdaptive(7);

    expect(written, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/playback/video_track_selector_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'viet_ktv' ... video_track_selector.dart` / "Target of URI doesn't exist".

- [ ] **Step 3: Write minimal implementation**

Create `lib/features/playback/data/video_track_selector.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

final videoTrackSelectorProvider = Provider<VideoTrackSelector>(
  (ref) => PlatformVideoTrackSelector(),
);

/// Narrow port over video quality selection.
///
/// `VideoPlayerController` does not wrap `getVideoTracks`/`selectVideoTrack`
/// even though the platform interface declares them and Android implements
/// them, so this reaches `VideoPlayerPlatform.instance` directly using the
/// controller's public `playerId`. Keeping that in one file means a future
/// plugin version that exposes these properly is a one-file change.
abstract interface class VideoTrackSelector {
  /// Returns true only when a genuinely smaller track was selected.
  Future<bool> downscaleToSmallest(int playerId);

  /// Restores adaptive (automatic) quality selection.
  Future<void> restoreAdaptive(int playerId);
}

typedef VideoTracksReader = Future<List<VideoTrack>> Function(int playerId);
typedef VideoTrackWriter =
    Future<void> Function(int playerId, VideoTrack? track);

class PlatformVideoTrackSelector implements VideoTrackSelector {
  PlatformVideoTrackSelector({
    bool Function()? isSupported,
    VideoTracksReader? readTracks,
    VideoTrackWriter? writeTrack,
  }) : _isSupportedOverride = isSupported,
       _readTracksOverride = readTracks,
       _writeTrackOverride = writeTrack;

  final bool Function()? _isSupportedOverride;
  final VideoTracksReader? _readTracksOverride;
  final VideoTrackWriter? _writeTrackOverride;

  // Resolved per call, never captured as a tear-off in the constructor:
  // `VideoPlayerPlatform.instance` is swapped by tests (see
  // `test/support/fake_video_player_platform.dart`), and a tear-off bound at
  // construction time would keep pointing at whichever instance was current
  // when this provider was first read.
  bool _isSupported() =>
      _isSupportedOverride?.call() ??
      VideoPlayerPlatform.instance.isVideoTrackSupportAvailable();

  Future<List<VideoTrack>> _readTracks(int playerId) =>
      _readTracksOverride?.call(playerId) ??
      VideoPlayerPlatform.instance.getVideoTracks(playerId);

  Future<void> _writeTrack(int playerId, VideoTrack? track) =>
      _writeTrackOverride?.call(playerId, track) ??
      VideoPlayerPlatform.instance.selectVideoTrack(playerId, track);

  @override
  Future<bool> downscaleToSmallest(int playerId) async {
    if (!_isSupported()) {
      return false;
    }
    try {
      final tracks = await _readTracks(playerId);
      // Fewer than two tracks means there is nothing smaller to move to. This
      // is the normal case when the user pinned a quality, because the URL was
      // already narrowed to a single rendition before playback started.
      if (tracks.length < 2) {
        return false;
      }
      final measured = tracks.where((track) => track.height != null).toList();
      if (measured.isEmpty) {
        return false;
      }
      final smallest = measured.reduce(
        (a, b) => a.height! <= b.height! ? a : b,
      );
      await _writeTrack(playerId, smallest);
      return true;
    } catch (_) {
      // Track selection is an optimisation. It must never break playback.
      return false;
    }
  }

  @override
  Future<void> restoreAdaptive(int playerId) async {
    if (!_isSupported()) {
      return;
    }
    try {
      await _writeTrack(playerId, null);
    } catch (_) {
      // Same reasoning as above.
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/playback/video_track_selector_test.dart`
Expected: PASS, 8 tests.

- [ ] **Step 5: Verify analyzer and formatting**

Run: `dart format . && flutter analyze`
Expected: "No issues found!"

---

### Task 2: Absolute seek on NowPlayingController

Notification and media-button seek is absolute, but the controller only offers
relative and fractional seek. Add `seekTo` and express `seekToFraction` in
terms of it so there is one clamping rule instead of three.

**Files:**
- Modify: `lib/features/playback/presentation/providers/now_playing_controller.dart:492-551`
- Test: `test/features/playback/now_playing_seek_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `void seekTo(Duration position)` on `NowPlayingController`, clamped
  to `[Duration.zero, duration]`, covering the video and audio paths.

- [ ] **Step 1: Write the failing test**

Create `test/features/playback/now_playing_seek_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/features/playback/data/audio_track_player.dart';
import 'package:viet_ktv/features/playback/presentation/providers/now_playing_controller.dart';
import 'package:viet_ktv/features/song_browser/data/models/song_item.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/music_sdk_repository_provider.dart';
import 'package:viet_ktv/features/source_selection/data/models/music_source.dart';

import '../../support/fake_audio_track_player.dart';
import '../../support/fake_local_storage_service.dart';
import '../../support/fake_music_sdk_platform.dart';

const _song = SongItem(
  id: 'track-1',
  title: 'Test Song',
  subtitle: 'SoundCloud',
  duration: '00:30',
  thumbnailSeed: 1,
  badge: null,
);

ProviderContainer _container(FakeAudioTrackPlayer player) {
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(FakeLocalStorageService()),
      musicSdkPlatformProvider.overrideWithValue(FakeMusicSdkPlatform()),
      audioTrackPlayerFactoryProvider.overrideWithValue(() => player),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<NowPlayingController> _playing(
  ProviderContainer container,
  FakeAudioTrackPlayer player,
) async {
  final controller = container.read(nowPlayingProvider.notifier);
  // SoundCloud takes the just_audio path, which the fake stands in for.
  await controller.play(_song, MusicSourceLogoStyle.soundcloud);
  return controller;
}

void main() {
  test('seeks_to_the_requested_position_on_the_audio_path', () async {
    final player = FakeAudioTrackPlayer();
    final container = _container(player);
    final controller = await _playing(container, player);

    controller.seekTo(const Duration(seconds: 12));

    expect(player.lastSeek, const Duration(seconds: 12));
  });

  test('clamps_a_negative_seek_to_zero', () async {
    final player = FakeAudioTrackPlayer();
    final container = _container(player);
    final controller = await _playing(container, player);

    controller.seekTo(const Duration(seconds: -5));

    expect(player.lastSeek, Duration.zero);
  });

  test('clamps_a_seek_past_the_end_to_the_duration', () async {
    final player = FakeAudioTrackPlayer();
    final container = _container(player);
    final controller = await _playing(container, player);
    // FakeAudioTrackPlayer.setUrl reports a 30s duration.

    controller.seekTo(const Duration(seconds: 99));

    expect(player.lastSeek, const Duration(seconds: 30));
  });

  test('seek_to_fraction_maps_onto_the_same_clamped_path', () async {
    final player = FakeAudioTrackPlayer();
    final container = _container(player);
    final controller = await _playing(container, player);

    controller.seekToFraction(0.5);

    expect(player.lastSeek, const Duration(seconds: 15));
  });

  test('seeking_with_nothing_playing_is_a_no_op', () async {
    final player = FakeAudioTrackPlayer();
    final container = _container(player);
    final controller = container.read(nowPlayingProvider.notifier);

    controller.seekTo(const Duration(seconds: 5));

    expect(player.lastSeek, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/playback/now_playing_seek_test.dart`
Expected: FAIL — "The method 'seekTo' isn't defined for the class 'NowPlayingController'".

- [ ] **Step 3: Write minimal implementation**

In `now_playing_controller.dart`, add `seekTo` and rewrite `seekToFraction` to
delegate to it. Replace the existing `seekToFraction` method (currently at
lines 525-551) with:

```dart
  /// Absolute seek, clamped to the track. Media-button and notification seeks
  /// are absolute, and both playback paths need the same clamping rule, so all
  /// other seek entry points funnel through here.
  void seekTo(Duration position) {
    final controller = state.videoController;
    if (controller != null && controller.value.isInitialized) {
      unawaited(controller.seekTo(_clamp(position, controller.value.duration)));
      return;
    }

    final audioPlayer = state.audioPlayer;
    if (audioPlayer != null) {
      unawaited(audioPlayer.seek(_clamp(position, state.audioDuration)));
    }
  }

  void seekToFraction(double fraction) {
    final normalized = fraction.clamp(0.0, 1.0);
    final controller = state.videoController;
    final duration = controller != null && controller.value.isInitialized
        ? controller.value.duration
        : state.audioDuration;
    seekTo(
      Duration(milliseconds: (duration.inMilliseconds * normalized).round()),
    );
  }

  Duration _clamp(Duration position, Duration duration) {
    if (position < Duration.zero) {
      return Duration.zero;
    }
    if (duration > Duration.zero && position > duration) {
      return duration;
    }
    return position;
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/playback/now_playing_seek_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Verify nothing regressed**

Run: `flutter test && dart format . && flutter analyze`
Expected: all tests pass; "No issues found!"

---

### Task 3: Duck factor separated from user volume

Ducking must not clobber the user's volume setting, and restoring must return
to whatever the user has set *now*, not the value captured when ducking began.

**Files:**
- Modify: `lib/features/playback/presentation/providers/now_playing_controller.dart:129,293,329,444-454`
- Test: `test/features/playback/now_playing_duck_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `void setDuckFactor(double factor)` on `NowPlayingController`.
  Effective volume is `_userVolume * _duckFactor`. Applies only when
  `state.audioPlayer != null`; the video path is left to ExoPlayer.

- [ ] **Step 1: Write the failing test**

Create `test/features/playback/now_playing_duck_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/features/playback/data/audio_track_player.dart';
import 'package:viet_ktv/features/playback/presentation/providers/now_playing_controller.dart';
import 'package:viet_ktv/features/song_browser/data/models/song_item.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/music_sdk_repository_provider.dart';
import 'package:viet_ktv/features/source_selection/data/models/music_source.dart';

import '../../support/fake_audio_track_player.dart';
import '../../support/fake_local_storage_service.dart';
import '../../support/fake_music_sdk_platform.dart';

const _song = SongItem(
  id: 'track-1',
  title: 'Test Song',
  subtitle: 'SoundCloud',
  duration: '00:30',
  thumbnailSeed: 1,
  badge: null,
);

ProviderContainer _container(FakeAudioTrackPlayer player) {
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(FakeLocalStorageService()),
      musicSdkPlatformProvider.overrideWithValue(FakeMusicSdkPlatform()),
      audioTrackPlayerFactoryProvider.overrideWithValue(() => player),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('ducking_scales_the_current_user_volume', () async {
    final player = FakeAudioTrackPlayer();
    final container = _container(player);
    final controller = container.read(nowPlayingProvider.notifier);
    controller.setPlaybackVolume(0.8);
    await controller.play(_song, MusicSourceLogoStyle.soundcloud);

    controller.setDuckFactor(0.2);

    expect(player.lastVolume, closeTo(0.16, 1e-9));
  });

  test('releasing_the_duck_restores_the_user_volume', () async {
    final player = FakeAudioTrackPlayer();
    final container = _container(player);
    final controller = container.read(nowPlayingProvider.notifier);
    controller.setPlaybackVolume(0.8);
    await controller.play(_song, MusicSourceLogoStyle.soundcloud);

    controller.setDuckFactor(0.2);
    controller.setDuckFactor(1);

    expect(player.lastVolume, closeTo(0.8, 1e-9));
  });

  test('volume_changed_while_ducked_keeps_the_duck', () async {
    // Dragging the volume slider during a navigation prompt must not cancel
    // the duck, and must not be forgotten once the prompt ends.
    final player = FakeAudioTrackPlayer();
    final container = _container(player);
    final controller = container.read(nowPlayingProvider.notifier);
    controller.setPlaybackVolume(0.8);
    await controller.play(_song, MusicSourceLogoStyle.soundcloud);

    controller.setDuckFactor(0.2);
    controller.setPlaybackVolume(0.5);

    expect(player.lastVolume, closeTo(0.1, 1e-9));

    controller.setDuckFactor(1);

    expect(player.lastVolume, closeTo(0.5, 1e-9));
  });

  test('ducking_with_nothing_playing_is_a_no_op', () async {
    final player = FakeAudioTrackPlayer();
    final container = _container(player);
    final controller = container.read(nowPlayingProvider.notifier);

    controller.setDuckFactor(0.2);

    expect(player.lastVolume, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/playback/now_playing_duck_test.dart`
Expected: FAIL — "The method 'setDuckFactor' isn't defined for the class 'NowPlayingController'".

- [ ] **Step 3: Write minimal implementation**

In `now_playing_controller.dart`, replace the `double _playbackVolume = 1;`
field declaration (line 129) with:

```dart
  double _userVolume = 1;
  // Ducking is a separate multiplier rather than an overwrite of _userVolume,
  // so a volume change during a navigation prompt is not lost when the prompt
  // ends, and releasing the duck restores whatever the user has set by then.
  double _duckFactor = 1;

  double get _effectiveVolume => _userVolume * _duckFactor;
```

Replace the body of `setPlaybackVolume` (lines 444-454) with:

```dart
  void setPlaybackVolume(double volume) {
    _userVolume = volume.clamp(0.0, 1.0);
    _applyVolume();
  }

  /// Only the audio path is ducked here. On the video path ExoPlayer holds
  /// audio focus itself (`mixWithOthers: false` sets `handleAudioFocus=true`)
  /// and already ducks on transient loss, so applying a second duck would
  /// lower the volume twice.
  void setDuckFactor(double factor) {
    final clamped = factor.clamp(0.0, 1.0);
    if (_duckFactor == clamped) {
      return;
    }
    _duckFactor = clamped;
    if (state.audioPlayer == null) {
      return;
    }
    _applyVolume();
  }

  void _applyVolume() {
    final videoController = state.videoController;
    if (videoController != null && videoController.value.isInitialized) {
      unawaited(videoController.setVolume(_userVolume));
    }
    final audioPlayer = state.audioPlayer;
    if (audioPlayer != null) {
      unawaited(audioPlayer.setVolume(_effectiveVolume));
    }
  }
```

Then replace the two remaining reads of the old field:
- line 293, `await controller.setVolume(_playbackVolume);` →
  `await controller.setVolume(_userVolume);`
- line 329, `await audioPlayer.setVolume(_playbackVolume);` →
  `await audioPlayer.setVolume(_effectiveVolume);`

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/playback/now_playing_duck_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Verify nothing regressed**

Run: `flutter test && dart format . && flutter analyze`
Expected: all tests pass, including the existing `test/volume_test.dart` and
`test/features/playback/now_playing_controller_test.dart`; "No issues found!"

---

### Task 4: Audio-path interruption handling

`just_audio`'s built-in interruption handling pauses on a duck event instead of
ducking. Turn it off and handle interruptions explicitly so navigation prompts
duck and only real focus loss pauses.

**Files:**
- Modify: `lib/features/playback/data/audio_track_player.dart:35`
- Create: `lib/features/playback/data/playback_interruption_handler.dart`
- Test: `test/features/playback/playback_interruption_handler_test.dart`

**Interfaces:**
- Consumes: `NowPlayingController.setDuckFactor` (Task 3).
- Produces:
  - `enum PlaybackInterruption { duck, pause }`
  - `class InterruptionSignal { final PlaybackInterruption type; final bool begin; }`
  - `abstract interface class AudioInterruptionSource` with
    `Stream<InterruptionSignal> get signals`, `Future<void> configure()`, and
    `Future<void> dispose()`. **`dispose()` was added during execution:** the
    original interface omitted it, so `PlaybackInterruptionHandler.dispose()`
    had no way to tear down the platform subscription and `StreamController`
    that `configure()` creates — a real leak across create/destroy cycles. The
    handler sets the source up in `start()`, so it tears it down too.
  - `class PlaybackInterruptionHandler` with named params `source`,
    `setDuckFactor`, `pausePlayback`, `resumePlayback`, `isPlaying`; methods
    `Future<void> start()` and `Future<void> dispose()`.
  - `const double kDuckFactor = 0.2;`

- [ ] **Step 1: Write the failing test**

Create `test/features/playback/playback_interruption_handler_test.dart`:

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/features/playback/data/playback_interruption_handler.dart';

class FakeInterruptionSource implements AudioInterruptionSource {
  final StreamController<InterruptionSignal> _controller =
      StreamController<InterruptionSignal>.broadcast();
  int configureCallCount = 0;

  void emit(PlaybackInterruption type, {required bool begin}) {
    _controller.add(InterruptionSignal(type: type, begin: begin));
  }

  @override
  Stream<InterruptionSignal> get signals => _controller.stream;

  @override
  Future<void> configure() async => configureCallCount++;

  Future<void> close() => _controller.close();
}

class _Harness {
  _Harness({this.playing = true});

  final source = FakeInterruptionSource();
  final ducks = <double>[];
  int pauseCallCount = 0;
  int resumeCallCount = 0;
  bool playing;

  late final PlaybackInterruptionHandler handler = PlaybackInterruptionHandler(
    source: source,
    setDuckFactor: ducks.add,
    pausePlayback: () {
      pauseCallCount++;
      playing = false;
    },
    resumePlayback: () {
      resumeCallCount++;
      playing = true;
    },
    isPlaying: () => playing,
  );

  Future<void> start() async {
    await handler.start();
  }

  /// Signals travel through a broadcast stream, so give the microtask queue a
  /// turn before asserting.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  Future<void> close() async {
    await handler.dispose();
    await source.close();
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

  test('stops_reacting_after_dispose', () async {
    final harness = _Harness();
    await harness.start();
    await harness.handler.dispose();

    harness.source.emit(PlaybackInterruption.duck, begin: true);
    await harness.settle();
    await harness.source.close();

    expect(harness.ducks, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/playback/playback_interruption_handler_test.dart`
Expected: FAIL — "Target of URI doesn't exist: 'package:viet_ktv/features/playback/data/playback_interruption_handler.dart'".

- [ ] **Step 3: Write minimal implementation**

Create `lib/features/playback/data/playback_interruption_handler.dart`:

```dart
import 'dart:async';

import 'package:audio_session/audio_session.dart';

/// Volume multiplier applied while another app holds transient focus, such as
/// a navigation prompt.
const double kDuckFactor = 0.2;

enum PlaybackInterruption { duck, pause }

class InterruptionSignal {
  const InterruptionSignal({required this.type, required this.begin});

  final PlaybackInterruption type;
  final bool begin;
}

/// Port over `audio_session` so the handler is testable without a platform.
abstract interface class AudioInterruptionSource {
  Stream<InterruptionSignal> get signals;
  Future<void> configure();
}

class AudioSessionInterruptionSource implements AudioInterruptionSource {
  @override
  Stream<InterruptionSignal> get signals => _controller.stream;

  final StreamController<InterruptionSignal> _controller =
      StreamController<InterruptionSignal>.broadcast();
  StreamSubscription<AudioInterruptionEvent>? _subscription;

  @override
  Future<void> configure() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    _subscription = session.interruptionEventStream.listen((event) {
      _controller.add(
        InterruptionSignal(
          // `duck` is the only genuinely transient type; `pause` and `unknown`
          // both mean the audio must actually stop.
          type: event.type == AudioInterruptionType.duck
              ? PlaybackInterruption.duck
              : PlaybackInterruption.pause,
          begin: event.begin,
        ),
      );
    });
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
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
  }) : _source = source,
       _setDuckFactor = setDuckFactor,
       _pausePlayback = pausePlayback,
       _resumePlayback = resumePlayback,
       _isPlaying = isPlaying;

  final AudioInterruptionSource _source;
  final void Function(double factor) _setDuckFactor;
  final void Function() _pausePlayback;
  final void Function() _resumePlayback;
  final bool Function() _isPlaying;

  StreamSubscription<InterruptionSignal>? _subscription;
  bool _pausedByInterruption = false;

  Future<void> start() async {
    await _source.configure();
    _subscription = _source.signals.listen(_handle);
  }

  void _handle(InterruptionSignal signal) {
    switch (signal.type) {
      case PlaybackInterruption.duck:
        _setDuckFactor(signal.begin ? kDuckFactor : 1.0);
      case PlaybackInterruption.pause:
        if (signal.begin) {
          // Only remember the pause if we were the ones who stopped playback,
          // so that regaining focus never starts music the user had paused.
          if (_isPlaying()) {
            _pausedByInterruption = true;
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
  }
}
```

- [ ] **Step 4: Add the dependency and disable just_audio's own handling**

Run: `flutter pub add audio_session`

Then in `lib/features/playback/data/audio_track_player.dart`, replace line 35:

```dart
  // just_audio's built-in interruption handling pauses on a duck event unless
  // usage is `game`, which is wrong for a car head unit — a navigation prompt
  // should lower the music, not stop it. PlaybackInterruptionHandler takes
  // over instead.
  final AudioPlayer _player = AudioPlayer(handleInterruptions: false);
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/playback/playback_interruption_handler_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 6: Verify nothing regressed**

Run: `flutter test && dart format . && flutter analyze`
Expected: all tests pass; "No issues found!"

---

### Task 5: Background playback flag and lifecycle observer

Stops `video_player` from pausing on background, then cuts the now-wasted video
decode and pauses the decorative visualizer.

**Files:**
- Modify: `lib/features/playback/presentation/providers/now_playing_controller.dart:281-284`
- Create: `lib/features/playback/presentation/providers/playback_lifecycle_observer.dart`
- Test: `test/features/playback/playback_lifecycle_observer_test.dart`

**Interfaces:**
- Consumes: `VideoTrackSelector` (Task 1).
- Produces: `class PlaybackLifecycleObserver` with named params
  `trackSelector`, `videoPlayerId`, `pauseVisualizer`, `resumeVisualizer`,
  `isPlaying`; methods `Future<void> didBackground()` and
  `Future<void> didForeground()`.

- [ ] **Step 1: Write the failing test**

Create `test/features/playback/playback_lifecycle_observer_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/features/playback/data/video_track_selector.dart';
import 'package:viet_ktv/features/playback/presentation/providers/playback_lifecycle_observer.dart';

class FakeVideoTrackSelector implements VideoTrackSelector {
  final List<int> downscaled = [];
  final List<int> restored = [];
  bool downscaleResult = true;

  @override
  Future<bool> downscaleToSmallest(int playerId) async {
    downscaled.add(playerId);
    return downscaleResult;
  }

  @override
  Future<void> restoreAdaptive(int playerId) async => restored.add(playerId);
}

class _Harness {
  _Harness({this.playerId, this.playing = true});

  final selector = FakeVideoTrackSelector();
  int? playerId;
  bool playing;
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

  test('audio_only_playback_touches_no_video_track', () async {
    final harness = _Harness();

    await harness.observer.didBackground();
    await harness.observer.didForeground();

    expect(harness.selector.downscaled, isEmpty);
    expect(harness.selector.restored, isEmpty);
    expect(harness.pauseVisualizerCallCount, 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/playback/playback_lifecycle_observer_test.dart`
Expected: FAIL — "Target of URI doesn't exist: '.../playback_lifecycle_observer.dart'".

- [ ] **Step 3: Write minimal implementation**

Create `lib/features/playback/presentation/providers/playback_lifecycle_observer.dart`:

```dart
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

  bool _didDownscale = false;

  Future<void> didBackground() async {
    _pauseVisualizer();
    final playerId = _videoPlayerId();
    if (playerId == null) {
      return;
    }
    _didDownscale = await _trackSelector.downscaleToSmallest(playerId);
  }

  Future<void> didForeground() async {
    if (_isPlaying()) {
      _resumeVisualizer();
    }
    // Restoring a quality we never lowered would override a pinned setting.
    if (!_didDownscale) {
      return;
    }
    final playerId = _videoPlayerId();
    if (playerId == null) {
      return;
    }
    _didDownscale = false;
    await _trackSelector.restoreAdaptive(playerId);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/playback/playback_lifecycle_observer_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 5: Let video playback survive backgrounding**

In `now_playing_controller.dart`, replace the controller construction at lines
281-284:

```dart
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(link),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: false,
        // Suppresses video_player's own _VideoAppLifeCycleObserver, which
        // otherwise pauses the track the moment the app is backgrounded. This
        // flag is Dart-side only; it is never sent to the platform.
        allowBackgroundPlayback: true,
      ),
    );
```

- [ ] **Step 6: Add the visualizer pause/resume entry points**

In `now_playing_controller.dart`, add these methods next to `togglePlayPause`:

```dart
  /// Called by [PlaybackLifecycleObserver]. Only the visualizer stops; the
  /// primary player must keep running in the background.
  void pauseVisualizer() {
    unawaited(state.visualizerController?.pause());
  }

  void resumeVisualizer() {
    unawaited(state.visualizerController?.play());
  }
```

- [ ] **Step 7: Run tests to verify nothing regressed**

Run: `flutter test && dart format . && flutter analyze`
Expected: all tests pass; "No issues found!"

---

### Task 6: audio_service dependency and Android configuration

Declares the foreground service, media button receiver, and permissions, and
switches the activity base class. Nothing here is unit-testable; the gate is a
clean release build.

**Files:**
- Modify: `car-app/pubspec.yaml`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `android/app/src/main/kotlin/com/example/viet_ktv/MainActivity.kt:9,17,40-47,310-318`

**Interfaces:**
- Consumes: nothing.
- Produces: the `audio_service` package on the classpath, a declared
  `AudioService`, and a `requestNotificationPermission` method on the existing
  `viet_ktv/system` channel returning `bool`.

- [ ] **Step 1: Add the dependency**

Run: `flutter pub add audio_service`
Expected: `pubspec.yaml` gains an `audio_service` entry; `flutter pub get` succeeds.

- [ ] **Step 2: Read the manifest before editing it**

Run: `cat android/app/src/main/AndroidManifest.xml`

This file has uncommitted local edits. Confirm what is there, then add only the
elements below. Do not rewrite the file.

- [ ] **Step 3: Add permissions**

Add alongside the existing `<uses-permission>` entries, before `<application>`:

```xml
    <!-- audio_service runs playback in a foreground service so Android cannot
         kill the process while music is playing in the background. -->
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
```

- [ ] **Step 4: Declare the service and media button receiver**

Add inside `<application>`, after the existing `<activity>` block:

```xml
        <service
            android:name="com.ryanheise.audioservice.AudioService"
            android:foregroundServiceType="mediaPlayback"
            android:exported="true">
            <intent-filter>
                <action android:name="android.media.browse.MediaBrowserService" />
            </intent-filter>
        </service>
        <!-- Routes steering-wheel and Bluetooth media keys into the app. -->
        <receiver
            android:name="com.ryanheise.audioservice.MediaButtonReceiver"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MEDIA_BUTTON" />
            </intent-filter>
        </receiver>
```

- [ ] **Step 5: Switch the activity base class**

In `MainActivity.kt`, replace the import on line 9:

```kotlin
import com.ryanheise.audioservice.AudioServiceActivity
```

and the class declaration on line 17:

```kotlin
class MainActivity : AudioServiceActivity() {
```

`AudioServiceActivity` extends `FlutterActivity`, so `configureFlutterEngine`
and both method channels keep working unchanged. Delete the now-unused
`io.flutter.embedding.android.FlutterActivity` import.

- [ ] **Step 6: Add the notification permission method**

In `MainActivity.kt`, add a branch to `onSystemMethodCall`:

```kotlin
            "requestNotificationPermission" -> requestNotificationPermission(result)
```

and this method next to `restartApp`:

```kotlin
    /**
     * Android 13+ hides the media notification unless POST_NOTIFICATIONS is
     * granted. The foreground service still runs without it, so a denial is
     * reported rather than treated as an error.
     */
    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }
        if (checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) ==
            android.content.pm.PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        requestPermissions(
            arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST_CODE,
        )
        // The dialog is asynchronous; report the current (not yet granted)
        // state and let the next launch see the updated value.
        result.success(false)
    }
```

and this constant inside `companion object`:

```kotlin
        private const val NOTIFICATION_PERMISSION_REQUEST_CODE = 1001
```

- [ ] **Step 7: Verify the build**

Run: `flutter build apk --release --dart-define=MUSIC_SDK_LICENSE_KEY=test`
Expected: BUILD SUCCESSFUL. A manifest merger error naming
`com.ryanheise.audioservice.AudioService` means the dependency step did not
take; a `FOREGROUND_SERVICE_MEDIA_PLAYBACK` error means the permission is
missing.

- [ ] **Step 8: Verify the Dart side still analyzes**

Run: `flutter test && dart format . && flutter analyze`
Expected: all tests pass; "No issues found!"

---

### Task 7: Audio handler and app wiring

Connects the notification and media buttons to the existing controllers, and
mounts everything from `main()`.

**Files:**
- Create: `lib/features/playback/data/karaoke_audio_handler.dart`
- Create: `lib/features/playback/presentation/providers/background_playback_provider.dart`
- Modify: `lib/main.dart:10-21`
- Modify: `lib/app.dart:14-20`
- Test: `test/features/playback/karaoke_audio_handler_test.dart`

**Interfaces:**
- Consumes: `NowPlayingController.seekTo` (Task 2),
  `NowPlayingController.setDuckFactor` (Task 3),
  `PlaybackInterruptionHandler` (Task 4), `PlaybackLifecycleObserver` (Task 5).
- Produces: `class KaraokeAudioHandler extends BaseAudioHandler with SeekHandler`,
  constructed as `KaraokeAudioHandler(this._container)`; and
  `final backgroundPlaybackProvider = Provider<void>(...)` which starts the
  interruption handler and the lifecycle listener.

- [ ] **Step 1: Write the failing test**

Create `test/features/playback/karaoke_audio_handler_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/features/playback/data/audio_track_player.dart';
import 'package:viet_ktv/features/playback/data/karaoke_audio_handler.dart';
import 'package:viet_ktv/features/playback/presentation/providers/now_playing_controller.dart';
import 'package:viet_ktv/features/song_browser/data/models/song_item.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/music_sdk_repository_provider.dart';
import 'package:viet_ktv/features/source_selection/data/models/music_source.dart';

import '../../support/fake_audio_track_player.dart';
import '../../support/fake_local_storage_service.dart';
import '../../support/fake_music_sdk_platform.dart';

const _song = SongItem(
  id: 'track-1',
  title: 'Test Song',
  subtitle: 'SoundCloud',
  duration: '00:30',
  thumbnailSeed: 1,
  imageUrl: 'https://example.com/art.jpg',
  badge: null,
);

ProviderContainer _container(FakeAudioTrackPlayer player) {
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(FakeLocalStorageService()),
      musicSdkPlatformProvider.overrideWithValue(FakeMusicSdkPlatform()),
      audioTrackPlayerFactoryProvider.overrideWithValue(() => player),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('pause_from_the_notification_pauses_playback', () async {
    final player = FakeAudioTrackPlayer();
    final container = _container(player);
    final handler = KaraokeAudioHandler(container);
    await container
        .read(nowPlayingProvider.notifier)
        .play(_song, MusicSourceLogoStyle.soundcloud);

    await handler.pause();

    expect(player.pauseCallCount, 1);
  });

  test('play_from_the_notification_resumes_playback', () async {
    final player = FakeAudioTrackPlayer();
    final container = _container(player);
    final handler = KaraokeAudioHandler(container);
    await container
        .read(nowPlayingProvider.notifier)
        .play(_song, MusicSourceLogoStyle.soundcloud);
    await handler.pause();

    await handler.play();

    expect(player.playCallCount, 2);
  });

  test('seek_from_the_notification_seeks_the_player', () async {
    final player = FakeAudioTrackPlayer();
    final container = _container(player);
    final handler = KaraokeAudioHandler(container);
    await container
        .read(nowPlayingProvider.notifier)
        .play(_song, MusicSourceLogoStyle.soundcloud);

    await handler.seek(const Duration(seconds: 9));

    expect(player.lastSeek, const Duration(seconds: 9));
  });

  test('stop_from_the_notification_returns_playback_to_idle', () async {
    final player = FakeAudioTrackPlayer();
    final container = _container(player);
    final handler = KaraokeAudioHandler(container);
    await container
        .read(nowPlayingProvider.notifier)
        .play(_song, MusicSourceLogoStyle.soundcloud);

    await handler.stop();

    expect(container.read(nowPlayingProvider).playback, isA<PlaybackIdle>());
  });

  test('commands_with_nothing_playing_are_no_ops', () async {
    // A steering-wheel button pressed before any song was chosen must not throw.
    final player = FakeAudioTrackPlayer();
    final container = _container(player);
    final handler = KaraokeAudioHandler(container);

    await handler.play();
    await handler.pause();
    await handler.seek(const Duration(seconds: 3));
    await handler.skipToNext();
    await handler.skipToPrevious();
    await handler.stop();

    expect(player.playCallCount, 0);
    expect(player.pauseCallCount, 0);
  });

  test('publishes_the_current_song_as_a_media_item', () async {
    final player = FakeAudioTrackPlayer();
    final container = _container(player);
    final handler = KaraokeAudioHandler(container);

    await container
        .read(nowPlayingProvider.notifier)
        .play(_song, MusicSourceLogoStyle.soundcloud);
    handler.syncFromPlayback();

    expect(handler.mediaItem.value?.id, 'track-1');
    expect(handler.mediaItem.value?.title, 'Test Song');
    expect(
      handler.mediaItem.value?.artUri,
      Uri.parse('https://example.com/art.jpg'),
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/playback/karaoke_audio_handler_test.dart`
Expected: FAIL — "Target of URI doesn't exist: '.../karaoke_audio_handler.dart'".

- [ ] **Step 3: Write minimal implementation**

Create `lib/features/playback/data/karaoke_audio_handler.dart`:

```dart
import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../queue/presentation/providers/queue_playback_controller.dart';
import '../../song_browser/data/models/song_item.dart';
import '../presentation/providers/now_playing_controller.dart';

/// Bridges the media notification, lock screen, and hardware media buttons to
/// the controllers that already own playback.
///
/// It holds a [ProviderContainer] rather than a late-bound delegate because
/// `AudioService.init()` runs before `runApp`, and a media button pressed
/// during startup must still find a working target.
class KaraokeAudioHandler extends BaseAudioHandler with SeekHandler {
  KaraokeAudioHandler(this._container);

  final ProviderContainer _container;

  NowPlayingController get _nowPlaying =>
      _container.read(nowPlayingProvider.notifier);

  QueuePlaybackController get _queue =>
      _container.read(queuePlaybackControllerProvider.notifier);

  bool get _hasPlayback {
    final state = _container.read(nowPlayingProvider);
    return state.videoController != null || state.audioPlayer != null;
  }

  bool get _isPlaying {
    final state = _container.read(nowPlayingProvider);
    final video = state.videoController;
    if (video != null) {
      return video.value.isPlaying;
    }
    return state.audioIsPlaying;
  }

  @override
  Future<void> play() async {
    if (!_hasPlayback || _isPlaying) {
      return;
    }
    _nowPlaying.togglePlayPause();
    syncFromPlayback();
  }

  @override
  Future<void> pause() async {
    if (!_hasPlayback || !_isPlaying) {
      return;
    }
    _nowPlaying.togglePlayPause();
    syncFromPlayback();
  }

  @override
  Future<void> seek(Duration position) async {
    if (!_hasPlayback) {
      return;
    }
    _nowPlaying.seekTo(position);
  }

  @override
  Future<void> skipToNext() => _queue.playNext(fromCompletion: false);

  @override
  Future<void> skipToPrevious() => _queue.playPrevious();

  @override
  Future<void> stop() async {
    if (!_hasPlayback) {
      return;
    }
    _nowPlaying.stopPlayback();
    syncFromPlayback();
  }

  /// Pushes the current playback state into the notification. Called from the
  /// provider listener whenever [nowPlayingProvider] changes.
  void syncFromPlayback() {
    final state = _container.read(nowPlayingProvider);
    mediaItem.add(_mediaItemFor(state));
    playbackState.add(_playbackStateFor(state));
  }

  MediaItem? _mediaItemFor(NowPlayingState state) {
    final song = switch (state.playback) {
      PlaybackLoading(:final song) => song,
      PlaybackReady(:final song) => song,
      PlaybackFailed(:final song) => song,
      PlaybackIdle() => null,
    };
    if (song == null) {
      return null;
    }
    return MediaItem(
      id: song.id,
      title: song.title,
      artist: song.subtitle,
      artUri: _artUri(song),
      duration: _durationFor(state),
    );
  }

  Uri? _artUri(SongItem song) {
    // SongItem.imageUrl is nullable and is empty for several mock sources.
    final imageUrl = song.imageUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      return null;
    }
    return Uri.tryParse(imageUrl);
  }

  Duration? _durationFor(NowPlayingState state) {
    final video = state.videoController;
    if (video != null && video.value.isInitialized) {
      return video.value.duration;
    }
    return state.audioDuration > Duration.zero ? state.audioDuration : null;
  }

  PlaybackState _playbackStateFor(NowPlayingState state) {
    final video = state.videoController;
    final playing = _isPlaying;
    final position = video != null && video.value.isInitialized
        ? video.value.position
        : state.audioPosition;
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: switch (state.playback) {
        PlaybackIdle() => AudioProcessingState.idle,
        PlaybackLoading() => AudioProcessingState.loading,
        PlaybackReady() => AudioProcessingState.ready,
        PlaybackFailed() => AudioProcessingState.error,
      },
      playing: playing,
      updatePosition: position,
    );
  }
}
```

- [ ] **Step 4: Add the stop entry point to NowPlayingController**

The handler calls `stopPlayback()`, which does not exist yet. In
`now_playing_controller.dart`, add next to `replayFromStart`:

```dart
  /// Tears playback down completely. Reached by dismissing the media
  /// notification, which on Android means the user wants playback gone, not
  /// merely paused.
  void stopPlayback() {
    _playRequestId++;
    final controller = state.videoController;
    controller?.removeListener(_handleTick);
    unawaited(controller?.dispose());
    unawaited(state.visualizerController?.dispose());
    _disposeAudioPlayer();
    state = NowPlayingState(
      activeSource: state.activeSource,
      isExpanded: state.isExpanded,
    );
  }
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/playback/karaoke_audio_handler_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 6: Wire the background services provider**

Create `lib/features/playback/presentation/providers/background_playback_provider.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  if (handler != null) {
    ref.listen<NowPlayingState>(
      nowPlayingProvider,
      (_, _) => handler.syncFromPlayback(),
      fireImmediately: true,
    );
  }

  final nowPlaying = ref.read(nowPlayingProvider.notifier);

  final interruptions = PlaybackInterruptionHandler(
    source: AudioSessionInterruptionSource(),
    setDuckFactor: nowPlaying.setDuckFactor,
    pausePlayback: nowPlaying.togglePlayPause,
    resumePlayback: nowPlaying.togglePlayPause,
    isPlaying: () => ref.read(nowPlayingProvider).audioIsPlaying,
  );
  unawaited(interruptions.start());

  final observer = PlaybackLifecycleObserver(
    trackSelector: ref.read(videoTrackSelectorProvider),
    videoPlayerId: () => ref.read(nowPlayingProvider).videoController?.playerId,
    pauseVisualizer: nowPlaying.pauseVisualizer,
    resumeVisualizer: nowPlaying.resumeVisualizer,
    isPlaying: () {
      final state = ref.read(nowPlayingProvider);
      return state.audioIsPlaying ||
          (state.videoController?.value.isPlaying ?? false);
    },
  );

  final lifecycle = AppLifecycleListener(
    onPause: () => unawaited(observer.didBackground()),
    onResume: () => unawaited(observer.didForeground()),
  );

  ref.onDispose(() {
    lifecycle.dispose();
    unawaited(interruptions.dispose());
  });
});
```

Add `import 'dart:async';` at the top of that file for `unawaited`.

- [ ] **Step 7: Wire main.dart**

Replace the body of `main()` in `lib/main.dart`:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _tuneImageCacheForTvBox();
  unawaited(ensureMusicSdkInitialized());
  unawaited(ensureSupabaseInitialized());

  // The handler needs the controllers, but AudioService.init must run before
  // runApp. Building the container here lets the handler hold a working target
  // from the very first media-button press.
  final container = ProviderContainer();

  audioHandler = await AudioService.init(
    builder: () => KaraokeAudioHandler(container),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.viet_ktv.playback',
      androidNotificationChannelName: 'Phát nhạc',
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: true,
    ),
  );

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const VietKtvApp(),
    ),
  );
}
```

Add these imports to `lib/main.dart`:

```dart
import 'package:audio_service/audio_service.dart';

import 'features/playback/data/karaoke_audio_handler.dart';
import 'features/playback/presentation/providers/background_playback_provider.dart';
```

`androidNotificationOngoing: false` is what allows swipe-to-dismiss, which the
design calls for.

- [ ] **Step 8: Keep the provider alive from the app root**

In `lib/app.dart`, inside `build`, after the existing
`ref.watch(historyControllerProvider);`:

```dart
    // Keeps the media notification, audio-focus handling, and background
    // lifecycle behaviour alive for the whole app lifetime.
    ref.watch(backgroundPlaybackProvider);
```

and add the import:

```dart
import 'features/playback/presentation/providers/background_playback_provider.dart';
```

- [ ] **Step 9: Request the notification permission**

The Dart side of the `viet_ktv/system` channel is `AppSystemService` in
`lib/core/services/app_system_service.dart:29`. It is a `const` class used as
`const AppSystemService()` at each call site — there is no provider for it — so
follow that pattern rather than introducing one. Add:

```dart
  /// Android 13+ hides the media notification without this. A denial is not
  /// fatal — the foreground service still keeps playback alive.
  Future<bool> requestNotificationPermission() async {
    try {
      final granted = await _channel.invokeMethod<bool>(
        'requestNotificationPermission',
      );
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }
```

Call it once from `backgroundPlaybackProvider`, after the listener is attached:

```dart
  unawaited(const AppSystemService().requestNotificationPermission());
```

with `import '../../../../core/services/app_system_service.dart';`.

- [ ] **Step 10: Run the full suite**

Run: `flutter test && dart format . && flutter analyze`
Expected: all tests pass; "No issues found!"

- [ ] **Step 11: Verify on real hardware**

Debug mode is not representative on these devices.

```bash
flutter build apk --release --dart-define=MUSIC_SDK_LICENSE_KEY=<key>
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Check each of these on the device:
1. Play a SoundCloud track, press Home — audio continues, notification appears.
2. Play a YouTube track, press Home — audio continues.
3. Press the notification's next button — the queue advances.
4. Press a steering-wheel or Bluetooth next button — the queue advances.
5. Trigger a navigation prompt — music ducks, then returns to its old level.
6. Swipe the notification away — playback stops.
7. Return to the foreground — video is showing again, audio never broke.

- [ ] **Step 12: Measure the downscaling**

This is the one claim that cannot be verified by inspection.

```bash
adb shell top -p $(adb shell pidof com.example.viet_ktv) -n 1
```

Sample it with a YouTube track in the foreground, then again after pressing
Home. CPU must drop. If it does not, `selectVideoTrack` is not taking effect —
most likely `getVideoTracks` returned fewer than two tracks because a specific
`VideoQuality` was pinned. Re-test with quality set to Auto before concluding
the feature works.

---

## Self-Review

**Spec coverage.** Every spec section maps to a task: platform constraint 1 →
Task 5 Step 5; constraint 2 → Tasks 1 and 5; constraint 3 → Tasks 3 and 4;
Architecture (`ProviderContainer`, `UncontrolledProviderScope`) → Task 7 Step 7;
Dependencies → Tasks 4 and 6; Android configuration → Task 6; Data Flow
(`MediaItem`, command table, `seekTo`) → Tasks 2 and 7; Ducking → Tasks 3 and 4;
Background Video Downscaling → Tasks 1 and 5; visualizer pause → Task 5;
`POST_NOTIFICATIONS` → Task 6 Step 6 and Task 7 Step 9; Error Handling → the
no-op tests in Tasks 1, 2, 3, and 7; Testing → every task, plus Task 7 Steps 11
and 12.

**Type consistency.** `VideoTrackSelector.downscaleToSmallest` /
`restoreAdaptive` are used with the same names and signatures in Tasks 1 and 5.
`setDuckFactor(double)` is defined in Task 3 and consumed in Tasks 4 and 7.
`seekTo(Duration)` is defined in Task 2 and consumed in Task 7.
`pauseVisualizer` / `resumeVisualizer` are defined in Task 5 Step 6 and consumed
in Task 7. `stopPlayback()` is defined in Task 7 Step 4 and consumed by the
handler in the same task. `syncFromPlayback()` is defined in Task 7 Step 3 and
consumed in Step 6. `kDuckFactor` is defined in Task 4 and used in its own test.

**Verified against the codebase, not assumed.** `SongItem` requires
`thumbnailSeed` and `badge` and its `imageUrl` is `String?`
(`song_item.dart:1-18`) — the test fixtures and `_artUri` reflect that.
`AppSystemService` is a `const` class with an injectable channel
(`app_system_service.dart:29-33`). `test/support/` already provides
`fake_local_storage_service.dart`, `fake_music_sdk_platform.dart`,
`fake_audio_track_player.dart`, and `fake_video_player_platform.dart`, so no new
fake is needed outside the ones written inline here.

**Known risks.** Two things cannot be settled from source and must be confirmed
on device. `AudioService.init` returning before `runApp` assumes the plugin
tolerates a `ProviderContainer` built beforehand — if provider initialisation
turns out to need a `WidgetsBinding` frame, move the container construction
after `AudioService.init` and pass it in via a setter. And `resumePlayback`
being wired to `togglePlayPause` in Task 7 Step 6 is only correct while
playback is paused; if a race is observed where focus returns before the pause
lands, give `NowPlayingController` explicit `pausePlayback`/`resumePlayback`
methods instead of toggling.

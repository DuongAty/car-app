# Audio and Visualizer Playback Synchronization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow SoundCloud and Mixcloud audio to play concurrently with a muted visualizer and keep both controlled by the application's play/pause button.

**Architecture:** Keep `just_audio` as the only Android audio-focus owner for audio-only sources. Configure only the local visualizer `VideoPlayerController` to mix with other audio, while preserving the default audio-focus behavior of YouTube network video controllers.

**Tech Stack:** Flutter, Riverpod, `just_audio`, `video_player`, `flutter_test`

## Global Constraints

- Target Android 10 (API 29) and above.
- Limit synchronization to the application's play/pause control.
- Do not change Bluetooth, system media control, phone-call, or external audio-focus behavior.
- Do not change YouTube playback behavior.
- Run `dart format .`, `flutter analyze`, `flutter test`, and `flutter build apk` before completion.
- The workspace's `.git` directory is not a valid Git repository, so commit steps cannot run until repository metadata is restored.

## File Structure

- Modify `test/support/fake_video_player_platform.dart`: record video play and pause calls for transport synchronization assertions.
- Modify `test/support/fake_audio_track_player.dart`: expose fake playback state and command counts for transport synchronization assertions.
- Modify `test/widget_test.dart`: add focused regression and transport tests for audio-only playback.
- Modify `lib/features/playback/presentation/providers/now_playing_controller.dart`: configure only the visualizer controller to mix with other audio.

---

### Task 1: Reproduce Visualizer Audio-Focus Ownership

**Files:**
- Test: `test/widget_test.dart`

**Interfaces:**
- Consumes: `VideoPlayerController.videoPlayerOptions` from `video_player`.
- Produces: Regression test `soundcloud_visualizer_does_not_claim_audio_focus`.

- [ ] **Step 1: Add the failing assertion to the SoundCloud visualizer test**

```dart
expect(player.controller.videoPlayerOptions?.mixWithOthers, isTrue);
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```powershell
flutter test test/widget_test.dart --plain-name "soundcloud_playback_displays_looping_visualizer_asset"
```

Expected: FAIL because `videoPlayerOptions` is null and `mixWithOthers` therefore is not true.

- [ ] **Step 3: Configure the visualizer to mix with other audio**

Change the visualizer construction in `_createVisualizerController` to:

```dart
final controller = VideoPlayerController.asset(
  asset,
  videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
);
```

Configure `VideoPlayerController.networkUrl` with
`VideoPlayerOptions(mixWithOthers: false)` so Android's globally shared plugin
option is reset when switching back to YouTube.

- [ ] **Step 4: Run the focused test and verify GREEN**

Run:

```powershell
flutter test test/widget_test.dart --plain-name "soundcloud_playback_displays_looping_visualizer_asset"
```

Expected: PASS.

### Task 2: Cover In-App Play/Pause Synchronization

**Files:**
- Modify: `test/support/fake_video_player_platform.dart`
- Modify: `test/support/fake_audio_track_player.dart`
- Test: `test/widget_test.dart`

**Interfaces:**
- Consumes: `NowPlayingController.togglePlayPause()` through the preview transport button.
- Produces: `FakeVideoPlayerPlatform.playCallCount`, `FakeVideoPlayerPlatform.pauseCallCount`, `FakeAudioTrackPlayer.playCallCount`, and `FakeAudioTrackPlayer.pauseCallCount`.

- [ ] **Step 1: Add observable command counters to the fakes**

In `FakeVideoPlayerPlatform`:

```dart
int playCallCount = 0;
int pauseCallCount = 0;

@override
Future<void> play(int playerId) async {
  playCallCount++;
}

@override
Future<void> pause(int playerId) async {
  pauseCallCount++;
}
```

In `FakeAudioTrackPlayer`:

```dart
int playCallCount = 0;
int pauseCallCount = 0;

@override
Future<void> play() {
  playCallCount++;
  // Keep the existing stream and completer behavior.
}

@override
Future<void> pause() async {
  pauseCallCount++;
  // Keep the existing stream and completer behavior.
}
```

- [ ] **Step 2: Let the widget test inject and retain one fake audio player**

Add an optional `AudioTrackPlayerFactory` parameter to `_pumpSongBrowser` and use it in the provider override:

```dart
Future<void> _pumpSongBrowser(
  WidgetTester tester, {
  MusicSdkPlatform? musicSdkPlatform,
  MusicSource source = _source,
  AudioTrackPlayerFactory audioPlayerFactory = FakeAudioTrackPlayer.new,
}) async {
  // Existing setup.
  audioTrackPlayerFactoryProvider.overrideWithValue(audioPlayerFactory),
}
```

- [ ] **Step 3: Add a transport characterization test**

Create a SoundCloud widget test that retains the fake platform and audio player, starts a track, taps `Icons.pause_rounded`, and verifies both pause counters increment. Then tap `Icons.play_arrow_rounded` and verify both play counters increment once more.

```dart
expect(audioPlayer.pauseCallCount, 1);
expect(videoPlatform.pauseCallCount, 1);
expect(audioPlayer.playCallCount, 2);
expect(videoPlatform.playCallCount, 2);
```

- [ ] **Step 4: Run the synchronization test**

Run:

```powershell
flutter test test/widget_test.dart --plain-name "in_app_transport_controls_audio_and_visualizer_together"
```

Expected: PASS because the existing transport flow already forwards both commands.

### Task 3: Verification

**Files:**
- Verify: all modified Dart files and Android build output.

**Interfaces:**
- Consumes: completed Tasks 1 and 2.
- Produces: formatted, analyzed, tested, Android-buildable application.

- [ ] **Step 1: Format the workspace**

Run `dart format .` and expect exit code 0.

- [ ] **Step 2: Run static analysis**

Run `flutter analyze` and expect no issues.

- [ ] **Step 3: Run all tests**

Run `flutter test` and expect all tests to pass.

- [ ] **Step 4: Build Android APK**

Run `flutter build apk` and expect exit code 0 with an APK under `build/app/outputs/flutter-apk/`.

- [ ] **Step 5: Review the final diff without Git**

Because Git metadata is unavailable, inspect the four modified source/test files directly and confirm the production change remains limited to visualizer construction.

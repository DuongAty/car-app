# Background Audio Playback

## Context

The app has no background playback support today. There is no foreground
service, no `MediaSession`, and no notification controls. `AndroidManifest.xml`
declares only `INTERNET`, `ACCESS_NETWORK_STATE`, and `RECORD_AUDIO`, and
contains a single `<activity>` with no `<service>`. No package in
`pubspec.yaml` provides background audio (`just_audio` and `video_player`
only).

Current behaviour differs per source, and the difference is caused by plugin
internals rather than application code:

- **YouTube** (`VideoPlayerController`) **pauses when the app is
  backgrounded.** `video_player` installs `_VideoAppLifeCycleObserver`
  (`video_player-2.13.0/lib/video_player.dart:1073-1083`), which pauses on
  `AppLifecycleState.paused` and resumes on `resumed`. The Android plugin
  itself has no lifecycle handling.
- **SoundCloud / MixCloud** (`just_audio`) **keep playing**, because
  `just_audio` installs no such observer. Playback is unprotected: with no
  foreground service, Android may kill the process at any time, which matters
  on the 2GB RAM boxes and head units this app targets.

Neither source shows a notification, exposes media-button controls, or
coordinates audio focus with navigation prompts and calls.

## Goals

Audio continues in the background for **both** sources, survives with a
foreground service, exposes a full media notification, responds to
steering-wheel and Bluetooth media buttons, and ducks for navigation prompts
instead of stopping. Backgrounded video decode is cut to near zero without
interrupting audio.

## Non-Goals

Android Auto / `MediaBrowserService` browsing, lock-screen artwork beyond what
`MediaItem.artUri` provides, and iOS support.

Handing YouTube off to a `just_audio` audio-only rendition while backgrounded
was considered and rejected. It would eliminate video decode entirely, and the
HLS master playlist may well carry such a rendition — `_parseVariants` skips
every `#EXT-X-STREAM-INF` without a `RESOLUTION` attribute
(`youtube_quality_selector.dart:65-68`), which is the shape an audio-only
rendition takes. It was rejected because it introduces an audible gap and
position drift at every foreground/background transition, adds a second player
to an already dense controller, and is not always available: non-HLS
progressive links would still need a fallback path. Downscaling captures most
of the saving with none of that.

## Platform Constraints

These three findings, verified against the resolved plugin sources, determine
the design.

### 1. Background audio for the video path is a Dart-side flag

`VideoPlayerOptions(allowBackgroundPlayback: true)` only suppresses
`_VideoAppLifeCycleObserver`. It is never sent to the platform:
`setAllowBackgroundPlayback` throws `UnimplementedError` in
`video_player_platform_interface-6.9.0:121-123` and Android does not override
it.

### 2. The video track can be downscaled but not disabled

Nothing exposes `setTrackTypeDisabled` or `TrackSelectionParameters`. Native
uses `setTrackTypeDisabled` internally as a 150ms workaround during resolution
changes (`video_player_android-2.11.0/.../VideoPlayer.java:402-406`) without
exposing it, so the video track cannot be switched off.

Quality *selection* is reachable, though it takes an indirect route with a real
caveat.

**Correction, found during implementation:** an earlier draft of this document
called `controller.playerId` public. It is not, in spirit. It is a public
getter, but annotated `@visibleForTesting` and documented "This is just exposed
for testing. It shouldn't be used by anyone depending on the plugin"
(`video_player-2.13.0/lib/video_player.dart:558-565`). Using it needs an
`// ignore: invalid_use_of_visible_for_testing_member`.

This is accepted rather than avoided, because the blast radius is bounded: if a
future `video_player` removes the getter, the failure is a **compile error** —
loud and immediate — not silent misbehaviour. And every runtime failure inside
the seam already degrades to a no-op that leaves playback untouched. The
alternative is forking the plugin. Anyone upgrading `video_player` should
expect to revisit `video_track_selector.dart` and
`background_playback_provider.dart`.

`VideoPlayerController` does not wrap the track methods, but the platform
interface declares
`getVideoTracks(int playerId)` and `selectVideoTrack(int playerId, VideoTrack?)`
(`video_player_platform_interface-6.9.0:171,179`), both implemented on Android
(`VideoPlayer.java:307-347`). Passing `null` restores adaptive selection.

This is what makes background decode cheap rather than free. See *Background
Video Downscaling*.

### 3. The two players handle audio focus by opposite mechanisms

- Video: `setAudioAttributes(attrs, handleAudioFocus = !isMixMode)`
  (`VideoPlayer.java:97-101`). With the app's `mixWithOthers: false`, ExoPlayer
  requests focus itself and **already ducks on transient loss and pauses on
  permanent loss** — exactly the desired behaviour, at no cost.
- Audio: `just_audio` passes `handleAudioFocus = false` natively
  (`just_audio-0.10.6/.../AudioPlayer.java:355`); focus lives entirely in
  `audio_session` on the Dart side. Its default `handleInterruptions: true`
  **pauses on a duck event** unless usage is `game`
  (`just_audio.dart:371-395`), which does not match the desired behaviour.

The design is therefore **deliberately asymmetric**: the video path keeps
ExoPlayer's built-in focus handling untouched, and the audio path takes over
interruption handling explicitly. Adding a second focus layer to the video
path would duck or pause twice.

This is safe because the two players never coexist: `NowPlayingController.play`
disposes the previous video controller and calls `_disposeAudioPlayer()` before
creating a new player.

## Architecture

`audio_service` is used rather than `just_audio_background`, which can only
wrap `just_audio` and cannot cover the YouTube `video_player` path.
`audio_service` does not own a player, so a `BaseAudioHandler` can delegate to
the existing controllers.

`AudioService.init()` must run before `runApp`, but the handler needs
`NowPlayingController` and `QueuePlaybackController`, which live inside
`ProviderScope`. The chosen resolution is to build a `ProviderContainer`
manually in `main()`, pass it to the handler, and mount the tree with
`UncontrolledProviderScope`.

The rejected alternative was a handler with a late-bound delegate wired after
startup. It leaves a window in which the handler accepts media-button commands
with no delegate attached — a real failure when a steering-wheel button is
pressed during startup.

## Components

### Dependencies

Add `audio_service`. Promote `audio_session` from a transitive dependency of
`just_audio` to a direct one, since the interruption handler uses it directly.
Resolve exact versions with `flutter pub add` rather than pinning by guess.

### Android configuration

`AndroidManifest.xml` gains:

- Permissions: `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK`,
  `POST_NOTIFICATIONS`, `WAKE_LOCK`.
- `com.ryanheise.audioservice.AudioService` with
  `android:foregroundServiceType="mediaPlayback"` and an intent filter for
  `android.media.browse.MediaBrowserService`.
- `com.ryanheise.audioservice.MediaButtonReceiver` with an intent filter for
  `android.intent.action.MEDIA_BUTTON`. This is what makes steering-wheel and
  Bluetooth buttons work.

`MainActivity` extends `AudioServiceActivity` instead of `FlutterActivity`.
`AudioServiceActivity` is itself a `FlutterActivity` subclass, so the existing
`configureFlutterEngine` override and both method channels are unaffected.

The manifest and `MainActivity` both carry uncommitted local edits. Changes
must be additive; do not overwrite the working tree.

### New files

- `lib/features/playback/data/karaoke_audio_handler.dart` —
  `KaraokeAudioHandler extends BaseAudioHandler with SeekHandler`, holding the
  `ProviderContainer`.
- `lib/features/playback/data/playback_interruption_handler.dart` — subscribes
  to `AudioSession.interruptionEventStream` for the audio path only.
- `lib/features/playback/data/video_track_selector.dart` — the seam over
  `VideoPlayerPlatform.instance` for `getVideoTracks` / `selectVideoTrack`,
  with a support check and no-op fallbacks. Injectable so tests need no
  platform.
- `lib/features/playback/presentation/providers/playback_lifecycle_observer.dart`
  — `AppLifecycleListener` driving background downscale and visualizer pause.

### Modified files

- `main.dart` — `ProviderContainer`, `AudioService.init`,
  `UncontrolledProviderScope`.
- `now_playing_controller.dart` — `allowBackgroundPlayback`, duck factor,
  `seekTo`, and the pause/resume entry points the lifecycle observer calls.
- `audio_track_player.dart` — `AudioPlayer(handleInterruptions: false)`.

## Data Flow

**Controller to notification.** A provider watches `nowPlayingProvider` and
pushes `MediaItem` and `PlaybackState` into the handler. `_handleTick` already
collapses updates to one-second granularity, so this respects the existing
rule against per-frame rebuilds.

`MediaItem` maps `song.id`, `song.title`, the source display name as artist,
`song.imageUrl` as `artUri`, and the known duration.

**Notification to controller.**

| Command | Target |
| --- | --- |
| `play` / `pause` | `NowPlayingController.togglePlayPause` |
| `skipToNext` | `QueuePlaybackController.playNext(fromCompletion: false)` |
| `skipToPrevious` | `QueuePlaybackController.playPrevious` |
| `seek` | `NowPlayingController.seekTo` |
| `stop` | dispose players, return to idle |

Notification seek is absolute, but `NowPlayingController` currently offers only
`seekBackward`, `seekForward`, and `seekToFraction`. Add `seekTo(Duration)`
covering both the video and audio paths, and reimplement `seekToFraction` in
terms of it.

## Ducking

`NowPlayingController` splits its single `_playbackVolume` into `_userVolume`
and `_duckFactor`; effective volume is their product. `setPlaybackVolume`
writes only `_userVolume`, so moving the volume slider while ducked preserves
the duck, and releasing the duck restores the user's current level rather than
a stale one.

`setDuckFactor` applies **only when `state.audioPlayer != null`**. The video
path is left to ExoPlayer.

`JustAudioTrackPlayer` constructs `AudioPlayer(handleInterruptions: false)` so
`just_audio` stops pausing on duck events. `playback_interruption_handler.dart`
then maps `AudioInterruptionType.duck` to a duck factor of `0.2`, and
`pause`/`unknown` to a real pause with resume when focus returns.

## Background Video Downscaling

The app has no app-lifecycle observer today. One is added, and it drives two
background behaviours. It must never pause the primary player, whose whole
purpose here is to keep running.

**On `AppLifecycleState.paused`, with a video controller active:** read
`getVideoTracks(controller.playerId)`, pick the smallest by height, and pass it
to `selectVideoTrack`. A 144p or 240p decode is close to free next to 720p, so
this removes nearly all of the wasted work while the audio stream continues
untouched — no gap, no second player, no position drift.

**On `AppLifecycleState.resumed`:** call `selectVideoTrack(playerId, null)` to
restore adaptive selection, or re-select the track matching the user's
`VideoQuality` when it is not `auto`.

Two honest limits. Some decode remains; only an audio-only handoff reaches
zero, and that was rejected above. And the win is largest at `VideoQuality.auto`,
where the master playlist offers several tracks — when the user has pinned a
specific quality, `_qualitySelector` has already narrowed the URL to a single
rendition, so there may be no smaller track to choose. The code must handle
`getVideoTracks` returning one track, or an empty list, as a no-op rather than
an error.

Because this reaches past `VideoPlayerController` into
`VideoPlayerPlatform.instance`, it is isolated behind one small seam so a
future plugin version that wraps these methods properly is a one-file change.
`isVideoTrackSupportAvailable()`
(`video_player_platform_interface-6.9.0:195`) is checked before use so
unsupported hosts degrade to no-ops.

## Additional Work Found During Review

**Visualizer must pause in the background.** It is a decorative looping 720p
MP4; decoding it unseen wastes CPU on 2GB hardware. The same lifecycle observer
pauses it, and resumes it on return only when audio is actually playing.

**`POST_NOTIFICATIONS` needs a runtime request on Android 13+.**
`audio_service` does not request it; without it the foreground service still
runs but its notification is hidden. Rather than adding `permission_handler`,
extend the existing `viet_ktv/system` method channel in `MainActivity` with a
notification-permission request, avoiding a new dependency.

## Error Handling

Media commands received while playback is idle are no-ops. A link that fails to
resolve in the background yields `PlaybackFailed`, the notification moves to a
stopped state, and `continuousPlayback` still advances through `playNext`.
Dismissing the notification calls `stop()`, which disposes the active player.
`AudioService.init` is called only from `main()`, so tests and non-Android
hosts never touch it.

## Testing

- `KaraokeAudioHandler` unit tests with fake controllers: all five commands
  delegate to the right target, and state maps correctly to `PlaybackState`
  and `MediaItem`.
- Duck unit tests: duck, then change user volume, then unduck, and assert the
  effective volume follows the newest user value; assert `setDuckFactor` is
  inert on the video path.
- `seekTo` unit tests on both the video and audio paths, including clamping at
  zero and at duration.
- Lifecycle unit tests with a fake `video_track_selector`: backgrounding picks
  the smallest track and pauses the visualizer but never pauses the primary
  player; resuming restores adaptive selection. Cover the degenerate inputs —
  one track, empty list, unsupported platform — and assert each is a silent
  no-op.
- Existing tests must stay green. They build their own `ProviderScope`, so the
  `main()` change does not reach them; the existing requirement to override
  `localStorageServiceProvider` with `FakeLocalStorageService` still applies.

Because `flutter run` in debug mode is not representative on this hardware,
background behaviour is verified with a release APK on a real box or head unit:
start a track, press Home, confirm audio continues and the notification
appears; trigger a navigation prompt and confirm ducking; press a steering-wheel
next button and confirm the queue advances; return to the foreground and confirm
the video is back at full quality with audio uninterrupted throughout.

Downscaling is verified by measurement, not by assumption: sample
`adb shell top -p <pid>` on a YouTube track in the foreground, again after
backgrounding, and confirm CPU actually drops. If it does not, the track
selection is not taking effect and the work has not landed.

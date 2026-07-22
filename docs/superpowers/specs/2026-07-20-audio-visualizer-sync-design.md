# Audio and Visualizer Playback Synchronization

## Context

SoundCloud and Mixcloud tracks are played through `just_audio`. A muted,
looping local MP4 is played through `video_player` as their visualizer. On
Android, starting either player currently pauses the other.

## Root Cause

`VideoPlayerOptions.mixWithOthers` defaults to `false`. The Android
`video_player` implementation therefore configures ExoPlayer to handle audio
focus even when the controller volume is zero. The visualizer and
`just_audio` compete for the same Android audio focus, causing each newly
started player to pause the other.

## Scope

Synchronize SoundCloud and Mixcloud audio with the visualizer when playback is
controlled by the application's play/pause button.

This change does not add synchronization for Bluetooth controls, system media
controls, phone calls, or other external audio-focus interruptions. YouTube
playback remains unchanged because its video player is also the primary audio
source.

## Design

Create visualizer asset controllers with
`VideoPlayerOptions(mixWithOthers: true)`. This tells the Android video player
not to claim audio focus, leaving `just_audio` as the only audio-focus owner.

Keep the existing application transport flow:

- When audio is playing, pause the audio player and visualizer controller.
- When audio is paused, start the audio player and visualizer controller.
- When the visualizer finishes loading asynchronously, start it only if the
  associated audio player is still active and playing.

The local visualizer controller explicitly enables the option. Network video
controllers used for YouTube explicitly disable it because the Android plugin
stores this option globally for subsequently created players. This preserves
YouTube's default audio-focus behavior after switching from an audio-only
source.

## Error Handling

Visualizer initialization remains optional. If the local video cannot be
initialized, audio continues playing without a visualizer. Existing request ID
checks continue to prevent a stale visualizer from attaching to a newer track.

## Testing

Add regression coverage that fails with the current implementation and proves:

- A SoundCloud or Mixcloud visualizer requests `mixWithOthers: true`.
- The in-app play/pause action pauses and resumes both the audio player and the
  visualizer.
- YouTube video creation is unaffected.

Run `dart format .`, the focused playback tests, `flutter analyze`, and the
full `flutter test` suite. Build the Android APK if the local Android toolchain
is available.

# Double-Tap Zones On The Video

## Context

Double-tapping the video currently toggles between `PlayerViewMode.normal` and
`PlayerViewMode.wide` — a single gesture over the whole picture, wired at
`preview_player.dart:180` as `onDoubleTap: notifier.toggleWide`.

Fullscreen and seeking both exist but are reachable only through the transport
row: two layout buttons and two seek buttons, all at the bottom of the strip. In
fullscreen that strip auto-hides after three seconds, so seeking means first
reviving the controls, then aiming at a small button.

## Goals

Put the two most-used actions — entering/leaving fullscreen, and seeking — on
the picture itself, where they can be reached without hunting for a control.

## Non-Goals

Changing the seek step (10s), single-tap behaviour, long-press, the transport
buttons, or anything about the audio-only path.

## Zones

The picture is split by horizontal fraction of its width:

| Zone | Range | Action |
| --- | --- | --- |
| Left | `dx < 0.3 * width` | `seekBackward()` — 10s back |
| Centre | `0.3 <= dx <= 0.7` | toggle fullscreen |
| Right | `dx > 0.7 * width` | `seekForward()` — 10s forward |

30/40/30 rather than a YouTube-style 40/20/40: the centre zone has to be hit
reliably on a head unit in a moving car, and a mis-hit there does not merely do
nothing — it jumps the song 10 seconds.

Only the horizontal position matters. Vertical position is ignored, so the zones
are full-height columns.

`GestureDetector.onDoubleTapDown` supplies the position; `onDoubleTap` is when
the gesture is confirmed. The position is captured in the first and acted on in
the second.

## Behaviour Across Modes

The zones behave identically in `normal`, `wide`, and `fullscreen` — one model to
learn.

A centre double-tap in `normal` goes straight to fullscreen, and leaving returns
to `normal`, because `enterFullscreen()` already records the originating mode and
`exitFullscreen()` restores it.

**This replaces the existing `normal ↔ wide` double-tap.** After this change,
wide mode is reachable only from its own button. That is a deliberate trade:
fullscreen is the more frequent destination, and the wide button remains.

## Seek Feedback

A karaoke video runs continuously, so a 10-second jump is not always obvious —
and in fullscreen with the controls auto-hidden, the progress bar that would
otherwise show it is not on screen.

On a seek, a small badge appears over the corresponding half of the picture: a
directional arrow and the text `10s`. It holds for **600ms** and then fades out.
No badge is shown for the centre zone; entering or leaving fullscreen is its own
evidence.

The badge lives in its own small leaf widget so showing and hiding it never
rebuilds the video subtree — the same rule the auto-hiding controls follow. Its
fade is a one-shot transition on a state change, not the continuous animation the
performance rules prohibit.

## Interaction With Existing Gestures

In fullscreen a `Listener(onPointerDown:)` reveals the auto-hidden controls. A
double-tap begins with a pointer-down, so the controls reveal as well. That is
wanted, and needs no change: `Listener` does not join the gesture arena, so it
cannot compete with the `GestureDetector` that recognises the double-tap.

Seeking with nothing playing is already a no-op inside `NowPlayingController`;
the zones do not need their own guard for it, and no badge should appear in that
case since nothing moved.

## Testing

- A double-tap at 20%, 50%, and 80% of the picture's width produces seek-back,
  fullscreen toggle, and seek-forward respectively.
- The boundaries at exactly 30% and 70% land in the centre zone, matching the
  table above.
- Centre double-tap enters fullscreen from `normal` and returns to `normal` on
  the second; entering from `wide` returns to `wide`.
- The badge appears on a seek, names the right direction, and is gone after the
  hold; it never appears for a centre tap.
- A seek with nothing playing changes no state and shows no badge.
- All 203 existing tests stay green and `flutter analyze` stays clean.

Gesture feel — whether 30/40/30 is comfortable and 600ms is long enough to
notice — is confirmed with a release build on the target box or head unit, since
debug mode is not representative there.

# Single Tap To Play/Pause

## Context

The video picture currently recognises one gesture: a double tap, split into
three horizontal zones — seek back on the left third, toggle fullscreen in the
middle, seek forward on the right third.

Play/pause is reachable only from the transport strip's button. In fullscreen
that strip auto-hides after three seconds, so pausing means reviving the
controls first and then aiming at a button.

Separately, in fullscreen a `Listener(onPointerDown:)` wrapped around the overlay
reveals the auto-hidden controls. It sits outside the gesture arena deliberately,
so the reveal is immediate rather than waiting for a gesture to be recognised.

## Goals

Make a single tap on the picture toggle play/pause, without breaking the reveal
gesture that shares the same surface.

## Non-Goals

Changing the double-tap zones, the seek step, the auto-hide delay, the transport
buttons, or the long-press-Enter remote shortcut.

## Behaviour

A single tap anywhere on the picture toggles play/pause. The left/right/centre
split applies to double taps only — it is irrelevant to a single tap.

The transport strip is unaffected: the `GestureDetector` wraps only the picture,
so tapping a control cannot also toggle playback.

**Fullscreen exception.** When the controls are hidden, a tap only reveals them
and leaves playback alone. When the controls are visible, a tap toggles
play/pause. `normal` and `wide` have no overlay and no auto-hide, so a tap there
always toggles.

The point of the exception is that glancing at the progress bar must not stop the
song.

## The Ordering Trap

The exception cannot be implemented by reading the overlay's visibility inside
`onTap`, and this is the whole difficulty of the change.

`Listener(onPointerDown:)` fires the instant the finger lands. `onTap` is
recognised roughly 300ms later, once Flutter is satisfied no second tap is
coming. So by the time `onTap` runs, `reveal()` has already executed and the
controls are **always** visible — the exception would never trigger and every tap
would toggle playback.

**Resolution:** capture whether the controls were visible at pointer-down, before
`reveal()` changes it, and have `onTap` decide from the captured value. This
requires exposing a visibility getter on the controls-overlay state, which the
existing `GlobalKey` already reaches.

## The Delay, Stated Plainly

Because `onDoubleTap` is registered on the same surface, `onTap` cannot fire
until the double-tap window closes. Single-tap play/pause will therefore lag by
roughly 300ms. This is inherent to hosting both gestures on one area, not an
implementation shortcoming, and it is what mainstream video players do.

The reveal stays immediate, because it runs through the `Listener` outside the
arena. So the frequently-used action is instant and only the deliberate one
waits.

## Testing

- A tap in `normal` and in `wide` toggles playback.
- In fullscreen with the controls hidden, a tap reveals them and **does not**
  change playback state.
- In fullscreen with the controls already visible, a tap toggles playback.
- A double tap still produces the three zone actions and does **not** also
  toggle playback.
- A tap with nothing playing changes nothing.

Gesture feel — whether the ~300ms delay is acceptable in practice — is judged
with a release build on the target box or head unit, since debug mode is not
representative there.

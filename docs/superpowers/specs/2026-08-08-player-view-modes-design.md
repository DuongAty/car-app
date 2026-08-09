# Player View Modes

## Context

The player has two layouts today, driven by a single `bool isExpanded` on
`NowPlayingState`:

- **Normal** — the search/results column on the left, the player on the right.
- **Expanded** — `CollapsibleAxis` slides the left column out of frame and the
  player takes the full width. The top navigation and the bottom hint bar stay
  visible.

Expanded is reached from the transport row's fullscreen button
(`preview_player.dart:458`) or by double-tapping the video
(`preview_player.dart:98`). Four pages consume the flag as
`collapsed: isExpanded` (`song_browser_page.dart:186`, `favorites_page.dart:43`,
`selected_queue_page.dart:37`, `history_page.dart:43`).

The button is labelled with a fullscreen icon but does not produce fullscreen —
`KaraokeShell` (`karaoke_shell.dart:14-25`) takes `topBar`, `body`, and
`bottomBar` as required widgets and always lays out all three. There is no way
to give the video the whole screen.

## Goals

Separate the two ideas the fullscreen button currently conflates: widening the
player, and actually filling the screen. Give each its own control, and make
fullscreen mean fullscreen.

## Non-Goals

Changing the normal or wide layouts themselves, picture-in-picture, landscape
locking, and any change to what the double-tap gesture does.

## State Model

`bool isExpanded` becomes `enum PlayerViewMode { normal, wide, fullscreen }` on
`NowPlayingState`.

Two booleans would admit a contradictory state (expanded *and* fullscreen at
once) with no defined meaning. An enum makes that unrepresentable.

Both `wide` and `fullscreen` hide the left column, so the four consuming pages
become `collapsed: mode != PlayerViewMode.normal`.

`NowPlayingController` replaces `toggleExpanded` with:

- `toggleWide()` — `normal ↔ wide`. Called by the new wide button and by the
  existing double-tap gesture, whose behaviour is unchanged.
- `enterFullscreen()` / `exitFullscreen()` — fullscreen is reachable from either
  other mode, and exiting **returns to the mode it was entered from**. Entering
  fullscreen from `wide` and leaving must land back on `wide`, not `normal`.
  The controller stores the pre-fullscreen mode to do this.

## Controls

The transport row (`preview_player.dart`) gains a second layout button. Both sit
after the repeat button:

| Button | Icons | Action |
| --- | --- | --- |
| Wide | `left_panel_close_rounded` / `left_panel_open_rounded` | `toggleWide()` |
| Fullscreen | `fullscreen_rounded` / `fullscreen_exit_rounded` | enter / exit fullscreen |

`AppIcons` currently defines only the fullscreen pair (`app_icons.dart:53-54`);
the left-panel pair is added there. Those icons are chosen because the panel
being hidden is literally the left one.

## Hiding the App Chrome

`KaraokeShell` gains `bool chromeVisible = true`. When false it does not build
`topBar` or `bottomBar` at all — they are removed from the widget tree rather
than made transparent, so they cost no layout or paint. Pages pass
`chromeVisible: mode != PlayerViewMode.fullscreen`.

On entering fullscreen the app also calls
`SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)`, restoring
`SystemUiMode.edgeToEdge` on exit **and** on dispose. Most target head units and
TV boxes have no system bars, making this a no-op there, but it matters on
phones and emulators used for testing.

## Auto-Hiding the Controls

In `fullscreen` only, the progress section and transport row hide after **3
seconds** without interaction. Any tap on the video or any key event reveals
them and restarts the timer. `normal` and `wide` are unchanged — their controls
are always visible.

The visibility flag lives in a small leaf widget wrapping just the overlay, not
on the page. Putting it higher would rebuild the whole tree on every hide and
reveal, which the 2GB-box performance rules forbid.

Transitions use a 150ms opacity fade. This is a one-shot animation on a state
change, not the continuous background animation the performance rules prohibit.

The timer must be cancelled when leaving fullscreen and on dispose, or a fired
timer will call `setState` after unmount.

## Escaping Fullscreen

Being stranded in fullscreen on a car head unit is the worst outcome this
feature could produce, so there are three redundant exits:

1. The `fullscreen_exit` button, whenever the controls are visible.
2. **Back** — Android's back gesture/button and the D-pad back key. A
   `PopScope` intercepts it and exits fullscreen instead of popping the route.
   The pattern already exists in `license_gate_page.dart:40`.
3. Any key press reveals the controls first, so exit #1 is always reachable in
   one further press.

Entering fullscreen must `requestFocus` on the player's existing `FocusNode`
(`preview_player.dart:228`), otherwise D-pad events land on a widget that was
just removed from the tree and nothing responds.

The existing key handling in that node (`preview_player.dart:187-221` — right
arrow for next, enter/select/space for play-pause, long-press enter for replay)
keeps working in fullscreen; those keys both perform their action and reveal the
controls.

## Known Consequence

The bottom bar carries the volume control, so fullscreen hides it. Hardware
volume keys still work — `volume_provider` listens for system volume changes
independently of the UI. On a head unit with no hardware volume keys the user
must leave fullscreen to change volume. This is accepted for now; a small
floating volume indicator was discussed and deliberately deferred rather than
built speculatively.

## Testing

- Mode transitions: `normal ↔ wide`; entering fullscreen from each mode and
  confirming exit returns to the originating mode.
- `chromeVisible` is false only in fullscreen; the top bar and bottom bar are
  absent from the tree, not merely invisible.
- Back exits fullscreen and does not pop the route; Back in `normal` and `wide`
  still pops normally.
- Controls hide after the timeout in fullscreen and reveal on a key event and on
  a tap; they never auto-hide in `normal` or `wide`.
- The timer is cancelled on dispose — a test that enters fullscreen, disposes the
  widget, and advances time past the timeout must not throw.
- All 165 existing tests stay green; `flutter analyze` stays clean.

Layout and focus behaviour on a real device is verified separately with a
release build on the target box or head unit, since debug mode is not
representative on that hardware.

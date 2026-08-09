# Seamless Surface On The Song Browser

## Context

The song browser reads as four separate islands: the search field, the results
panel, the player, and the bottom hint bar. Each is its own rounded surface with
its own lit rim, floating on the shell background with a gap between them.

Each surface is a `LiquidGlass`:

- `native_song_search_field.dart:57` — the search field
- `panel_frame.dart:36` — used by `SearchResultsPanel` for the results column
- `preview_player.dart:326` — the player
- `app_bottom_hint_bar.dart:36` — the hint bar

`PanelFrame` is not local to this screen. Ten files across six features use it,
so it is the pattern that produces this look app-wide.

## Goals

Make the browser's content area read as one composition rather than a set of
tiles, without blur.

## Non-Goals

`BackdropFilter`, glassmorphism, animated gradients, and large blur passes are
all forbidden on the 2GB-RAM target hardware and are not options here. Seamlessness
comes from layout and surface strategy instead.

The other six screens are out of scope. This establishes the language on one
screen; rolling it out is separate work.

## The Surface Model

The content area becomes **one** `LiquidGlass`. The search field, results, and
player live inside it, separated by **1px hairlines** rather than by gaps and
rims — a vertical hairline between the left column and the player, a horizontal
one between the search field and the results.

The hairline colour is `AppColors.panelBorderSoft`, already used for exactly this
purpose at `search_results_panel.dart:89`. No new token.

This also cuts paint work: four `LiquidGlass` surfaces each draw their own rim and
bevel today; one draws it once.

**The bottom hint bar stays separate.** It is app chrome built by `KaraokeShell`
for every screen — a legend and status strip, not content — and merging it here
alone would desynchronise it from the screens not yet converted.

**Small repeated chips keep their own surfaces.** `search_result_tile`,
`category_grid_panel`'s tiles, and the hint bar's buttons all use
`LiquidGlassDetail.simple` and stay as they are. They are items within a region,
not layout blocks.

## How Widgets Know They Are Inside The Slab

`NativeSongSearchField`, `PreviewPlayer`, and `PanelFrame` are all shared with
other screens, so their surfaces cannot simply be deleted.

A `SurfaceScope` `InheritedWidget` wraps the slab. It carries no data — its
presence is the signal. Each of those three widgets looks it up and, when found,
returns its content bare instead of wrapping it in `LiquidGlass`. Screens without
the scope are untouched.

The alternative was threading a `bool framed` through three or four widget
layers. The scope avoids changing those signatures and cannot be forgotten at an
intermediate layer.

## The Three Layout States

This is where the change is most likely to break.

**Normal** — the slab spans the left column and the player. Vertical hairline
between them, horizontal hairline between the search field and results.

**Wide** — the left column is already collapsed by `CollapsibleAxis`. The
vertical hairline must collapse *with it*, not linger as a stray line down the
player's left edge.

**Fullscreen** — the player returns bare, full-bleed content, as built earlier.
No slab is created at all in this mode; wrapping one would reintroduce the
rounded frame that fullscreen work removed.

The category tab is a different layout — a genre grid beside the results, with no
player. It also sits in the slab, with a vertical hairline between grid and
results.

## Testing

Whether it *looks* seamless cannot be tested. What can be tested is the structure,
which is what will drift later:

- In normal mode the content area contains exactly **one** panel-level
  `LiquidGlass`. Adding a nested panel back turns this red.
- In wide mode no vertical hairline is rendered.
- In fullscreen no `LiquidGlass` wraps the player, continuing the existing
  fullscreen assertion.
- Small repeated chips still carry their own `LiquidGlassDetail.simple`, so a
  future change cannot quietly absorb them into the slab.
- An unconverted screen — favorites — still renders its own `PanelFrame` surface,
  proving `SurfaceScope` does not leak beyond the browser.

## Verification And Revision

The visual result can only be judged on the target hardware with a release build;
debug mode is not representative there.

One revision round is expected and planned for, not treated as failure: tone
steps, hairline weight, and corner radius are the values most likely to need
adjusting once seen on a real panel at viewing distance.

## Rollback

A verbatim copy of `lib/` and `test/` from before this work sits in
`.superpowers/ui-redesign-backup/`, with a `restore` script supporting a dry run,
a full revert, and per-file reverts. `README.md` there carries an inventory of
every file created or modified, since the script restores modified files but
cannot delete new ones.

That backup is git-ignored scratch and `git clean -fdx` destroys it. Committing
before this work would give a rollback that cannot be lost that way; no commit is
made here because the user manages git themselves.

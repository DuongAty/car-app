# VietKTV Full HD Design

## Summary
Adopt `1920x1080` as the primary design canvas for the entire VietKTV app. The app should render as a fixed Full HD karaoke TV interface first, then scale down proportionally on smaller displays instead of reflowing each screen independently.

This replaces the current `1280x720` shell approach and aligns the running app more closely with the approved karaoke neon references.

## Goals
- Make `1920x1080` the canonical layout target for all major screens
- Keep the karaoke neon visual language intact
- Ensure mockup proportions and runtime UI stay visually consistent
- Avoid layout breakage caused by mixing fixed pixel blocks with flexible vertical compression
- Keep future UI edits anchored to one stable TV-first layout system

## Non-Goals
- No new feature development
- No redesign of the karaoke neon visual identity
- No separate mobile-first layout system in this phase
- No attempt to optimize every screen for portrait beyond safe fallback behavior

## Core Decision
Use a single Full HD design canvas for the app:
- design width: `1920`
- design height: `1080`
- render strategy: fixed canvas inside a shell, scaled with `FittedBox(BoxFit.contain)` on smaller displays

On screens smaller than Full HD, the app should shrink as one composed surface. It should not selectively reflow columns, swap into alternate desktop-like or mobile-like compositions, or re-balance spacing independently.

## Root Cause Of Current Breakage
The current UI diverges from the references because of three combined issues:
- the app shell still uses a `1280x720` canvas
- individual screens mix fixed heights with `Expanded` regions
- key panel widths and heights are hardcoded without a single Full HD layout contract

This causes preview, keyboard, result list, and surrounding panels to compete for height differently at runtime than they do in the reference composition.

## Architecture Changes
### Shell
Update `lib/core/shared/widgets/karaoke_shell.dart` to be the single owner of design-canvas sizing:
- change canvas from `1280x720` to `1920x1080`
- keep background, aura, and content slots
- centralize outer padding and safe-area compensation for the Full HD frame

### Layout Tokens
Add Full HD layout constants under `lib/core/` for:
- shell paddings
- top bar height target
- bottom hint bar height target
- source-card sizes
- recommendation panel width
- result panel width
- center panel width behavior
- preview panel height
- search panel height
- virtual keyboard height

These values should be named and shared rather than repeated inline across features.

## Screen-Level Design
### Source Selection Screen
Rebuild around the `1920x1080` canvas:
- larger and more spacious top bar
- centered headline block sized for TV viewing distance
- three source cards sized and aligned for a Full HD row
- wider bottom hint bar with balanced spacing

The three source cards should remain a stable row in the Full HD composition rather than wrapping responsively in the primary design mode.

### Song Browser Screen
Define a stable three-column TV layout for Full HD:
- left recommendations panel with fixed design width
- center preview and search zone as the primary visual focus
- right results panel with fixed design width

Within the center column:
- preview panel has a fixed Full HD target height
- search bar has a fixed target height
- virtual keyboard has a fixed target height when visible
- when keyboard is hidden, the center column should preserve preview prominence rather than collapsing into mixed flex behavior

## Behavioral Rules
- `BACK` closes the on-screen keyboard first, then navigates back
- tapping or focusing the search field opens the keyboard
- tapping outside the search region closes the keyboard
- these behaviors remain unchanged during the Full HD migration

This phase is about layout consistency, not new interaction design.

## Responsive Strategy
Primary strategy:
- render Full HD first
- scale the composed surface down uniformly on smaller screens

Fallback behavior:
- if the device is not landscape, the existing safe fallback can remain temporarily
- no new portrait parity work is required in this phase

The key rule is that landscape TV-style screens should no longer switch into a partially reflowed layout based on intermediate width thresholds.

## Files Expected To Change
- `lib/core/shared/widgets/karaoke_shell.dart`
- `lib/core/theme/` or `lib/core/constants/` for new Full HD layout tokens
- `lib/features/source_selection/presentation/pages/source_selection_page.dart`
- `lib/features/song_browser/presentation/pages/song_browser_page.dart`
- related shared widgets only if they need new size variants

## Testing Strategy
Add or update widget tests to verify:
- the main screens still render under the new shell
- the song browser search keyboard still opens and closes correctly
- no obvious render overflow occurs at the Full HD test size

Manual verification should cover:
- `1920x1080`
- a smaller landscape display where the Full HD canvas is scaled down

## Acceptance Criteria
- the app shell uses `1920x1080` as the primary design canvas
- home and song browser screens look proportionally aligned with the karaoke references
- the song browser no longer shows distorted preview or compressed keyboard layout in landscape
- the app preserves the TV-style Full HD composition when scaled down
- `flutter analyze` passes
- `flutter test` passes

## Risks
- some existing fixed dimensions may need one more tuning pass after the first migration
- bottom and top bars may need balancing once the larger canvas is active
- if any shared widget encodes assumptions from the older `1280x720` layout, those assumptions will need to be removed rather than patched around

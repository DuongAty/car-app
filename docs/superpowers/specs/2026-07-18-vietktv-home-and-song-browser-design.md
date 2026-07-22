# VietKTV Home And Song Browser Design

## Summary
Build two Android-first Flutter screens for VietKTV:
- a source selection home screen matching the provided neon karaoke reference
- a song browser screen reached from the selected source card

The implementation must use the existing feature-first Flutter structure, Riverpod state management, shared design-system components, and responsive layouts that remain usable on Android 10+ devices. Landscape is the primary layout. Portrait does not need a separate design, but it must not overflow or break.

## Goals
- Recreate the visual feel of both reference screens as closely as practical in Flutter
- Support both touch and remote/D-pad navigation
- Make focus behavior deterministic by screen region rather than relying on default Flutter traversal
- Use mock local data for the first version
- Support virtual keyboard input and live filtering on the song browser screen
- Keep the UI easy to extend toward real APIs and additional karaoke flows
- Establish `karaoke neon` as the default visual language for future UI work in this repository

## Non-Goals
- No backend integration in this phase
- No real media playback
- No full language localization system beyond a local toggle UI state
- No portrait-specific redesign

## Architecture
Use two dedicated features:
- `lib/features/source_selection/presentation/...`
- `lib/features/song_browser/presentation/...`

Use `lib/core/` for shared UI and tokens:
- `theme/` for neon color tokens, spacing, radius, text styles, glow styles
- `shared/widgets/` for layout shell and reusable focusable components
- optional `shared/models/` or feature-local models for mock UI data

Add routes for:
- source selection screen
- song browser screen

The song browser route receives the selected music source so the second screen can style its header and data appropriately.

## Shared UI System
Create or extend these reusable primitives:
- `karaoke_shell`: app background, safe-area handling, content padding, top navigation slot, bottom hint bar slot
- `focusable_tile`: generic focus wrapper with focused, pressed, and idle visual states
- `glow_card`: neon bordered source card used on the home screen
- `app_top_nav`: top action row with icon, label, badge, and active state
- `app_bottom_hint_bar`: bottom instruction bar for remote and touch hints
- `search_input_shell`: stylized search field matching the dark neon look
- `virtual_key_tile`: keyboard key with focus and pressed states

Design tokens must centralize:
- background colors
- neon accent colors by source type
- text colors
- border colors
- glow intensity and shadows
- spacing and radius values

Any later UI change in this repository should inherit this same visual language by default unless the user explicitly asks for a different direction.

## Screen 1: Source Selection
### Layout
The screen contains:
- left-aligned VietKTV logo
- top-right action menu with connection/settings/exit
- language toggle
- centered welcome headline and subtitle
- three large source cards for YouTube, SoundCloud, and M-Cloud
- bottom instruction bar with volume, OK/select, back, clear queue, and queue count

### Behavior
- Initial focus is on the YouTube card
- Left/right moves between source cards
- Up moves from cards to the nearest top action or language toggle
- Down moves from cards to the bottom hint bar when needed
- Pressing OK on a source card navigates to the song browser screen and passes the selected source
- Touch interaction triggers the same actions as focus selection

### Visual Direction
The layout should stay close to the provided reference:
- dark gradient background
- neon card borders and underlines
- strong source-specific glow
- bold centered headline
- minimal chrome around top actions

## Screen 2: Song Browser
### Layout
The screen contains:
- top navigation with search/list/selected/settings/exit and language/globe controls
- left recommendation panel
- center video preview/player panel
- search input below the preview
- on-screen keyboard below the search field
- right search results panel
- bottom instruction bar

### Behavior
- Initial focus is on the search input or first keyboard key, depending on the final implementation convenience, but keyboard entry must be immediately accessible
- Typing from the virtual keyboard updates the search query
- Results filter live against mock data
- Selecting a result can add it to a local queue state
- Recommendation items, result items, top nav actions, keyboard keys, and bottom actions are all touchable and focusable
- Focus traversal is region-based and explicit

### Player Panel Scope
The preview panel is visual only in this phase:
- static image
- mock rating stars
- mock timeline and playback controls
- no actual streaming or playback

## Focus And Navigation Model
Use explicit focus nodes and a small focus-coordination layer per screen. Each screen defines named regions and directional transitions.

### Screen 1 Regions
- `topActions`
- `languageToggle`
- `sourceCards`
- `bottomHints`

### Screen 2 Regions
- `topActions`
- `leftRecommendations`
- `previewPanel`
- `searchInput`
- `virtualKeyboard`
- `rightResults`
- `bottomHints`

The goal is stable D-pad behavior:
- left/right move inside rows first
- up/down move between related regions in a predictable way
- focus restoration returns to the previously selected item when re-entering a region

## State Management
Use Riverpod for local UI state.

### Source Selection State
- selected source card index
- selected top action index
- selected language

### Song Browser State
- current source
- search query
- focused keyboard position if needed
- filtered mock results
- selected result index
- local queue count
- favorite state if included in bottom hints

Keep business rules out of widgets. Providers should expose state and simple intent methods such as:
- `selectSource`
- `toggleLanguage`
- `appendSearchCharacter`
- `backspaceSearch`
- `clearSearch`
- `addSongToQueue`

## Data Model
Use mock local data with typed models:
- `music_source.dart`
- `song_item.dart`
- `nav_action_item.dart`
- `bottom_hint_item.dart`

`SongItem` should include:
- id
- title
- artist or subtitle
- duration
- thumbnail path or mock reference
- source type
- badge text when needed

## Responsive Strategy
Landscape is primary. For smaller widths:
- reduce horizontal gaps
- clamp panel widths
- allow internal scrolling for long lists
- keep keyboard and result list visible without overflow

Portrait does not need separate artwork parity, but:
- the screen must remain scrollable or adapt with stacked sections
- no clipped controls
- no render overflow

Avoid using a single full-screen image background as the implementation basis. The reference image may be reused for temporary thumbnails or visual placeholders, but the UI itself should be built from Flutter widgets for maintainability.

## Testing Strategy
Add basic widget tests for:
- source selection screen renders core sections
- tapping a source card navigates to song browser
- typing on the virtual keyboard updates the query
- filtering reduces visible result items

Focus traversal tests are optional in this phase if they become brittle, but core navigation and query behavior should be covered.

## Implementation Order
1. Extend theme tokens for the karaoke neon visual system
2. Build shared shell, top nav, bottom hint bar, focus wrapper, and glow card components
3. Implement source selection feature and route
4. Implement song browser feature and route handoff
5. Add virtual keyboard and mock filtering
6. Add explicit focus graph and D-pad behavior
7. Add basic widget tests

## Risks And Constraints
- Pixel-perfect visual matching may require iterative tuning of gradients, glow, and spacing
- Focus behavior across touch and D-pad can become messy if not centralized early
- Using the reference screenshots as direct full-screen backgrounds would speed up visuals but would reduce responsiveness and maintainability, so this design rejects that approach
- Large thumbnail assets may need to be mocked or compressed for smooth local iteration

## Acceptance Criteria
- Home screen visually matches the first reference closely enough to be recognizable at a glance
- Selecting a source card opens the song browser screen
- Song browser visually matches the second reference closely enough to be recognizable at a glance
- Virtual keyboard input updates the query and filters mock results live
- Main actions are usable by both touch and D-pad
- Layout remains usable on Android 10+ devices in landscape and does not break in portrait

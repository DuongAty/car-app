# Karaoke Neon Guidelines

## Purpose
This repository uses `karaoke neon` as the default visual language. When adding or editing UI, keep the result visually consistent with the existing VietKTV screens unless a newer requirement explicitly asks for a different style.

## Core Look
- Use dark cinematic backgrounds, never flat white app surfaces by default.
- Use neon accents sparingly but clearly: green, red, orange, purple, and blue.
- Surfaces are liquid glass: translucent slabs with thickness, floating above the
  background aurora. Never plain opaque containers.
- Use glow only to emphasize focus, active state, selected items, or primary branded areas.

## Liquid Glass
Every surface and control goes through `LiquidGlass` in
`lib/core/shared/widgets/liquid_glass.dart`. Do not hand-roll a translucent
`Container` when a surface is needed.

What makes it liquid rather than flat glassmorphism:
- The rim catches light **unevenly**, brightest toward the top-left, with a
  weaker catch opposite. A uniform border reads as a plain box.
- A bright bevel sits inside the top edge and a shadow inside the bottom edge,
  so the slab has apparent thickness.
- Corners are Apple-style superellipses (`RoundedSuperellipseBorder`); buttons
  and chips are true capsules (`capsule: true`).
- Surfaces are lifted by a soft drop shadow.

Rules when using it:
- `detail: LiquidGlassDetail.full` for large surfaces (panels, cards, bars).
  Use `simple` for anything that appears in bulk — keys, badges, small round
  buttons — because the blurred edge passes add up.
- Raise `opacity` when a glow sits directly behind the surface, otherwise the
  bloom bleeds through the face and washes the whole panel out.
- No `BackdropFilter`. Real refraction needs a full-screen texture read per
  surface and these screens stack many surfaces at once; Android TV boxes
  cannot afford it. The gradient plus rim treatment stands in for it.

## Tokens First
Do not hardcode visual values directly in feature screens when the value should be shared. Reuse or extend:
- `app_colors.dart`
- `app_spacing.dart`
- `app_radius.dart`
- `app_text_styles.dart`
- `app_glows.dart`
- `app_theme.dart`

If a new screen needs another repeated color, shadow, radius, or spacing rule, add it to `lib/core/theme/` first.

## Focus And Interaction
- Remote/D-pad focus must be obvious at a glance.
- Focused elements should use brighter border color, stronger glow, or higher contrast background.
- Touch and focus states should feel like the same component system, not two different designs.

## Component Rules
- Build reusable shared widgets before repeating neon cards, top actions, bottom hint bars, search shells, or keyboard keys.
- Extend `lib/core/shared/widgets/` when a visual pattern appears more than once.
- Keep feature screens responsible for layout and state wiring, not repeated styling details.

## Typography
- Use bold, high-contrast headings for primary karaoke screens.
- Use muted secondary text for supporting labels, metadata, and helper copy.
- Avoid decorative font changes unless the whole screen direction requires it.

## Responsive Behavior
- Landscape is the primary karaoke layout.
- On smaller widths, preserve hierarchy first: top bar, primary content, actions.
- Reduce gaps and panel widths before collapsing the visual language.
- Do not allow render overflow or clipped controls on Android 10+ devices.

## Editing Rule
If you are changing only one part of the UI, do not redesign it in isolation. Match the existing karaoke neon tokens, panel shapes, accent behavior, and focus treatment so the screen still looks like part of the same product.

# Vision wall interaction performance — analysis and fixes (2026-08-04)

Owner report: the redesigned vision board feels laggy and stuttering.
This document is the analysis, what shipped, what was tried and rejected
(with numbers), and what remains open.

## How it was measured

`VisionWallPerformanceTests` hosts the real `VisionBoardCanvas` in an
offscreen `NSWindow` and pumps pan / zoom / drag / republish ticks
through the same code paths a trackpad drives, timing each tick.
Two hard-won rules about this harness:

- **The window and a runloop pump are mandatory.** Without them,
  @Published mutations queue an update that never runs; the first cut
  of the harness reported 0.13ms/tick for everything — the cost of
  nothing. The empty-tick floor is now measured explicitly (~0.3ms).
- **This machine drifts up to 2× with thermals.** Numbers are only
  comparable within one process, interleaved A/B. Several early
  conclusions drawn from run-to-run comparisons were wrong.

Board under test: 150 elements (pictures, clippings, notes, links) and
12 cords, 1440×900 viewport, debug build.

## What was wrong

One `ObservableObject` published everything. Every trackpad tick mutated
`transform` on the same object that holds cards, selection, and working
state, so at up to 120Hz:

1. the whole canvas body re-evaluated,
2. the card list re-filtered,
3. every element was rebuilt with ~20 fresh closures — closures never
   compare equal, so SwiftUI could not skip a single one,
4. every element re-rendered: shadow, paper texture, tack, torn edges,
5. every cord re-stroked eight paths, three through `.blur` (an
   offscreen render pass per blur per cord).

Measured: **pan 33.4ms/tick, zoom 53.9, drag-one-card 28.5 — and even a
selection change 27.9**, against an 8.3ms budget at 120Hz. The flat
~28ms floor for *any* publish was the signature: cost was O(everything)
regardless of what changed.

## What shipped

- **The camera is its own object** (`VisionWallCamera`), observed only
  by the views that genuinely follow it: the transform-applying wrapper
  (`WallCameraApplied`), the wall surface, and the cords layer (weight
  is zoom-boosted). `viewModel.transform` remains as a forwarding
  accessor, so every caller and test compiled unchanged.
- **Elements are skippable.** `WallScrap` wraps each element and is
  `Equatable` over what draws (card + flags), deliberately excluding
  the closures. Unchanged elements skip wholesale — shadows, textures
  and all. `WallCordStrand` does the same per cord, with zoom folded
  into the compared thickness so pans skip cords and zooms re-stroke
  them.
- **Zoom reaches screen-constant adornments through the environment**
  (`\.wallZoom`), read only by leaf views (working badge, link tag,
  rotate handle). A pinch re-lays-out those leaves, never whole
  elements.
- **Cords lost their three `.blur` passes** — the cast shadow is two
  nested strokes, the sub-point edge blurs were invisible at any zoom.
  Verified by eye against a render; the twist and round body survive.
- **The toolbar's zoom readout** is fed by a coarse integer percent
  (`onReceive` + `removeDuplicates`), so chrome re-renders a handful of
  times per pinch instead of at 120Hz.
- **`VisionWallInvalidationTests`** pins the architecture with
  deterministic render-counts (thermal-immune, unlike milliseconds):
  select → exactly 1 element body; pan/zoom → exactly 0; drag → 1.
  Before this work those numbers were "all of them, every tick."

Same-session before/after: **pan 33.4 → 10.5ms, zoom 53.9 → 23.6,
drag 28.5 → 15.6, republish 27.9 → 14.8** — and the republish/drag
remainder is dominated by the one-time diff walk (~63µs/element in
debug; release builds are substantially faster), not rendering.

## Tried, measured, rejected

- **9-slice shadow sprite via `NSImage.capInsets`** — routed every
  element's shadow through the AppKit CPU draw path per tick; made
  everything worse. Reverted. (A SwiftUI-`capInsets` sprite measured
  fine in isolation, but the live `.shadow` turned out not to be the
  dominant cost once measured honestly — see below.)
- **Viewport culling with hysteresis** — interleaved A/B at fit zoom,
  working zoom, and on a deliberately huge wall: no measurable
  difference in any regime (10.5ms both ways). Removed rather than
  keep unproven complexity.
- **Region-cached world-anchored marks tile** — worked, but subtly
  darkened the whole wall (two snapshot tests caught it) and saved
  ~1ms. Removed; the surface draws its marks inline as before.
- **Tack blur → gradient fills** — part of the sprite experiment;
  reverted with it.

## Open questions (honest)

- ~10ms/tick of pan cost remains at 150 elements that does **not**
  reproduce in micro-harnesses: rectangles with the same shadows,
  rotations, hover/context-menu/gesture machinery, and Canvas textures
  all pan at ≈1ms. Finding it needs a live Instruments profile of the
  running app (Core Animation + SwiftUI instruments), not more proxy
  experiments. At owner-scale boards (40–60 elements) the shipped
  work should already feel markedly smoother, and release builds
  shrink the remaining per-element diff cost further.
- Dragging a card republishes the whole card array per tick by design;
  a transient drag-offset outside the model would cut the diff walk
  during drags. Worth doing if drags still read as heavy in release.

## Guardrails left in place

- `VisionWallInvalidationTests` — deterministic, CI-safe.
- `VisionWallPerformanceTests` — prints ms/tick per scenario with
  catastrophe-level ceilings (120–150ms) that flag an architectural
  regression without flaking on thermals; read the printed numbers,
  not just the green.

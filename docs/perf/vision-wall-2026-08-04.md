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

---

# Scaling audit — big projects (2026-08-05)

Owner requirement: the wall must be usable on really big projects and
must never constrain the app because the project is large. Audited by
measurement on a 1,000-element / 80-cord board (32-column grid, mixed
pictures and clippings), plus code review of every O(N) path.

## What big projects actually hit

1. **A 1,000-element board did not lag — it died.** The full canvas
   crashed during its first ticks (silently: exit 1, no crash report —
   and a harness lesson: stdout is block-buffered when piped, so the
   evidence of how far it got was sitting unflushed in the buffer;
   breadcrumbs go to stderr).
2. **Every mounted full element costs ~150µs per camera tick** in
   AppKit bookkeeping (tracking areas, tooltips, menus) even when its
   SwiftUI body never re-runs: 1,000 mounted elements pan at 155ms/tick
   against 5.4ms for 1,000 bare rectangles, and rotation, gestures, and
   a repainting full-viewport backdrop were each measured innocent
   (+0.6, +0.4, +1.6ms). The cost is being mounted, not being drawn.
3. **Cords were worse per unit**: 80 interactive cords cost ~40ms/tick
   — each carries a tooltip, tap targets, and a giant invisible hit
   stroke along its whole length.
4. **Every element retains its decoded thumbnail in @State** (~0.9MB at
   card size), so resident memory scaled with the project, not the
   screen: ~900MB для 1,000 pictures. (The decode cache itself was
   already bounded and off-main — this was view-state retention.)
5. **A ⌘A drag was quadratic** — one array search per dragged card per
   tick.

## The scale policy (WallScale)

Boards at or under 150 elements are untouched — every element mounts in
full at every zoom, pixel-identical to before (snapshot tests unchanged).
Past 150:

- **Working zoom** mounts full elements only for the camera's stage
  (visible rect + 75% margin, republished with hysteresis a few times
  per screenful — never per tick). Off-stage elements don't exist:
  no AppKit bookkeeping, no retained thumbnails.
- **Far out** (zoom < 0.35, where a tack is sub-pixel and a tag is
  eight pixels wide) every element renders as a flat chip: paper tone,
  tilt, words, the picture if a thumbnail is ALREADY decoded — a chip
  never starts a decode, so standing back over a huge board fires zero
  decode storms. Chips keep tap-select and drag (screen-space gesture),
  and the wall-level right-click ring works unchanged.
- **Cords on big boards** draw the same twine but register no per-cord
  interaction (the wall's own hit-test opens the thread ring, where
  naming and cutting live); far out they drop their sub-pixel knots
  and tags too.
- The zoom threshold reaches views as a **published boolean that flips
  only on crossings** — observing the zoom itself from the elements
  layer would put the ForEach back on the 120Hz path this file just
  got off.
- The ⌘A drag uses an index map captured at drag start: O(K) per tick.

## Numbers (1,000 elements, 80 cords, debug)

| scenario            | before      | after |
|---------------------|-------------|-------|
| mount               | crash       | 0.6s  |
| pan (overview)      | 217ms/tick  | 28ms  |
| pan (working zoom)  | —           | 21ms  |
| select              | 364ms       | 88ms  |
| drag one (overview) | 294ms       | 88ms  |
| drag all 1,000      | died        | 356ms |

Release ≈ debug here: the costs are CA/AppKit-side, which optimization
levels don't touch.

## Honest remainders

- Any publish still walks all N for diffing (~63µs/element debug): a
  selection click on 1,000 elements is ~0.1s. One-off, acceptable;
  the fix if ever needed is identifier-keyed ForEach with per-element
  observation, which is real surgery.
- Dragging at working zoom republishes the model per tick (the
  transient-drag-offset refactor remains the right follow-up if drags
  read heavy in release on real boards).
- Guards: `VisionWallScaleTests` runs the 1,000-element board through
  every scenario with catastrophe ceilings — before the policy that
  test *crashes*, which is the regression it exists to catch. Policy
  edges (150 gate, 0.35 threshold, hysteresis, nil-stage default) are
  pinned in `WallScalePolicyTests`.

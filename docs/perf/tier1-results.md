# Tier 1 Results — 2026-07-08

Same machine, same deterministic stress project, same scenarios as
`baseline.md`. Raw JSONs in `docs/perf/tier1-2026-07-08/`.

## What shipped in Tier 1

1. **Incremental editor sync (audit B1)** — `ParagraphDiff` minimal splice
   replaces the full-document `setAttributedString` for every rebuild
   instruction; style-aware (type-only changes re-render); full-rebuild
   fallback when the diff can't be trusted. 17 unit tests on the splice math.
2. **Double rebuild killed (B2)** — `applyRebuildInstruction` stamps the
   version it applied; `updateNSView` skips the redundant second rebuild.
   Wizard focus path's unconditional third rebuild → no-op sync.
3. **Stats off the keystroke path (B3)** — the 4× O(document) outline/stat
   passes are debounced 300ms instead of running synchronously inside every
   structural keystroke.
4. **Margin redraw gated (B4)** — dirty-rect culling before layout queries;
   no more unconditional `needsDisplay` per SwiftUI pass.
5. **Hidden tabs sleep (A2, LRU-2)** — only current + previous tab stay
   mounted; heavy view-models survive as `CentralViewStack` @StateObjects.
6. **characterImageMap cached (B8)** — no longer rebuilt per render pass.

## Headless model benchmarks (XCTClockMetric averages)

| Benchmark | Baseline | Tier 1 | Δ |
|---|---|---|---|
| **Return-key burst ×20** | 529 ms (26 ms/Return) | **33 ms (1.7 ms/Return)** | **−94% (16×)** |
| **Undo burst (10+10)** | 535 ms | **32 ms** | **−94% (17×)** |
| Convert project → script | 6 ms | 6 ms | — (untouched) |
| Typing flush ×20 | 8 ms | 8 ms | — (already cheap) |
| Stats passes (single run) | 26 ms | 26 ms | — (now debounced, off keystroke) |
| Timeline rebuild (headless) | ~0.4 ms | ~0.4 ms | — (Tier 2 target) |

## In-app scenarios (hang watchdog)

| Scenario | Metric | Baseline | Tier 1 | Δ |
|---|---|---|---|---|
| **tabsweep** | hitch rate | 459/517 (89%) | 299/431 (69%) | **−35% rate** |
| | hangs >100ms | 415 | 250 | **−40%** |
| | worst stall | 1,650 ms | 887 ms | **−46%** |
| | cumulative stall | ~230 s | ~97 s | **−58%** |
| **publish** | hangs >100ms | 10 | 8 | −20% |
| | cumulative stall | 4.2 s | 4.0 s | −6% |
| **open** | worst stall | 65 ms | 66 ms | — (load 85 ms unchanged) |

In-app editor path (from tabsweep counters): the old
`rebuildAttributedString` averaged 24 ms / max 64 ms per operation on the
stress script and ran 2–3× per keystroke; the splice path
(`editor.incrementalSync`) now handles content changes and full rebuilds run
only on mount/layout changes.

## Honest read

- **Editor typing/structural feel: fixed at this scale.** A Return went from
  ~75–150 ms of main-thread work to single-digit ms model-side plus one
  targeted splice — under the 16 ms frame budget with headroom.
- **Tab switching: halved, not solved.** The remaining tabsweep stall is each
  tab's own FIRST-mount cost and per-tab body work — Tier 2/3 items
  (timeline lazy rebuild, image decoding off-main) and the LRU-2 tradeoff
  (revisits remount).
- **The publish fan-out barely moved — as the audit predicted.** With only
  one tab alive, the residual cost is the current tab's own subtree
  re-diffing on every whole-project publish (Overview's O(scenes×shots)
  computed props, A8) and the monolithic `@Published project` itself (A1,
  Tier 4). The `publish` scenario is the metric to watch for Tier 2+.

## Regression guards now active

- `PerformanceBaselineTests` runs in every full test pass — a future change
  that reintroduces O(document) work on the keystroke path shows up as a
  529 ms-style number in the log.
- `ParagraphDiffTests` (17 cases incl. UTF-16/emoji, repeated-paragraph
  ambiguity, style-only changes) pins the splice math.

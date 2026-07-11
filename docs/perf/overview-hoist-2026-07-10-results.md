# Overview computed-prop hoist — perf results (2026-07-10)

Release build, `--perf-scenario` runner, stress project. Measures the
main-thread watchdog (hangs >100 ms, worst single stall, cumulative stall).

## Change

`ProjectOverviewView.body` recomputed `allScenes` (O(scenes)) ~4× and
`allShotsWithImages` (O(scenes×shots)) 2× per body pass, plus a third full
shot-walk for the stat bar's count — and every whole-project publish
re-evaluated the body, so the editor's 500 ms flush fan-out paid that cost on
every tick while Overview was the visible tab (audit A8).

Fix: walk the project **once per body pass** — hoist `scenes`,
`shotsWithImages`, and `totalShotCount` into `let` bindings at the top of
`body`; `shotsWithImages(in:)` now takes the already-computed scene list
instead of recomputing `allScenes` internally. Pure efficiency change, no
behavior or layout difference.

## Numbers (2 runs each; pre-fix captured same session, same binary config)

| Scenario | Metric | Pre-fix | Post-fix |
|---|---|---|---|
| **publish** | hangs >100 ms | 2 | **0** |
| | worst stall | 125 ms | **66–69 ms** |
| | cumulative stall | 1,127 ms | **764–901 ms** |
| **tabsweep** | hangs >100 ms | 143 | 139–140 (noise) |
| | worst stall | 742 ms | 735–789 ms (noise) |

## Honest read

- **Publish path: crosses under the hang threshold.** Typing with Overview
  visible no longer produces a >100 ms main-thread hang; worst stall roughly
  halved. This is the direct payoff — Overview's redundant recompute was a
  real term in the editor flush fan-out.
- **Tabsweep unchanged, as expected.** Overview is one of many tabs; its mount
  cost was never the dominant tabsweep term. The residual ~139 hangs / ~742 ms
  worst stall is per-tab **first-mount** cost (timeline lazy rebuild, image
  decode off-main) — the remaining Tier 2/3 work, tracked separately.
- **Fan-out refactors deprioritised by measurement.** The `publish` fan-out
  that Tier 4 (@Published project split, A1) targets is now at 0–2 hangs /
  ~0.8 s — down from 8 hangs / 4.0 s at Tier 1. The coordinator-chrome split
  (A5/A7) touches only 5 files and never appeared in the hot path. Neither is
  justified by current numbers; **tab first-mount is the next real target.**

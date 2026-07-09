# UI Performance Baseline — 2026-07-08 (pre-remediation)

Captured on branch `screenplay_update` BEFORE any Tier 1–4 fixes from
`document/summary/directorschair-ui-performance-audit.html`. Every number
below is against the deterministic stress project (**Stress Test L60**:
60 scenes, ~420 shots, ~2,000 script elements, 25 characters, 30 locations,
40 props, 70 cues; seed fixed in `StressProjectGenerator.swift` — never
change the seed between comparisons).

## How to reproduce

```bash
# Headless model-layer benchmarks (5 iterations each, averages below):
xcodebuild test -project DirectorsChair-Desktop.xcodeproj \
  -scheme DirectorsChair-Desktop -destination 'platform=macOS' \
  -only-testing:DirectorsChair-DesktopTests/PerformanceBaselineTests

# In-app scenarios (JSON reports land in "~/Directors Chair/perf-results/"):
BIN=<DerivedData>/Build/Products/Debug/DirectorsChair-Desktop.app/Contents/MacOS/DirectorsChair-Desktop
"$BIN" --perf-scenario open
"$BIN" --perf-scenario publish     # simulates the editor's 500ms flush fan-out, 20 ticks
"$BIN" --perf-scenario tabsweep    # visits every tab twice
"$BIN" --perf-scenario idle        # 30s background churn
```

Raw scenario JSONs archived in `docs/perf/baseline-2026-07-08/`.

## Headless model-layer benchmarks (XCTClockMetric averages)

| Benchmark | Baseline | Notes |
|---|---|---|
| Convert project → script elements | **6 ms** | runs on every external `.script` event (audit F5) |
| Typing flush cycle ×20 | **8 ms** (0.4 ms/flush) | model-side flush is cheap — the cost is the publish fan-out |
| **Return-key burst ×20 (model only)** | **529 ms (26 ms/Return)** | audit B3 quantified: the 4 stat passes are ~26 ms (below) — stats ARE the model-side Return cost |
| Undo burst (10 returns + 10 undos) | **535 ms** | snapshot restore + full-rebuild path |
| Stats passes (pages+words+stats+outline) | **26 ms** | synchronous on EVERY structural edit (audit B3) |
| Timeline rebuild (VM only) | **~0.4 ms** | cheap headless; 23 ms in-app with duration estimation (below) |

## In-app scenarios (hang watchdog: 50 ms sampling; hitch >16 ms, hang >100 ms)

| Scenario | Duration | Hitches | Hangs >100ms | Worst stall | Total stall | Key counters |
|---|---|---|---|---|---|---|
| **open** | 2.1 s | 3/41 samples | 0 | 65 ms | 143 ms | `project.load` 85 ms |
| **publish** (20 simulated typing flushes) | 12.4 s | **69/247 (28%)** | **10** | **124 ms** | **4.2 s** | CentralViewStack body woke 43× for 20 publishes |
| **tabsweep** (all tabs ×2) | 25.9 s | **459/517 (89%)** | **415** | **1,650 ms** | ~230 s cumulative | `timeline.rebuild` 23 ms/event; `editor.rebuildAttributedString` avg 24 ms, max 64 ms |

## What the baseline confirms (mapping to audit findings)

- **Typing feel (audit B1–B3):** every Return = ~26 ms model-side (stats)
  + 2 × ~24–64 ms view-side attributed-string rebuilds → **~75–150 ms per
  structural keystroke** on a 2,000-element script. Frame budget is 16 ms.
- **Flush fan-out (audit A1/A2):** 20 whole-project publishes produced 10
  main-thread hangs >100 ms and 4.2 s of cumulative stall — while "typing".
- **Hidden-tabs-alive (audit A2/F2):** with all tabs mounted, the main
  thread was stalled during **89% of samples**; worst freeze 1.65 s.
- **Open path:** 85 ms decode+publish at 60 scenes with no assets — real
  projects add the asset-directory walk and first-render image decodes.

## Rules for comparison runs

1. Same machine, plugged in, no other heavy apps.
2. Never change the generator seed or scale; the shape test
   (`testStressProjectShape`) fails if the workload silently shrinks.
3. Run each scenario after a fresh app launch (the runner terminates the app).
4. Record results as a new `docs/perf/<label>.md` + archived JSONs; compare
   hitch counts, worst stall, and the per-path counter averages.

# Navigator Responsiveness — 2026-07-08

Owner report: "the navigation panel still feels a bit sluggish."
Scenario: `--perf-scenario navigator` — stress project on the script view with
the navigator mounted, 20 typing-flush publishes, then a 10-click rapid
navigation probe (80ms cadence). Raw JSONs in `docs/perf/navigator-2026-07-08/`.

## Result

| Metric | Before | After | Δ |
|---|---|---|---|
| Main-thread hitch rate | 408/472 (86%) | **153/348 (44%)** | **−49%** |
| Hangs >100ms | 333 | **77** | **−77%** |
| Cumulative stall | 91.6 s | **21.1 s** | **−77%** |
| Outline teardowns per 20 events | 20 | **0** | eliminated |
| Timeline refreshes per 20 events | 20 | **1** | eliminated |
| Rapid clicks landed (80ms cadence) | dropped by design | **10/10** | fixed |

## The four defects found and fixed

1. **navigateTo dropped clicks.** A 150ms lock + 250ms debounce silently
   ignored fast clicks (a unit test literally documented the defect as an
   XCTExpectFailure). Guards protected animated transitions that no longer
   exist — removed; every click lands. History stacks also stopped being
   @Published (each navigation re-rendered all coordinator observers).
2. **The outline destroyed itself on every project event** (audit A4):
   `.id(UUID())` tore down all rows per editor flush — and killed in-progress
   inline rename/add fields. Rows diff by stable ids; teardown removed.
3. **Single-clicks on scene rows waited out the double-click window**
   (~250ms) because `.onTapGesture(count:1)` sat next to a count-2
   recognizer. Selection now fires instantly via simultaneousGesture.
4. **The timeline canvases repainted EVERYTHING on every publish** — 65-72%
   of all main-thread samples (caught by CPU sampling, invisible to the
   counters). Two fixes: (a) TimelineContainer skips setProject/refresh when
   a content fingerprint of what the timeline renders is unchanged;
   (b) TimelineCanvas/TimelineHeaderCanvas are Equatable over their render
   inputs and gated with .equatable() — closure props were defeating
   SwiftUI's dependency pruning, so every container body re-eval redrew the
   full display list.

## Remaining (Tier 2/3)

Worst single stall (~800ms) is tab first-mount cost during the click sweep —
image decoding off-main (Tier 3) and per-tab body work are the next targets.
The `publish` scenario's residual (current-tab subtree re-diff on the
monolithic @Published project) remains the Tier 4 metric.

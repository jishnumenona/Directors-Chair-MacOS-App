# Tab first-mount: image decode off the main thread (2026-07-11)

Release build, `--perf-scenario tabsweep`, stress project. The tabsweep now
attributes per-tab main-thread stall via a watchdog snapshot bracketing each
navigation (`tabstall.<view>` counters; perf-scenario only, not shipped).

## Finding 1 — the benchmark was blind to image decode

The stress fixture (`StressProjectGenerator`) created 60 scenes / 400 shots /
25 characters but **no image files**, so every `NSImage(contentsOf:)` on mount
hit a missing path and returned nil in microseconds. Image decode — a real,
dominant mount cost in actual projects — was completely unmeasured.

Fix: `generateOnDisk()` now writes 24 distinct high-entropy PNGs (1600×1000)
and wires them into scenes/shots/characters/locations/poster. `makeProject`
(used by the byte-stable QA fixture and the regression guards) is deliberately
left image-less and unchanged.

Effect of adding images (aggregate tabsweep stall): **~40s → ~56s**. That +16s
is the image-decode-on-mount cost the harness previously could not see.

## Finding 2 — the decode runs synchronously on the main thread

Overview cards decoded images synchronously inside `.onAppear { loadImage() }`
— on the main thread — unlike `SceneCardView`, which already decodes off-main
via `Task.detached` + cache (Tier 3). Overview's five loaders now delegate to
`OverviewImageCache.loadAsync(...)`, which returns a cache hit immediately and
otherwise decodes off-main, assigning back on the main actor.

### Overview tab, controlled before/after (identical image fixture, 3 runs)

| | worst mount stall |
|---|---|
| **Sync (before)** | 7638 / 8160 / 7635 ms |
| **Async (after)** | 6400 / 6679 / 5383 ms |

Consistent **~16% reduction (~1.2s)** on the landing tab's worst mount stall.

## Honest scope

The *aggregate* tabsweep stall did **not** drop — because only Overview was
converted. ~10 other tabs (Script/avatars, Playback viewfinder, Story Design,
Curation, Shot List, Scenes, Assets) still decode synchronously on mount, and
several live in `DirectorsChairViews`. Overview is fixed as the exemplar (and
the highest-traffic tab); the same `loadAsync` pattern should be swept across
the remaining views to move the aggregate. Async decode adds a small
Task-spawn + image-arrival re-render cost, so the win shows per-tab, not in the
aggregate, until the sweep is complete.

**Net this change:** the benchmark now measures image decode (permanently), and
the landing tab's mount is ~16% faster. The cross-view sweep is the tracked
follow-up.

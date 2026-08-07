# App-wide view scale audit — big projects (2026-08-06)

Owner requirement: every view — Overview, Script, Bubble, Shot List,
Scenes, Assets, Production, Story Design, and their sub-surfaces — must
be usable on projects of any size, and the app must never feel
constrained by project size. Same discipline as the wall's audit
(`vision-wall-2026-08-04.md`): measure first, fix what the numbers
convict, document the rest honestly.

## Method

`BigProjectViewAuditTests` (app test target) mounts each tab through the
REAL router — `CentralViewRouter` with the real coordinator, project
view-model, and timeline — against a **300-scene / 3,600-shot / ~10k
element** stress project (StressProjectGenerator, deterministic seed),
measuring cold mount and the cost of one whole-project publish while
the tab is frontmost. Model paths that run on every save/open/sync are
timed at the same scale. Debug build; run-to-run thermal variance is
±50%, so only order-of-magnitude and before/after-in-one-session
comparisons are meaningful.

## Results

Model layer — **healthy, no action**:

| path                    | at 300 scenes |
|-------------------------|---------------|
| save encode             | 111ms / 3.6MB |
| open decode             | 144ms         |
| script conversion       | 40ms          |
| timeline rebuild        | ~0ms          |

Views — before → after this audit's fixes:

| view        | mount           | publish/tick     |
|-------------|-----------------|------------------|
| Overview    | 1,171 → **131ms** | 91.5 → **16ms** |
| Script      | 1,201ms         | 12ms             |
| Bubble      | 117ms           | ~20ms            |
| Shot List   | 407ms           | ~44ms (see below)|
| Scenes      | 235ms           | ~10–20ms         |
| Assets      | 47ms            | 5ms              |
| Production  | 128–235ms       | ~12–25ms         |
| Story Design| 735ms           | ~20ms            |

No view crashed and no view exceeded ~1.2s to mount — the wall's cliff
(death at 1,000 elements) has no analogue here.

## Fixed

1. **Overview scene strip** — a non-lazy `HStack` mounted every scene
   card (300 of them), and each card resolved its sequence name by
   walking all sequences: O(scenes × sequences) per body pass, re-paid
   on every publish. That held the whole tab at ~11fps during anything
   that publishes repeatedly (sync progress, inline edits). Now a
   `LazyHStack` with a one-pass sceneId→sequenceName index. Mount 9×
   better, publish 5.6× better. Character and location strips made lazy
   in the same pass.
2. **Scene grid cards decoded full-resolution stills** for ~300pt tiles
   (async, but a 12MP bitmap per mounted card). Now downsampled through
   the shared `ThumbnailImageCache` (max 1024px).
3. **Scene detail shot thumbnails used `AsyncImage`** — which routes a
   LOCAL file through URLSession and decodes at full resolution per
   card. Now `AsyncThumbnail` (shared cache, downsampled, off-main).
4. **`filteredShots` recomputed three times per Shot List body pass**
   (count, isEmpty, ForEach source — each a full filter+sort+copy of
   3,600 shots). Now cached behind a revision/filter key.
5. **Shot List resync deep-compared 3,600 `Shot` structs on every
   publish** (`onChange(of: shots)`) just to conclude "unchanged". The
   host now passes a revision integer the adapter bumps when shots
   actually change; comparison is O(1). (Hosts that pass no revision
   keep the old deep-compare path — previews and tests unchanged.)

## Documented, not fixed (with reasons)

- **Shot List publish ~44ms** (debug) survives the fixes above: it is
  `List` diffing 3,600 rows per update — the same ~12µs/item diff-walk
  constant the wall audit measured. Unlike the wall's AppKit costs this
  is pure Swift work, which release builds cut several-fold (~10–15ms
  expected); and it is paid per edit, not per frame. If real release
  use feels heavy, the fix is scene-sectioned or paged shot lists —
  a UX decision, not a patch.
- **Script mount 1.2s** at ~10k elements: building the NSTextView
  storage for the whole screenplay. Typing, undo, and stats are already
  optimized and measured flat (Tier-1 work, `PerformanceBaselineTests`);
  the 1.2s is once per cold tab switch, and current+previous tabs stay
  mounted. Incremental storage build is possible but risks the editor —
  not worth it at current evidence.
- **Story Design mount 735ms** — cold once, publish fine. Watch, don't
  touch.
- **Overview poster and example browser still use `AsyncImage`** for
  one-off hero images — single images, not per-row: harmless.
- Timeline, Curation, Playback rebuilds measured ~0 at scale (timeline)
  or are media-bound rather than project-size-bound (playback).

## Guards

`BigProjectViewAuditTests` stays in the suite: every central view is
mounted against the 300-scene project on every verify run, with a 30s
mount ceiling per view as the catastrophe guard, and the numbers print
to stderr for eyeballing (stdout buffering eats evidence when a runner
dies — the wall audit's lesson).

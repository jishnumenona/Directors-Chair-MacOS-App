# DirectorsChair — Master Test Plan

**Status: living document.** The authoritative statement of *what* we test,
*how* we test it, and *how quality is judged*. The executable form of the
workflow catalog lives in `qa/catalog/*.json`; this document is the strategy
and the human-readable plan around it.

---

## 1. Purpose & scope

Guarantee that every user-facing feature of the DirectorsChair Desktop app
works end-to-end, that regressions are caught before merge, and that the same
framework extends to the future server and desktop↔server integration without
redesign. The plan is written to a standard an acquiring engineering
organization would recognize as professional: layered coverage, explicit
gates, deterministic fixtures, a defect lifecycle, traceability from
requirement → test → result, and an autonomous triage-and-fix loop.

**In scope now:** the Desktop macOS app (all six Swift packages + the app
target). **Reserved (schema in place, wired later):** server contract/API
tests, desktop↔server integration.

---

## 2. Test levels (the pyramid)

| Level | What it proves | Where | Gate |
|---|---|---|---|
| **Unit** | Model, persistence, business logic in isolation | `*/Tests` per package + app-target tests | ✅ blocking |
| **Contract / component** | A subsystem's public API (converters, exporters, timeline builder, save manager) | package tests | ✅ blocking |
| **Snapshot** | Rendered SwiftUI components match reference pixels | `DirectorsChairViews` snapshots | ✅ blocking locally; CI-skipped (machine-dependent) |
| **Performance** | Hot paths stay within budget on a large project | `PerformanceBaselineTests` + `--perf-scenario` | ✅ blocking on regression |
| **End-to-end (UI)** | Real user workflows through the actual UI | `DirectorsChair-DesktopUITests` (XCUITest) | ⚠️ advisory now (see §8) |
| **Manual / exploratory** | Judgment, aesthetics, VoiceOver, unscripted paths | owner, guided by the catalog | tracked, not gated |

The base of the pyramid (unit/contract) is broad and fast (1,125 tests,
seconds); E2E is the thin, high-value top that exercises whole workflows.

---

## 3. Environments & test data

- **Deterministic fixtures.** Every automated test runs against generated,
  seeded data — never a hand-made project that can drift:
  - `StressProjectGenerator` (seeded SplitMix64) — 60-scene project for
    performance and load.
  - `QAFixture` (`--qa-fixture`) — a small 3-scene project the app
    regenerates and opens on launch, so UI E2E assertions are byte-stable.
- **Launch modes** (composable flags): `--uitesting` (skip onboarding/auth
  gate), `--qa-fixture` (deterministic project), `--perf-scenario <name>`
  (headless benchmark).
- **Isolation.** Fixtures live under `~/Directors Chair/local/` and are
  disposable; no test depends on a pre-existing user project.

---

## 4. Entry & exit criteria

**Entry (a change is ready to test):** it compiles; `./scripts/verify.sh`
has been run locally.

**Exit / Definition of Done (a change may merge):**
1. All **gate** suites pass (unit, contract, snapshot-local, performance, app
   target) — the QA orchestrator reports `gate_pass: true`.
2. No **open P0/P1 bug** attributable to the change.
3. Any behavior change has a test proving it (same commit).
4. Performance-sensitive changes show benchmark numbers that did not regress.
5. The change went through the git workflow (branch → PR → green CI).

---

## 5. Severity & priority

**Priority** (of a test case — how important the workflow is):
- **P0** — core value / data safety. Must be automated and green always.
- **P1** — primary features users touch every session.
- **P2** — secondary features, format variations.
- **P3** — polish, rare paths, deep accessibility.

**Severity** (of a bug — how bad the failure is):
- **S1 Critical** — data loss, crash, or a P0 workflow broken. Blocks release.
- **S2 Major** — a P1 workflow broken or wrong output. Blocks release.
- **S3 Minor** — cosmetic, an edge case, a non-blocking annoyance.
- **S4 Trivial** — nit, wording, ideal-world improvement.

Release gate: **zero open S1/S2.**

---

## 6. Defect lifecycle

Every failing test becomes a fingerprinted bug in `qa/bugs/bugs.json` with a
stable id that persists across runs:

```
identified → diagnosed → fixing → fixed → verified
                      ↘ flagged-ux (owner decision)
   verified ──(fails again)──> regressed → …
```

- **Automatic transitions:** first failure → `identified`; a later run that
  no longer sees it → `verified`; a `verified` bug that fails again →
  `regressed`.
- **Claude-driven transitions:** `diagnosed` (root cause written), `fixing`,
  `fixed` (code/test fix applied), `flagged-ux` (a design decision left for
  the owner). Protocol: `qa/CLAUDE-QA.md`.
- **Autonomy policy:** code defects and test defects are fixed autonomously
  and re-verified in the same cycle; UX/product-judgment issues are flagged
  with a recommended fix and wait for the owner.

---

## 7. Traceability

`qa/catalog/*.json` links every workflow case to its executing test via the
`automation` field. The report renders **coverage** (automated cases ÷
catalogued cases) per feature, so the gap between "what we intend to test"
and "what is automated" is always visible and shrinking — never hidden.

Requirement → catalog case (`E2E-EDIT-004`) → test
(`testNewSceneWizardTypedFlow`) → run result → (if failed) bug
(`BUG-XXXXXXXX`) → fix commit. The whole chain is inspectable.

---

## 8. Known limitations & roadmap

- **UI E2E is advisory, not gating, today.** The XCUITest suite is
  implemented and drives real workflows, but on this multi-display / multi-
  Space development Mac the app window does not register reliably with the
  UI-test driver (it passed intermittently at the timeout boundary). This is
  an **environment** issue, not an app defect — the app reaches the fixture
  project (confirmed in launch logs). It is marked `gate: false` in
  `qa/suites.json` until run on a dedicated, single-display CI agent where
  XCUITest is reliable. **This is itself a tracked QA finding**, exactly the
  kind of honest gap this framework is built to surface rather than paper
  over.
- **Snapshot tests are local-gating only** — machine-dependent pixel
  rendering (documented in the git-workflow CI history).
- **Server & integration levels are schema-reserved**, activated when the
  server exists.

Roadmap: stabilize UI E2E on a CI runner → promote to gating; automate the
P1/P2 catalog backlog; wire the perf gate to fail on regression thresholds.

---

## 9. Pipeline integration (deployment, later)

`qa/run-qa.sh` exits non-zero iff a gate suite fails, so it drops into a
deployment pipeline as a single quality gate. Planned stages:
`lint → gate suites → (dedicated agent) UI E2E → perf gate → build → sign →
release`. The report (`qa/reports/latest.html`) becomes the per-build quality
artifact; `run.json` is the machine-readable record a pipeline stores and
trends.

---

## 10. Running it

```bash
qa/run-qa.sh                 # everything (gate + advisory)
qa/run-qa.sh --gate-only     # fast pre-merge gate (no UI E2E)
qa/run-qa.sh --suite core    # one suite
open qa/reports/latest.html  # the report
```

The full architecture — orchestrator, parser, registry, report, Claude
bridge, and how the server plugs in — is in `qa/README.md`.

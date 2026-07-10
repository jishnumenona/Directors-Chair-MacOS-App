# QA Framework — Architecture

A scalable, component-agnostic test framework: it runs suites, normalizes
results into a machine-readable record, tracks bugs across runs with a full
lifecycle, renders an aesthetic report, and exposes a protocol for a Claude
Code instance to fix defects autonomously. Built so the future **server** and
**desktop↔server integration** slot in without changing the engine.

The strategy and the human test plan live in `docs/qa/test-plan.md`. This
document is the *implementation*.

## Data flow

```
        ┌───────────────┐
        │ qa/suites.json│  registry: which suites, how to run, gate vs advisory
        └──────┬────────┘
               │
        ┌──────▼────────┐     raw logs      ┌──────────────────┐
        │  run-qa.sh    │ ────────────────▶ │ qa/runs/<ts>/raw │
        │ (orchestrator)│                    └────────┬─────────┘
        └──────┬────────┘                             │
               │                          ┌───────────▼────────────┐
               │                          │ lib/parse_results.py   │  logs → run.json
               │                          └───────────┬────────────┘
               │                          ┌───────────▼────────────┐
               │                          │ lib/bug_registry.py    │  run.json + bugs.json
               │                          │  fingerprint + lifecycle│  → updated bugs.json
               │                          └───────────┬────────────┘
               │                          ┌───────────▼────────────┐
               │                          │ lib/generate_report.py │  → report.html
               │                          └───────────┬────────────┘
               ▼                                      ▼
        exit 0/1 (gate)                   qa/reports/latest.html + latest-run.json
                                                      │
                                          ┌───────────▼────────────┐
                                          │  Claude Code instance  │  reads run.json + bugs.json
                                          │  (qa/CLAUDE-QA.md)     │  → fix / flag / re-verify
                                          └────────────────────────┘
```

## Components

| Path | Role |
|---|---|
| `qa/suites.json` | Pluggable suite registry. Each entry: id, kind (`spm`/`xcodebuild`/`xcodebuild-ui`), target, `component`, `gate`. **Add a server = one entry.** |
| `qa/catalog/*.json` | The test *plan* as data — every feature's E2E workflows with IDs, priorities, steps, expected results, and the `automation` link. `desktop.json` is live; `server.json` / `integration.json` are schema-reserved. |
| `qa/run-qa.sh` | Orchestrator. Runs suites, calls the parser/registry/report, exits non-zero iff a **gate** suite fails (pipeline-ready). |
| `qa/lib/parse_results.py` | Normalizes raw xcodebuild/swift-test logs → `run.json` (suites, per-test results, flat `findings`). Component-agnostic. |
| `qa/lib/bug_registry.py` | Persistent ledger. Fingerprints each finding to a stable `BUG-XXXX`; drives the lifecycle (identified → verified, auto-reopen on regression). |
| `qa/lib/generate_report.py` | Self-contained aesthetic HTML: gate verdict, suites, catalog coverage, bug lifecycle board with fixes. |
| `qa/CLAUDE-QA.md` | The bridge protocol: how a Claude instance consumes a run, fixes code/test defects autonomously, flags UX, and re-verifies. |
| `qa/bugs/bugs.json` | The ledger (committed — it's the memory across runs). |
| `qa/reports/latest.html` | The published latest report; `latest-run.json` its machine-readable twin. |
| `qa/runs/<ts>/` | Per-run artifacts (raw logs, run.json, report). Gitignored — transient. |

## Design principles

1. **Component-agnostic core.** `run.json`, the ledger, and the report treat
   `desktop`, `server`, and `integration` identically. Nothing in the engine
   knows what a "desktop" is — it reads suite definitions.
2. **The catalog is data.** Coverage is computed, not claimed. A workflow that
   isn't automated shows as a gap, not a green tick.
3. **Bugs have memory.** Fingerprinting means the same defect keeps one id
   across runs; the report shows a real lifecycle, not a fresh dump each time.
4. **Gate vs advisory.** Flaky or environment-sensitive suites report without
   blocking; the release gate is only the trustworthy suites.
5. **Autonomy with a boundary.** Code and test defects fixed automatically;
   UX/product decisions flagged. Matches the repo's standing policy.
6. **No external dependencies.** Pure Python 3 stdlib + xcodebuild/swift;
   the report is a single self-contained HTML file.

## Extending to the server (when it exists)

1. Add its test invocations to `qa/suites.json` with `component: "server"`
   (and a new `kind` if the runner differs, e.g. `pytest`/`go-test` — add one
   branch in `run-qa.sh`'s `case`).
2. Fill in `qa/catalog/server.json` cases and wire their `automation`.
3. Add `component: "integration"` suites for desktop↔server round-trips.

The parser, registry, report, and Claude bridge need **zero changes** —
server findings flow into the same ledger and report, and the same
fix/flag/verify loop applies. That is the scalability guarantee.

## Usage

```bash
qa/run-qa.sh                 # all suites (gate + advisory)
qa/run-qa.sh --gate-only     # fast pre-merge gate
qa/run-qa.sh --suite views   # one suite
open qa/reports/latest.html  # the report
```

Exit code is the pipeline gate: `0` = releasable (all gate suites green),
`1` = blocked.

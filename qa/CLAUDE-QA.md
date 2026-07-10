# QA Bridge — Protocol for a Claude Code Instance

This file tells any Claude Code instance how to consume a QA run, fix the
bugs it can fix autonomously, flag the ones it shouldn't, and re-verify —
writing the outcome back so the next report shows the full lifecycle.

## Inputs (produced by every `qa/run-qa.sh`)

- `qa/reports/latest-run.json` — the run: suites, per-test results, and a
  flat `findings` array (each failing test / build error).
- `qa/bugs/bugs.json` — the persistent ledger. Each finding is fingerprinted
  to a stable `BUG-XXXXXXXX` id so a defect keeps one identity across runs.
- `qa/catalog/*.json` — what each test is supposed to prove (traceability).

## The loop

1. **Read** `latest-run.json`. If `summary.gate_pass` is true and there are
   no open bugs, report success and stop.
2. **For each open bug** in `bugs.json` (`status` not `verified`/`flagged-ux`):
   a. **Reproduce & diagnose.** Open the failing test and the code under it.
      Find the root cause. Write it to the bug's `diagnosis` field and set
      `status: "diagnosed"`.
   b. **Classify:**
      - **Code defect** (crash, wrong data, broken logic, dead control,
        race, off-by-one, regression): fix it. Set `status: "fixing"`,
        apply the fix, run `./scripts/verify.sh` (and the specific suite),
        write what you did to `fix`, set `status: "fixed"`.
      - **UX / design judgment** (is-this-the-right-behavior, visual
        preference, product decision): DO NOT change behavior. Write a
        recommended fix to `fix`, set `status: "flagged-ux"`. It surfaces in
        the report for the owner.
      - **Test defect** (flaky timing, wrong assertion, environment
        assumption — e.g. fixed sleeps, machine-dependent snapshots): fix
        the TEST, not the app. Note it in `fix`, set `status: "fixed"`.
   c. Never mark a bug `verified` by hand — that transition is automatic:
      the next run that no longer sees the finding flips it to `verified`.
3. **Re-run** `qa/run-qa.sh` (or the affected `--suite`). The registry
   auto-verifies fixed bugs and reopens any regressions.
4. **Report.** The regenerated `qa/reports/latest.html` now shows each bug's
   full arc. Summarize to the user: found N, fixed M code defects, flagged K
   UX items, verified all fixes green.

## Editing bugs.json safely

- Only touch these fields: `status`, `diagnosis`, `fix`, and append to
  `history` (`{"run": "<current run_id>", "event": "diagnosed|fixing|fixed|flagged-ux"}`).
- Never edit `id`, `first_seen`, or the fingerprint basis.
- Keep it valid JSON; the next `run-qa.sh` reads it.

## Guardrails (inherit the repo rules)

- All fixes go through the git workflow: a branch, `./scripts/verify.sh`
  green, a PR (see `docs/git-workflow.md`). QA fixes are commits like any
  other — `fix(<scope>): …` referencing the `BUG-XXXX` id.
- Autonomy boundary matches the owner's standing policy: **fix code and test
  defects autonomously; flag UX/product decisions.** When unsure whether a
  behavior is a bug or a decision, flag it — don't guess.
- Do not weaken a test to make it pass (deleting assertions, widening
  tolerances to meaninglessness). If a test is wrong, fix it correctly and
  say why in `fix`.

## Extending to the server (later)

When the server exists, its suites appear in `qa/suites.json` and its cases
in `qa/catalog/server.json` / `integration.json`. This protocol is unchanged:
findings from server contract/integration tests flow into the same ledger
with `component: "server" | "integration"`, and the same fix/flag/verify
loop applies.

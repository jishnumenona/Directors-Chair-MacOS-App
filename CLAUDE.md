# DirectorsChair Desktop — Project Rules for Claude

## Git — binding rules (full playbook: `docs/git-workflow.md`)

- **`main` is the protected trunk. Never commit to it directly** — every
  change goes: branch off main (`feature/` `fix/` `perf/` `chore/`) → PR →
  squash-merge when CI is green → branch deleted. No exceptions for docs
  or "tiny" changes.
- **Before every commit:** `./scripts/verify.sh` must be green.
- Conventional commits: `type(scope): imperative summary` + a WHY body with
  the test delta; perf claims carry measured numbers.
- Update a work branch by **rebasing onto origin/main**; force-push only
  work branches, only with `--force-with-lease`.
- Undo on main = `git revert` via PR. Never rewrite published history,
  never force-push main, never move a pushed release tag, never commit
  build products or secrets, never merge past red CI.
- Pre-2026-07 history lives in `archive/*` tags (old branch names and old
  commit hashes from before the 2026-07-09 history rewrite don't resolve).
- Owner-only: GitHub settings, history rewrites, release-tag deletion,
  credential operations (playbook §13).
- For anything not covered here, follow `docs/git-workflow.md` — it is
  binding, not advisory.

## Project practices

- After code changes, close any running instance of the app and relaunch:
  `./scripts/run.sh` (use `--no-build` only when the binary is already
  freshly built by a test run).
- The official status tracker is
  `../document/summary/directorschair-progress.html` — update it when
  status meaningfully changes (grades, test counts, shipped work).
- Performance-sensitive paths (editor, canvases, event fan-out,
  persistence) have benchmarks: `PerformanceBaselineTests` + the
  `--perf-scenario` runner. Record moved numbers in `docs/perf/`
  (protocol: `docs/perf/baseline.md`).
- Scope: Desktop app only. The Gitea server and iOS/iPad repos are
  deprecated; server-dependent features are deferred to the future
  server phase. Signing + App Sandbox are parked until the owner has an
  Apple Developer account.

# DirectorsChair Git Workflow — The Playbook

**Status: binding.** This document defines how all git work happens in this
repo. Claude follows it on every feature, fix, and release; the repo-root
`CLAUDE.md` carries the always-loaded summary and points here. When this
document and habit disagree, this document wins. Established 2026-07-09,
after the repo professionalization (trunk model, rewritten history).

---

## 1. Repository model

```
main                    ← THE TRUNK. Default branch. Protected:
                          no force-push, no deletion, linear history.
                          Every commit on main has green CI and came
                          through a merged branch — never a direct commit.
<type>/<topic>          ← short-lived work branches, cut from main,
                          merged back via PR, deleted after merge.
archive/*  (tags)       ← retired history (pre-2026-07 branches). Read-only.
v<semver>  (tags)       ← releases.
```

- One long-running branch exists as a legacy exception: `screenplay_update`
  (Editor v2). It merges to `main` once the owner validates Phase 1; after
  that, no work branch should live longer than roughly a week.
- Remote: `origin` = github.com/jishnumenona/Directors-Chair-MacOS-App.
  History was rewritten on 2026-07-09 — commit hashes in notes/docs from
  before that date no longer resolve; look content up via `archive/*` tags.

### Branch naming

| Prefix | Use | Example |
|---|---|---|
| `feature/` | new functionality | `feature/editor-v2-pagination` |
| `fix/` | bug fix | `fix/outline-hit-area` |
| `perf/` | performance work | `perf/tier3-image-cache` |
| `chore/` | tooling, docs, CI, refactors with no behavior change | `chore/git-workflow-docs` |
| `hotfix/` | urgent fix branched from a release tag | `hotfix/v3.4.1-save-crash` |

Lowercase, hyphenated, descriptive, no ticket-number soup.

---

## 2. The standard feature loop

Every unit of work — feature, fix, perf pass — follows this loop:

```bash
# 1. Start clean, from current trunk
git switch main && git pull --ff-only
git switch -c feature/<topic>

# 2. Work in small, coherent commits (see §3)
#    Before EVERY commit:
./scripts/verify.sh          # all suites green — no exceptions
#    (app-behavior changes: relaunch the app per global CLAUDE.md and
#     sanity-check the changed surface)

# 3. Keep the branch current if main moves (see §5)
git fetch origin && git rebase origin/main

# 4. Publish and open a PR
git push -u origin feature/<topic>
gh pr create --fill --base main

# 5. Merge when CI is green (squash keeps main linear and readable)
gh pr merge --squash --delete-branch

# 6. Update the local trunk and clean up
git switch main && git pull --ff-only
```

Definition of done for the loop: tests green locally AND in CI, tracker
(`document/summary/directorschair-progress.html`) updated if status changed,
branch deleted local+remote, `main` fast-forwarded locally.

**Perf-sensitive changes** (editor, canvases, event fan-out, persistence)
additionally run the relevant benchmark before merge and record numbers in
`docs/perf/` when they move (see `docs/perf/baseline.md` for the protocol).

---

## 3. Commit standards

Conventional-commit format, enforced by habit not tooling:

```
<type>(<scope>): <imperative summary ≤ 72 chars>

<body: WHY it changed and what the observable effect is — the diff
already says WHAT. Include measured numbers for perf claims and the
test delta ("App tests: 181 (was 178)").>

Co-Authored-By: Claude <the harness-required trailer>
```

- Types: `feat` `fix` `perf` `refactor` `test` `docs` `chore` `ci` `revert`.
- Scope = subsystem: `editor`, `navigator`, `timeline`, `bubble`, `core`,
  `sync`, `production`, `perf`, …
- **One logical change per commit.** Mechanical rename + behavior change =
  two commits. A commit must build and pass tests on its own.
- Tests belong in the same commit as the change they cover.
- **Never commit:** secrets/tokens/keys (push protection will also block),
  `.build/`/DerivedData/user-state files (gitignored — do not "force add"),
  binaries > ~1 MB without explicit owner discussion, commented-out code.

---

## 4. Pull requests & merging

- Every change to `main` goes through a PR — including Claude's, including
  docs. Direct pushes to `main` are reserved for repo-bootstrap emergencies
  and require stating the reason in the commit body.
- PR body: what + why + how verified (test counts, perf numbers, screenshots
  for UI). End with the harness-required generated-with footer.
- **Merge method: squash** (default — one clean commit per topic on main,
  linear history satisfied). Use **rebase-merge** only when a branch's
  individual commits are each independently valuable (e.g. a multi-commit
  perf tier where each step carries its own measurements).
- Merge only when CI is green. If CI is broken for unrelated reasons, fix CI
  first — never merge past a red pipeline.
- Delete the branch on merge (`--delete-branch`), local and remote.
- Solo-review reality: the owner isn't reviewing every PR, so the PR is the
  reviewable record, not a gate. Anything user-visible or risky: pause and
  ask the owner to try it before merging.

---

## 5. Keeping branches current

- **Rebase, don't merge, to update a work branch:**
  `git fetch origin && git rebase origin/main`. This preserves the linear
  history `main` requires.
- After rebasing a branch that was already pushed:
  `git push --force-with-lease` — **feature branches only, never `main`**
  (`main` rejects force-push at the server anyway). `--force-with-lease`
  always, never bare `--force`: it refuses to clobber commits you haven't
  seen.
- Conflicts during rebase: resolve favoring the semantics of BOTH changes
  (read both commits' intent, don't just pick a side), run
  `./scripts/verify.sh` after resolution, then `git rebase --continue`.
  If resolution turns risky mid-way: `git rebase --abort` and reassess.

---

## 6. Releases

Semantic versioning: `vMAJOR.MINOR.PATCH` (next release from v3.3 is v3.4.0).
MINOR for features, PATCH for fix-only releases, MAJOR for breaking
project-format changes (schema bumps).

```bash
git switch main && git pull --ff-only
./scripts/verify.sh --clean            # authoritative clean-build run
# 1. Release PR (chore/release-v3.4.0) MUST contain BOTH:
#      - CHANGELOG.md section "## [3.4.0]" (Keep-a-Changelog style, from the
#        conventional commits since the last tag: git log v3.3..main --oneline)
#      - MARKETING_VERSION bump to 3.4.0 in project.pbxproj
#    (release.yml verifies tag == MARKETING_VERSION and fails the build if not)
# 2. Merge it via the normal PR loop
# 3. Tag — ANNOTATED, on main, after the release PR merges:
git tag -a v3.4.0 -m "v3.4.0 — <one-line theme>"
git push origin v3.4.0
# 4. CI (release.yml) builds the versioned dmg/zip + SHA-256SUMS and creates a
#    DRAFT GitHub Release automatically. Publishing to users is a deliberate
#    second step: dispatch promote-desktop.yml (see docs/release-pipeline.md).
```

Release tags are permanent — never delete or move a pushed release tag. A
bad release gets a new PATCH release, not a rewritten tag. (Pre-release
dry-run tags like `v3.4.0-rc.1` are exempt: their drafts may be deleted.)
`./scripts/build-release.sh` remains the local, signed-path build for when
the Apple Developer account exists; CI is the canonical release builder.

---

## 7. Hotfixes

For a defect in a shipped release when `main` already carries unreleased work:

```bash
git switch -c hotfix/v3.4.1-<topic> v3.4.0    # branch from the TAG
# fix + test + verify.sh
git tag -a v3.4.1 && git push origin hotfix/... v3.4.1
git switch main && git cherry-pick <fix-sha>   # fix lands on trunk too — always
```

While `main` is itself unreleased-but-healthy (current situation), a plain
`fix/` branch through the standard loop is the hotfix.

---

## 8. Undo & recovery matrix

| Situation | Correct operation | Never |
|---|---|---|
| Uncommitted mess in working tree | `git restore <file>` / `git restore .` (look at the diff first) | `checkout .` blindly |
| Staged but unwanted | `git restore --staged <file>` | |
| Last commit wrong, **not pushed** | `git commit --amend` or `git reset --soft HEAD~1`, fix, recommit | amending PUSHED commits on shared branches |
| Commit wrong, **already pushed to main** | `git revert <sha>` via the normal PR loop — history moves forward | reset/force-push on main (server-blocked anyway) |
| Wrong branch committed to | `git switch correct-branch && git cherry-pick <sha>`, then remove from the wrong branch (reset if unpushed, revert if pushed) | |
| Branch deleted too early | commits live in `git reflog` for ≥90 days: `git branch rescue <sha>` | |
| Need pre-2026-07 history | `archive/*` tags (`git log archive/gantt_chart`) | recreating old branches |
| Catastrophic local corruption | fresh clone from origin; pre-rewrite state also exists in `../DirectorsChair-Desktop-backup-pre-rewrite.git` | |
| Anything involving `git reset --hard` | state what will be lost FIRST, check `git status` + `git stash list`, prefer `--keep` | reflexive `--hard` |

**The revert rule:** anything that reached `main` is undone by *adding* a
revert commit, never by removing history.

---

## 9. Stash policy

Stashes are for interruptions measured in minutes, not storage. If work must
pause longer: commit it to the work branch with `wip:` prefix (squashed away
at merge) — commits are visible and pushed; stashes rot invisibly. Never end
a session with a stash you haven't either applied or consciously dropped.

---

## 10. Tags

- `v*` — releases: annotated, on main, permanent (§6).
- `archive/*` — retired branch history: frozen; never build on them.
- Ad-hoc tags for experiments are allowed locally but never pushed.

---

## 11. History invariants (the never list)

1. **Never force-push `main`** (server-enforced, but don't try).
2. **Never rewrite published history again.** The 2026-07-09 rewrite was a
   one-time purge with the owner's explicit sign-off. If a large file or
   secret lands in history: rotate/revoke FIRST, tell the owner, and treat a
   rewrite as an owner-approved exceptional event.
3. **Never commit build products.** `.gitignore` covers Xcode/SPM outputs;
   if a path fights the ignore rules, fix the rules, don't force-add.
4. **Never delete or move a pushed release tag.**
5. **Never merge past red CI.**
6. Keep the repo clone-fast: if a legitimate asset >1 MB must be versioned,
   raise it with the owner (Git LFS decision) before committing.

---

## 12. CI operations

- Config: `.github/workflows/ci.yml` — lint + all package suites + app
  target; triggers on push to `main`/work-branch prefixes, on PRs to main,
  and manually.
- Manual run: `gh workflow run CI --ref <branch>`.
- Watch: `gh run watch <id> --exit-status`; list: `gh run list`.
- If CI infra itself breaks (runner/billing/plugin), fixing it is a `ci:`
  commit and takes priority over feature work in flight.
- Roadmap item (owner-gated): once CI history is stable, add the CI job as a
  *required* status check on `main`'s protection so merges gate on it
  server-side.

---

## 13. Owner-only operations

Claude never does these autonomously; they need explicit owner direction
per occurrence:

- Changing GitHub repo settings (protection, default branch, visibility).
- Any history rewrite or force-push outside a work-branch rebase (§5).
- Deleting/moving release tags, deleting the backup mirror.
- Credential/token operations; adding collaborators.
- Creating/deleting repositories.

Routine pushes of work branches, opening/merging PRs per §4, and tagging
releases the owner asked for are all standing-authorized.

---

## 14. Quick reference

```bash
./scripts/verify.sh                  # all tests (before every commit)
./scripts/run.sh [--no-build]        # build+launch the app
git switch -c feature/<topic> main   # start work
git rebase origin/main               # stay current
gh pr create --fill --base main      # publish
gh pr merge --squash --delete-branch # land it
git revert <sha>                     # undo on main
git reflog                           # find "lost" commits
git log archive/<name>               # read retired history
```

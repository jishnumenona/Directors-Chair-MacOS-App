#!/usr/bin/env bash
#
# rewrite-history.sh — one-shot purge of committed build artifacts from git history.
#
# WHY: ~333 MB of the repo's .git store is stale `*/.build/*` SourceKit index
# blobs (six 64 MB data.mdb files + .pcm module caches) that were committed
# early and later untracked. They remain in history, so every clone drags all
# of it. Apple-grade repos of this size clone in seconds.
#
# WHAT IT DOES: rewrites ALL branches to remove every `*/.build/*` path, then
# aggressively garbage-collects. Expected result: .git drops from ~333 MB to
# single-digit MB.
#
# ⚠️  THIS IS DESTRUCTIVE AND REWRITES EVERY COMMIT HASH ON EVERY BRANCH.
#     After running it you MUST force-push, and anyone with a clone must
#     re-clone (their old hashes no longer exist). Because it touches the
#     public remote, it is intentionally left for the repo owner to run and
#     force-push consciously — the automated remediation does not do this step.
#
# HOW TO RUN (owner):
#   1. Ensure a backup:   git clone --mirror . ../DirectorsChair-Desktop-backup.git
#   2. Install the tool:  brew install git-filter-repo
#   3. Run this script:   ./scripts/rewrite-history.sh
#   4. Verify size:       du -sh .git         # expect < 15 MB
#   5. Verify build:      xcodebuild -scheme DirectorsChair-Desktop build
#   6. Force-push all:    git push --force --all && git push --force --tags
#
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> .git size before: $(du -sh .git | cut -f1)"

if command -v git-filter-repo >/dev/null 2>&1; then
  echo "==> Using git-filter-repo (recommended)"
  git filter-repo --force --path-glob '*/.build/*' --invert-paths
else
  echo "==> git-filter-repo not found; falling back to git filter-branch (slower)."
  echo "    Install the faster tool with: brew install git-filter-repo"
  git filter-branch --force --index-filter \
    'git rm -r --cached --ignore-unmatch "*/.build/*"' \
    --prune-empty --tag-name-filter cat -- --all
  rm -rf .git/refs/original/
fi

echo "==> Expiring reflog and garbage-collecting…"
git reflog expire --expire=now --all
git gc --prune=now --aggressive

echo "==> .git size after:  $(du -sh .git | cut -f1)"
echo
echo "Next: verify the build, then force-push:"
echo "  git push --force --all && git push --force --tags"

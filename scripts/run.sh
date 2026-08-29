#!/usr/bin/env bash
#
# run.sh — build (if needed) and launch the DirectorsChair Desktop app.
#
#   ./scripts/run.sh            # incremental build + launch
#   ./scripts/run.sh --no-build # just launch the last built app
#
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "${1:-}" != "--no-build" ]]; then
  echo "==> Building (incremental)…"
  xcodebuild build -scheme DirectorsChair-Desktop -destination 'platform=macOS' \
    CODE_SIGNING_ALLOWED=NO -quiet
fi

# Launch exactly what this tree builds: ask xcodebuild for the products dir
# (several DirectorsChair-Desktop-* DerivedData folders can coexist — one per
# worktree/checkout — and picking the first by listing order launched a
# day-old copy on 2026-08-29).
PRODUCTS=$(xcodebuild -showBuildSettings -scheme DirectorsChair-Desktop -destination 'platform=macOS' 2>/dev/null \
      | awk -F' = ' '/ BUILT_PRODUCTS_DIR = /{print $2; exit}')
APP="$PRODUCTS/DirectorsChair-Desktop.app"

if [[ ! -d "$APP" ]]; then
  echo "App not found — run without --no-build to build first." >&2
  exit 1
fi

# Close any running instance, then launch fresh
pkill -f "DirectorsChair-Desktop.app" 2>/dev/null || true
sleep 1
open "$APP"
echo "==> Launched: $APP"

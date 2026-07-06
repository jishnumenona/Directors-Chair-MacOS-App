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

# Locate the built app in DerivedData (path hash can change, so search for it)
APP=$(find ~/Library/Developer/Xcode/DerivedData -maxdepth 1 -name "DirectorsChair-Desktop-*" -type d 2>/dev/null \
      | head -1)/Build/Products/Debug/DirectorsChair-Desktop.app

if [[ ! -d "$APP" ]]; then
  echo "App not found — run without --no-build to build first." >&2
  exit 1
fi

# Close any running instance, then launch fresh
pkill -f "DirectorsChair-Desktop.app" 2>/dev/null || true
sleep 1
open "$APP"
echo "==> Launched: $APP"

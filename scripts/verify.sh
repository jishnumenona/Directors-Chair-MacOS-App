#!/bin/bash
#
# verify.sh - one-command health check for DirectorsChair-Desktop.
#
# Runs exactly what CI runs: every SPM package's test suite plus the app-target
# tests through the shared scheme, then prints a pass/fail summary. Exits
# non-zero if anything fails, so it doubles as a pre-merge gate.
#
# Usage:
#   ./scripts/verify.sh          # fast: uses incremental build caches
#   ./scripts/verify.sh --clean  # trustworthy: clears .build first (what CI sees)
#
set -o pipefail
cd "$(dirname "$0")/.." || exit 1

CLEAN=0
if [ "$1" = "--clean" ]; then CLEAN=1; fi

PACKAGES="DirectorsChairCore DirectorsChairServices DirectorsChairProduction DirectorsChairViews DirectorsChairExports"
FAIL=0
SUMMARY=""

if [ "$CLEAN" = "1" ]; then
  echo "==> Clearing build caches (clean mode)..."
  for p in $PACKAGES; do rm -rf "$p/.build"; done
fi

# Serial `swift test` prints a clean "Executed N tests, with M failures" summary
# (parallel mode suppresses it). CI runs the parallel variant to also catch
# test-isolation bugs; this local check favours a readable count.
for p in $PACKAGES; do
  echo "==> Testing $p..."
  out=$(cd "$p" && swift test 2>&1)
  # Reliable signals: per-failure "error: -[" markers, per-build-error markers,
  # and the grand-total test count (max of all "Executed N tests" lines).
  builderr=$(echo "$out" | grep -cE "error: (cannot|couldn't|no such|missing)|Compilation failed")
  testfail=$(echo "$out" | grep -c "error: -\[")
  tests=$(echo "$out" | grep -oE "Executed [0-9]+ tests" | grep -oE "[0-9]+" | sort -rn | head -1)
  if [ "$builderr" -gt 0 ]; then
    SUMMARY="$SUMMARY\nFAIL  $p  (build errors: $builderr -- suite did not run)"
    FAIL=1
  elif [ "$testfail" -gt 0 ]; then
    SUMMARY="$SUMMARY\nFAIL  $p  ($testfail tests failing of ${tests:-?})"
    FAIL=1
  else
    SUMMARY="$SUMMARY\nok    $p  (${tests:-?} tests)"
  fi
done

echo "==> Building & testing the app target (shared scheme)..."
appout=$(xcodebuild test -scheme DirectorsChair-Desktop -destination 'platform=macOS' \
  -only-testing:DirectorsChair-DesktopTests CODE_SIGNING_ALLOWED=NO 2>&1)
if echo "$appout" | grep -q "TEST SUCCEEDED"; then
  tests=$(echo "$appout" | grep -oE "Executed [0-9]+ tests" | grep -oE "[0-9]+" | sort -rn | head -1)
  SUMMARY="$SUMMARY\nok    DirectorsChair-Desktop (app)  ($tests tests)"
else
  n=$(echo "$appout" | grep -cE "error: -\[")
  SUMMARY="$SUMMARY\nFAIL  DirectorsChair-Desktop (app)  (failures: $n)"
  FAIL=1
fi

echo ""
echo "======================== VERIFY SUMMARY ========================"
printf "%b\n" "$SUMMARY"
echo "---------------------------------------------------------------"
if [ "$FAIL" = "0" ]; then echo "ALL GREEN"; else echo "FAILURES PRESENT (see per-package output above)"; fi
exit $FAIL

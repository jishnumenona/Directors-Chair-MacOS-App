#!/usr/bin/env bash
#
# run-qa.sh — the QA orchestrator.
#
# Runs every registered suite (qa/suites.json), normalizes results into a
# single machine-readable run.json, merges findings into the persistent bug
# registry, and renders an aesthetic HTML report. Designed so a Claude Code
# instance can then read run.json + bugs.json, fix code defects, and re-run.
#
# Usage:
#   qa/run-qa.sh                 # full run (all suites)
#   qa/run-qa.sh --gate-only     # skip advisory suites (fast pre-merge gate)
#   qa/run-qa.sh --suite core    # a single suite by id
#
# Exit code: 0 iff all GATE suites pass (advisory failures never block).
#
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
QA="$ROOT/qa"
PROJ="DirectorsChair-Desktop.xcodeproj"
DEST='platform=macOS'

GATE_ONLY=0
ONE_SUITE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --gate-only) GATE_ONLY=1 ;;
    --suite) ONE_SUITE="$2"; shift ;;
    *) echo "unknown arg: $1"; exit 2 ;;
  esac
  shift
done

# Deterministic run id from the environment (no Date in scripts we cache),
# fall back to a filesystem timestamp.
TS="$(date +%Y-%m-%d_%H-%M-%S)"
RUN_DIR="$QA/runs/$TS"
mkdir -p "$RUN_DIR/raw"
echo "==> QA run $TS"
echo "    $RUN_DIR"

# jq-free suite iteration via python (already a dependency for parsing).
# Delimiter is '|' (NOT tab): tab is IFS-whitespace, so bash `read` collapses
# empty fields between tabs and shifts columns — '|' preserves empty fields.
read_suites() {
  python3 - "$QA/suites.json" <<'PY'
import json, sys
for s in json.load(open(sys.argv[1]))["suites"]:
    print("|".join([s["id"], s["kind"], s.get("package",""),
                    s.get("scheme",""), "1" if s.get("gate") else "0"]))
PY
}

run_spm() {  # $1=package $2=logfile
  ( cd "$1" && swift test 2>&1 ) > "$2" 2>&1
}
run_xcode() {  # $1=scheme $2=logfile
  xcodebuild test -project "$PROJ" -scheme "$1" -destination "$DEST" \
    > "$2" 2>&1
}
run_xcode_ui() {  # $1=scheme $2=logfile — build once, then run
  xcodebuild test -project "$PROJ" -scheme "$1" -destination "$DEST" \
    -only-testing:DirectorsChair-DesktopUITests/DirectorsChair_DesktopUITests \
    > "$2" 2>&1
}

pkill -x DirectorsChair-Desktop 2>/dev/null || true

while IFS='|' read -r id kind package scheme gate; do
  [ -z "$id" ] && continue
  [ -n "$ONE_SUITE" ] && [ "$id" != "$ONE_SUITE" ] && continue
  if [ "$GATE_ONLY" = "1" ] && [ "$gate" = "0" ]; then
    echo "    skip (advisory): $id"
    continue
  fi
  log="$RUN_DIR/raw/$id.log"
  printf "    running %-12s ... " "$id"
  case "$kind" in
    spm)          run_spm "$package" "$log" ;;
    xcodebuild)   run_xcode "$scheme" "$log" ;;
    xcodebuild-ui) run_xcode_ui "$scheme" "$log" ;;
    *) echo "unknown kind $kind" > "$log" ;;
  esac
  if grep -q "TEST SUCCEEDED\|Test Suite 'All tests' passed\|0 failures" "$log"; then
    echo "done"
  else
    echo "FAILURES (see raw/$id.log)"
  fi
done < <(read_suites)

echo "==> parsing results"
python3 "$QA/lib/parse_results.py" "$RUN_DIR" "$QA/suites.json"
GATE_RESULT=$?

echo "==> updating bug registry"
python3 "$QA/lib/bug_registry.py" "$RUN_DIR/run.json" "$QA/bugs/bugs.json"

echo "==> rendering report"
python3 "$QA/lib/generate_report.py" "$RUN_DIR/run.json" "$QA/bugs/bugs.json" \
  "$QA/catalog" "$RUN_DIR/report.html"
# Also publish the latest report to a stable path.
cp "$RUN_DIR/report.html" "$QA/reports/latest.html"
cp "$RUN_DIR/run.json" "$QA/reports/latest-run.json"

echo
echo "==> report:  $QA/reports/latest.html"
echo "==> run.json: $RUN_DIR/run.json"
# Exit non-zero if any gate suite failed (for pipeline integration).
grep -q '"gate_pass": true' "$RUN_DIR/run.json" && exit 0 || exit 1

#!/usr/bin/env python3
"""
bug_registry.py — the persistent bug ledger.

Merges a run's findings into qa/bugs/bugs.json, preserving lifecycle across
runs. A finding is fingerprinted by (component, suite, test, normalized
message) so the SAME defect keeps ONE stable bug id run-to-run — its status,
diagnosis, and fix history accumulate rather than duplicating.

Lifecycle (a bug's `status`):
  identified  -> first seen; awaiting triage
  diagnosed   -> root cause written (by the Claude bridge)
  fixing      -> a fix is in progress
  fixed       -> fix applied; awaiting a green re-run to confirm
  verified    -> a subsequent run passed the case (auto-closed)
  flagged-ux  -> not a code defect; a design/UX decision for the owner
  regressed   -> was verified, now failing again (reopened)

This script only handles automatic transitions (identified / reopened /
verified). The Claude bridge writes diagnosed / fixing / fixed / flagged-ux
via the same file (see qa/CLAUDE-QA.md).
"""
import json
import re
import sys
import hashlib
from pathlib import Path


def fingerprint(f):
    msg = re.sub(r"\d+", "#", f.get("message", ""))  # ignore volatile numbers
    basis = f"{f['component']}|{f['suite']}|{f.get('test')}|{msg}"
    return "BUG-" + hashlib.sha1(basis.encode()).hexdigest()[:8].upper()


def main():
    run = json.loads(Path(sys.argv[1]).read_text())
    ledger_path = Path(sys.argv[2])
    ledger = json.loads(ledger_path.read_text()) if ledger_path.exists() else {"bugs": {}}
    bugs = ledger["bugs"]

    run_id = run["run_id"]
    current_fps = set()

    # Register / reopen everything failing this run.
    for f in run["findings"]:
        fp = fingerprint(f)
        current_fps.add(fp)
        if fp not in bugs:
            bugs[fp] = {
                "id": fp,
                "component": f["component"],
                "suite": f["suite"],
                "test": f.get("test"),
                "kind": f["kind"],
                "gate": f.get("gate", True),
                "title": (f.get("test") or f["suite"]) + ": " + f["message"][:80],
                "message": f["message"],
                "locations": f.get("locations", []),
                "status": "identified",
                "first_seen": run_id,
                "last_seen": run_id,
                "diagnosis": None,
                "fix": None,
                "history": [{"run": run_id, "event": "identified"}],
            }
        else:
            b = bugs[fp]
            b["last_seen"] = run_id
            b["message"] = f["message"]
            if b["status"] in ("verified", "fixed"):
                b["status"] = "regressed"
                b["history"].append({"run": run_id, "event": "regressed"})

    # Anything previously open that no longer appears is verified-fixed.
    for fp, b in bugs.items():
        if fp not in current_fps and b["status"] in (
                "identified", "diagnosed", "fixing", "fixed", "regressed"):
            b["status"] = "verified"
            b["last_seen"] = run_id
            b["history"].append({"run": run_id, "event": "verified"})

    ledger_path.parent.mkdir(parents=True, exist_ok=True)
    ledger_path.write_text(json.dumps(ledger, indent=2))

    open_bugs = [b for b in bugs.values()
                 if b["status"] not in ("verified", "flagged-ux")]
    print(f"registry: {len(bugs)} total, {len(open_bugs)} open, "
          f"{len(current_fps)} failing this run")


if __name__ == "__main__":
    main()

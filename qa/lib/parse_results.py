#!/usr/bin/env python3
"""
parse_results.py — normalize raw xcodebuild/swift test logs into a single
machine-readable run.json the report generator and the Claude bridge consume.

Input : per-suite raw logs written by run-qa.sh (qa/runs/<ts>/raw/<suite>.log)
Output: qa/runs/<ts>/run.json

The schema is component-agnostic on purpose: desktop, and later server /
integration suites, all produce the same record shape.
"""
import json
import os
import re
import sys
from pathlib import Path


TESTCASE_RE = re.compile(
    r"Test Case '-\[(?P<suite>[\w.]+)\.(?P<cls>\w+) (?P<method>\w+)\]' (?P<status>passed|failed) \((?P<dur>[\d.]+) seconds\)"
)
# Assertion failure lines: "<path>:<line>: error: -[Cls method] : <message>"
FAILURE_RE = re.compile(
    r"(?P<file>[\w/.\-]+\.swift):(?P<line>\d+): error: -\[[\w.]+ (?P<method>\w+)\][: ]+(?P<message>.*)"
)
EXECUTED_RE = re.compile(
    r"Executed (?P<count>\d+) tests?, with (?P<failures>\d+) failures?"
)
SKIPPED_RE = re.compile(r"with (?P<skipped>\d+) tests? skipped")


def parse_log(path: Path):
    text = path.read_text(errors="replace")
    tests = {}
    for m in TESTCASE_RE.finditer(text):
        key = f"{m['cls']}/{m['method']}"
        tests[key] = {
            "class": m["cls"],
            "method": m["method"],
            "status": m["status"],
            "duration": float(m["dur"]),
            "failures": [],
        }
    # Attach assertion messages to their test method.
    method_index = {}
    for key, t in tests.items():
        method_index.setdefault(t["method"], []).append(t)
    for m in FAILURE_RE.finditer(text):
        for t in method_index.get(m["method"], []):
            t["failures"].append({
                "file": os.path.basename(m["file"]),
                "path": m["file"],
                "line": int(m["line"]),
                "message": m["message"].strip(),
            })
    # Suite-level totals (last "Executed ..." line wins).
    executed = failures = skipped = None
    for m in EXECUTED_RE.finditer(text):
        executed, failures = int(m["count"]), int(m["failures"])
    sm = None
    for sm in SKIPPED_RE.finditer(text):
        pass
    if sm:
        skipped = int(sm["skipped"])
    build_failed = "** TEST FAILED **" in text and executed is None
    compile_errors = [
        line.strip() for line in text.splitlines()
        if ".swift:" in line and ": error:" in line and "Test Case" not in line
        and not FAILURE_RE.search(line)
    ][:20]
    return {
        "tests": list(tests.values()),
        "executed": executed,
        "failures": failures,
        "skipped": skipped,
        "build_failed": build_failed,
        "compile_errors": compile_errors,
    }


def main():
    run_dir = Path(sys.argv[1])
    raw_dir = run_dir / "raw"
    suites_meta = json.loads((Path(sys.argv[2])).read_text())["suites"]
    meta_by_id = {s["id"]: s for s in suites_meta}

    suites = []
    for log in sorted(raw_dir.glob("*.log")):
        suite_id = log.stem
        meta = meta_by_id.get(suite_id, {"id": suite_id, "name": suite_id,
                                         "component": "desktop", "gate": True})
        parsed = parse_log(log)
        passed = sum(1 for t in parsed["tests"] if t["status"] == "passed")
        failed = sum(1 for t in parsed["tests"] if t["status"] == "failed")
        status = "pass"
        if parsed["build_failed"] or parsed["executed"] is None:
            status = "error"
        elif failed > 0 or (parsed["failures"] or 0) > 0:
            status = "fail"
        suites.append({
            "id": suite_id,
            "name": meta.get("name", suite_id),
            "component": meta.get("component", "desktop"),
            "gate": meta.get("gate", True),
            "status": status,
            "passed": passed,
            "failed": failed,
            "skipped": parsed["skipped"] or 0,
            "executed": parsed["executed"],
            "build_failed": parsed["build_failed"],
            "compile_errors": parsed["compile_errors"],
            "tests": parsed["tests"],
        })

    gate_suites = [s for s in suites if s["gate"]]
    gate_pass = all(s["status"] == "pass" for s in gate_suites)
    total_pass = sum(s["passed"] for s in suites)
    total_fail = sum(s["failed"] for s in suites)
    total_skip = sum(s["skipped"] for s in suites)

    # All failing tests, flattened, as bug candidates for the Claude bridge.
    findings = []
    for s in suites:
        if s["build_failed"]:
            findings.append({
                "suite": s["id"], "component": s["component"],
                "kind": "build", "test": None,
                "message": "; ".join(s["compile_errors"]) or "Build/test invocation failed",
                "gate": s["gate"],
            })
        for t in s["tests"]:
            if t["status"] == "failed":
                findings.append({
                    "suite": s["id"], "component": s["component"],
                    "kind": "test", "test": f"{t['class']}/{t['method']}",
                    "message": " | ".join(f["message"] for f in t["failures"]) or "assertion failed",
                    "locations": [f"{f['file']}:{f['line']}" for f in t["failures"]],
                    "gate": s["gate"],
                })

    run = {
        "run_id": run_dir.name,
        "summary": {
            "gate_pass": gate_pass,
            "releasable": gate_pass,
            "total_passed": total_pass,
            "total_failed": total_fail,
            "total_skipped": total_skip,
            "suite_count": len(suites),
            "gate_suite_count": len(gate_suites),
            "finding_count": len(findings),
        },
        "suites": suites,
        "findings": findings,
    }
    out = run_dir / "run.json"
    out.write_text(json.dumps(run, indent=2))
    print(f"parsed {len(suites)} suites, {total_pass} passed, {total_fail} failed, "
          f"{len(findings)} findings → {out}")
    print("GATE_PASS" if gate_pass else "GATE_FAIL")


if __name__ == "__main__":
    main()

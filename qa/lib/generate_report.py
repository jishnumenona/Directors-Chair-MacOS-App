#!/usr/bin/env python3
"""
generate_report.py — render a run into an aesthetic, self-contained HTML report.

Reads run.json + bugs.json + the catalog, produces one standalone HTML file
(no external assets) styled to match the project's status documents. Sections:
gate verdict, suite results, catalog coverage, and the bug lifecycle board
(identified → diagnosed → fixed → verified, with fixes shown).
"""
import json
import sys
import html
from pathlib import Path


def esc(s):
    return html.escape(str(s if s is not None else ""))


def main():
    run = json.loads(Path(sys.argv[1]).read_text())
    bugs = json.loads(Path(sys.argv[2]).read_text())["bugs"]
    catalog_dir = Path(sys.argv[3])
    out = Path(sys.argv[4])

    s = run["summary"]
    gate_ok = s["gate_pass"]

    # Coverage: how many catalog cases have a wired automation.
    cov_rows = []
    total_cases = automated = 0
    for cat_file in sorted(catalog_dir.glob("*.json")):
        cat = json.loads(cat_file.read_text())
        if cat.get("status") == "planned":
            continue
        for feat in cat["features"]:
            f_total = len(feat["cases"])
            f_auto = sum(1 for c in feat["cases"] if c.get("automation"))
            total_cases += f_total
            automated += f_auto
            cov_rows.append((cat["component"], feat["name"], f_auto, f_total))
    cov_pct = round(100 * automated / total_cases) if total_cases else 0

    open_bugs = [b for b in bugs.values()
                 if b["status"] not in ("verified", "flagged-ux")]
    verified_bugs = [b for b in bugs.values() if b["status"] == "verified"]
    ux_bugs = [b for b in bugs.values() if b["status"] == "flagged-ux"]

    verdict_class = "ok" if gate_ok else "bad"
    verdict_word = "RELEASABLE" if gate_ok else "BLOCKED"

    def suite_row(su):
        cls = {"pass": "ok", "fail": "bad", "error": "warn"}[su["status"]]
        ex = su["executed"] if su["executed"] is not None else "—"
        skip = f" · {su['skipped']} skipped" if su["skipped"] else ""
        gate = "gate" if su["gate"] else "advisory"
        return f"""<tr>
          <td><span class="dot {cls}"></span>{esc(su['name'])}</td>
          <td class="dim">{esc(su['component'])}</td>
          <td><span class="tag {'gate' if su['gate'] else 'adv'}">{gate}</span></td>
          <td class="num">{su['passed']}</td>
          <td class="num">{su['failed']}</td>
          <td class="num dim">{ex}{skip}</td>
        </tr>"""

    STATUS_STYLE = {
        "identified": ("bad", "Identified"),
        "diagnosed": ("warn", "Diagnosed"),
        "fixing": ("warn", "Fixing"),
        "fixed": ("acc", "Fixed — awaiting re-run"),
        "verified": ("ok", "Verified fixed"),
        "regressed": ("bad", "Regressed"),
        "flagged-ux": ("warn", "Flagged for owner (UX)"),
    }

    def bug_card(b):
        cls, label = STATUS_STYLE.get(b["status"], ("dim", b["status"]))
        loc = ("<div class='loc'>" + " · ".join(esc(x) for x in b.get("locations", [])) + "</div>") if b.get("locations") else ""
        diag = f"<div class='blk'><b>Diagnosis.</b> {esc(b['diagnosis'])}</div>" if b.get("diagnosis") else ""
        fix = f"<div class='blk fix'><b>Fix.</b> {esc(b['fix'])}</div>" if b.get("fix") else ""
        return f"""<div class="bug {cls}">
          <div class="bughdr"><span class="bugid">{esc(b['id'])}</span>
            <span class="pill {cls}">{esc(label)}</span>
            <span class="dim">{esc(b['component'])} · {esc(b['suite'])}</span></div>
          <div class="bugtitle">{esc(b['title'])}</div>
          {loc}{diag}{fix}
        </div>"""

    suites_html = "\n".join(suite_row(su) for su in run["suites"])
    cov_html = "\n".join(
        f"<tr><td>{esc(c)}</td><td>{esc(n)}</td><td class='num'>{a}/{t}</td>"
        f"<td class='barcell'><div class='bar'><div class='fill' style='width:{round(100*a/t) if t else 0}%'></div></div></td></tr>"
        for c, n, a, t in cov_rows)
    open_html = "\n".join(bug_card(b) for b in open_bugs) or "<div class='empty'>No open bugs. 🎉</div>"
    fixed_html = "\n".join(bug_card(b) for b in (verified_bugs + ux_bugs)) or "<div class='empty'>Nothing resolved yet.</div>"

    doc = f"""<!doctype html><meta charset="utf-8">
<title>QA Report — {esc(run['run_id'])}</title>
<style>
:root{{--bg:#0d1117;--panel:#161b22;--panel2:#1c2129;--line:#2d333b;--ink:#e6edf3;--ink2:#9da7b3;--ink3:#6e7681;--acc:#58a6ff;--ok:#3fb950;--warn:#d29922;--bad:#f85149;}}
@media(prefers-color-scheme:light){{:root{{--bg:#f6f8fa;--panel:#fff;--panel2:#eef1f4;--line:#d0d7de;--ink:#1f2328;--ink2:#57606a;--ink3:#8c959f;--acc:#0969da;--ok:#1a7f37;--warn:#9a6700;--bad:#cf222e;}}}}
*{{box-sizing:border-box}}
body{{background:var(--bg);color:var(--ink);font:14px/1.55 -apple-system,"SF Pro Text",Segoe UI,sans-serif;max-width:1000px;margin:0 auto;padding:32px 20px 80px;}}
h1{{font-size:1.5rem;margin:0 0 2px}}.sub{{color:var(--ink2);margin:0 0 18px}}
.verdict{{display:flex;align-items:center;gap:16px;border-radius:12px;padding:18px 22px;margin-bottom:22px;border:1.5px solid}}
.verdict.ok{{background:rgba(63,185,80,.08);border-color:var(--ok)}}.verdict.bad{{background:rgba(248,81,73,.07);border-color:var(--bad)}}
.verdict .big{{font-size:1.5rem;font-weight:800;letter-spacing:.02em}}.verdict.ok .big{{color:var(--ok)}}.verdict.bad .big{{color:var(--bad)}}
.stats{{display:flex;gap:26px;margin-left:auto;text-align:right}}.stats div b{{display:block;font-size:1.35rem;font-variant-numeric:tabular-nums}}.stats div span{{font-size:.72rem;color:var(--ink3);text-transform:uppercase;letter-spacing:.06em}}
.seclabel{{font-size:.73rem;letter-spacing:.12em;color:var(--ink3);text-transform:uppercase;margin:30px 0 10px}}
table{{border-collapse:collapse;width:100%;font-size:.88rem}}.tw{{overflow-x:auto}}
th{{text-align:left;color:var(--ink3);font-size:.7rem;letter-spacing:.06em;text-transform:uppercase;padding:8px 10px;border-bottom:1px solid var(--line)}}
td{{padding:9px 10px;border-bottom:1px solid var(--line);vertical-align:middle}}.num{{text-align:right;font-variant-numeric:tabular-nums}}.dim{{color:var(--ink3)}}
.dot{{display:inline-block;width:9px;height:9px;border-radius:50%;margin-right:8px;vertical-align:0}}.dot.ok{{background:var(--ok)}}.dot.bad{{background:var(--bad)}}.dot.warn{{background:var(--warn)}}
.tag{{font-size:.68rem;padding:1px 7px;border-radius:7px;border:1px solid var(--line);color:var(--ink3)}}.tag.gate{{border-color:var(--acc);color:var(--acc)}}
.bar{{height:7px;background:var(--panel2);border-radius:4px;overflow:hidden;min-width:90px}}.fill{{height:100%;background:var(--acc)}}.barcell{{width:120px}}
.bug{{border:1px solid var(--line);border-left-width:3px;border-radius:9px;padding:12px 14px;margin-bottom:10px;background:var(--panel)}}
.bug.bad{{border-left-color:var(--bad)}}.bug.warn{{border-left-color:var(--warn)}}.bug.ok{{border-left-color:var(--ok)}}.bug.acc{{border-left-color:var(--acc)}}.bug.dim{{border-left-color:var(--ink3)}}
.bughdr{{display:flex;align-items:center;gap:10px;font-size:.8rem;margin-bottom:4px}}.bugid{{font:12px ui-monospace,Menlo,monospace;color:var(--ink2)}}
.bugtitle{{font-weight:600;margin-bottom:6px}}.loc{{font:11px ui-monospace,Menlo,monospace;color:var(--ink3);margin-bottom:6px}}
.pill{{font-size:.68rem;padding:1px 8px;border-radius:8px;font-weight:600}}.pill.bad{{background:rgba(248,81,73,.15);color:var(--bad)}}.pill.warn{{background:rgba(210,153,34,.15);color:var(--warn)}}.pill.ok{{background:rgba(63,185,80,.15);color:var(--ok)}}.pill.acc{{background:rgba(88,166,255,.13);color:var(--acc)}}.pill.dim{{background:var(--panel2);color:var(--ink3)}}
.blk{{font-size:.86rem;margin-top:6px;padding:8px 10px;background:var(--panel2);border-radius:6px}}.blk.fix{{border-left:2px solid var(--ok)}}
.empty{{color:var(--ink3);padding:14px;text-align:center;border:1px dashed var(--line);border-radius:9px}}
.cov{{display:flex;align-items:baseline;gap:10px}}.cov .pct{{font-size:1.1rem;font-weight:700;color:var(--acc)}}
.foot{{margin-top:34px;color:var(--ink3);font-size:.8rem;border-top:1px solid var(--line);padding-top:12px}}
</style>
<h1>🧪 QA Report</h1>
<p class="sub">DirectorsChair Desktop · run <b>{esc(run['run_id'])}</b></p>

<div class="verdict {verdict_class}">
  <div><div class="big">{verdict_word}</div><div class="dim">{'All gate suites passed' if gate_ok else 'A gate suite is failing — see bugs below'}</div></div>
  <div class="stats">
    <div><b>{s['total_passed']}</b><span>passed</span></div>
    <div><b>{s['total_failed']}</b><span>failed</span></div>
    <div><b>{s['total_skipped']}</b><span>skipped</span></div>
    <div><b>{len(open_bugs)}</b><span>open bugs</span></div>
  </div>
</div>

<div class="seclabel">Suites</div>
<div class="tw"><table>
<thead><tr><th>Suite</th><th>Component</th><th>Type</th><th>Pass</th><th>Fail</th><th>Total</th></tr></thead>
<tbody>{suites_html}</tbody></table></div>

<div class="seclabel">Catalog coverage <span class="dim">— automated E2E cases per feature</span></div>
<div class="cov"><span class="pct">{cov_pct}%</span><span class="dim">{automated} of {total_cases} catalogued cases have wired automation (the rest are the documented manual/roadmap backlog).</span></div>
<div class="tw"><table>
<thead><tr><th>Component</th><th>Feature</th><th>Automated</th><th></th></tr></thead>
<tbody>{cov_html}</tbody></table></div>

<div class="seclabel">Open bugs <span class="dim">— identified → diagnosed → fixed → verified</span></div>
{open_html}

<div class="seclabel">Resolved &amp; flagged</div>
{fixed_html}

<div class="foot">
Generated by <code>qa/run-qa.sh</code> → <code>qa/lib/generate_report.py</code>.
Machine-readable source of this report: <code>run.json</code>. Bug lifecycle ledger: <code>qa/bugs/bugs.json</code>.
A Claude Code instance consumes those two files to triage, fix code defects, and re-verify (protocol: <code>qa/CLAUDE-QA.md</code>).
</div>
"""
    out.write_text(doc)
    print(f"report → {out}  ({cov_pct}% coverage, {len(open_bugs)} open bugs)")


if __name__ == "__main__":
    main()

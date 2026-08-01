#!/usr/bin/env python3
"""Generate the Sparkle appcast from desktop/manifest.json (release pipeline).

The appcast is a PURE TRANSFORM of the manifest — the manifest stays the single
source of truth that both the downloads page and Sparkle feed render from.
Entries without an edSignature (pre-Sparkle releases, e.g. v3.4.0) are skipped:
the app verifies every update archive against SUPublicEDKey, so an unsigned
enclosure could never install anyway. Entries without a numeric build are ALSO
skipped: Sparkle compares <sparkle:version> (the build number), and an empty
one defeats downgrade protection (a Mac on 3.9.0 was offered 3.7.1 by a feed
carrying an empty-version item, 2026-08-01) — omit the stale entry entirely
rather than emit an empty version.

Usage:
    generate_appcast.py manifest.json appcast.xml
    generate_appcast.py --validate appcast.xml
    generate_appcast.py --self-test
"""
import email.utils
import json
import sys
from datetime import datetime, timezone
from xml.sax.saxutils import escape, quoteattr

FEED_TITLE = "DirectorsChair"
FEED_URL = "https://directorschair.app/downloads/appcast.xml"


def rfc2822(iso: str) -> str:
    dt = datetime.strptime(iso, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    return email.utils.format_datetime(dt)


def item(entry: dict) -> str | None:
    zip_artifact = entry.get("artifacts", {}).get("zip") or {}
    if not zip_artifact.get("edSignature"):
        return None
    version = str(entry.get("version") or "").strip()
    build = str(entry.get("build") if entry.get("build") is not None else "").strip()
    if not version or not build.isdigit():
        print(f"generate_appcast: omitting entry with unknown build/version "
              f"(version={version!r}, build={build!r}) — empty sparkle:version "
              f"would break Sparkle downgrade protection", file=sys.stderr)
        return None
    notes = entry.get("releaseNotes") or ""
    return f"""    <item>
      <title>{escape(version)}</title>
      <pubDate>{escape(rfc2822(entry["released"]))}</pubDate>
      <sparkle:version>{escape(build)}</sparkle:version>
      <sparkle:shortVersionString>{escape(version)}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>{escape(str(entry.get("minOS", "15.0")))}</sparkle:minimumSystemVersion>
      <description><![CDATA[<pre>{notes.replace("]]>", "]]&gt;")}</pre>]]></description>
      <enclosure url={quoteattr(zip_artifact["url"])}
                 length="{int(zip_artifact["size"])}"
                 type="application/octet-stream"
                 sparkle:edSignature={quoteattr(zip_artifact["edSignature"])} />
    </item>"""


def appcast(manifest: dict) -> str:
    entries = ([manifest["latest"]] if manifest.get("latest") else []) + manifest.get("history", [])
    items = [x for x in (item(e) for e in entries) if x]
    body = "\n".join(items)
    return f"""<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>{escape(FEED_TITLE)}</title>
    <link>{escape(FEED_URL)}</link>
    <description>Most recent updates to {escape(FEED_TITLE)}</description>
    <language>en</language>
{body}
  </channel>
</rss>
"""


def validate(path: str) -> None:
    """Fail (exit non-zero) unless every item carries a numeric sparkle:version
    and a non-empty sparkle:shortVersionString. Gates the appcast upload in
    promote-desktop.yml — a feed item with an empty version must never ship."""
    import xml.etree.ElementTree as ET

    ns = {"sparkle": "http://www.andymatuschak.org/xml-namespaces/sparkle"}
    items = ET.parse(path).getroot().findall("./channel/item")
    if not items:
        sys.exit(f"{path}: appcast has no items — refusing to publish an empty feed")
    bad = []
    for it in items:
        title = (it.findtext("title") or "?").strip()
        build = (it.findtext("sparkle:version", "", ns) or "").strip()
        short = (it.findtext("sparkle:shortVersionString", "", ns) or "").strip()
        if not build.isdigit() or not short:
            bad.append(f"  item {title!r}: sparkle:version={build!r} "
                       f"sparkle:shortVersionString={short!r}")
    if bad:
        sys.exit(f"{path}: invalid items (empty/non-numeric sparkle:version breaks "
                 f"Sparkle downgrade protection):\n" + "\n".join(bad))
    print(f"{path}: {len(items)} item(s) OK — all carry numeric sparkle:version")


def self_test() -> None:
    import tempfile
    import xml.etree.ElementTree as ET

    signed = {
        "version": "3.5.0", "build": 1400, "released": "2026-07-20T00:00:00Z",
        "minOS": "15.0", "releaseNotes": "### Added\n- auto-updates ]]> escaped",
        "artifacts": {"zip": {"url": "https://directorschair.app/download/v3.5.0/DirectorsChair-3.5.0.zip",
                              "sha256": "ab", "size": 123, "edSignature": "c2ln"}},
    }
    unsigned = {
        "version": "3.4.0", "build": 1300, "released": "2026-07-19T00:00:00Z",
        "minOS": "15.0", "releaseNotes": "",
        "artifacts": {"zip": {"url": "https://x/z.zip", "sha256": "cd",
                              "size": 1, "edSignature": None}},
    }
    xml = appcast({"latest": signed, "history": [unsigned]})
    root = ET.fromstring(xml)  # well-formed
    ns = {"sparkle": "http://www.andymatuschak.org/xml-namespaces/sparkle"}
    items = root.findall("./channel/item")
    assert len(items) == 1, "unsigned entry must be excluded"
    enclosure = items[0].find("enclosure")
    assert enclosure.get("{http://www.andymatuschak.org/xml-namespaces/sparkle}edSignature") == "c2ln"
    assert enclosure.get("length") == "123"
    assert items[0].find("sparkle:version", ns).text == "1400", "sparkle:version must be the BUILD number"
    assert "Sun, 19 Jul 2026" not in xml  # rfc2822 sanity: 2026-07-20 is a Monday
    assert "Mon, 20 Jul 2026" in xml
    empty = appcast({"latest": None, "history": [unsigned]})
    assert ET.fromstring(empty).findall("./channel/item") == []
    # Unknown build → entry omitted entirely, never an empty <sparkle:version>.
    for bad_build in ("", None, "  ", "abc"):
        stale = dict(signed, version="3.4.1", build=bad_build)
        got = appcast({"latest": signed, "history": [stale]})
        assert len(ET.fromstring(got).findall("./channel/item")) == 1, \
            f"entry with build={bad_build!r} must be omitted"
        assert "3.4.1" not in got
    no_build = {k: v for k, v in signed.items() if k != "build"}
    got = appcast({"latest": signed, "history": [dict(no_build, version="3.4.2")]})
    assert len(ET.fromstring(got).findall("./channel/item")) == 1, \
        "entry missing the build key must be omitted"
    # --validate: passes a good feed, rejects empty versions and empty feeds.
    with tempfile.TemporaryDirectory() as d:
        good = f"{d}/good.xml"
        open(good, "w").write(xml)
        validate(good)
        bad = f"{d}/bad.xml"
        open(bad, "w").write(xml.replace("<sparkle:version>1400</sparkle:version>",
                                         "<sparkle:version></sparkle:version>"))
        try:
            validate(bad)
        except SystemExit as e:
            assert e.code not in (0, None), "validate must exit non-zero"
        else:
            raise AssertionError("validate must reject an empty sparkle:version")
        none = f"{d}/none.xml"
        open(none, "w").write(empty)
        try:
            validate(none)
        except SystemExit as e:
            assert e.code not in (0, None)
        else:
            raise AssertionError("validate must reject a feed with no items")
    print("generate_appcast self-test OK")


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        self_test()
    elif len(sys.argv) == 3 and sys.argv[1] == "--validate":
        validate(sys.argv[2])
    elif len(sys.argv) == 3:
        manifest = json.load(open(sys.argv[1]))
        with open(sys.argv[2], "w") as f:
            f.write(appcast(manifest))
        print(f"wrote {sys.argv[2]}")
    else:
        sys.exit(__doc__)

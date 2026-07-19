#!/usr/bin/env python3
"""Generate the Sparkle appcast from desktop/manifest.json (release pipeline).

The appcast is a PURE TRANSFORM of the manifest — the manifest stays the single
source of truth that both the downloads page and Sparkle feed render from.
Entries without an edSignature (pre-Sparkle releases, e.g. v3.4.0) are skipped:
the app verifies every update archive against SUPublicEDKey, so an unsigned
enclosure could never install anyway.

Usage:
    generate_appcast.py manifest.json appcast.xml
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
    notes = entry.get("releaseNotes") or ""
    return f"""    <item>
      <title>{escape(str(entry["version"]))}</title>
      <pubDate>{escape(rfc2822(entry["released"]))}</pubDate>
      <sparkle:version>{escape(str(entry["build"]))}</sparkle:version>
      <sparkle:shortVersionString>{escape(str(entry["version"]))}</sparkle:shortVersionString>
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


def self_test() -> None:
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
    print("generate_appcast self-test OK")


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        self_test()
    elif len(sys.argv) == 3:
        manifest = json.load(open(sys.argv[1]))
        with open(sys.argv[2], "w") as f:
            f.write(appcast(manifest))
        print(f"wrote {sys.argv[2]}")
    else:
        sys.exit(__doc__)

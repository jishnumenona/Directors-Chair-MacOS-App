# Release pipeline

How a DirectorsChair Desktop version reaches users. Tag-driven with a human
promotion gate: **a tag builds and stores; a person ships.** Full architecture
(both repos): plan of record in the server repo's CI/CD runbook.

## The train

1. **Release PR** (`chore/release-vX.Y.Z`): bump `MARKETING_VERSION` in
   `project.pbxproj` **and** add the `## [X.Y.Z]` section to `CHANGELOG.md`.
   Merge via the normal PR loop (`verify.sh` green).
2. **Tag**: annotated `vX.Y.Z` on main, pushed. This triggers `release.yml`.
3. **`release.yml`** (CI, macos-15):
   - `verify-version` — fails fast if the tag ≠ `MARKETING_VERSION`, or a
     non-prerelease tag has no CHANGELOG section.
   - `build-package` — `xcodebuild archive` (Release, `CODE_SIGNING_ALLOWED=NO`,
     `CURRENT_PROJECT_VERSION` = commit count), stage as `DirectorsChair.app`,
     **ad-hoc codesign** (Apple Silicon refuses wholly-unsigned binaries),
     `ditto` zip + `create-dmg.sh` dmg (`DMG_FORCE_HDIUTIL=1` — no npm at
     release time), `SHA-256SUMS`, `manifest-entry.json`, then a **draft**
     GitHub Release with all four assets. Draft = stored, not shipped.
4. **Promotion** (`promote-desktop.yml`, `workflow_dispatch`): a human enters
   the tag twice (confirm guard). The workflow re-verifies checksums, publishes
   the release (immutable), uploads dmg/zip/SUMS to the public downloads bucket
   (versioned prefix + `latest/` aliases), and rebuilds `desktop/manifest.json`.
   The downloads page on directorschair.app renders from that manifest.
5. **Verify** (promotion checklist): `directorschair.app/downloads` shows the
   new version; `/download/latest` serves the new dmg; its SHA-256 matches.

Pre-release dry-runs: tag `vX.Y.Z-rc.N` — same build path, marked prerelease,
CHANGELOG section not required, draft may be deleted afterwards.

## Promotion checklist (the human gate)

- CI green on the exact tagged commit.
- CHANGELOG section reviewed; version-bump PR merged.
- Draft assets smoke-installed once from the DMG on a real Mac — drag-install,
  first launch through the Gatekeeper "Open Anyway" path, open a project.
  (UI E2E does not cover the quarantine/first-launch path.)
- `SHA-256SUMS` matches the assets (promotion re-verifies mechanically).
- Rollback target identified: the previous version stays at its versioned URL;
  re-promoting the previous tag restores `latest/`.

## Sparkle auto-updates (live since v3.5.0)

Users on v3.5.0+ get in-app updates; no Apple account involved (EdDSA):

- **App side:** Sparkle 2 (SPM, pinned ≥2.9.4) starts at launch
  (`UpdateCommands.swift`; harness runs — `--uitesting` etc. — never start it).
  `Info.plist` carries `SUFeedURL` (`https://directorschair.app/downloads/appcast.xml`),
  `SUPublicEDKey`, and `SUEnableAutomaticChecks` (daily check).
- **Key custody:** the EdDSA private key lives in the owner's login Keychain
  ("Private key for signing Sparkle updates") AND as the
  `SPARKLE_ED_PRIVATE_KEY` repo secret (exported copy at
  `~/.directorschair/sparkle_ed25519_private.key`, mode 600). Losing BOTH means
  shipping a new public key — an update users must fetch manually. Guard it.
- **release.yml** downloads the pinned Sparkle dist (sha256-verified),
  EdDSA-signs the zip + dmg with the secret, and writes the signatures into
  `manifest-entry.json` (`artifacts.*.edSignature`). A missing secret FAILS the
  release — an unsigned archive is undeliverable to Sparkle clients anyway.
- **promote-desktop.yml** regenerates `desktop/appcast.xml` from the rebuilt
  manifest via `scripts/generate_appcast.py` (pure transform; entries without
  `edSignature` — e.g. v3.4.0 — are excluded; `sparkle:version` is the BUILD
  number, `CFBundleVersion`) and uploads it beside the manifest (10-min edge
  TTL). The server serves it same-origin at `/downloads/appcast.xml` (nginx
  proxy to the CDN, same pattern as `manifest.json`).
- **Verification path:** the app accepts an update only if the archive's EdDSA
  signature verifies against `SUPublicEDKey` — a compromised bucket/CDN cannot
  ship a malicious update without the private key.
- **v3.4.0 cohort:** has no Sparkle; those users update once more by hand
  (downloads page). Every later cohort auto-updates.

## Unsigned-build reality (until the Apple Developer account exists)

Builds are **ad-hoc signed, not notarized**. On macOS 15, downloaded builds hit
"Apple could not verify…" and users must use System Settings → Privacy &
Security → **Open Anyway** (Sequoia removed the right-click→Open bypass). The
downloads page owns these instructions plus checksum verification. Treat Apple
Developer enrollment as a launch blocker for any marketing push.

**Enablement checklist (flips the pipeline to signed):**
1. Enroll; create a Developer ID Application certificate; export `.p12`.
2. Repo secrets: `APPLE_ID`, `APPLE_TEAM_ID`, `APPLE_APP_PASSWORD` (app-specific
   password), `DEVELOPER_ID_P12` (base64), `P12_PASSWORD`.
3. Implement the dormant `sign-notarize` job in `release.yml` (temp keychain →
   Developer ID + hardened runtime + timestamp → `notarytool submit --wait` →
   `stapler staple`), set repo variable `SIGNING_ENABLED=true`.
4. Manifest `signed` flips true; downloads page drops the Gatekeeper caveats.
5. Later (roadmap P1): Sparkle 2 auto-update — EdDSA keys, appcast generated
   from `manifest.json` `history` (works with or without Apple signing).

## Versioning

- `MARKETING_VERSION` (`CFBundleShortVersionString`): the SemVer release, bumped
  in the release PR, verified against the tag.
- `CURRENT_PROJECT_VERSION` (`CFBundleVersion`): commit count on main
  (`git rev-list --count HEAD`), injected at archive time — monotonic and
  reproducible locally; never hand-edited.

# Changelog

All notable user-facing changes to DirectorsChair Desktop.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning: SemVer
(`vMAJOR.MINOR.PATCH` — see `docs/git-workflow.md §6`). The release pipeline extracts
the tagged version's section into the GitHub Release notes and the website's
release-notes history, so write entries for users, not for git archaeologists.

## [Unreleased]

### Added
- Tag-driven release pipeline: pushing `vX.Y.Z` builds a versioned, checksummed
  `.dmg`/`.zip` as a draft GitHub Release; a dispatched promotion publishes it to
  the directorschair.app downloads page.

## [3.3] — 2026-07-18

Baseline for the changelog (versions before 3.3 predate it). Highlights of the
3.3 line, shipped across PRs #18–#19:

### Added
- Director-grade video generation: resolution and duration controls honest to
  Veo's capabilities, mid-keyframe reference frames, end-frame bridging, aspect-
  aware preview player, and prompt visibility ("Show Prompt").
- Film-style look bible with per-shot/scene/project resolution, wardrobe
  assignments per scene, and atmosphere (time-of-day, weather, lighting).
- Scene Connections hub: deep links from Bubble/Shots/Story Design, Cmd+[ / Cmd+]
  navigation history, drag or menu linking, undo, and live freshness.
- Costume department (Wardrobe tab + per-scene wardrobe plot) and Prop Shop
  (AI concept art, web/clipboard reference imports, scene placement).
- Story Design imagery flows into AI generation as reference collages
  (characters / location+props / user extra) within Veo's 3-reference limit.

### Fixed
- AI cost meter reflects Veo's real $0.40/s video pricing; speech usage tracked.
- AI assistant overlay no longer auto-opens over the login screen.

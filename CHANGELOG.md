# Changelog

All notable user-facing changes to DirectorsChair Desktop.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning: SemVer
(`vMAJOR.MINOR.PATCH` — see `docs/git-workflow.md §6`). The release pipeline extracts
the tagged version's section into the GitHub Release notes and the website's
release-notes history, so write entries for users, not for git archaeologists.

## [Unreleased]

## [3.10.0] — 2026-08-02

### Added
- **One-click web dashboard sign-in**: "Open Web Dashboard" in the account
  menu now signs you straight into the web portal — a secure single-sign-on
  handoff, no second login in the browser. If the handoff can't be minted,
  the button still opens the dashboard sign-in page.
- **The web dashboard now shows your whole project.** Syncing projects far
  more content into the portal:
  - Full **character sheets** — biography, physical appearance with the
    six-angle image gallery, personality traits (with the AI's confidence
    and reasoning), voice profile, relationships, scene appearances, and
    costume cards.
  - The **screenplay**, readable in the portal — generated from your scenes
    with proper slug lines, dialogue (including CONT'D), and sound effects.
  - **Location detail** — image galleries, mood and architecture, color
    palettes, cinematography defaults, address and notes, and the scenes
    each location appears in.
  - **Scene bubbles** — each scene's beats as chronological chat bubbles
    with speaker colors and tone tags, just like the desktop bubble view.
  - **Shot pages** now list the dialogue and action lines each shot covers,
    plus lighting, film-style override, and take counts.
  - **Props**, the **vision board**, and the full **production suite** —
    schedule, Gantt chart, cast, crew, teams, budget, and equipment.
- **Live sync progress**: the toolbar sync button shows a determinate
  progress ring with a percentage while uploading or downloading, weighted
  by bytes actually transferred.

### Fixed
- Shot images now appear in the web dashboard — the Overview deck, Scenes
  tab, and Shot list previously rendered every shot card as a placeholder
  even when the project was fully synced.
- Selecting a location in the web dashboard's Story tab no longer jumps
  back to the first location.
- Sync no longer uploads the same content twice when two files are
  identical (faster pushes, accurate progress).
- The in-app updater can no longer offer a downgrade to an older version
  (appcast entries with a missing build number are dropped, and every
  published feed is validated before it goes live).

## [3.9.0] — 2026-08-01

### Added
- **Voice conversations** with the AI assistant: hands-free back-and-forth with
  natural Gemini speech (or the free on-device voice), auto-listening after
  each reply.
- **Storyteller mode** in Playback: the screenplay performed scene-by-scene by
  an AI narrator with a synced image slideshow and timeline playhead, a
  per-scene cost preview before generating, and local caching so replays are
  free. Also launchable by asking the assistant.
- **Example projects**: five fully-produced downloadable examples — short film,
  music video, commercial, YouTube documentary, and a feature proof-of-concept —
  complete with poster art, character turnarounds, location plates, shot
  stills, vision boards, and audio.
- **AI Usage** tab in Accounting: real per-capability API spend (images, video,
  speech, text, AI assistant) plus an estimate calculator, including a live
  "generate video for every shot with Veo" costing for the open project.
- **Open from Cloud**: browse and download your synced projects grouped by
  organization. Viewer-role projects sync pull-only, and the sync toolbar
  shows which organization a project belongs to.
- Assistant conversations now **remember context across app restarts**
  (server-side threads), and resumed conversations regain their memory.

### Fixed
- Assistant no longer intermittently returns "empty response" on complex
  requests.
- Natural-voice assistant replies play reliably (audio container fix).
- Sync shows clear messages when a project is archived or your access level
  changed, instead of generic errors.
- App-generated notices in chat are labeled "App" instead of the misleading
  "On-device".

## [3.8.1] — 2026-07-27

### Added
- The AI Assistant now creates, not just edits. Ask it to generate scene
  keyframes, location shots with weather/time variations, mood-board images,
  and character reference sets — or say "generate images for everything
  that's missing" and review one card with the per-item costs and the batch
  total before anything is spent.
- Voice your scenes: the assistant renders dialogue in each character's cast
  voice (text-to-speech), line by line or a whole scene at once, with
  per-line cost estimates up front.
- Render shots from chat: "render shot 12 as a 4-second clip" submits a Veo
  video job — cost shown before you approve, progress narrated right in the
  conversation, and the finished clip lands as a new take in Cinematography.
- Build your project from a screenplay: give the assistant a PDF and it runs
  the full AI import — scenes, dialogue, characters, locations, props — as
  one undoable step, with a clear warning before replacing anything.
- New character tools: AI-written biographies and script-wide personality
  trait calibration (with the AI's confidence and reasoning saved), plus
  full timeline analysis on demand.
- Optional proactive checks: flip the bell in the assistant's header and it
  flags schedule conflicts and plan problems the moment you open it — no AI
  cost, instant.
- Choose your assistant's brain: a new "AI Assistant (chat)" picker in
  Preferences → AI Services (Google Gemini, Anthropic Claude, or DeepSeek),
  and the Temperature slider now applies to the assistant too.

### Changed
- Assistant conversations are faster and cheaper: instead of sending large
  project excerpts with every message, the assistant now looks up exactly
  what it needs, when it needs it — answers always reflect your project's
  live state.

## [3.7.1] — 2026-07-26

### Added
- The AI Assistant now has a permanent home in the toolbar: a ✦ button
  (top right) opens it, and its ⇧⇧ label shows the shortcut — press Shift
  twice anytime, from anywhere in the app.

## [3.7.0] — 2026-07-26

### Added
- AI Assistant, rebuilt end-to-end. Ask about your project and the assistant
  reads live data — schedule conflicts, budget figures, scenes, cast — instead
  of guessing. It can draft scenes and dialogue, schedule shoots, plan
  production tasks, record expenses, staff cast and crew, and generate
  character reference images. Every change arrives as a reviewable proposal
  with before→after previews and warnings (double-bookings, budget overruns,
  dependency cycles), one-click Apply, and whole-turn Undo.
- Voice input: click the mic — or tap ⌘ while the assistant is open — and
  speak; on-device transcription streams into the input field as you talk.
- Assistant replies stream in live, with activity chips while it checks your
  project.
- Conversations persist: reopening the assistant resumes where you left off,
  and the history sidebar lists every past chat.

### Fixed
- The assistant could show no reply even though the service had responded;
  responses are now reliable, and any failure is shown instead of silence.

## [3.6.0] — 2026-07-19

### Added
- Upload your own images anywhere the app shows a preview: scene overviews,
  shot previews, every location variation, and all character angle views now
  have an "Upload custom image" option next to Generate — use photos,
  storyboards, or concept art from your own library instead of (or alongside)
  AI-generated images.

## [3.5.0] — 2026-07-19

### Added
- Automatic updates: DirectorsChair now checks for new versions daily and
  offers them in-app ("DirectorsChair → Check for Updates…" to check
  manually). Updates are cryptographically verified end to end. This is the
  last version you need to download by hand.

## [3.4.0] — 2026-07-19

The first publicly downloadable release of DirectorsChair Desktop — available
directly from [directorschair.app/downloads](https://directorschair.app/downloads).

### Added
- Direct-download distribution: versioned, checksummed `.dmg`/`.zip` builds
  published to directorschair.app with SHA-256 verification. Builds are not yet
  notarized (Apple Developer enrollment pending) — the downloads page walks
  through the macOS first-launch steps.
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

## [3.3] — 2026-07-18

Internal baseline (never shipped as a downloadable artifact; versions before
3.3 predate this changelog). The 3.3 line's work — PRs #18–#19 — ships to
users as part of 3.4.0 above.

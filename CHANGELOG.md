# Changelog

All notable user-facing changes to DirectorsChair Desktop.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning: SemVer
(`vMAJOR.MINOR.PATCH` — see `docs/git-workflow.md §6`). The release pipeline extracts
the tagged version's section into the GitHub Release notes and the website's
release-notes history, so write entries for users, not for git archaeologists.

## [Unreleased]

### Added
- **Trim any timeline block by its edges.** Drag the left or right edge of a
  dialogue, action, narration, sound note or shot on the Timeline to change
  its length (the cursor becomes a resize arrow over an edge, and the new
  duration is shown while you drag). Durations snap to a tenth of a second
  and never go below half a second; a trimmed block keeps its size across
  reloads and in Playback.
- **Resizable Shots track.** Drag the bottom edge of the Shots track to make
  it taller and see shot previews bigger (double-click the handle to reset,
  or pick a size from the new toolbar menu next to the Shots toggle). The
  height is remembered.
- **Reset a dialogue block to its spoken length.** Right-click a dialogue on
  the Timeline for "Reset to spoken length (N.N s)": the block takes the time
  the line needs at its speaker's pace — the character's voice pace from the
  Voice tab scaled onto the timeline's WPM, or the timeline WPM alone — and
  flows back into its place in the scene.

### Changed
- **Bubble View cards hug their text.** Dialogue, action, narration, note and
  sound bubbles are only as wide as what they say (plus padding), up to 70% of
  the row, after which the text wraps — while editing too: a field grows as
  you type instead of stretching across the row.
- **Trim minimums follow the block.** Action, narration and sound blocks can
  be trimmed right down to half a second whatever their text (it clips inside
  the block); a dialogue block can't be trimmed narrower than its line needs
  to stay readable at the current zoom.

## [3.10.1] — 2026-08-29

### Fixed
- **Sign-in no longer loops after installing a new version.** macOS treats each
  unsigned build of the app as a different program, so a session saved by an
  earlier build could block the new one from saving its own — the app then
  dropped the sign-in it had just completed and showed the sign-in screen
  again. Signing in now always succeeds; if the Mac refuses to store the
  session, the app keeps it for this launch, stores it locally, and tells you
  you'll be asked to sign in again after a relaunch.

## [3.10.0] — 2026-08-28

### Added
- **Drawing on your Mac, no cloud needed.** Storyboard frames, shot and scene
  previews, character looks, costume sheets, location plates and prop studies
  can now be drawn by an open image model that runs on this Mac (a one-time
  download from Settings → AI Services). Pick the look once — **Sketch**
  (pencil and ink on paper) or **Comic** (bold inks and flat colour) — and
  every drawing in the project speaks the same line. Drawings follow your
  references: a character keeps their face, a location keeps its architecture,
  a prop keeps its design.
- **Edit a picture by marking it up.** Drop numbered pins on any preview,
  write what should change at each pin, and the picture is repainted only
  where you marked — the rest stays pixel-identical. On the Mac the pins are
  handled one at a time so every change lands where you put it; each pin's
  reach can be widened or narrowed.
- **Notes on scenes and shots.** A Notes card on the scene detail and in the
  shot editor, edited in place and saved with the project; notes travel into
  the EDL/FCPXML export and the web portal.
- **Voice all dialogue from Playback.** One control on the transport voices
  every line in the timeline that has no voice yet, in order, in each
  character's cast voice — with the cost shown before it starts, progress and
  cancel while it runs, and a tally when it's done (Creator plan).
- **On-device AI insights and chat.** A bundled text model (downloaded on
  request) powers the Overview insights and can be chosen as the text service
  and for assistant chat — replies wear an "On-device" badge so you always
  know what answered.
- **Choose your AI services per job.** Settings → AI Services now lets you
  pick the provider (and, where it applies, the model) separately for text,
  images, video and speech, with live availability shown for each.
- **The Vision Board wall.** A board that feels like a real wall: paper
  scraps on pins, twine between them, a ring of tools around the cursor,
  sticky notes and annotations, zoom-to-fit and marquee selection, a
  lookbook export that is the wall itself, and an Imagine panel for
  generating straight onto it.
- **Free plan, Creator plan.** The creative core is free forever; generation
  and studio features are marked with a small lock and explain what plan
  they belong to. Cloud sync on the Free plan holds up to three projects and
  says so clearly.
- **Your whole project in the web portal.** Syncing now carries full
  character sheets, the screenplay, location detail, scene bubbles, shot
  pages with their lines, props, the vision board and the production suite —
  plus one-click sign-in to the portal from the account menu and a live
  sync-progress ring on the toolbar.

### Changed
- **One personality-trait vocabulary.** Characters, the Personality tab, the
  character sheet, script analysis and the portal all use the same 25
  Big-Five facets. Projects from earlier versions are brought across on
  open; a score you set by hand under an older name is kept, never dropped.
- Shot previews travel with the shot's own cast and the props it names;
  scene previews now carry the scene's place, people and props too — on
  every provider.
- Location and prop drawings are people-free by design (the app checks and
  redraws if a figure sneaks in).
- Reference pictures, annotation edits and the assistant's image actions all
  go through one shared path, so every surface behaves the same way.
- The on-device models give memory back when you stop using them: the image
  model and the text model both release their weights after a few idle
  minutes and hand the cache back after every job.

### Fixed
- **Two people on one cloud project no longer lose work in a merge.** When
  one of you had only regenerated pictures and the other had edited the
  script, the automatic merge recorded the other person's files without
  fetching them and could overwrite their document on the next Sync.
  Merges now bring the latest version onto your Mac first, keep your own
  deletions, and reload the editor when the document changed.
- **A drag on the timeline or an edit in the shot list can no longer revert
  something you changed elsewhere** (a schedule, a budget line, typed
  script text): those surfaces now write back only what they own.
- Opening a project no longer marks it as changed and rewrites the file half
  a second later; the backup ring keeps your five most recent saves instead
  of arbitrary old ones; restoring a snapshot keeps cloud sync working;
  quitting is immediate and no longer produces a false "quit unexpectedly"
  report on the next launch.
- Regenerated pictures show up immediately everywhere (the thumbnail cache
  notices when a file changes); the shot detail, scene connections, keyframe
  cards, costume and prop racks and the Playback viewfinder no longer decode
  full-resolution images on every redraw, which removes stutter while
  recording, dragging connections, or scrolling those lists; a leaked video
  player observer per viewed take is fixed.
- Interrupted proxy transcodes no longer leave an unplayable proxy behind;
  importing dailies no longer freezes the app while a large clip copies.
- The legacy "Sync" control on the Projects screen is hidden: one Sync, one
  set of rules.
- Shot images now appear in the web dashboard's Overview deck, Scenes tab and
  Shot list; selecting a location in the portal no longer jumps back to the
  first one; sync no longer uploads identical files twice.
- The in-app updater can no longer offer a downgrade to an older version.
- The assistant can no longer invent a personality trait outside the
  vocabulary; unknown character names are answered with the known ones.
- The "coming soon" sheet's OK button is reachable to assistive technology,
  and lock badges say which feature they lock.
- A scene-preview edit that can't run says why instead of quietly generating
  a fresh scene; on-device edits never receive a cloud-only prompt.
- The Physical Appearance gallery no longer crashes when many tier gates are
  present; a flaky autosave test no longer fails the release gate under load.

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

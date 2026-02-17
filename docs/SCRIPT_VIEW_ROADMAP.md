# Script View Feature Roadmap

Competitive gap analysis against Final Draft and Celtx, with a phased implementation plan to bring Directors Chair's Script View to professional parity and beyond.

---

## Current Unique Strengths

Features that **neither Final Draft nor Celtx** offer:

1. **Cmd+Click cross-navigation** - Click a character name to jump to their profile; click a scene heading to jump to the location or bubble view.
2. **7-trigger autocomplete system** - `@` `%` `$` `#` `(` `~` `^` for characters, locations, time, transitions, parentheticals, sound, and props.
3. **New Scene Wizard** - Guided 2-step scene creation (location -> time) with autocomplete.
4. **Bulk visual highlighting** - Cmd-hold highlights ALL character names (yellow) and ALL scene headings (blue) simultaneously.
5. **Sound Cue element** - Native SFX element type with detailed audio metadata.
6. **Integrated production pipeline** - Script alongside cinematography, storyboarding, scheduling, budgeting, cast/crew, and AI generation.

---

## Phase 1 - Quick Wins (COMPLETED)

Low effort, high impact features that leverage existing infrastructure.

### 1.1 Find & Replace
- **Status:** DONE
- **What:** Exposed NSTextView's built-in find bar via `Cmd+F`
- **Details:** `usesFindBar = true` and `isIncrementalSearchingEnabled = true` on the NSTextView. Supports find, replace, find next/previous. Added to shortcuts popover.

### 1.2 Spell Check
- **Status:** DONE
- **What:** Toggle-able continuous spell checking and grammar checking
- **Details:** Toolbar checkbox "Spelling" toggles `isContinuousSpellCheckingEnabled` and `isGrammarCheckingEnabled`. Defaults to off to preserve typewriter aesthetic.

### 1.3 Word Count & Script Statistics
- **Status:** DONE
- **What:** Real-time word count in toolbar + comprehensive stats popover
- **Details:**
  - Word count displayed alongside page count in toolbar
  - Stats popover (chart icon) showing:
    - Overview: pages, words, scenes, unique speaking characters
    - Content breakdown: dialogue vs action word counts with percentages and visual ratio bar
    - Character dialogue breakdown: top 10 characters by word count, with line and word counts
  - Stats update on load, refresh, and every text change

### 1.4 Typewriter Mode
- **Status:** DONE
- **What:** Auto-scroll to keep insertion point centered vertically
- **Details:** Toolbar checkbox "Typewriter" enables mode where cursor stays centered in the viewport. Smooth 0.15s animation on selection/text changes.

---

## Phase 2 - Core Writing Features

Essential writing tools that professional screenwriters expect.

### 2.1 Dual Dialogue Rendering
- **Status:** NOT STARTED
- **Effort:** Medium
- **What:** Side-by-side column layout for simultaneous dialogue
- **Details:** The `dualDialogue` element type exists in the model but has no UI rendering. Need to implement side-by-side column layout in the NSTextView's attributed string builder. Each column gets its own character name, parenthetical, and dialogue indentation within half the content width.
- **Approach:**
  - Detect consecutive `dualDialogue` elements (left + right pairs)
  - Use `NSTextTable` with 2 cells for side-by-side layout in attributed string
  - Each cell maintains proper screenplay indentation within its column
  - Add a toolbar/menu action to toggle selected dialogue to dual dialogue mode

### 2.2 Inline Bold/Italic/Underline
- **Status:** NOT STARTED
- **Effort:** Medium
- **What:** Rich text formatting within individual elements (e.g., bold a word in dialogue)
- **Details:** Currently formatting is element-level only (entire character name is bold, entire dialogue is regular). Need inline `NSAttributedString` ranges for bold/italic/underline within action and dialogue text.
- **Approach:**
  - Store inline formatting as Fountain-style markers in element text (`*italic*`, `**bold**`, `_underline_`)
  - Parse markers during `rebuildAttributedString()` and apply font traits to sub-ranges
  - Add `Cmd+B`, `Cmd+I`, `Cmd+U` keyboard shortcuts that wrap selection in markers
  - Bidirectional sync: strip markers before sending to Project model, re-apply from stored text

### 2.3 Character Dialogue Statistics Report
- **Status:** DONE (basic stats in popover, Phase 2 = dedicated report view)
- **Effort:** Medium
- **What:** Full report view with per-character line/word counts, speaking time estimates, interaction matrix
- **Approach:**
  - New `ScriptStatsView` as a sheet/panel accessible from the stats popover
  - Per-character: line count, word count, estimated screen time (words / 150 wpm)
  - Character interaction: which characters share scenes
  - Sortable table columns
  - Export to CSV

### 2.4 Dark Mode / Night Mode
- **Status:** NOT STARTED
- **Effort:** Medium
- **What:** Alternative dark color scheme for the script view
- **Details:** Currently the script view forces light mode (`NSAppearance(named: .aqua)`) with a cream background. Need a dark mode option that uses dark backgrounds and light text while maintaining readability.
- **Approach:**
  - Add `darkMode` toggle to `ScriptViewModel`
  - Create a `ScreenplayTheme` struct with light/dark variants of all colors
  - Dark theme: dark charcoal background (#1E1E1E), light cream text (#E8E0D0), muted scene heading color
  - Replace all hardcoded `ScreenplayFormatting` colors with theme-aware accessors
  - Toggle in toolbar or follow system appearance setting

---

## Phase 3 - Import & Structure

File import capabilities and structural editing tools.

### 3.1 Import FDX (Final Draft XML)
- **Status:** NOT STARTED
- **Effort:** Medium
- **What:** Parse `.fdx` files into the Project model
- **Details:** FDX is XML-based. Parse `<Paragraph>` elements with `Type` attributes (Scene Heading, Action, Character, Dialogue, Parenthetical, Transition). Map to Project sequences/scenes/dialogues/actions.
- **Approach:**
  - Create `FDXImportService` in DirectorsChairExports (or a new DirectorsChairImports package)
  - Use `XMLParser` or `XMLDocument` to parse FDX structure
  - Map FDX paragraphs to Project model items
  - Handle scene detection (group paragraphs between Scene Headings)
  - Create characters from unique character names
  - Handle dual dialogue, script notes, transitions
  - File picker in toolbar/menu: "Import > Final Draft (.fdx)"

### 3.2 Import Fountain
- **Status:** NOT STARTED
- **Effort:** Medium
- **What:** Parse `.fountain` plain-text screenplay format into the Project model
- **Details:** Fountain is a Markdown-like format for screenplays. Scene headings start with `INT.`/`EXT.`/etc., character names are ALL CAPS lines, dialogue follows character names, etc.
- **Approach:**
  - Create `FountainImportService`
  - Line-by-line parser with state machine (current element context)
  - Scene heading detection: lines starting with INT./EXT./EST./I/E. or forced with `.`
  - Character detection: ALL CAPS line followed by dialogue
  - Handle parentheticals, transitions, notes (`[[...]]`), sections (`#`), emphasis (`*`, `**`, `_`)
  - Map to Project model (create sequences from sections, scenes from headings)

### 3.3 Drag-and-Drop Scene Reorder
- **Status:** NOT STARTED
- **Effort:** Medium
- **What:** Reorder scenes by dragging in the navigator sidebar
- **Details:** Currently scenes are displayed in order but cannot be rearranged. Need drag-and-drop in `ScriptSceneNavigator` that reorders scenes in both the elements array and the Project model.
- **Approach:**
  - Add `.onMove` modifier to the scene list in `ScriptSceneNavigator`
  - On move: identify source scene (sequence/scene indices) and destination position
  - Update `Project.sequences[].scenes[]` ordering
  - Regenerate elements and rebuild attributed string
  - Sync changes back via `ProjectViewModel`
  - Also support drag-and-drop in the main text view (drag scene heading to reorder)

### 3.4 Outline Editor
- **Status:** NOT STARTED
- **Effort:** Medium
- **What:** Hierarchical outline view of acts/sequences/scenes with synopsis
- **Approach:**
  - New `ScriptOutlineView` (SwiftUI) shown as an alternative to the scene navigator
  - Tree structure: Acts (sequences) > Scenes > Key beats
  - Each node shows: scene number, heading, synopsis (scene description), page number
  - Editable synopsis field
  - Collapse/expand acts
  - Click to navigate to scene in editor
  - Toggle between Navigator and Outline in toolbar

---

## Phase 4 - Production & Polish

Production-oriented features and export enhancements.

### 4.1 Text-to-Speech / Table Read
- **Status:** NOT STARTED
- **Effort:** Medium
- **What:** Read the script aloud with different voices per character
- **Details:** A TTS service already exists in `DirectorsChairServices/`. Need to integrate it with the Script View for a "table read" experience.
- **Approach:**
  - Create `TableReadController` that walks through elements sequentially
  - For character dialogue: use character-assigned voice (or default voice per character)
  - For action/narration: use a distinct "narrator" voice
  - Playback controls: Play/Pause/Stop/Skip in a floating toolbar
  - Highlight current element being read in the text view
  - Speed control (0.5x - 2.0x)
  - Voice assignment per character in a settings panel

### 4.2 PDF Export Enhancements
- **Status:** NOT STARTED
- **Effort:** Low-Medium
- **What:** Watermarks, custom headers/footers, revision colors
- **Approach:**
  - Add watermark overlay (diagonal text, configurable: "CONFIDENTIAL", "DRAFT", custom)
  - Add header: page number (right), revision date (left)
  - Add footer: project name, production company
  - Revision color support: colored page background per WGA revision colors (white, blue, pink, yellow, green, goldenrod, buff, salmon, cherry)
  - Settings panel before export to configure options

### 4.3 Index Cards / Beat Board
- **Status:** NOT STARTED
- **Effort:** High
- **What:** Visual card-based scene planning view
- **Approach:**
  - New `IndexCardView` as an alternative view mode (toggle from toolbar or tab)
  - Each scene = one card showing: scene number, heading, synopsis, page count, color tag
  - Grid layout (3-4 cards per row, responsive)
  - Drag-and-drop to reorder scenes
  - Color coding: user-assignable per scene (or auto by INT/EXT, DAY/NIGHT)
  - Double-click card to jump to scene in editor
  - Card editing: click to edit synopsis directly on card
  - Print index cards (4-up on letter paper)

### 4.4 Revision Tracking
- **Status:** NOT STARTED
- **Effort:** High
- **What:** Track changes with revision marks and colored revision pages
- **Approach:**
  - Version snapshot system: save current state as a named revision
  - Diff engine: compare two revisions, mark changed elements
  - Revision marks: asterisk (*) in right margin next to changed lines
  - Colored pages: per WGA standard revision color sequence
  - Revision mode toggle: when active, all changes are tracked
  - UI: revision selector dropdown, revision marks visibility toggle
  - Storage: revisions saved as part of Project file (array of snapshots)

---

## Phase 5 - Advanced

Major features requiring significant architecture work.

### 5.1 Locked Pages / A-B Scene Numbering
- **Status:** NOT STARTED
- **Effort:** Medium
- **What:** Production mode where page and scene numbers are locked for distribution
- **Details:** In production, page numbers are locked so that revisions don't shift page references. New scenes inserted between locked scenes get A/B suffixes (e.g., 5A, 5B).
- **Approach:**
  - "Lock" action that snapshots current scene numbers and page breaks
  - Inserted scenes get alphanumeric suffixes (5A, 5B, etc.)
  - Deleted scenes leave omitted markers ("OMITTED")
  - Page locks: new content on a locked page gets continuation markers
  - Production mode toggle in toolbar

### 5.2 Compare Drafts
- **Status:** NOT STARTED
- **Effort:** High
- **What:** Side-by-side diff comparison of two script versions
- **Approach:**
  - Diff algorithm operating on ScriptElement arrays (not raw text)
  - Three diff types: added (green), removed (red), modified (yellow)
  - Side-by-side view: left = old draft, right = new draft, colored diff highlights
  - Summary: number of added/removed/modified elements, changed pages
  - Navigate between changes (Next/Previous buttons)
  - Export diff report as PDF

### 5.3 Real-Time Collaboration
- **Status:** NOT STARTED
- **Effort:** Very High
- **What:** Google Docs-style co-writing with multiple users
- **Details:** This is a major architectural undertaking requiring a sync engine, conflict resolution, user presence, and networking infrastructure.
- **Approach (high-level):**
  - Operational Transform (OT) or CRDT-based sync engine
  - WebSocket connection to collaboration server
  - User cursors: show other writers' cursor positions with color-coded names
  - Conflict resolution for simultaneous edits to the same element
  - Session management: create/join sessions, permissions (edit/view/comment)
  - Offline support: queue changes, sync on reconnect
  - This is a multi-month effort and may be better served by integration with an existing real-time editing framework

### 5.4 Script Breakdown Tagging
- **Status:** NOT STARTED
- **Effort:** Medium
- **What:** Inline tagging of script elements for production breakdown (props, wardrobe, vehicles, etc.)
- **Approach:**
  - Select text in script, right-click > "Tag as..." submenu
  - Tag categories: Props, Wardrobe, Vehicles, Animals, Special Effects, Stunts, Extras, Music, Sound
  - Tagged text gets colored underline/highlight per category
  - Breakdown report: all tagged items grouped by category and scene
  - Integration with existing production breakdown features in the app
  - Tags stored as metadata on ScriptElement (array of tagged ranges)

---

## Feature Comparison Reference

### Script Elements & Formatting

| Feature | Directors Chair | Final Draft | Celtx |
|---------|:-:|:-:|:-:|
| Scene Heading (INT/EXT) | YES | YES | YES |
| Action | YES | YES | YES |
| Character | YES | YES | YES |
| Dialogue | YES | YES | YES |
| Parenthetical | YES | YES | YES |
| Transition | YES | YES | YES |
| Dual Dialogue (side-by-side) | Model only, NO UI | YES | YES |
| Script Notes / Annotations | YES (`[[note]]`) | YES (color-coded, dated) | YES (text-anchored) |
| Sound Cues | YES (SFX element) | NO | NO |
| Section/Act Headings | YES | YES | YES |
| Custom Element Types | NO | YES | NO |
| Auto-uppercase scene headings | YES | YES | YES |
| Auto-uppercase character names | YES | YES | YES |
| CONT'D tracking | YES (auto) | YES | YES |
| Industry Courier 12pt | YES | YES | YES |
| Bold/Italic/Underline (inline) | NO (Phase 2) | YES | YES |

### Editing & Writing Tools

| Feature | Directors Chair | Final Draft | Celtx |
|---------|:-:|:-:|:-:|
| Tab/Enter element cycling | YES | YES | YES |
| Character name autocomplete | YES (`@` trigger) | YES (SmartType) | YES |
| Location autocomplete | YES (`%` trigger) | YES | YES |
| Time of day autocomplete | YES (`$` trigger) | YES | YES |
| Transition autocomplete | YES (`#` trigger) | YES | YES |
| Parenthetical autocomplete | YES (`(` trigger) | NO | NO |
| Props autocomplete | YES (`^` trigger) | NO | NO |
| Sound/Music autocomplete | YES (`~` trigger) | NO | NO |
| Find & Replace | YES (Phase 1) | YES | YES |
| Spell Check | YES (Phase 1) | YES | YES |
| Undo/Redo | YES (NSTextView native) | YES | YES |
| Typewriter Mode | YES (Phase 1) | YES | NO |
| Word Count | YES (Phase 1) | YES | YES |

### Navigation & Structure

| Feature | Directors Chair | Final Draft | Celtx |
|---------|:-:|:-:|:-:|
| Scene Navigator sidebar | YES | YES | YES |
| Scene count display | YES | YES | YES |
| Click-to-navigate to scene | YES | YES | YES |
| Cmd+Click cross-navigation | YES | NO | NO |
| Index Cards | NO (Phase 4) | YES | YES |
| Outline Editor | NO (Phase 3) | YES | YES |
| Drag-and-drop scene reorder | NO (Phase 3) | YES | YES |

### Pages & Pagination

| Feature | Directors Chair | Final Draft | Celtx |
|---------|:-:|:-:|:-:|
| Paginated view (US Letter) | YES | YES | YES |
| Continuous scroll view | YES | NO | YES |
| Page count estimate | YES | YES | YES |
| Page break indicators | YES | YES | YES |
| Title page | YES (auto from metadata) | YES | YES |
| Locked pages (production) | NO (Phase 5) | YES | NO |

### Import / Export

| Feature | Directors Chair | Final Draft | Celtx |
|---------|:-:|:-:|:-:|
| Export Fountain (.fountain) | YES | NO | YES |
| Export FDX (.fdx) | YES | YES | YES |
| Export PDF | YES | YES | YES |
| Import FDX | NO (Phase 3) | YES | YES |
| Import Fountain | NO (Phase 3) | YES | YES |

### Statistics & Reports

| Feature | Directors Chair | Final Draft | Celtx |
|---------|:-:|:-:|:-:|
| Page count | YES | YES | YES |
| Word count | YES (Phase 1) | YES | YES |
| Character dialogue statistics | YES (Phase 1) | YES | YES |
| Scene count | YES (Phase 1) | YES | YES |
| Content breakdown | YES (Phase 1) | YES | YES |

### Visual & UX

| Feature | Directors Chair | Final Draft | Celtx |
|---------|:-:|:-:|:-:|
| Zoom / magnification | YES (50-300%, pinch) | YES | YES |
| Dark Mode | NO (Phase 2) | YES | YES |
| Typewriter aesthetic | YES | YES | NO |
| Character highlight (bulk) | YES (Cmd-hold) | YES | NO |
| Location highlight (bulk) | YES (Cmd-hold) | NO | NO |
| Hover cursor navigation | YES | NO | NO |
| New Scene Wizard | YES | NO | NO |

# Editor v2 — Industry-Standard Screenplay Editing (Final Draft parity)

Branch: `screenplay_update` · Started 2026-07-06 · Owner verdict on v1: "very broken, rewrite"

## 1. Investigation: what Final Draft actually does

Sources: Final Draft knowledge base (keyboard shortcuts, SmartType), finaldraft.com
formatting guides, StudioBinder/Celtx margin references.

### 1.1 The industry page format (already compliant in DirectorsChair)
| Measure | Standard | DirectorsChair (`ScreenplayFormatting`) |
|---|---|---|
| Font | Courier 12pt | ✅ Courier 12 |
| Page | US Letter 8.5×11" | ✅ 612×792pt |
| Left margin | 1.5" (binding) | ✅ 108pt |
| Top/bottom/right | 1" | ✅ 72pt |
| Scene heading / action | 1.5" from page-left, full width | ✅ indent 0 |
| Character cue | 3.7" from page-left | ✅ 108+158 = 266pt = 3.7" |
| Parenthetical | 3.1" | ✅ 108+115 = 223pt = 3.1" |
| Dialogue | 2.5", ~3.5" wide column | ✅ 108+72 = 180pt = 2.5", 252pt wide |
| Transition | right-aligned | ✅ |
| ~55 lines/page ≈ 1 min | pagination | ⚠️ pages-mode approximation; exact keep-with rules are Phase 3 |

### 1.2 The Final Draft interaction model (the part v1 lacked)
FD's speed comes from a deterministic element-flow state machine:

**Return ("Next Element" defaults):**
| From | Return creates |
|---|---|
| Scene Heading | Action |
| Action | Action |
| Character | Dialogue |
| Parenthetical | Dialogue |
| Dialogue | Action *(FD default; configurable to Character)* |
| Transition | Scene Heading |

**Tab (element transition, not focus):**
| From | Tab |
|---|---|
| Scene Heading | → Action *(and inside a heading: Tab after location inserts " - " and opens the Time list)* |
| Action | → Character |
| Character | → Transition |
| Parenthetical | → Dialogue |
| Dialogue | → Parenthetical |
| Transition | → Scene Heading |

Tab semantics: on an **empty** element it converts the element in place; at the
end of a **non-empty** element it creates the target as the next element.

**SmartType:** autocomplete lists for character names, extensions (V.O., O.S.),
scene intros (INT./EXT.), locations, times, transitions — triggered by element
context. Tab/Return accepts.

**Auto-formatting:** scene headings / character cues / transitions are
UPPERCASED as typed; `(CONT'D)` is appended automatically when the same
character speaks consecutively; MORE/CONT'D at page breaks.

**Direct element switching:** ⌘1–6 in FD (Scene Heading, Action, Character,
Parenthetical, Dialogue, Transition). DirectorsChair uses ⌘1–9 for view
navigation, so we bind **⌃1–6** instead.

## 2. Architecture decision

**Keep:** the model-authoritative layer — `ScriptViewModel` + `[ScriptElement]`
(paragraph N == element N invariant), `RebuildInstruction`, snapshot undo,
UTF-16 range ops, and `ProjectToScriptConverter` (the bridge that keeps the
script and the **bubble view editing the same scene data** — dialogue ↔
Dialogue, action ↔ Action, etc.). This layer is unit-tested and is exactly what
makes "script view and bubble view are two faces of one model" true.

**Rebuild:** the interaction layer to the FD state machine above
(`FDElementFlow` tables + handler rewiring), plus write-back canonicalization
so a typed cue "ALEX" maps to the canonical `Character` "Alex" (protects
name-matching, avatars, and rename cascades — the bubble connection).

## 3. Phases

**Phase 1 (this commit):**
- `FDElementFlow` — Return/Tab tables exactly as §1.2, with the FD-style
  "Return after Dialogue" preference (action|character) in UserDefaults.
- `handleReturn`/`handleTab` rewired to the tables; Tab converts empty
  elements and creates-next on non-empty ones.
- Auto-UPPERCASE on commit for scene headings and transitions.
- Character-cue write-back canonicalizes to the existing Character's name
  (case-insensitive match) so bubble-view identity is never broken.
- ⌃1–6 direct element switching.
- Flow-table unit tests.

**Phase 2:** scene-heading structured Tab (" - " + time SmartType inline),
SmartType extensions (V.O./O.S./CONT'D in cue autocomplete), current-element
indicator in the status area, dual dialogue.

**Phase 3:** exact pagination (55-line pages, MORE/CONT'D at breaks,
keep-with rules: never orphan a cue at a page bottom), revision marks.

## 4. Acceptance criteria (Phase 1)
1. Typing `INT. OFFICE - DAY` ⏎ lands in Action; type action ⏎ Action; Tab →
   empty Character cue; type name ⏎ → Dialogue; ⏎ after dialogue → Action
   (or Character if preference flipped); Tab in dialogue → Parenthetical.
2. Scene headings/transitions commit UPPERCASE regardless of typed case.
3. Typing a cue in any case for an existing character stores the canonical
   name — the bubble view shows the dialogue under the right character with
   the right avatar, and rename cascades still find it.
4. ⌃1–6 converts the current element's type instantly.
5. All existing model tests (paste/undo/invariants) stay green.

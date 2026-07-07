# BubbleView Test Plan — CRUD & Cross-View Integration

## Architecture Summary

BubbleView is the primary dialogue/scene content editor. It shows 5 item types (Dialogue, Action, Narration, Note, SoundNote) in a chat-like bubble layout. Items are ordered by `chronologyNumber` and can be nested under dialogues via `parentDialogueId`.

**Data flow:** `BubbleView` mutates `@Binding var project: Project` directly → `ProjectViewModel` detects change → auto-save. Cross-view sync relies on `onContentChanged?()` / `onItemsReordered?()` callbacks → `AppCoordinator.notifyProjectChanged()` → all views refresh.

---

## Known Bugs Found During Code Review

These are confirmed issues in the code that tests will surface:

| # | Bug | Root Cause | Impact |
|---|-----|-----------|--------|
| B1 | Deleting Action/Narration/Note/SoundNote doesn't sync to Timeline/Script | `deleteAction`, `deleteNarration`, `deleteNote`, `deleteSoundNote` never call `onContentChanged?()` | Timeline shows deleted items |
| B2 | Editing any item doesn't sync to Timeline/Script | All `update*()` methods never call `onContentChanged?()` | Timeline/Script show stale data |
| B3 | Connect/Disconnect item doesn't sync | `connectItem` and `disconnectItem` never call `onContentChanged?()` | Script view shows wrong grouping |
| B4 | `addDialogue` uses wrong max chronology | Uses only `scene.dialogues.map(\.chronologyNumber).max()` instead of max across ALL item types | New dialogue gets duplicate chronologyNumber, appears at wrong position |
| B5 | Standalone add/delete/update don't rebuild bubble cache | Only `addConnected*` methods call `rebuildBubbleCache()` — others rely only on `sortRefreshTrigger` | Stale cache causes wrong display order, missing items in sub-bubbles |
| B6 | Notes/SoundNotes reorder doesn't update `globalChronologyNumber` | `reorderItems` only updates `chronologyNumber` for notes/soundNotes, not `globalChronologyNumber` (unlike dialogues/actions/narrations) | Timeline ordering wrong for notes/sound notes after reorder |

---

## Test Matrix

### 1. CREATE Operations

#### 1.1 Add Dialogue
- [ ] Click "+" to add dialogue → appears at bottom of bubble list
- [ ] New dialogue auto-opens in edit mode
- [ ] Dialogue has correct chronologyNumber (max across ALL item types + 1)
- [ ] **BUG TEST:** Add dialogue after adding an action with chronologyNumber 5 → dialogue should get 6, not 1 (tests B4)
- [ ] Character defaults to first project character
- [ ] After add → switch to Timeline → new dialogue visible
- [ ] After add → switch to Script → new dialogue element present
- [ ] After add → Outline sidebar shows updated dialogue count

#### 1.2 Add Action
- [ ] Click "+" for action → appears at bottom
- [ ] ChronologyNumber = max across all types + 1
- [ ] Auto-opens in edit mode (`newlyAddedItemId`)
- [ ] Cross-view: Timeline reflects new action
- [ ] Cross-view: Script view shows new action element

#### 1.3 Add Narration
- [ ] Same tests as Action (1.2)
- [ ] Appears as narration bubble style (no character avatar)

#### 1.4 Add Note
- [ ] Same tests as Action (1.2)
- [ ] Default `noteType` is "text"
- [ ] Appears with note styling

#### 1.5 Add SoundNote
- [ ] Same tests as Action (1.2)
- [ ] Default `soundType` is "ambient"
- [ ] Appears with sound note styling

#### 1.6 Add Connected Items (sub-bubbles)
- [ ] Right-click dialogue → Add Action → action appears nested under dialogue
- [ ] Connected action has `parentDialogueId` set to dialogue's ID
- [ ] Connected action does NOT appear as standalone top-level bubble
- [ ] Connected action visible in dialogue's sub-bubble group
- [ ] Repeat for connected Narration, Note, SoundNote
- [ ] After adding connected item → switch to Timeline → items reflected
- [ ] Cache is rebuilt after add (connected items call `rebuildBubbleCache`)

---

### 2. READ / Display Operations

#### 2.1 Chronological Ordering
- [ ] Items display in `chronologyNumber` ascending order
- [ ] Items with same chronologyNumber maintain stable order
- [ ] After reorder, positions are visually correct
- [ ] Filter toggles (show/hide dialogues, actions, etc.) work correctly
- [ ] Filtered items don't affect visible item order

#### 2.2 Parent-Child Grouping
- [ ] Connected items (parentDialogueId set) appear nested under their parent dialogue
- [ ] Disconnected items (parentDialogueId = nil) appear as standalone bubbles
- [ ] Sub-bubble group is sorted by chronologyNumber within the group

#### 2.3 Character Alignment
- [ ] Primary character's dialogue bubbles align LEFT
- [ ] Other characters' dialogue bubbles align RIGHT
- [ ] Left-alignment overrides work per character
- [ ] Actions/Narrations/Notes/SoundNotes are centered or neutral

#### 2.4 Scene Switching
- [ ] Select different scene in sidebar → bubbles update to new scene's items
- [ ] Previous scene's selection state cleared
- [ ] Cache rebuilds on scene switch
- [ ] Empty scene shows appropriate empty state

---

### 3. UPDATE / Edit Operations

#### 3.1 Edit Dialogue
- [ ] Click dialogue bubble → editor panel opens on right
- [ ] Edit character name → saves correctly
- [ ] Edit text → saves correctly
- [ ] Edit tags → saves correctly
- [ ] **BUG TEST:** Edit dialogue text → switch to Timeline → should show updated text (tests B2)
- [ ] **BUG TEST:** Edit dialogue text → switch to Script → should show updated text (tests B2)
- [ ] Changes persist after switching scenes and switching back

#### 3.2 Edit Action
- [ ] Double-click or edit button → inline edit or dialog opens
- [ ] Edit description → saves to model
- [ ] **BUG TEST:** Edit action → Timeline/Script doesn't update (tests B2)
- [ ] Edit connected action → parent dialogue grouping preserved

#### 3.3 Edit Narration / Note / SoundNote
- [ ] Same edit workflow as Action (3.2)
- [ ] Each type's specific fields editable (narration text, note content, soundNote volume/type)
- [ ] **BUG TEST:** Edits don't propagate to other views (tests B2)

---

### 4. DELETE Operations

#### 4.1 Delete Dialogue
- [ ] Delete dialogue → removed from bubble list
- [ ] Selected dialogue cleared if it was the deleted one
- [ ] `onContentChanged` called (this one works)
- [ ] Connected sub-items: What happens to children? (orphaned items still in model)
- [ ] Cross-view: Timeline removes deleted dialogue
- [ ] Cross-view: Script removes deleted dialogue

#### 4.2 Delete Action
- [ ] Delete action → removed from bubble list
- [ ] **BUG TEST:** Delete action → switch to Timeline → action still shows (tests B1)
- [ ] **BUG TEST:** Delete action → switch to Script → action still shows (tests B1)
- [ ] Delete connected action → sub-bubble disappears, parent dialogue unaffected

#### 4.3 Delete Narration / Note / SoundNote
- [ ] Same as Delete Action tests (4.2)
- [ ] **BUG TEST:** All non-dialogue deletes fail to sync to other views (tests B1)

#### 4.4 Delete Edge Cases
- [ ] Delete last item in scene → empty state shows
- [ ] Delete item then undo (if supported) → item restored
- [ ] Rapid delete of multiple items → no crash, correct state
- [ ] Delete dialogue that has connected sub-items → sub-items become orphaned (should they be deleted too?)

---

### 5. REORDER Operations

#### 5.1 Drag-and-Drop Reorder
- [ ] Drag dialogue up → chronologyNumber updates, visual position changes
- [ ] Drag dialogue down → same
- [ ] Drag action between two dialogues → correct chronology shift
- [ ] Items in between shift their chronologyNumber correctly (no gaps, no duplicates)
- [ ] **BUG TEST:** Reorder notes/soundNotes → `globalChronologyNumber` not updated (tests B6)
- [ ] After reorder → `onItemsReordered` called → Timeline reflects new order
- [ ] After reorder → Script view reflects new order

#### 5.2 Reorder with Connected Items
- [ ] Reorder a dialogue that has sub-items → sub-items move with it
- [ ] Reorder a standalone action past a dialogue with sub-items → positions correct
- [ ] Reorder doesn't break parent-child relationships

#### 5.3 Reorder Edge Cases
- [ ] Drag item to same position → no-op, no crash
- [ ] Drag first item to last position → all items shift
- [ ] Drag last item to first position → all items shift
- [ ] Reorder in scene with only 1 item → no crash

---

### 6. CONNECT / DISCONNECT (Parent-Child)

#### 6.1 Connect Item
- [ ] Drag standalone action onto dialogue bubble → becomes sub-item
- [ ] `parentDialogueId` set correctly on the action
- [ ] Action disappears from top-level list
- [ ] Action appears in dialogue's sub-bubble group
- [ ] **BUG TEST:** Connect doesn't call `onContentChanged` (tests B3)
- [ ] **BUG TEST:** Connect doesn't sync to Script/Timeline (tests B3)
- [ ] Repeat for narration, note, soundNote

#### 6.2 Disconnect Item
- [ ] Click disconnect/detach on connected item → becomes standalone
- [ ] `parentDialogueId` cleared to nil
- [ ] Item appears back in top-level chronological list
- [ ] **BUG TEST:** Disconnect doesn't call `onContentChanged` (tests B3)
- [ ] Repeat for all item types

#### 6.3 Connect Edge Cases
- [ ] Connect item that's already connected to different dialogue → moves to new parent
- [ ] Connect dialogue to another dialogue → should not be possible (dialogues can't be sub-items)
- [ ] Multiple items connected to same dialogue → all visible as sub-bubbles

---

### 7. CROSS-VIEW INTEGRATION

#### 7.1 BubbleView → Timeline
- [ ] Add item in Bubble → appears in Timeline
- [ ] Delete item in Bubble → disappears from Timeline
- [ ] Edit item text in Bubble → Timeline shows updated text
- [ ] Reorder items in Bubble → Timeline order changes
- [ ] **Verify `onContentChanged` is called for ALL mutation types**

#### 7.2 BubbleView → Script View
- [ ] Add dialogue in Bubble → Script shows new dialogue element
- [ ] Add action in Bubble → Script shows new action element
- [ ] Delete in Bubble → Script removes element
- [ ] Edit in Bubble → Script shows updated text
- [ ] Reorder in Bubble → Script paragraph order matches

#### 7.3 BubbleView → Outline/Navigator
- [ ] Add items → scene item counts update in sidebar
- [ ] Delete items → counts decrement
- [ ] Switch scene in sidebar → Bubble shows correct scene

#### 7.4 Timeline → BubbleView (Highlighting)
- [ ] Double-click item in Timeline → BubbleView scrolls to and highlights that item
- [ ] Highlight auto-clears after ~1.5 seconds
- [ ] Highlight works across scene boundaries (auto-switches scene if needed)

#### 7.5 Outline → BubbleView (Scene Selection)
- [ ] Click scene in Outline sidebar → BubbleView switches to that scene
- [ ] `externalSelectedSceneName` sync works correctly
- [ ] Double-click scene in Outline → navigates to Bubble and selects scene

#### 7.6 Persistence Round-Trip
- [ ] Make changes in Bubble → close and reopen project → changes preserved
- [ ] Make changes → Cloud Sync → pull on another device → changes present
- [ ] project.json contains correct chronologyNumber values after reorder

---

### 8. SCENE-LEVEL CRUD (via Sidebar)

#### 8.1 Scene Selection
- [ ] Click scene in sidebar → scene content loads in main area
- [ ] First scene auto-selected on view appear
- [ ] Scene selection persists across view switches (Bubble → Timeline → Bubble)

#### 8.2 Add/Delete Scene
- [ ] If scene add exists: new scene appears in sidebar with empty content
- [ ] If scene delete exists: scene removed, selection moves to adjacent scene
- [ ] Deleting scene with items → all items deleted too
- [ ] Outline sidebar reflects scene add/delete

#### 8.3 Scene with No Items
- [ ] Empty scene shows helpful empty state (not blank white)
- [ ] Can add items to empty scene
- [ ] Filter toggles don't cause crash on empty scene

---

### 9. CACHE CONSISTENCY

#### 9.1 Cache Rebuild Triggers
- [ ] Scene switch → cache rebuilds (confirmed at line 201)
- [ ] **BUG TEST:** `addDialogue` → cache NOT rebuilt → display may be stale (tests B5)
- [ ] **BUG TEST:** `deleteAction` → cache NOT rebuilt → deleted item may still appear in cache (tests B5)
- [ ] **BUG TEST:** `updateDialogue` → cache NOT rebuilt → character map may be stale (tests B5)
- [ ] `addConnectedAction` → cache IS rebuilt (confirmed at line 1407)
- [ ] `sortRefreshTrigger` UUID change triggers re-render but doesn't rebuild cache

#### 9.2 Cache Correctness
- [ ] After cache rebuild, `cachedChronologicalItems` matches actual scene items
- [ ] No items with `parentDialogueId != nil` appear in chronological list
- [ ] All items with `parentDialogueId` appear in `cachedConnectedItems`
- [ ] `cachedCharacterMap` reflects current project characters

---

### 10. STRESS & EDGE CASES

- [ ] Scene with 50+ items → performance acceptable, no lag on reorder
- [ ] Rapid add-delete-add → no crash, consistent state
- [ ] Switch scenes rapidly while items are being edited → no crash
- [ ] Edit item, then immediately switch scene before save completes → edit preserved
- [ ] Project with 0 sequences → Bubble shows empty state gracefully
- [ ] Project with sequence but 0 scenes → no crash
- [ ] Item with very long text (1000+ chars) → displays correctly, doesn't break layout

---

## Priority Fix Order

1. **B1 + B2 + B3** (Missing `onContentChanged` calls) — Add `onContentChanged?()` to all `delete*`, `update*`, `connectItem`, and `disconnectItem` methods
2. **B4** (Wrong chronology for `addDialogue`) — Change to use max across ALL item types like other add methods
3. **B5** (Missing cache rebuilds) — Add `rebuildBubbleCache` calls to standalone add/delete/update methods
4. **B6** (Missing `globalChronologyNumber` for notes/soundNotes in reorder) — Add the update like dialogues/actions/narrations have

## Files to Fix

| File | Lines | Fix |
|------|-------|-----|
| `BubbleView.swift` | 1176-1191 | Add `onContentChanged?()` to `updateDialogue` |
| `BubbleView.swift` | 1193-1214 | Fix `addDialogue` chronology to use max of ALL types |
| `BubbleView.swift` | 1522-1584 | Add `onContentChanged?()` to `deleteAction`, `deleteNarration`, `deleteNote`, `deleteSoundNote` |
| `BubbleView.swift` | 1586-1640 | Add `onContentChanged?()` to `updateAction`, `updateNarration`, `updateNote`, `updateSoundNote` |
| `BubbleView.swift` | 1865-1930 | Add `onContentChanged?()` to `connectItem`, `disconnectItem` |
| `BubbleView.swift` | 988-1024 | Add `globalChronologyNumber` updates for notes and soundNotes in `reorderItems` |

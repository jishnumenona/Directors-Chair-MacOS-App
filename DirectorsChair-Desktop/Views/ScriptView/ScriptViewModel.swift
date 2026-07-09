//
//  ScriptViewModel.swift
//  DirectorsChair-Desktop
//
//  Script View: ViewModel managing script elements with model-authoritative editing.
//  [ScriptElement] is the single source of truth. NSTextView is a derived view.
//  Key invariant: Paragraph N in NSTextView == elements[N]. Always.
//
//  PERFORMANCE: Text-only edits do NOT touch @Published properties.
//  Pending text is held in a shadow buffer and flushed on structural edits or timer.
//

import Foundation
import SwiftUI
import Combine
import DirectorsChairCore

// MARK: - Rebuild Instruction

/// Instruction returned by structural edit methods telling the Coordinator
/// how to update NSTextView after elements[] has been mutated.
enum RebuildInstruction {
    case none
    case updateParagraph(Int)
    case insertParagraph(Int, UUID)
    case removeParagraph(Int)
    case fullRebuild(focusElementId: UUID?, cursorOffset: Int?)
}

// MARK: - New Scene Wizard

enum NewSceneWizardStep: Equatable {
    case idle
    case selectingLocation(headingId: UUID, descId: UUID)
    case selectingTime(headingId: UUID, descId: UUID)
}

@MainActor
class ScriptViewModel: ObservableObject {
    @Published var elements: [ScriptElement] = []
    @Published var sceneOutline: [SceneOutlineItem] = []
    @Published var estimatedPageCount: Int = 0
    @Published var wordCount: Int = 0
    @Published var scriptStats: ScreenplayFormatting.ScriptStats = .init()
    @Published var currentElementIndex: Int = 0
    @Published var scrollToElementId: UUID?

    /// Monotonic version counter — incremented on every structural elements change.
    @Published var elementsVersion: Int = 0

    // MARK: - Model-level undo (WS7.2)
    //
    // NSTextView's built-in undo is DISABLED: it restores raw text without the
    // model, breaking the paragraph==element invariant. Structural edits push
    // a snapshot of (elements, project scenes) here instead; Cmd+Z / Cmd+Shift+Z
    // swap them back atomically.

    private struct EditorSnapshot {
        let elements: [ScriptElement]
        let sequences: [DirectorsChairCore.Sequence]
    }
    private var undoStack: [EditorSnapshot] = []
    private var redoStack: [EditorSnapshot] = []
    private let undoLimit = 50

    /// Call at the START of every structural edit (before mutation).
    func registerUndoSnapshot() {
        guard let projectViewModel else { return }
        undoStack.append(EditorSnapshot(elements: elements,
                                        sequences: projectViewModel.project.sequences))
        if undoStack.count > undoLimit { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    func performUndo() -> RebuildInstruction {
        // Undo may remove the wizard's elements — never leave a wizard
        // pointing at them.
        if isWizardActive { newSceneWizardStep = .idle; wizardScenePlacement = nil }
        guard let snapshot = undoStack.popLast(), let projectViewModel else { return .none }
        redoStack.append(EditorSnapshot(elements: elements,
                                        sequences: projectViewModel.project.sequences))
        restore(snapshot)
        return .fullRebuild(focusElementId: nil, cursorOffset: nil)
    }

    func performRedo() -> RebuildInstruction {
        if isWizardActive { newSceneWizardStep = .idle; wizardScenePlacement = nil }
        guard let snapshot = redoStack.popLast(), let projectViewModel else { return .none }
        undoStack.append(EditorSnapshot(elements: elements,
                                        sequences: projectViewModel.project.sequences))
        restore(snapshot)
        return .fullRebuild(focusElementId: nil, cursorOffset: nil)
    }

    private func restore(_ snapshot: EditorSnapshot) {
        pendingTexts.removeAll()
        dirtyElements.removeAll()
        elements = snapshot.elements
        projectViewModel?.project.sequences = snapshot.sequences
        projectViewModel?.isDirty = true
        elementsVersion += 1
        scheduleOutlineAndStats()
    }

    // Autocomplete state
    @Published var showingAutocomplete: Bool = false
    @Published var autocompleteItems: [AutocompleteItem] = []
    @Published var autocompleteTrigger: String = ""

    // Inline filtering support
    private var allAutocompleteItems: [AutocompleteItem] = []
    var autocompleteElementId: UUID?
    var autocompleteAnchorOffset: Int = 0

    // New scene wizard
    @Published var newSceneWizardStep: NewSceneWizardStep = .idle

    var isWizardActive: Bool { newSceneWizardStep != .idle }

    // Element to focus cursor on after rebuild
    @Published var focusElementId: UUID?
    var focusCursorOffset: Int = 0

    // Project base path for resolving image paths
    var projectBasePath: URL?

    // Configuration
    @Published var showSceneNumbers: Bool = true
    @Published var showSceneNavigator: Bool = true
    @Published var showPagesMode: Bool = false
    @Published var spellCheckEnabled: Bool = false
    @Published var typewriterMode: Bool = false

    // Transliteration
    @Published var transliterationEnabled: Bool = false
    let transliterationService = TransliterationService()

    // Zoom
    @Published var currentZoom: CGFloat = 2.0
    @Published var savedZoomLevel: CGFloat = UserDefaults.standard.double(forKey: "scriptView.savedZoomLevel") == 0
        ? 2.0 : CGFloat(UserDefaults.standard.double(forKey: "scriptView.savedZoomLevel"))

    func saveZoomLevel() {
        savedZoomLevel = currentZoom
        UserDefaults.standard.set(Double(currentZoom), forKey: "scriptView.savedZoomLevel")
    }

    func restoreZoomLevel() {
        currentZoom = savedZoomLevel
    }

    // Project reference for reverse sync
    private weak var projectViewModel: ProjectViewModel?
    private weak var coordinator: AppCoordinator?

    // MARK: - Performance: Shadow Text Buffer
    // Text-only edits are stored here instead of modifying @Published elements,
    // avoiding SwiftUI re-renders on every keystroke. Merged into elements on
    // structural edits or flush timer.
    private var pendingTexts: [UUID: String] = [:]

    /// Per-element dirty tracking: set of element IDs that have pending text changes
    private var dirtyElements: Set<UUID> = []
    /// Flush timer for dirty elements
    private var flushTask: Task<Void, Never>?
    /// Stats debounce timer (separate from dirty flush)
    private var statsTask: Task<Void, Never>?
    /// Outline+stats debounce timer (structural edits — perf audit B3)
    private var outlineTask: Task<Void, Never>?

    /// When true, the next `refresh(from:)` call is skipped.
    private var skipNextRefresh = false

    // Tracks where wizard scene was inserted so we can remove on cancel
    private var wizardScenePlacement: (sequenceIndex: Int, sceneIndex: Int)?

    // Character/location lists for autocomplete
    private(set) var characters: [DirectorsChairCore.Character] = []
    private var locationNames: [String] = []
    private var propNames: [String] = []
    /// [UPPERCASED name → avatar/color] for ⌘-highlight badges (cached; B8)
    private(set) var characterImageMap: [String: (imagePath: String?, color: String?)] = [:]

    // Time of day options
    private let timeOfDayOptions = [
        "DAY", "NIGHT", "DAWN", "DUSK", "MORNING",
        "AFTERNOON", "EVENING", "CONTINUOUS", "LATER", "MOMENTS LATER"
    ]

    // Transition options
    private let transitionOptions = [
        "CUT TO:", "HARD CUT TO:", "SMASH CUT TO:",
        "FADE IN:", "FADE OUT.", "DISSOLVE TO:",
        "MATCH CUT TO:", "JUMP CUT TO:", "IRIS IN:", "IRIS OUT:"
    ]

    // Parenthetical options
    private let parentheticalOptions = [
        "beat", "pause", "sotto", "continuing", "into phone",
        "V.O.", "O.S.", "O.C.", "whispers", "laughing", "crying"
    ]

    // MARK: - Load from Project

    func loadFromProject(_ project: Project, projectViewModel: ProjectViewModel, coordinator: AppCoordinator? = nil) {
        self.projectViewModel = projectViewModel
        self.coordinator = coordinator
        self.projectBasePath = projectViewModel.projectPath?.deletingLastPathComponent()

        rebuildSuggestionSources(from: project)

        elements = ProjectToScriptConverter.convert(from: project)
        elementsVersion += 1

        sceneOutline = ProjectToScriptConverter.extractSceneOutline(from: elements)
        estimatedPageCount = ScreenplayFormatting.estimatePageCount(from: elements)
        wordCount = ScreenplayFormatting.wordCount(from: elements)
        scriptStats = ScreenplayFormatting.computeStats(from: elements)
    }

    // MARK: - Refresh (after external project changes)

    func refresh(from project: Project) {
        guard !isWizardActive else { return }

        if skipNextRefresh {
            skipNextRefresh = false
            return
        }

        flushDirtyElements()

        elements = ProjectToScriptConverter.convert(from: project)
        pendingTexts.removeAll()
        elementsVersion += 1
        sceneOutline = ProjectToScriptConverter.extractSceneOutline(from: elements)
        estimatedPageCount = ScreenplayFormatting.estimatePageCount(from: elements)
        wordCount = ScreenplayFormatting.wordCount(from: elements)
        scriptStats = ScreenplayFormatting.computeStats(from: elements)

        rebuildSuggestionSources(from: project)
    }

    // MARK: - Suggestion Sources (SmartType)

    /// Build the sigil suggestion lists the way FD's SmartType does: from the
    /// project's DEFINED entities plus everything already USED in the script —
    /// locations appearing in scene headings and props assigned to scenes. A
    /// fresh project with scenes therefore always has real suggestions.
    private func rebuildSuggestionSources(from project: Project) {
        characters = project.characters

        // Cached for the ⌘-highlight badges — was rebuilt inside ScriptView's
        // body on every render pass (perf audit B8).
        characterImageMap = Dictionary(uniqueKeysWithValues: project.characters.map { char in
            (char.name.uppercased(), (imagePath: char.avatar ?? char.baseImage ?? char.imageFront,
                                      color: char.color))
        })

        let scenes = project.sequences.flatMap { $0.scenes }

        let definedLocations = project.locations.map { $0.name }
        let usedLocations = scenes.compactMap { scene in
            Self.locationName(fromHeading: scene.location ?? "")
        }
        locationNames = Self.orderedUnique(definedLocations + usedLocations)

        let definedProps = project.props.map { $0.name }
        let usedProps = scenes.flatMap { $0.props }
        propNames = Self.orderedUnique(definedProps + usedProps)
    }

    /// "INT. OFFICE - DAY" → "OFFICE". Returns nil for empty headings and
    /// the wizard's unfinished intros/placeholders.
    static func locationName(fromHeading heading: String) -> String? {
        var text = heading.trimmingCharacters(in: .whitespaces)

        for intro in ["INT./EXT.", "INT/EXT", "I/E.", "I/E", "INT.", "INT", "EXT.", "EXT"] {
            if text.uppercased().hasPrefix(intro) {
                text = String(text.dropFirst(intro.count))
                break
            }
        }
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: " ."))

        // Drop the time segment (" - DAY")
        if let dashRange = text.range(of: " - ", options: .backwards) {
            text = String(text[..<dashRange.lowerBound])
        }
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: " -"))

        guard !text.isEmpty, text.uppercased() != "LOCATION" else { return nil }
        return text
    }

    /// Case-insensitive de-duplication preserving first appearance and casing.
    private static func orderedUnique(_ names: [String]) -> [String] {
        var seen = Set<String>()
        return names.filter { name in
            let key = name.uppercased().trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty, !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }

    // MARK: - Navigate to Scene

    func scrollToScene(_ sceneNumber: String) {
        if let outlineItem = sceneOutline.first(where: { $0.sceneNumber == sceneNumber }) {
            scrollToElementId = outlineItem.elementId
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.scrollToElementId = nil
            }
        }
    }

    func scrollToSourceItem(_ sourceItemId: String) {
        if let element = elements.first(where: { $0.sourceItemId == sourceItemId }) {
            scrollToElementId = element.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.scrollToElementId = nil
            }
        }
    }

    // MARK: - Shadow Buffer Management

    /// Merge pending text edits into the elements array.
    /// Called before any structural edit so that elements[] is up to date.
    private func syncPendingTexts() {
        guard !pendingTexts.isEmpty else { return }
        for (id, text) in pendingTexts {
            if let idx = elements.firstIndex(where: { $0.id == id }) {
                elements[idx].text = text
                if elements[idx].isPlaceholder {
                    elements[idx].isPlaceholder = false
                }
            }
        }
        pendingTexts.removeAll()
    }

    /// Get the current text for an element, considering pending edits.
    private func currentText(for element: ScriptElement) -> String {
        return pendingTexts[element.id] ?? element.text
    }

    // MARK: - Model-Authoritative Edit Methods

    /// Handle a text-only edit within a single element (no structural change).
    /// PERFORMANCE: Does NOT touch any @Published property — no SwiftUI re-render.
    func handleTextEdit(elementIndex: Int, newText: String) {
        guard elementIndex >= 0, elementIndex < elements.count else { return }

        let element = elements[elementIndex]

        // Store in shadow buffer — NO @Published mutation
        pendingTexts[element.id] = newText

        // Mark as dirty for debounced sync to project model
        dirtyElements.insert(element.id)
        scheduleDirtyFlush()

        // Debounce stats update (don't block the typing path)
        scheduleStatsUpdate()
    }

    /// Handle Return key press — create a new element after the current one.
    func handleReturn(atElementIndex index: Int, cursorOffset: Int) -> RebuildInstruction {
        guard index >= 0, index < elements.count else { return .none }

        registerUndoSnapshot()

        // Merge any pending text so elements[] is current
        syncPendingTexts()
        flushDirtyElement(at: index)

        let currentElement = elements[index]

        // Editor v2: Final Draft "Next Element" flow (FDElementFlow §1.2).
        let nextType = FDElementFlow.nextOnReturn(after: currentElement.type)

        let context = ProjectToScriptConverter.findSceneContext(at: index, in: elements)

        // Handle splitting
        let currentText = currentElement.text
        var newElementText = ""
        if cursorOffset > 0 && cursorOffset < currentText.count {
            let splitIndex = currentText.index(currentText.startIndex, offsetBy: cursorOffset)
            elements[index].text = String(currentText[..<splitIndex])
            newElementText = String(currentText[splitIndex...])
            dirtyElements.insert(elements[index].id)
            flushDirtyElement(at: index)
        }

        let newElement = ScriptElement(
            type: nextType,
            text: newElementText,
            sourceSequenceIndex: context?.sequenceIndex,
            sourceSceneIndex: context?.sceneIndex
        )

        elements.insert(newElement, at: index + 1)
        elementsVersion += 1
        scheduleOutlineAndStats()

        return .fullRebuild(focusElementId: newElement.id, cursorOffset: 0)
    }

    /// Handle Backspace at the beginning of an element — merge with previous or delete.
    func handleBackspace(atElementIndex index: Int, cursorOffset: Int) -> RebuildInstruction {
        guard index > 0, index < elements.count else { return .none }

        registerUndoSnapshot()

        syncPendingTexts()

        let currentElement = elements[index]
        let previousElement = elements[index - 1]

        if currentElement.type == .sceneHeading {
            deleteScene(elementId: currentElement.id)
            return .none
        }

        flushDirtyElement(at: index)
        flushDirtyElement(at: index - 1)

        let cursorInMerged: Int

        if previousElement.type == .blankLine {
            elements.remove(at: index - 1)
            cursorInMerged = 0
            let focusId = elements[max(0, index - 1)].id
            elementsVersion += 1
            scheduleOutlineAndStats()
            return .fullRebuild(focusElementId: focusId, cursorOffset: cursorInMerged)
        } else {
            cursorInMerged = previousElement.text.count
            if !currentElement.text.isEmpty && !currentElement.isPlaceholder {
                elements[index - 1].text += currentElement.text
            }
            elements.remove(at: index)

            dirtyElements.insert(elements[index - 1].id)
            flushDirtyElement(at: index - 1)

            let focusId = elements[index - 1].id
            elementsVersion += 1
            scheduleOutlineAndStats()
            return .fullRebuild(focusElementId: focusId, cursorOffset: cursorInMerged)
        }
    }

    /// WS7.1 — multi-line paste and multi-paragraph deletion as ONE model
    /// operation, preserving the paragraph==element invariant. Previously a
    /// multi-line paste reached NSTextView directly while the model synced
    /// only the paragraph under the cursor — silent data loss on save.
    ///
    /// Offsets are UTF-16 code units (NSRange coordinates from the text view).
    /// The affected span [startIndex@startOffset ... endIndex@endOffset] is
    /// replaced by `replacement` (possibly multi-line, empty for deletion).
    func handleRangeReplacement(startIndex: Int, startOffset: Int,
                                endIndex: Int, endOffset: Int,
                                replacement: String) -> RebuildInstruction {
        guard startIndex >= 0, startIndex <= endIndex, endIndex < elements.count else { return .none }

        // Conservative guard: a deletion that swallows a scene heading has
        // scene-structure consequences (the heading anchors a Scene). Block it;
        // scenes are deleted via the explicit delete-scene affordance.
        if endIndex > startIndex {
            for i in (startIndex + 1)...endIndex where elements[i].type == .sceneHeading {
                return .none
            }
        }

        registerUndoSnapshot()
        syncPendingTexts()
        flushDirtyElement(at: startIndex)
        if endIndex != startIndex { flushDirtyElement(at: endIndex) }

        func utf16Slice(_ s: String, _ range: Range<Int>) -> String {
            let u = Array(s.utf16)
            let lo = min(max(range.lowerBound, 0), u.count)
            let hi = min(max(range.upperBound, lo), u.count)
            return String(decoding: u[lo..<hi], as: UTF16.self)
        }

        let prefix = utf16Slice(elements[startIndex].text, 0..<startOffset)
        let suffix = utf16Slice(elements[endIndex].text,
                                endOffset..<elements[endIndex].text.utf16.count)
        let lines = replacement.components(separatedBy: "\n")

        let context = ProjectToScriptConverter.findSceneContext(at: startIndex, in: elements)

        // First line joins the start element's prefix.
        elements[startIndex].text = prefix + (lines.first ?? "")
        dirtyElements.insert(elements[startIndex].id)

        // Drop the elements the range consumed.
        if endIndex > startIndex {
            elements.removeSubrange((startIndex + 1)...endIndex)
        }

        // Remaining lines become new elements after the start element; the
        // final one carries the end element's suffix. New paragraphs default
        // to .action (the standard type for free-typed screenplay text).
        var focusId = elements[startIndex].id
        var cursorOffset = elements[startIndex].text.count
        if lines.count > 1 {
            var insertAt = startIndex + 1
            for (i, line) in lines.dropFirst().enumerated() {
                let isLast = (i == lines.count - 2)
                let text = isLast ? line + suffix : line
                let newElement = ScriptElement(
                    type: .action,
                    text: text,
                    sourceSequenceIndex: context?.sequenceIndex,
                    sourceSceneIndex: context?.sceneIndex
                )
                elements.insert(newElement, at: insertAt)
                if isLast {
                    focusId = newElement.id
                    cursorOffset = line.count
                }
                insertAt += 1
            }
        } else {
            // Single-line replacement: suffix rejoins the start element.
            elements[startIndex].text += suffix
            cursorOffset = (prefix + (lines.first ?? "")).count
        }
        flushDirtyElement(at: startIndex)

        elementsVersion += 1
        scheduleOutlineAndStats()
        return .fullRebuild(focusElementId: focusId, cursorOffset: cursorOffset)
    }

    /// Handle Tab — Final Draft semantics (Editor v2): on an EMPTY element the
    /// element converts in place to the Tab target; on a non-empty element a
    /// NEW element of the target type is created after it (cursor there).
    func handleTabCycle(atElementIndex index: Int) -> RebuildInstruction {
        guard index >= 0, index < elements.count else { return .none }

        syncPendingTexts()
        flushDirtyElement(at: index)

        let target = FDElementFlow.nextOnTab(from: elements[index].type)

        if elements[index].text.trimmingCharacters(in: .whitespaces).isEmpty {
            // Convert in place
            registerUndoSnapshot()
            elements[index].type = target
            elementsVersion += 1
            dirtyElements.insert(elements[index].id)
            flushDirtyElement(at: index)
            return .fullRebuild(focusElementId: elements[index].id, cursorOffset: 0)
        } else {
            // Create the target as the next element
            registerUndoSnapshot()
            let context = ProjectToScriptConverter.findSceneContext(at: index, in: elements)
            let newElement = ScriptElement(
                type: target,
                text: "",
                sourceSequenceIndex: context?.sequenceIndex,
                sourceSceneIndex: context?.sceneIndex
            )
            elements.insert(newElement, at: index + 1)
            elementsVersion += 1
            scheduleOutlineAndStats()
            return .fullRebuild(focusElementId: newElement.id, cursorOffset: 0)
        }
    }

    /// Direct element switching (FD's ⌘1–6, bound to ⌃1–6 here): convert the
    /// current element's type in place.
    func handleSetElementType(atElementIndex index: Int, digit: Int) -> RebuildInstruction {
        guard index >= 0, index < elements.count,
              let target = FDElementFlow.elementType(forDigit: digit),
              elements[index].type != target else { return .none }

        syncPendingTexts()
        flushDirtyElement(at: index)
        registerUndoSnapshot()

        elements[index].type = target
        if FDElementFlow.autoUppercases(target) {
            elements[index].text = elements[index].text.uppercased()
        }
        elementsVersion += 1
        dirtyElements.insert(elements[index].id)
        flushDirtyElement(at: index)
        return .fullRebuild(focusElementId: elements[index].id, cursorOffset: elements[index].text.count)
    }

    /// Whether a sigil trigger has anything to suggest. A sigil whose list
    /// would be empty is not consumed — it types literally, so the key never
    /// dies silently in a project without locations/props/characters.
    func hasSuggestions(for trigger: String) -> Bool {
        switch trigger {
        case "character": return !characters.isEmpty
        case "location": return !locationNames.isEmpty
        case "prop": return !propNames.isEmpty
        default: return true  // time/transition/sound are static lists; "/" always works
        }
    }

    /// Accept an autocomplete suggestion. What "accept" means depends on the
    /// trigger that opened the popover: "@" runs the character-cue flow,
    /// "#" converts the element to a transition, and the inline triggers
    /// (% location, $ time, ~ sound, ^ prop, parentheticals) replace the
    /// [replaceStart, replaceEnd) range — the sigil anchor through the cursor
    /// — without changing the element's type.
    func handleAutocompleteSelection(item: String, atElementIndex index: Int,
                                     replaceStart: Int = 0, replaceEnd: Int = 0) -> RebuildInstruction {
        guard index >= 0, index < elements.count else { return .none }

        switch autocompleteTrigger {
        case "character":
            return acceptCharacterCue(item, atElementIndex: index)
        case "transition":
            return acceptTransition(item, atElementIndex: index)
        default:
            return acceptInlineInsert(item, atElementIndex: index,
                                      replaceStart: replaceStart, replaceEnd: replaceEnd)
        }
    }

    /// "@" — the selected name becomes a character cue, followed by an empty
    /// dialogue element (the FD cue → dialogue flow).
    private func acceptCharacterCue(_ item: String, atElementIndex index: Int) -> RebuildInstruction {
        registerUndoSnapshot()
        syncPendingTexts()

        elements[index].type = .character
        elements[index].text = item
        elements[index].isPlaceholder = false

        if elements[index].sourceSequenceIndex == nil {
            if let context = ProjectToScriptConverter.findSceneContext(at: index, in: elements) {
                elements[index].sourceSequenceIndex = context.sequenceIndex
                elements[index].sourceSceneIndex = context.sceneIndex
            }
        }

        dirtyElements.insert(elements[index].id)
        flushDirtyElement(at: index)

        let context = ProjectToScriptConverter.findSceneContext(at: index, in: elements)
        let dialogueElement = ScriptElement(
            type: .dialogue,
            text: "",
            sourceSequenceIndex: context?.sequenceIndex,
            sourceSceneIndex: context?.sceneIndex
        )

        elements.insert(dialogueElement, at: index + 1)
        elementsVersion += 1

        dismissAutocompleteState()
        scheduleOutlineAndStats()

        return .fullRebuild(focusElementId: dialogueElement.id, cursorOffset: 0)
    }

    /// "#" — the selected transition replaces the current element's type and text.
    private func acceptTransition(_ item: String, atElementIndex index: Int) -> RebuildInstruction {
        registerUndoSnapshot()
        syncPendingTexts()

        elements[index].type = .transition
        elements[index].text = item.uppercased()
        elements[index].isPlaceholder = false
        elementsVersion += 1

        dismissAutocompleteState()
        scheduleOutlineAndStats()

        return .fullRebuild(
            focusElementId: elements[index].id,
            cursorOffset: elements[index].text.utf16.count
        )
    }

    /// "%", "$", "~", "^", "(" — the selection replaces [replaceStart,
    /// replaceEnd) (the sigil anchor through the cursor, i.e. the typed
    /// filter characters); the element keeps its type and backing object.
    private func acceptInlineInsert(_ item: String, atElementIndex index: Int,
                                    replaceStart: Int, replaceEnd: Int) -> RebuildInstruction {
        registerUndoSnapshot()
        syncPendingTexts()

        let ns = elements[index].text as NSString
        let start = min(max(replaceStart, 0), ns.length)
        let end = min(max(replaceEnd, start), ns.length)
        let text = ns.replacingCharacters(in: NSRange(location: start, length: end - start), with: item)

        elements[index].text = text
        elements[index].isPlaceholder = false
        pendingTexts.removeValue(forKey: elements[index].id)
        dirtyElements.insert(elements[index].id)
        flushDirtyElement(at: index)
        elementsVersion += 1

        dismissAutocompleteState()
        scheduleOutlineAndStats()

        return .fullRebuild(
            focusElementId: elements[index].id,
            cursorOffset: start + (item as NSString).length
        )
    }

    private func dismissAutocompleteState() {
        showingAutocomplete = false
        autocompleteItems = []
        allAutocompleteItems = []
        autocompleteElementId = nil
    }

    // MARK: - Dirty Element Flushing

    private func scheduleDirtyFlush() {
        flushTask?.cancel()
        flushTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms debounce
            guard !Task.isCancelled else { return }
            self?.flushDirtyElements()
        }
    }

    private func scheduleStatsUpdate() {
        statsTask?.cancel()
        statsTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000) // 800ms debounce for stats
            guard !Task.isCancelled else { return }
            self?.updateStatsFromPending()
        }
    }

    /// Update stats using pending texts merged temporarily (without publishing element changes).
    private func updateStatsFromPending() {
        // Build a temporary snapshot with pending texts applied
        var snapshot = elements
        for (id, text) in pendingTexts {
            if let idx = snapshot.firstIndex(where: { $0.id == id }) {
                snapshot[idx].text = text
            }
        }
        estimatedPageCount = ScreenplayFormatting.estimatePageCount(from: snapshot)
        wordCount = ScreenplayFormatting.wordCount(from: snapshot)
    }

    /// Flush all dirty elements to the project model
    func flushDirtyElements() {
        PerfSignpost.measure("editor.flushDirtyElements") { flushDirtyElementsBody() }
    }

    private func flushDirtyElementsBody() {
        // Merge pending texts into elements first
        syncPendingTexts()

        guard let projectViewModel = projectViewModel, !dirtyElements.isEmpty else { return }

        var project = projectViewModel.project
        var anyChanged = false

        for elementId in dirtyElements {
            guard let element = elements.first(where: { $0.id == elementId }) else { continue }
            let createdId = ProjectToScriptConverter.applyEdit(element: element, newText: element.text, to: &project)

            if let newId = createdId,
               let idx = elements.firstIndex(where: { $0.id == elementId }) {
                elements[idx].sourceItemId = newId
                elements[idx].sourceItemType = elements[idx].type == .scriptNote ? "note" : "dialogue"
            }
            anyChanged = true
        }

        dirtyElements.removeAll()

        if anyChanged {
            projectViewModel.project = project
            projectViewModel.isDirty = true

            skipNextRefresh = true
            coordinator?.notifyProjectChanged(.script)
        }
    }

    /// Flush a specific dirty element by index
    private func flushDirtyElement(at index: Int) {
        guard index >= 0, index < elements.count else { return }
        // Editor v2: industry format stores scene headings and transitions in
        // UPPERCASE — normalize at the single write-back point.
        if FDElementFlow.autoUppercases(elements[index].type),
           elements[index].text != elements[index].text.uppercased() {
            elements[index].text = elements[index].text.uppercased()
        }
        let element = elements[index]
        guard dirtyElements.contains(element.id) else { return }

        guard let projectViewModel = projectViewModel else { return }
        var project = projectViewModel.project
        let createdId = ProjectToScriptConverter.applyEdit(element: element, newText: element.text, to: &project)

        if let newId = createdId {
            elements[index].sourceItemId = newId
            elements[index].sourceItemType = elements[index].type == .scriptNote ? "note" : "dialogue"
        }

        dirtyElements.remove(element.id)
        projectViewModel.project = project
        projectViewModel.isDirty = true

        skipNextRefresh = true
        coordinator?.notifyProjectChanged(.script)
    }

    // MARK: - Autocomplete

    func handleAutocompleteTrigger(_ trigger: String) {
        switch trigger {
        case "@", "character":
            autocompleteItems = characters.map { char in
                let imagePath = char.avatar ?? char.baseImage ?? char.imageFront
                return AutocompleteItem(text: char.name, imagePath: imagePath, color: char.color)
            }
            autocompleteTrigger = "character"
        case "%", "location":
            autocompleteItems = locationNames.map { AutocompleteItem(text: $0) }
            autocompleteTrigger = "location"
        case "$", "time":
            autocompleteItems = timeOfDayOptions.map { AutocompleteItem(text: $0) }
            autocompleteTrigger = "time"
        case "#", "transition":
            autocompleteItems = transitionOptions.map { AutocompleteItem(text: $0) }
            autocompleteTrigger = "transition"
        case "(":
            autocompleteItems = parentheticalOptions.map { AutocompleteItem(text: $0) }
            autocompleteTrigger = "parenthetical"
        case "~", "sound":
            autocompleteItems = ["phone ring", "music plays", "door slam", "ambient noise", "silence", "gunshot", "car engine", "footsteps"].map { AutocompleteItem(text: $0) }
            autocompleteTrigger = "sound"
        case "^", "prop":
            autocompleteItems = propNames.map { AutocompleteItem(text: $0) }
            autocompleteTrigger = "prop"
        case "/", "note":
            insertScriptNote()
            return
        default:
            autocompleteItems = []
        }

        allAutocompleteItems = autocompleteItems
        showingAutocomplete = !autocompleteItems.isEmpty
    }

    func selectAutocompleteItem(_ text: String) {
        showingAutocomplete = false
        autocompleteItems = []
        allAutocompleteItems = []
        autocompleteElementId = nil
    }

    func filterAutocomplete(prefix: String) {
        // During the wizard the filter arrives as the WHOLE heading text;
        // only what the user typed after the anchor ("INT. ", "… - ") counts.
        var effective = prefix
        if isWizardActive, autocompleteAnchorOffset > 0 {
            effective = effective.count >= autocompleteAnchorOffset
                ? String(effective.dropFirst(autocompleteAnchorOffset))
                : ""
        }

        guard !effective.isEmpty else {
            autocompleteItems = allAutocompleteItems
            showingAutocomplete = !autocompleteItems.isEmpty
            return
        }
        let lowered = effective.lowercased()
        autocompleteItems = allAutocompleteItems
            .filter { $0.text.lowercased().hasPrefix(lowered) || $0.text.lowercased().contains(lowered) }
            .sorted { a, b in
                let aPrefix = a.text.lowercased().hasPrefix(lowered)
                let bPrefix = b.text.lowercased().hasPrefix(lowered)
                if aPrefix != bPrefix { return aPrefix }
                return a.text < b.text
            }
        if autocompleteItems.isEmpty {
            showingAutocomplete = false
        }
    }

    func handlePlaceholderEdit(elementIndex: Int, newText: String) -> RebuildInstruction {
        elements[elementIndex].text = newText
        elements[elementIndex].isPlaceholder = false
        elementsVersion += 1
        return .fullRebuild(focusElementId: elements[elementIndex].id, cursorOffset: newText.count)
    }

    func dismissAutocomplete() {
        showingAutocomplete = false
        autocompleteItems = []
        allAutocompleteItems = []
        autocompleteTrigger = ""
        autocompleteElementId = nil

        guard isWizardActive else { return }

        // Esc during the wizard. If nothing was typed yet (the heading is
        // still a bare intro on the location step) the scene is clearly
        // unwanted — remove it. Otherwise keep the scene and the typed text
        // and return to free editing.
        syncPendingTexts()
        if case .selectingLocation(let hid, _) = newSceneWizardStep,
           let idx = elements.firstIndex(where: { $0.id == hid }) {
            let bare = elements[idx].text
                .trimmingCharacters(in: .whitespaces)
                .uppercased()
            if bare.isEmpty || ["INT.", "INT", "EXT.", "EXT", "I/E.", "I/E"].contains(bare) {
                cancelWizard(keepScene: false)
                return
            }
        }
        cancelWizard(keepScene: true)
    }

    // MARK: - Insert Helpers

    private func insertScriptNote() {
        registerUndoSnapshot()
        syncPendingTexts()

        var noteElement = ScriptElement(
            type: .scriptNote,
            text: "[[Note: ]]"
        )
        let insertIndex = min(currentElementIndex + 1, elements.count)
        // Anchor the note to the enclosing scene so it persists as a
        // scene Note (visible in the bubble view) instead of evaporating
        // on the next model refresh.
        if let context = ProjectToScriptConverter.findSceneContext(at: max(insertIndex - 1, 0), in: elements) {
            noteElement.sourceSequenceIndex = context.sequenceIndex
            noteElement.sourceSceneIndex = context.sceneIndex
        }
        elements.insert(noteElement, at: insertIndex)
        dirtyElements.insert(noteElement.id)
        flushDirtyElement(at: insertIndex)
        elementsVersion += 1
    }

    // MARK: - New Scene Wizard (Cmd+Shift+N)

    func insertNewScene(afterElementIndex: Int) {
        guard let projectViewModel = projectViewModel else { return }

        // ⌘⇧N while a wizard is already running: finish it with whatever was
        // typed, then start the next scene cleanly.
        if isWizardActive { commitWizardTypedText() }
        if isWizardActive { cancelWizard(keepScene: true) }

        registerUndoSnapshot()
        syncPendingTexts()

        var project = projectViewModel.project
        guard let placement = ProjectToScriptConverter.createScene(
            afterElementIndex: afterElementIndex,
            elements: elements,
            in: &project
        ) else { return }

        projectViewModel.project = project
        projectViewModel.isDirty = true
        wizardScenePlacement = placement

        let existingSceneCount = elements.filter { $0.type == .sceneHeading }.count
        let nextSceneNum = "\(existingSceneCount + 1)"

        let blankLine = ScriptElement(type: .blankLine, text: "")

        // The heading holds REAL text from the first frame ("INT. ") — no
        // placeholder string for keystrokes to interleave with. Each wizard
        // step only ever appends to it.
        let heading = ScriptElement(
            type: .sceneHeading,
            text: "INT. ",
            sourceSequenceIndex: placement.sequenceIndex,
            sourceSceneIndex: placement.sceneIndex,
            sceneNumber: nextSceneNum
        )

        let descPlaceholder = ScriptElement(
            type: .action,
            text: "Scene description...",
            sourceSequenceIndex: placement.sequenceIndex,
            sourceSceneIndex: placement.sceneIndex,
            isPlaceholder: true
        )

        let insertIndex = min(afterElementIndex + 1, elements.count)
        elements.insert(contentsOf: [blankLine, heading, descPlaceholder], at: insertIndex)
        elementsVersion += 1
        scheduleOutlineAndStats()

        // Cursor at the end of "INT. " — a pure element-text offset. Scene
        // numbers are margin decorations now, so no prefix math exists.
        focusCursorOffset = heading.text.utf16.count
        focusElementId = heading.id
        scrollToElementId = heading.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.scrollToElementId = nil
            self?.focusElementId = nil
        }

        newSceneWizardStep = .selectingLocation(headingId: heading.id, descId: descPlaceholder.id)
        openWizardSuggestions(anchoredAt: heading.text,
                              items: locationNames.map { AutocompleteItem(text: $0) },
                              trigger: "location")
    }

    /// Open a wizard suggestion popover synchronously. The anchor is the
    /// current heading length — typed characters after it become the filter.
    private func openWizardSuggestions(anchoredAt headingText: String,
                                       items: [AutocompleteItem],
                                       trigger: String) {
        autocompleteAnchorOffset = headingText.count
        autocompleteItems = items
        allAutocompleteItems = items
        autocompleteTrigger = trigger
        showingAutocomplete = !items.isEmpty
    }

    /// "EXT. " / "I/E. " typed by the user is preserved; anything else is "INT. ".
    private static func headingIntro(from text: String) -> String {
        let upper = text.uppercased()
        if upper.hasPrefix("EXT") { return "EXT. " }
        if upper.hasPrefix("I/E") { return "I/E. " }
        return "INT. "
    }

    func advanceWizard(selectedText: String) {
        switch newSceneWizardStep {
        case .selectingLocation(let headingId, let descId):
            guard let idx = elements.firstIndex(where: { $0.id == headingId }) else {
                cancelWizard(keepScene: true)
                return
            }
            syncPendingTexts()

            // Only the location segment is replaced — a user-typed intro
            // (EXT. / I/E.) survives.
            let intro = Self.headingIntro(from: elements[idx].text)
            let newText = "\(intro)\(selectedText.uppercased()) - "
            elements[idx].text = newText
            pendingTexts.removeValue(forKey: headingId)
            dirtyElements.insert(headingId)
            elementsVersion += 1

            focusCursorOffset = newText.utf16.count
            focusElementId = headingId
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.focusElementId = nil
            }

            newSceneWizardStep = .selectingTime(headingId: headingId, descId: descId)
            openWizardSuggestions(anchoredAt: newText,
                                  items: timeOfDayOptions.map { AutocompleteItem(text: $0) },
                                  trigger: "time")

        case .selectingTime(let headingId, let descId):
            guard let idx = elements.firstIndex(where: { $0.id == headingId }) else {
                cancelWizard(keepScene: true)
                return
            }
            syncPendingTexts()

            var text = elements[idx].text
            if !text.hasSuffix(" - ") {
                text = text.trimmingCharacters(in: .whitespaces)
                if text.hasSuffix(" -") { text.removeLast(2) }
                text += " - "
            }
            text += selectedText.uppercased()
            elements[idx].text = text
            pendingTexts.removeValue(forKey: headingId)
            finishWizard(headingIndex: idx, descId: descId)

        case .idle:
            break
        }
    }

    /// Common wizard completion: persist the heading through the normal
    /// write-back path (applyEdit parses it into the scene's location) and
    /// hand the cursor to the description line.
    private func finishWizard(headingIndex idx: Int, descId: UUID) {
        dirtyElements.insert(elements[idx].id)
        flushDirtyElement(at: idx)
        wizardScenePlacement = nil
        newSceneWizardStep = .idle

        dismissAutocompleteState()
        autocompleteTrigger = ""
        elementsVersion += 1
        scheduleOutlineAndStats()

        // Skip the refresh triggered by this notification — our elements
        // already have the correct state, including the description placeholder
        skipNextRefresh = true
        coordinator?.notifyProjectChanged(.script)

        focusCursorOffset = 0
        focusElementId = descId
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.focusElementId = nil
        }
    }

    /// Return/Tab during the wizard with no popover selection: accept what
    /// the user typed after the anchor as the current step's value.
    func commitWizardTypedText() {
        let headingId: UUID
        switch newSceneWizardStep {
        case .idle:
            return
        case .selectingLocation(let hid, _), .selectingTime(let hid, _):
            headingId = hid
        }
        guard let idx = elements.firstIndex(where: { $0.id == headingId }) else {
            cancelWizard(keepScene: true)
            return
        }
        syncPendingTexts()

        let text = elements[idx].text
        let anchor = min(autocompleteAnchorOffset, text.count)
        let typed = String(text.dropFirst(anchor)).trimmingCharacters(in: .whitespaces)

        if typed.isEmpty {
            // Nothing typed. On the time step a heading without a time is
            // legal — finish with what we have (minus the dangling " - ").
            // On the location step there is no heading yet — exit the wizard
            // and leave the text freely editable.
            if case .selectingTime(_, let did) = newSceneWizardStep {
                var t = text.trimmingCharacters(in: .whitespaces)
                if t.hasSuffix(" -") { t.removeLast(2) }
                elements[idx].text = t.trimmingCharacters(in: .whitespaces)
                pendingTexts.removeValue(forKey: headingId)
                finishWizard(headingIndex: idx, descId: did)
            } else {
                cancelWizard(keepScene: true)
            }
            return
        }

        // Rewind the element to the anchor; advanceWizard rebuilds the
        // segment from the typed value (uppercased, delimited).
        elements[idx].text = String(text.prefix(anchor))
        pendingTexts.removeValue(forKey: headingId)
        advanceWizard(selectedText: typed)
    }

    /// Exit the wizard. The scene and any typed heading text stay (and are
    /// flushed) unless `keepScene` is false, which removes the created scene.
    private func cancelWizard(keepScene: Bool) {
        let step = newSceneWizardStep
        newSceneWizardStep = .idle
        dismissAutocompleteState()
        autocompleteTrigger = ""

        if !keepScene {
            removeWizardScene()
            if let projectViewModel = projectViewModel {
                refresh(from: projectViewModel.project)
            }
            return
        }
        wizardScenePlacement = nil

        // Persist whatever heading text exists so a partial heading is not lost.
        switch step {
        case .selectingLocation(let hid, _), .selectingTime(let hid, _):
            if let idx = elements.firstIndex(where: { $0.id == hid }) {
                dirtyElements.insert(hid)
                flushDirtyElement(at: idx)
            }
        case .idle:
            break
        }
    }

    // MARK: - Wizard Scene Cleanup

    private func removeWizardScene() {
        guard let placement = wizardScenePlacement,
              let projectViewModel = projectViewModel else { return }

        let seqIdx = placement.sequenceIndex
        let sceneIdx = placement.sceneIndex

        guard seqIdx < projectViewModel.project.sequences.count,
              sceneIdx < projectViewModel.project.sequences[seqIdx].scenes.count else { return }

        // Move any content that was split into the wizard scene back to the
        // previous scene so nothing is lost when the user cancels.
        let prevSceneIdx = sceneIdx - 1
        if prevSceneIdx >= 0, prevSceneIdx < projectViewModel.project.sequences[seqIdx].scenes.count {
            let wizardScene = projectViewModel.project.sequences[seqIdx].scenes[sceneIdx]
            projectViewModel.project.sequences[seqIdx].scenes[prevSceneIdx].dialogues.append(contentsOf: wizardScene.dialogues)
            projectViewModel.project.sequences[seqIdx].scenes[prevSceneIdx].actions.append(contentsOf: wizardScene.actions)
            projectViewModel.project.sequences[seqIdx].scenes[prevSceneIdx].narrations.append(contentsOf: wizardScene.narrations)
            projectViewModel.project.sequences[seqIdx].scenes[prevSceneIdx].sceneNotes.append(contentsOf: wizardScene.sceneNotes)
            projectViewModel.project.sequences[seqIdx].scenes[prevSceneIdx].soundNotes.append(contentsOf: wizardScene.soundNotes)
        }

        projectViewModel.project.sequences[seqIdx].scenes.remove(at: sceneIdx)
        projectViewModel.isDirty = true
        wizardScenePlacement = nil
    }

    // MARK: - Cmd+Click Navigation

    func navigateToElement(_ element: ScriptElement) {
        guard let projectViewModel = projectViewModel,
              let coordinator = coordinator else { return }

        let project = projectViewModel.project

        switch element.type {
        case .character:
            let charName = element.text
                .replacingOccurrences(of: " (CONT'D)", with: "")
                .trimmingCharacters(in: .whitespaces)
            if let character = project.characters.first(where: {
                $0.name.caseInsensitiveCompare(charName) == .orderedSame
            }) {
                coordinator.selectCharacter(character)
            }

        case .dialogue, .parenthetical:
            if let itemId = element.sourceItemId,
               let seqIdx = element.sourceSequenceIndex,
               let sceneIdx = element.sourceSceneIndex,
               seqIdx < project.sequences.count,
               sceneIdx < project.sequences[seqIdx].scenes.count {
                let scene = project.sequences[seqIdx].scenes[sceneIdx]
                if let dialogue = scene.dialogues.first(where: { $0.uuid == itemId }) {
                    if let character = project.characters.first(where: {
                        $0.name.caseInsensitiveCompare(dialogue.character) == .orderedSame
                    }) {
                        coordinator.selectCharacter(character)
                    }
                }
            }

        case .sceneHeading:
            if let seqIdx = element.sourceSequenceIndex,
               let sceneIdx = element.sourceSceneIndex,
               seqIdx < project.sequences.count,
               sceneIdx < project.sequences[seqIdx].scenes.count {
                let scene = project.sequences[seqIdx].scenes[sceneIdx]
                let sceneLocation = (scene.location ?? scene.name).uppercased()
                if let location = project.locations.first(where: {
                    sceneLocation.contains($0.name.uppercased())
                }) {
                    coordinator.selectLocation(location)
                } else {
                    coordinator.selectScene(scene)
                    coordinator.navigateTo(.bubble)
                }
            }

        case .action:
            if element.sourceItemId == nil,
               let seqIdx = element.sourceSequenceIndex,
               let sceneIdx = element.sourceSceneIndex,
               seqIdx < project.sequences.count,
               sceneIdx < project.sequences[seqIdx].scenes.count {
                let scene = project.sequences[seqIdx].scenes[sceneIdx]
                coordinator.selectScene(scene)
                coordinator.navigateTo(.bubble)
            }

        default:
            break
        }
    }

    // MARK: - Double-Click Scene Heading → Open Scene in Bubble/Timeline

    func openSceneInTimeline(_ element: ScriptElement) {
        guard let projectViewModel = projectViewModel,
              let coordinator = coordinator else { return }
        guard element.type == .sceneHeading,
              let seqIdx = element.sourceSequenceIndex,
              let sceneIdx = element.sourceSceneIndex,
              seqIdx < projectViewModel.project.sequences.count,
              sceneIdx < projectViewModel.project.sequences[seqIdx].scenes.count else { return }

        let scene = projectViewModel.project.sequences[seqIdx].scenes[sceneIdx]
        coordinator.selectScene(scene)
        coordinator.navigateTo(.scenes)
    }

    // MARK: - Delete Scene

    func deleteScene(elementId: UUID) {
        guard let projectViewModel = projectViewModel,
              let coordinator = coordinator else { return }

        guard let element = elements.first(where: { $0.id == elementId }),
              element.type == .sceneHeading,
              let seqIdx = element.sourceSequenceIndex,
              let sceneIdx = element.sourceSceneIndex else { return }

        guard seqIdx < projectViewModel.project.sequences.count,
              sceneIdx < projectViewModel.project.sequences[seqIdx].scenes.count else { return }

        let scene = projectViewModel.project.sequences[seqIdx].scenes[sceneIdx]
        if coordinator.selectedScene?.id == scene.id {
            coordinator.clearSelections()
        }

        var updatedProject = projectViewModel.project
        updatedProject.sequences[seqIdx].scenes.remove(at: sceneIdx)
        projectViewModel.project = updatedProject
        projectViewModel.isDirty = true

        let freshProject = projectViewModel.project
        elements = ProjectToScriptConverter.convert(from: freshProject)
        pendingTexts.removeAll()
        elementsVersion += 1
        scheduleOutlineAndStats()

        coordinator.notifyProjectChanged(.script)
    }

    // MARK: - Private Helpers

    private func updateOutlineAndStats() {
        PerfSignpost.measure("editor.updateOutlineAndStats") { updateOutlineAndStatsBody() }
    }

    /// Perf Tier 1.2 (audit B3): the outline + page/word/stat passes are
    /// 4× O(document) (~26ms on the 2,000-element stress script) and used to
    /// run SYNCHRONOUSLY inside every structural keystroke. Structural
    /// handlers now debounce them here; the toolbar/navigator lag ≤300ms.
    private func scheduleOutlineAndStats() {
        outlineTask?.cancel()
        outlineTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            self?.updateOutlineAndStats()
        }
    }

    private func updateOutlineAndStatsBody() {
        sceneOutline = ProjectToScriptConverter.extractSceneOutline(from: elements)
        estimatedPageCount = ScreenplayFormatting.estimatePageCount(from: elements)
        wordCount = ScreenplayFormatting.wordCount(from: elements)
        scriptStats = ScreenplayFormatting.computeStats(from: elements)
    }
}

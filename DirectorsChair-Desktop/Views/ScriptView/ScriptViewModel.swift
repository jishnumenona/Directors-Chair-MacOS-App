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
    case selectingTime(headingId: UUID, descId: UUID, location: String)
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
        guard let snapshot = undoStack.popLast(), let projectViewModel else { return .none }
        redoStack.append(EditorSnapshot(elements: elements,
                                        sequences: projectViewModel.project.sequences))
        restore(snapshot)
        return .fullRebuild(focusElementId: nil, cursorOffset: nil)
    }

    func performRedo() -> RebuildInstruction {
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
        updateOutlineAndStats()
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

    /// When true, the next `refresh(from:)` call is skipped.
    private var skipNextRefresh = false

    // Tracks where wizard scene was inserted so we can remove on cancel
    private var wizardScenePlacement: (sequenceIndex: Int, sceneIndex: Int)?

    // Character/location lists for autocomplete
    private(set) var characters: [DirectorsChairCore.Character] = []
    private var locationNames: [String] = []
    private var propNames: [String] = []

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

        characters = project.characters
        locationNames = project.locations.map { $0.name }
        propNames = project.props.map { $0.name }

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

        characters = project.characters
        locationNames = project.locations.map { $0.name }
        propNames = project.props.map { $0.name }
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
        updateOutlineAndStats()

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
            updateOutlineAndStats()
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
            updateOutlineAndStats()
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
        updateOutlineAndStats()
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
            updateOutlineAndStats()
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

    /// Handle autocomplete selection — insert the selected text as a character element.
    func handleAutocompleteSelection(item: String, atElementIndex index: Int) -> RebuildInstruction {
        guard index >= 0, index < elements.count else { return .none }

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

        showingAutocomplete = false
        autocompleteItems = []
        allAutocompleteItems = []
        autocompleteElementId = nil
        updateOutlineAndStats()

        return .fullRebuild(focusElementId: dialogueElement.id, cursorOffset: 0)
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
                elements[idx].sourceItemType = "dialogue"
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
            elements[index].sourceItemType = "dialogue"
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
        guard !prefix.isEmpty else {
            autocompleteItems = allAutocompleteItems
            showingAutocomplete = !autocompleteItems.isEmpty
            return
        }
        let lowered = prefix.lowercased()
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

        if isWizardActive {
            removeWizardScene()
            newSceneWizardStep = .idle

            if let projectViewModel = projectViewModel {
                refresh(from: projectViewModel.project)
            }
        }
    }

    // MARK: - Insert Helpers

    private func insertScriptNote() {
        let noteElement = ScriptElement(
            type: .scriptNote,
            text: "[[Note: ]]"
        )
        let insertIndex = min(currentElementIndex + 1, elements.count)
        elements.insert(noteElement, at: insertIndex)
        elementsVersion += 1
    }

    // MARK: - New Scene Wizard (Cmd+Shift+N)

    func insertNewScene(afterElementIndex: Int) {
        guard !isWizardActive else { return }
        guard let projectViewModel = projectViewModel else { return }

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

        let heading = ScriptElement(
            type: .sceneHeading,
            text: "INT. LOCATION - TIME OF DAY",
            sourceSequenceIndex: placement.sequenceIndex,
            sourceSceneIndex: placement.sceneIndex,
            sceneNumber: nextSceneNum,
            isPlaceholder: true
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
        updateOutlineAndStats()

        // Focus cursor on the heading at the LOCATION part (after scene number + "INT. ")
        let sceneNumPrefixLen = showSceneNumbers ? (nextSceneNum.count + 4) : 0  // "8    " = num + 4 spaces
        focusCursorOffset = sceneNumPrefixLen + 5  // + "INT. "
        focusElementId = heading.id
        scrollToElementId = heading.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.scrollToElementId = nil
            self?.focusElementId = nil
        }

        newSceneWizardStep = .selectingLocation(headingId: heading.id, descId: descPlaceholder.id)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            let items = self.locationNames.map { AutocompleteItem(text: $0) }
            self.autocompleteItems = items
            self.allAutocompleteItems = items
            self.autocompleteAnchorOffset = 0
            self.autocompleteTrigger = "location"
            self.showingAutocomplete = true
        }
    }

    func advanceWizard(selectedText: String) {
        switch newSceneWizardStep {
        case .selectingLocation(let headingId, let descId):
            let locationStr = selectedText.uppercased()
            if let idx = elements.firstIndex(where: { $0.id == headingId }) {
                elements[idx].text = "INT. \(locationStr) - TIME OF DAY"
            }

            showingAutocomplete = false
            autocompleteItems = []

            // Bump version to trigger immediate visual update showing the selected location
            elementsVersion += 1

            // Position cursor at "TIME OF DAY" part: after scene number + "INT. " + location + " - "
            if let idx = elements.firstIndex(where: { $0.id == headingId }) {
                let sceneNum = elements[idx].sceneNumber ?? ""
                let sceneNumPrefixLen = showSceneNumbers ? (sceneNum.count + 4) : 0
                focusCursorOffset = sceneNumPrefixLen + 5 + locationStr.count + 3  // "INT. " + LOCATION + " - "
            }
            focusElementId = headingId
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.focusElementId = nil
            }

            newSceneWizardStep = .selectingTime(headingId: headingId, descId: descId, location: locationStr)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self else { return }
                let items = self.timeOfDayOptions.map { AutocompleteItem(text: $0) }
                self.autocompleteItems = items
                self.allAutocompleteItems = items
                self.autocompleteAnchorOffset = 0
                self.autocompleteTrigger = "time"
                self.showingAutocomplete = true
            }

        case .selectingTime(let headingId, let descId, let location):
            let finalLocation = "INT. \(location) - \(selectedText.uppercased())"

            if let idx = elements.firstIndex(where: { $0.id == headingId }) {
                elements[idx].text = finalLocation
                elements[idx].isPlaceholder = false
            }

            if let placement = wizardScenePlacement,
               let projectViewModel = projectViewModel {
                let seqIdx = placement.sequenceIndex
                let sceneIdx = placement.sceneIndex
                if seqIdx < projectViewModel.project.sequences.count,
                   sceneIdx < projectViewModel.project.sequences[seqIdx].scenes.count {
                    projectViewModel.project.sequences[seqIdx].scenes[sceneIdx].location = finalLocation
                    projectViewModel.isDirty = true
                }
            }
            wizardScenePlacement = nil

            // Keep the description placeholder — it will be cleared when the user starts typing
            // (handled by handlePlaceholderEdit)

            showingAutocomplete = false
            autocompleteItems = []

            newSceneWizardStep = .idle
            elementsVersion += 1

            // Skip the refresh triggered by this notification — our elements already have
            // the correct state including the description placeholder
            skipNextRefresh = true
            coordinator?.notifyProjectChanged(.script)

            focusCursorOffset = 0
            focusElementId = descId
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.focusElementId = nil
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
        updateOutlineAndStats()

        coordinator.notifyProjectChanged(.script)
    }

    // MARK: - Private Helpers

    private func updateOutlineAndStats() {
        sceneOutline = ProjectToScriptConverter.extractSceneOutline(from: elements)
        estimatedPageCount = ScreenplayFormatting.estimatePageCount(from: elements)
        wordCount = ScreenplayFormatting.wordCount(from: elements)
        scriptStats = ScreenplayFormatting.computeStats(from: elements)
    }
}

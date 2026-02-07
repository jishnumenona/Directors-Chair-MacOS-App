//
//  ScriptViewModel.swift
//  DirectorsChair-Desktop
//
//  Script View: ViewModel managing script elements, page count, scene outline, and autocomplete
//

import Foundation
import SwiftUI
import Combine
import DirectorsChairCore

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
    @Published var currentElementIndex: Int = 0
    @Published var scrollToElementId: UUID?

    // Autocomplete state
    @Published var showingAutocomplete: Bool = false
    @Published var autocompleteItems: [AutocompleteItem] = []
    @Published var autocompleteTrigger: String = ""

    // New scene wizard
    @Published var newSceneWizardStep: NewSceneWizardStep = .idle

    var isWizardActive: Bool { newSceneWizardStep != .idle }

    // Element to focus cursor on after rebuild
    @Published var focusElementId: UUID?

    // Project base path for resolving image paths
    var projectBasePath: URL?

    // Configuration
    @Published var showSceneNumbers: Bool = true
    @Published var showSceneNavigator: Bool = true

    // Project reference for reverse sync
    private weak var projectViewModel: ProjectViewModel?
    private weak var coordinator: AppCoordinator?
    private var syncDebounceTask: Task<Void, Never>?

    // Character/location lists for autocomplete
    private var characters: [DirectorsChairCore.Character] = []
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

        // Cache character/location/prop data for autocomplete
        characters = project.characters
        locationNames = project.locations.map { $0.name }
        propNames = project.props.map { $0.name }

        // Convert project to script elements
        elements = ProjectToScriptConverter.convert(from: project)

        // Build scene outline
        sceneOutline = ProjectToScriptConverter.extractSceneOutline(from: elements)

        // Estimate page count
        estimatedPageCount = ScreenplayFormatting.estimatePageCount(from: elements)
    }

    // MARK: - Refresh (after external project changes)

    func refresh(from project: Project) {
        elements = ProjectToScriptConverter.convert(from: project)
        sceneOutline = ProjectToScriptConverter.extractSceneOutline(from: elements)
        estimatedPageCount = ScreenplayFormatting.estimatePageCount(from: elements)

        // Update autocomplete data
        characters = project.characters
        locationNames = project.locations.map { $0.name }
        propNames = project.props.map { $0.name }
    }

    // MARK: - Navigate to Scene

    func scrollToScene(_ sceneNumber: String) {
        if let outlineItem = sceneOutline.first(where: { $0.sceneNumber == sceneNumber }) {
            scrollToElementId = outlineItem.elementId
            // Clear after brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.scrollToElementId = nil
            }
        }
    }

    // MARK: - Handle Text Changes (reverse sync)

    func handleTextChanged(elementIndex: Int, newText: String) {
        guard elementIndex < elements.count else { return }

        let element = elements[elementIndex]

        // Update local element
        elements[elementIndex].text = newText

        // Update page count
        estimatedPageCount = ScreenplayFormatting.estimatePageCount(from: elements)

        // Debounced reverse sync to project
        syncDebounceTask?.cancel()
        syncDebounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms debounce
            guard !Task.isCancelled else { return }
            await self?.syncToProject(element: element, newText: newText)
        }
    }

    private func syncToProject(element: ScriptElement, newText: String) {
        guard let projectViewModel = projectViewModel else { return }
        var project = projectViewModel.project
        ProjectToScriptConverter.applyEdit(element: element, newText: newText, to: &project)
        projectViewModel.project = project
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

        showingAutocomplete = !autocompleteItems.isEmpty
    }

    func selectAutocompleteItem(_ text: String) {
        showingAutocomplete = false
        autocompleteItems = []
    }

    func dismissAutocomplete() {
        showingAutocomplete = false
        autocompleteItems = []
        autocompleteTrigger = ""

        // Cancel wizard if user dismisses during it
        if isWizardActive {
            newSceneWizardStep = .idle
        }
    }

    // MARK: - Insert Helpers

    private func insertScriptNote() {
        let noteElement = ScriptElement(
            type: .scriptNote,
            text: "[[Note: ]]"
        )
        // Insert after current element
        let insertIndex = min(currentElementIndex + 1, elements.count)
        elements.insert(noteElement, at: insertIndex)
    }

    // MARK: - New Scene Wizard (Cmd+Shift+N)

    /// Insert a new scene and start the guided wizard
    func insertNewScene(afterElementIndex: Int) {
        // Calculate the next scene number
        let existingSceneCount = elements.filter { $0.type == .sceneHeading }.count
        let nextSceneNum = "\(existingSceneCount + 1)"

        // Blank line separator
        let blankLine = ScriptElement(type: .blankLine, text: "")

        // Scene heading — starts with "INT. " and placeholder hint
        let heading = ScriptElement(
            type: .sceneHeading,
            text: "INT. LOCATION - TIME OF DAY",
            sceneNumber: nextSceneNum,
            isPlaceholder: true
        )

        // Action placeholder for scene description
        let descPlaceholder = ScriptElement(
            type: .action,
            text: "Scene description...",
            isPlaceholder: true
        )

        // Insert after current element
        let insertIndex = min(afterElementIndex + 1, elements.count)
        elements.insert(contentsOf: [blankLine, heading, descPlaceholder], at: insertIndex)

        // Update scene outline and page count
        sceneOutline = ProjectToScriptConverter.extractSceneOutline(from: elements)
        estimatedPageCount = ScreenplayFormatting.estimatePageCount(from: elements)

        // Scroll to the new heading
        scrollToElementId = heading.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.scrollToElementId = nil
        }

        // Start wizard: step 1 — show location autocomplete
        newSceneWizardStep = .selectingLocation(headingId: heading.id, descId: descPlaceholder.id)

        // Show location autocomplete after a brief delay for the rebuild to finish
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            self.autocompleteItems = self.locationNames.map { AutocompleteItem(text: $0) }
            self.autocompleteTrigger = "location"
            self.showingAutocomplete = true
        }
    }

    /// Called when user selects an autocomplete item during wizard mode
    func advanceWizard(selectedText: String) {
        switch newSceneWizardStep {
        case .selectingLocation(let headingId, let descId):
            // Update heading: "INT. {LOCATION} - TIME OF DAY"
            if let idx = elements.firstIndex(where: { $0.id == headingId }) {
                elements[idx].text = "INT. \(selectedText.uppercased()) - TIME OF DAY"
                // Still a partial placeholder (time part is still placeholder-like)
                // but we keep isPlaceholder for the gray time hint
            }

            // Dismiss current autocomplete
            showingAutocomplete = false
            autocompleteItems = []

            // Move to step 2: time selection
            newSceneWizardStep = .selectingTime(headingId: headingId, descId: descId, location: selectedText.uppercased())

            // Show time autocomplete after brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self else { return }
                self.autocompleteItems = self.timeOfDayOptions.map { AutocompleteItem(text: $0) }
                self.autocompleteTrigger = "time"
                self.showingAutocomplete = true
            }

        case .selectingTime(let headingId, let descId, let location):
            // Finalize heading: "INT. {LOCATION} - {TIME}"
            if let idx = elements.firstIndex(where: { $0.id == headingId }) {
                elements[idx].text = "INT. \(location) - \(selectedText.uppercased())"
                elements[idx].isPlaceholder = false
            }

            // Clear description placeholder and focus it
            if let descIdx = elements.firstIndex(where: { $0.id == descId }) {
                elements[descIdx].text = ""
                elements[descIdx].isPlaceholder = false
            }

            // Dismiss autocomplete
            showingAutocomplete = false
            autocompleteItems = []

            // Done with wizard
            newSceneWizardStep = .idle

            // Focus cursor at description element
            focusElementId = descId
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.focusElementId = nil
            }

        case .idle:
            break
        }
    }

    // MARK: - Delete Scene

    func deleteScene(elementId: UUID) {
        guard let projectViewModel = projectViewModel,
              let coordinator = coordinator else { return }

        // Find the scene heading element
        guard let element = elements.first(where: { $0.id == elementId }),
              element.type == .sceneHeading,
              let seqIdx = element.sourceSequenceIndex,
              let sceneIdx = element.sourceSceneIndex else { return }

        let project = projectViewModel.project
        guard seqIdx < project.sequences.count,
              sceneIdx < project.sequences[seqIdx].scenes.count else { return }

        let scene = project.sequences[seqIdx].scenes[sceneIdx]
        let sequence = project.sequences[seqIdx]

        projectViewModel.removeScene(scene, fromSequenceId: sequence.id)
        coordinator.notifyProjectChanged()
    }
}

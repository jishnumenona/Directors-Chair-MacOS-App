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

    // Tracks where wizard scene was inserted so we can remove on cancel
    private var wizardScenePlacement: (sequenceIndex: Int, sceneIndex: Int)?

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
        // Suppress external refresh during wizard — regenerating elements would
        // create new UUIDs and break the wizard's ID-based tracking
        guard !isWizardActive else { return }

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
            // Remove the scene we added to the project model
            removeWizardScene()
            newSceneWizardStep = .idle

            // Refresh elements to clean up local placeholders
            if let projectViewModel = projectViewModel {
                refresh(from: projectViewModel.project)
            }
        }
    }

    // MARK: - Project Scene Management

    /// Add a new scene to the project model and return its placement indices
    private func addSceneToProject(afterElementIndex: Int) -> (sequenceIndex: Int, sceneIndex: Int)? {
        guard let projectViewModel = projectViewModel else { return nil }

        // Determine target sequence from the element at cursor
        var targetSeqIdx: Int? = nil
        var insertAfterSceneIdx: Int? = nil

        if afterElementIndex < elements.count {
            let element = elements[afterElementIndex]
            targetSeqIdx = element.sourceSequenceIndex
            insertAfterSceneIdx = element.sourceSceneIndex
        }

        // If no sequences exist, create a default "Act 1"
        if projectViewModel.project.sequences.isEmpty {
            let newSequence = DirectorsChairCore.Sequence(name: "Act 1")
            projectViewModel.addSequence(newSequence)
            targetSeqIdx = 0
        }

        let seqIdx = targetSeqIdx ?? 0
        guard seqIdx < projectViewModel.project.sequences.count else { return nil }

        // Generate a unique scene name (Scene.id == name, must be unique)
        let existingNames = Set(projectViewModel.project.sequences.flatMap { $0.scenes.map { $0.name } })
        var counter = projectViewModel.project.sequences.flatMap({ $0.scenes }).count + 1
        var sceneName = "Scene \(counter)"
        while existingNames.contains(sceneName) {
            counter += 1
            sceneName = "Scene \(counter)"
        }

        // Create the scene with placeholder location
        let newScene = DirectorsChairCore.Scene(
            name: sceneName,
            location: "INT. LOCATION - TIME OF DAY"
        )

        // Insert at the correct position
        let sceneInsertIdx: Int
        if let afterIdx = insertAfterSceneIdx {
            sceneInsertIdx = afterIdx + 1
        } else {
            sceneInsertIdx = projectViewModel.project.sequences[seqIdx].scenes.count
        }

        projectViewModel.project.sequences[seqIdx].scenes.insert(newScene, at: sceneInsertIdx)
        projectViewModel.isDirty = true

        return (sequenceIndex: seqIdx, sceneIndex: sceneInsertIdx)
    }

    /// Remove the scene added by the wizard (called on cancel)
    private func removeWizardScene() {
        guard let placement = wizardScenePlacement,
              let projectViewModel = projectViewModel else { return }

        let seqIdx = placement.sequenceIndex
        let sceneIdx = placement.sceneIndex

        guard seqIdx < projectViewModel.project.sequences.count,
              sceneIdx < projectViewModel.project.sequences[seqIdx].scenes.count else { return }

        projectViewModel.project.sequences[seqIdx].scenes.remove(at: sceneIdx)
        projectViewModel.isDirty = true
        wizardScenePlacement = nil
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
        // Prevent double-wizard
        guard !isWizardActive else { return }

        // Add scene to project model first
        guard let placement = addSceneToProject(afterElementIndex: afterElementIndex) else { return }
        wizardScenePlacement = placement

        // Calculate the next scene number
        let existingSceneCount = elements.filter { $0.type == .sceneHeading }.count
        let nextSceneNum = "\(existingSceneCount + 1)"

        // Blank line separator
        let blankLine = ScriptElement(type: .blankLine, text: "")

        // Scene heading — starts with "INT. " and placeholder hint
        // Set source indices so reverse sync works
        let heading = ScriptElement(
            type: .sceneHeading,
            text: "INT. LOCATION - TIME OF DAY",
            sourceSequenceIndex: placement.sequenceIndex,
            sourceSceneIndex: placement.sceneIndex,
            sceneNumber: nextSceneNum,
            isPlaceholder: true
        )

        // Action placeholder for scene description
        let descPlaceholder = ScriptElement(
            type: .action,
            text: "Scene description...",
            sourceSequenceIndex: placement.sequenceIndex,
            sourceSceneIndex: placement.sceneIndex,
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
            let finalLocation = "INT. \(location) - \(selectedText.uppercased())"

            // Finalize heading: "INT. {LOCATION} - {TIME}"
            if let idx = elements.firstIndex(where: { $0.id == headingId }) {
                elements[idx].text = finalLocation
                elements[idx].isPlaceholder = false
            }

            // Sync scene location to project model
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

            // Clear description placeholder and focus it
            if let descIdx = elements.firstIndex(where: { $0.id == descId }) {
                elements[descIdx].text = ""
                elements[descIdx].isPlaceholder = false
            }

            // Dismiss autocomplete
            showingAutocomplete = false
            autocompleteItems = []

            // Done with wizard — set idle BEFORE notifying so refresh is not suppressed
            newSceneWizardStep = .idle

            // Notify global project change so other views refresh
            coordinator?.notifyProjectChanged()

            // Focus cursor at description element
            focusElementId = descId
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.focusElementId = nil
            }

        case .idle:
            break
        }
    }

    // MARK: - Cmd+Click Navigation

    func navigateToElement(_ element: ScriptElement) {
        guard let projectViewModel = projectViewModel,
              let coordinator = coordinator else { return }

        let project = projectViewModel.project

        switch element.type {
        case .character:
            // Navigate to the character in Story Design
            // Character name is stored in text, strip (CONT'D) suffix
            let charName = element.text
                .replacingOccurrences(of: " (CONT'D)", with: "")
                .trimmingCharacters(in: .whitespaces)
            if let character = project.characters.first(where: {
                $0.name.caseInsensitiveCompare(charName) == .orderedSame
            }) {
                coordinator.selectCharacter(character)
            }

        case .dialogue, .parenthetical:
            // Navigate to the character who speaks this dialogue
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
            // Navigate to the scene's location in Story Design
            if let seqIdx = element.sourceSequenceIndex,
               let sceneIdx = element.sourceSceneIndex,
               seqIdx < project.sequences.count,
               sceneIdx < project.sequences[seqIdx].scenes.count {
                let scene = project.sequences[seqIdx].scenes[sceneIdx]
                let sceneLocation = (scene.location ?? scene.name).uppercased()
                // Try to match against project locations
                if let location = project.locations.first(where: {
                    sceneLocation.contains($0.name.uppercased())
                }) {
                    coordinator.selectLocation(location)
                } else {
                    // Navigate to bubble view for the scene
                    coordinator.selectScene(scene)
                    coordinator.navigateTo(.bubble)
                }
            }

        case .action:
            // If it's a scene description (no sourceItemId), navigate to bubble for that scene
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

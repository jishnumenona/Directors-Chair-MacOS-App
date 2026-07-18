//
// StoryDesignView+Content.swift
//
// Extracted from StoryDesignView.swift (WS9.1 tier decomposition).
//

import SwiftUI
import DirectorsChairCore
import AppKit
import UniformTypeIdentifiers

extension StoryDesignView {

    // MARK: - Mode Picker Bar

    var modePickerBar: some View {
        HStack(spacing: 0) {
            ForEach(StoryDesignMode.allCases, id: \.self) { mode in
                Button {
                    selectedMode = mode
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: mode.icon)
                        Text(mode.displayName)
                    }
                    .font(.subheadline)
                    .fontWeight(selectedMode == mode ? .semibold : .regular)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(selectedMode == mode ? Color.accentColor.opacity(0.1) : Color.clear)
                    .foregroundColor(selectedMode == mode ? .accentColor : .primary)
                }
                .buttonStyle(.plain)
                .overlay(alignment: .bottom) {
                    if selectedMode == mode {
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(height: 2)
                    }
                }
            }
            Spacer()
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Characters Mode

    var charactersModeContent: some View {
        GeometryReader { _ in
            HStack(spacing: 0) {
                CharacterListSidebar(
                    project: $project,
                    selectedCharacter: $selectedCharacter,
                    projectBasePath: projectBasePath
                )
                .frame(width: 250)

                Divider()

                VStack(spacing: 0) {
                    if let _ = selectedCharacterIndex, let editingChar = editingCharacter {
                        characterHeader(for: editingChar)
                        Divider()
                        tabBar
                        Divider()
                        tabContent(for: editingCharacterBinding)
                    } else {
                        ContentUnavailableView(
                            "Select a Character",
                            systemImage: "person.fill",
                            description: Text("Choose a character from the sidebar to edit their details")
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Locations Mode

    var locationsModeContent: some View {
        GeometryReader { _ in
            HStack(spacing: 0) {
                LocationListSidebar(
                    project: $project,
                    selectedLocation: $selectedLocation
                )
                .frame(width: 250)

                Divider()

                VStack(spacing: 0) {
                    if let locationIndex = selectedLocationIndex {
                        LocationDetailView(
                            location: cascadingLocationBinding(at: locationIndex),
                            project: project,
                            projectBasePath: projectBasePath,
                            onGenerateImage: { variation, prompt, progressHandler in
                                onGenerateLocationImage?(project.locations[locationIndex], variation, prompt, progressHandler)
                            }
                        )
                    } else {
                        ContentUnavailableView(
                            "Select a Location",
                            systemImage: "map.fill",
                            description: Text("Choose a location from the sidebar to edit its details")
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Character Helpers

    var selectedCharacterIndex: Int? {
        guard let character = selectedCharacter else { return nil }
        return project.characters.firstIndex(where: { $0.id == character.id })
    }

    var selectedLocationIndex: Int? {
        guard let location = selectedLocation else { return nil }
        return project.locations.firstIndex(where: { $0.id == location.id })
    }

    // MARK: - Buffered Character Editing

    /// Binding to the selected location that cascades a rename through every
    /// name-based reference (scene/sequence locations, schedule rows, gantt
    /// tasks) before committing the edit (WS2.5b).
    func cascadingLocationBinding(at index: Int) -> Binding<Location> {
        Binding(
            get: { project.locations[index] },
            set: { newValue in
                let oldName = project.locations[index].name
                let newName = newValue.name.trimmingCharacters(in: .whitespaces)
                if oldName != newName, !oldName.isEmpty, !newName.isEmpty {
                    project.cascadeLocationRename(from: oldName, to: newName)
                }
                project.locations[index] = newValue
            }
        )
    }

    /// Binding to local editingCharacter buffer — mutations stay local until debounced sync
    var editingCharacterBinding: Binding<Character> {
        Binding(
            get: { editingCharacter ?? Character(name: "", role: "") },
            set: { newValue in
                editingCharacter = newValue
                scheduleSyncToProject()
            }
        )
    }

    /// Project version of selected character — used to detect external updates (AI analysis, etc.)
    var projectCharacterSnapshot: Character? {
        guard let index = selectedCharacterIndex else { return nil }
        return project.characters[index]
    }

    /// Load the selected character from project into the local editing buffer
    func loadEditingCharacter() {
        syncTask?.cancel()
        syncTask = nil
        if let index = selectedCharacterIndex {
            editingCharacter = project.characters[index]
        } else {
            editingCharacter = nil
        }
    }

    /// Commit the rename popover: update the editing buffer's name and flush
    /// immediately so the cascade (WS2.5b) runs now, not after the debounce.
    func commitRename() {
        let newName = renameDraft.trimmingCharacters(in: .whitespaces)
        guard !newName.isEmpty, var edited = editingCharacter else {
            showingRenamePopover = false
            return
        }
        edited.name = newName
        editingCharacter = edited
        flushEditingCharacter()
        selectedCharacter = editingCharacter
        showingRenamePopover = false
    }

    /// Immediately write the local editing buffer back to the project
    func flushEditingCharacter() {
        syncTask?.cancel()
        syncTask = nil
        commitEditingCharacterToProject()
    }

    /// Schedule a debounced sync (500ms) of the editing buffer back to the project
    func scheduleSyncToProject() {
        syncTask?.cancel()
        syncTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            commitEditingCharacterToProject()
            syncTask = nil
        }
    }

    /// Write the editing buffer to the project. If the character was renamed,
    /// cascade the rename through every name-based reference (dialogue cues,
    /// action/narration participants, primaryCharacter, costumes, cast, vision
    /// cards) so nothing is orphaned (WS2.5b).
    private func commitEditingCharacterToProject() {
        guard let editingChar = editingCharacter,
              let index = project.characters.firstIndex(where: { $0.id == editingChar.id }) else { return }
        let oldName = project.characters[index].name
        let newName = editingChar.name.trimmingCharacters(in: .whitespaces)
        if oldName != newName, !oldName.isEmpty, !newName.isEmpty {
            project.cascadeCharacterRename(from: oldName, to: newName)
        }
        project.characters[index] = editingChar
    }

    func characterHeader(for character: Character) -> some View {
        HStack {
            CharacterAvatarView(
                character: character,
                characterName: character.name,
                size: 50,
                projectBasePath: projectBasePath
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(character.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    // Rename: commits through the editing buffer, whose flush
                    // CASCADES the rename to every reference — dialogue cues,
                    // action/narration participants, cast assignments,
                    // costumes, vision cards (WS2.5b).
                    Button {
                        renameDraft = character.name
                        showingRenamePopover = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Rename character — all dialogue, cast, and scene references follow automatically")
                    .accessibilityLabel("Rename character")
                    .popover(isPresented: $showingRenamePopover) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Rename Character")
                                .font(.headline)
                            TextField("Character name", text: $renameDraft)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 240)
                                .onSubmit { commitRename() }
                            Text("All dialogue, cast, and scene references will follow the new name.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 240, alignment: .leading)
                            HStack {
                                Spacer()
                                Button("Cancel") { showingRenamePopover = false }
                                Button("Rename") { commitRename() }
                                    .keyboardShortcut(.defaultAction)
                                    .disabled(renameDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        }
                        .padding(14)
                    }
                }

                Text(character.role)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                exportCharacterHTML(character)
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .help("Export character sheet as HTML file to share with actors")

            Button {
                showGenerateAllConfirmation = true
            } label: {
                Label("Auto-Generate All", systemImage: "wand.and.stars")
            }
            .buttonStyle(.borderedProminent)
            .help("AI: Analyze script to generate traits, physical attributes, and biography")
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }

    var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(DesignTab.allCases, id: \.self) { tab in
                TabButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    action: { selectedTab = tab }
                )
            }
            Spacer()
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    @ViewBuilder
    func tabContent(for character: Binding<Character>) -> some View {
        switch selectedTab {
        case .physical:
            PhysicalAppearanceTab(
                character: character,
                projectBasePath: projectBasePath,
                onGenerateImage: { angle, prompt, progressHandler in
                    onGenerateImage?(character.wrappedValue, angle, prompt, progressHandler)
                },
                onAnalyzeTraits: {
                    onAnalyzeTraits?(character.wrappedValue)
                },
                onUploadReferenceImage: { imageData, progressHandler in
                    onUploadReferenceImage?(character.wrappedValue, imageData, progressHandler)
                }
            )
        case .costume:
            // Costume DESIGN moved to the Costumes department tab; this tab is
            // the character's wardrobe plot (scene → costume mapping).
            WardrobePlotTab(
                character: character,
                project: $project,
                projectBasePath: projectBasePath,
                onOpenCostumeDepartment: {
                    selectedMode = .costumes
                }
            )
        case .traits:
            PersonalityTraitsTab(
                character: character,
                analysisProgress: traitAnalysisProgress[character.wrappedValue.id],
                onAnalyzeFromScript: {
                    onAnalyzeTraits?(character.wrappedValue)
                },
                onResetToDefaults: {
                    for key in character.wrappedValue.traits.keys {
                        character.wrappedValue.traits[key] = 50.0
                    }
                }
            )
        case .biography:
            BiographyTab(
                character: character,
                isGenerating: biographyProgress[character.wrappedValue.id] != nil,
                onGenerateFromScript: {
                    onGenerateBiography?(character.wrappedValue)
                }
            )
        case .relationships:
            RelationshipsTab(
                character: character,
                allCharacters: project.characters
            )
        case .voice:
            VoiceTab(
                character: character,
                project: project,
                onSwitchToTraitsTab: {
                    selectedTab = .traits
                }
            )
        case .scenes:
            CharacterScenesView(
                character: character.wrappedValue,
                project: project
            )
        }
    }
}

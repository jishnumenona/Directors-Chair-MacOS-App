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
                            location: $project.locations[locationIndex],
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

    /// Immediately write the local editing buffer back to the project
    func flushEditingCharacter() {
        syncTask?.cancel()
        syncTask = nil
        guard let editingChar = editingCharacter,
              let index = project.characters.firstIndex(where: { $0.id == editingChar.id }) else { return }
        project.characters[index] = editingChar
    }

    /// Schedule a debounced sync (500ms) of the editing buffer back to the project
    func scheduleSyncToProject() {
        syncTask?.cancel()
        syncTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            guard let editingChar = editingCharacter,
                  let index = project.characters.firstIndex(where: { $0.id == editingChar.id }) else { return }
            project.characters[index] = editingChar
            syncTask = nil
        }
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
                Text(character.name)
                    .font(.title2)
                    .fontWeight(.bold)

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
            CostumeTab(
                character: character,
                projectBasePath: projectBasePath,
                project: project,
                onGenerateImage: { angle, prompt, progressHandler in
                    onGenerateImage?(character.wrappedValue, angle, prompt, progressHandler)
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

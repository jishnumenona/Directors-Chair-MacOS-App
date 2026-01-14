// DirectorsChairViews/Sources/DirectorsChairViews/StoryDesign/StoryDesignView.swift
//
// Main Story Design View - Character Design and Story World Management

import SwiftUI
import DirectorsChairCore

/// Main Story Design View - Character design and story world management
///
/// Layout:
/// - Left (20%): Character list with search and management
/// - Center (80%): Design area with tabs:
///   - Character Design: Physical, Traits, Biography, Relationships
///   - Costume Design (future)
///   - World Design (future)
public struct StoryDesignView: View {
    @Binding var project: Project
    @State private var selectedCharacter: Character?
    @State private var selectedTab: DesignTab = .physical
    @State private var showGenerateAllConfirmation = false

    let projectBasePath: URL?

    // Callbacks for AI operations (to be handled by Agent 3's services)
    var onGenerateImage: ((Character, String, String) -> Void)?  // (character, angle, prompt)
    var onAnalyzeTraits: ((Character) -> Void)?
    var onGenerateBiography: ((Character) -> Void)?

    public init(
        project: Binding<Project>,
        projectBasePath: URL? = nil,
        onGenerateImage: ((Character, String, String) -> Void)? = nil,
        onAnalyzeTraits: ((Character) -> Void)? = nil,
        onGenerateBiography: ((Character) -> Void)? = nil
    ) {
        self._project = project
        self.projectBasePath = projectBasePath
        self.onGenerateImage = onGenerateImage
        self.onAnalyzeTraits = onAnalyzeTraits
        self.onGenerateBiography = onGenerateBiography
    }

    public var body: some View {
        HSplitView {
            // Left: Character list sidebar
            CharacterListSidebar(
                project: $project,
                selectedCharacter: $selectedCharacter
            )
            .frame(minWidth: 200, maxWidth: 280)

            // Center: Design area
            VStack(spacing: 0) {
                if let characterIndex = selectedCharacterIndex {
                    // Character header
                    characterHeader(for: project.characters[characterIndex])

                    Divider()

                    // Tab bar
                    tabBar

                    Divider()

                    // Tab content
                    tabContent(for: $project.characters[characterIndex])
                } else {
                    // No character selected
                    ContentUnavailableView(
                        "Select a Character",
                        systemImage: "person.fill",
                        description: Text("Choose a character from the sidebar to edit their details")
                    )
                }
            }
        }
        .alert("Generate All Attributes", isPresented: $showGenerateAllConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Generate") {
                if let character = selectedCharacter {
                    onAnalyzeTraits?(character)
                    onGenerateBiography?(character)
                }
            }
        } message: {
            Text("This will analyze the script to generate personality traits, physical attributes, and biography information. This may take a few minutes.")
        }
    }

    private var selectedCharacterIndex: Int? {
        guard let character = selectedCharacter else { return nil }
        return project.characters.firstIndex(where: { $0.id == character.id })
    }

    // MARK: - Character Header

    private func characterHeader(for character: Character) -> some View {
        HStack {
            // Avatar
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

            // Generate all button
            Button {
                showGenerateAllConfirmation = true
            } label: {
                Label("Auto-Generate All", systemImage: "wand.and.stars")
            }
            .buttonStyle(.borderedProminent)
            .help("Analyze script to generate traits, physical attributes, and biography")
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
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

    // MARK: - Tab Content

    @ViewBuilder
    private func tabContent(for character: Binding<Character>) -> some View {
        switch selectedTab {
        case .physical:
            PhysicalAppearanceTab(
                character: character,
                projectBasePath: projectBasePath,
                onGenerateImage: { angle, prompt in
                    onGenerateImage?(character.wrappedValue, angle, prompt)
                },
                onAnalyzeTraits: {
                    onAnalyzeTraits?(character.wrappedValue)
                }
            )

        case .traits:
            PersonalityTraitsTab(
                character: character,
                onAnalyzeFromScript: {
                    onAnalyzeTraits?(character.wrappedValue)
                },
                onResetToDefaults: {
                    // Reset all traits to 50
                    for key in character.wrappedValue.traits.keys {
                        character.wrappedValue.traits[key] = 50.0
                    }
                }
            )

        case .biography:
            BiographyTab(
                character: character,
                onGenerateFromScript: {
                    onGenerateBiography?(character.wrappedValue)
                }
            )

        case .relationships:
            RelationshipsTab(
                character: character,
                allCharacters: project.characters
            )

        case .scenes:
            // Scenes & Dialogues tab - shows all scenes the character appears in
            CharacterScenesView(
                character: character.wrappedValue,
                project: project
            )
        }
    }
}

// MARK: - Design Tab Enum

enum DesignTab: String, CaseIterable {
    case physical
    case traits
    case biography
    case relationships
    case scenes

    var displayName: String {
        switch self {
        case .physical: return "Physical"
        case .traits: return "Traits"
        case .biography: return "Biography"
        case .relationships: return "Relationships"
        case .scenes: return "Scenes"
        }
    }

    var icon: String {
        switch self {
        case .physical: return "person.fill"
        case .traits: return "chart.pie.fill"
        case .biography: return "book.fill"
        case .relationships: return "person.2.fill"
        case .scenes: return "film"
        }
    }
}

// MARK: - Tab Button

private struct TabButton: View {
    let tab: DesignTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                Text(tab.displayName)
            }
            .font(.subheadline)
            .fontWeight(isSelected ? .semibold : .regular)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .foregroundColor(isSelected ? .accentColor : .primary)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            if isSelected {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(height: 2)
            }
        }
    }
}

// MARK: - Character Scenes View

private struct CharacterScenesView: View {
    let character: Character
    let project: Project

    var body: some View {
        List {
            ForEach(scenesWithCharacter) { sceneInfo in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(sceneInfo.sequenceName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(sceneInfo.sceneName)
                            .font(.headline)
                    }

                    Text("\(sceneInfo.dialogueCount) dialogue lines")
                        .font(.caption)
                        .foregroundColor(.blue)

                    if !sceneInfo.sampleDialogues.isEmpty {
                        ForEach(sceneInfo.sampleDialogues, id: \.self) { dialogue in
                            Text("\"\(dialogue)\"")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .italic()
                                .lineLimit(2)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var scenesWithCharacter: [SceneInfo] {
        var scenes: [SceneInfo] = []

        for sequence in project.sequences {
            for scene in sequence.scenes {
                let dialogues = scene.dialogues.filter { $0.character == character.name }
                if !dialogues.isEmpty {
                    scenes.append(SceneInfo(
                        sequenceName: sequence.name,
                        sceneName: scene.name,
                        dialogueCount: dialogues.count,
                        sampleDialogues: dialogues.prefix(2).map(\.text)
                    ))
                }
            }
        }

        return scenes
    }
}

private struct SceneInfo: Identifiable {
    let id = UUID()
    let sequenceName: String
    let sceneName: String
    let dialogueCount: Int
    let sampleDialogues: [String]
}

#Preview {
    struct PreviewWrapper: View {
        @State private var project = Project(
            name: "Test Project",
            characters: [
                Character(
                    name: "John Doe",
                    role: "Protagonist",
                    color: "#4A90D9",
                    age: 35,
                    traits: [
                        "Creativity": 75,
                        "Empathy": 80,
                        "Anxiety": 30
                    ],
                    fullName: "Jonathan Michael Doe",
                    occupation: "Private Detective"
                ),
                Character(name: "Jane Smith", role: "Supporting", color: "#D94A90"),
                Character(name: "Bob Wilson", role: "Antagonist", color: "#90D94A")
            ],
            sequences: [
                Sequence(name: "Act 1", scenes: [
                    Scene(name: "Opening", dialogues: [
                        Dialogue(character: "John Doe", text: "It was a dark night..."),
                        Dialogue(character: "Jane Smith", text: "I know what you mean.")
                    ])
                ])
            ]
        )

        var body: some View {
            StoryDesignView(project: $project)
        }
    }

    return PreviewWrapper()
        .frame(width: 1200, height: 800)
}

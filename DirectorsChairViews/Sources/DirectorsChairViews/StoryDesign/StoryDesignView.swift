// DirectorsChairViews/Sources/DirectorsChairViews/StoryDesign/StoryDesignView.swift
//
// Main Story Design View - Character Design, Location Design, and Story World Management

import SwiftUI
import DirectorsChairCore

// MARK: - Top-Level Mode

public enum StoryDesignMode: String, CaseIterable {
    case characters
    case locations

    var displayName: String {
        switch self {
        case .characters: return "Characters"
        case .locations: return "Locations"
        }
    }

    var icon: String {
        switch self {
        case .characters: return "person.fill"
        case .locations: return "map.fill"
        }
    }
}

/// Main Story Design View - Character design, location design, and story world management
///
/// Layout:
/// - Top: Mode picker (Characters / Locations)
/// - Characters mode:
///   - Left (250px): Character list with search and management
///   - Center: Design area with tabs (Physical, Traits, Biography, Relationships, Scenes)
/// - Locations mode:
///   - Left (250px): Location list with search and management
///   - Center: Location detail editor
public struct StoryDesignView: View {
    @Binding var project: Project
    @State private var selectedMode: StoryDesignMode = .characters
    @State private var selectedCharacter: Character?
    @State private var selectedLocation: Location?
    @State private var selectedTab: DesignTab = .physical
    @State private var showGenerateAllConfirmation = false

    let projectBasePath: URL?

    // External selection (set by coordinator via Cmd+Click navigation)
    var initialCharacterId: String?
    var initialLocationId: String?
    var preferredMode: String?

    // AI operation progress (survives navigation, passed from parent)
    var traitAnalysisProgress: [String: Int] = [:]
    var biographyProgress: [String: Int] = [:]

    // Callbacks for AI operations
    var onGenerateImage: ((Character, String, String, @escaping @MainActor (Double) -> Void) -> Void)?
    var onAnalyzeTraits: ((Character) -> Void)?
    var onGenerateBiography: ((Character) -> Void)?
    var onGenerateLocationImage: ((Location, String, String, @escaping @MainActor (Double) -> Void) -> Void)?

    public init(
        project: Binding<Project>,
        projectBasePath: URL? = nil,
        initialCharacterId: String? = nil,
        initialLocationId: String? = nil,
        preferredMode: String? = nil,
        traitAnalysisProgress: [String: Int] = [:],
        biographyProgress: [String: Int] = [:],
        onGenerateImage: ((Character, String, String, @escaping @MainActor (Double) -> Void) -> Void)? = nil,
        onAnalyzeTraits: ((Character) -> Void)? = nil,
        onGenerateBiography: ((Character) -> Void)? = nil,
        onGenerateLocationImage: ((Location, String, String, @escaping @MainActor (Double) -> Void) -> Void)? = nil
    ) {
        self._project = project
        self.projectBasePath = projectBasePath
        self.initialCharacterId = initialCharacterId
        self.initialLocationId = initialLocationId
        self.preferredMode = preferredMode
        self.traitAnalysisProgress = traitAnalysisProgress
        self.biographyProgress = biographyProgress
        self.onGenerateImage = onGenerateImage
        self.onAnalyzeTraits = onAnalyzeTraits
        self.onGenerateBiography = onGenerateBiography
        self.onGenerateLocationImage = onGenerateLocationImage
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Mode picker bar
            modePickerBar

            Divider()

            // Content based on mode
            switch selectedMode {
            case .characters:
                charactersModeContent
            case .locations:
                locationsModeContent
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
        .onAppear {
            applyInitialSelection()
        }
        .onChange(of: initialCharacterId) { newId in
            if let id = newId, let char = project.characters.first(where: { $0.id == id }) {
                selectedMode = .characters
                selectedCharacter = char
            }
        }
        .onChange(of: initialLocationId) { newId in
            if let id = newId, let loc = project.locations.first(where: { $0.id == id }) {
                selectedMode = .locations
                selectedLocation = loc
            }
        }
        .onChange(of: preferredMode) { newMode in
            if newMode == "locations" {
                selectedMode = .locations
            } else if newMode == "characters" {
                selectedMode = .characters
            }
        }
    }

    private func applyInitialSelection() {
        if let locId = initialLocationId,
           let loc = project.locations.first(where: { $0.id == locId }) {
            selectedMode = .locations
            selectedLocation = loc
        } else if let charId = initialCharacterId,
                  let char = project.characters.first(where: { $0.id == charId }) {
            selectedMode = .characters
            selectedCharacter = char
        } else if preferredMode == "locations" {
            selectedMode = .locations
            if selectedLocation == nil, let firstLocation = project.locations.first {
                selectedLocation = firstLocation
            }
        } else {
            // Default: select first character
            if selectedCharacter == nil, let firstCharacter = project.characters.first {
                selectedCharacter = firstCharacter
            }
            if selectedLocation == nil, let firstLocation = project.locations.first {
                selectedLocation = firstLocation
            }
        }
    }

    // MARK: - Mode Picker Bar

    private var modePickerBar: some View {
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

    private var charactersModeContent: some View {
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
                    if let characterIndex = selectedCharacterIndex {
                        characterHeader(for: project.characters[characterIndex])
                        Divider()
                        tabBar
                        Divider()
                        tabContent(for: $project.characters[characterIndex])
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

    private var locationsModeContent: some View {
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

    private var selectedCharacterIndex: Int? {
        guard let character = selectedCharacter else { return nil }
        return project.characters.firstIndex(where: { $0.id == character.id })
    }

    private var selectedLocationIndex: Int? {
        guard let location = selectedLocation else { return nil }
        return project.locations.firstIndex(where: { $0.id == location.id })
    }

    private func characterHeader(for character: Character) -> some View {
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

    @ViewBuilder
    private func tabContent(for character: Binding<Character>) -> some View {
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

// MARK: - Design Tab Enum

enum DesignTab: String, CaseIterable {
    case physical
    case costume
    case traits
    case biography
    case relationships
    case voice
    case scenes

    var displayName: String {
        switch self {
        case .physical: return "Physical"
        case .costume: return "Costume"
        case .traits: return "Traits"
        case .biography: return "Biography"
        case .relationships: return "Relationships"
        case .voice: return "Voice"
        case .scenes: return "Scenes"
        }
    }

    var icon: String {
        switch self {
        case .physical: return "person.fill"
        case .costume: return "tshirt"
        case .traits: return "chart.pie.fill"
        case .biography: return "book.fill"
        case .relationships: return "person.2.fill"
        case .voice: return "waveform"
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
        .help(tab.tooltip)
    }
}

// MARK: - Tab Tooltips

extension DesignTab {
    var tooltip: String {
        switch self {
        case .physical: return "Edit physical appearance: height, hair, eyes, etc."
        case .costume: return "Design costumes and wardrobe"
        case .traits: return "Adjust personality traits and characteristics"
        case .biography: return "Edit background story, goals, and motivations"
        case .relationships: return "Manage relationships with other characters"
        case .voice: return "Configure AI voice for dialogue playback"
        case .scenes: return "View scenes where this character appears"
        }
    }
}

// MARK: - Location List Sidebar

struct LocationListSidebar: View {
    @Binding var project: Project
    @Binding var selectedLocation: Location?
    @State private var searchText = ""
    @State private var showAddLocationSheet = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Locations")
                    .font(.headline)
                Text("(\(project.locations.count))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()

            TextField("Search locations...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .padding(.bottom, 8)

            List(selection: $selectedLocation) {
                ForEach(filteredLocations) { location in
                    LocationListRow(location: location)
                        .tag(location)
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                deleteLocation(location)
                            }
                        }
                }
            }
            .listStyle(.sidebar)

            Divider()

            VStack(spacing: 8) {
                Button {
                    showAddLocationSheet = true
                } label: {
                    Label("Add Location", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .help("Add a new location to the project")
            }
            .padding()
        }
        .frame(minWidth: 200, maxWidth: 280)
        .sheet(isPresented: $showAddLocationSheet) {
            AddLocationSheet(project: $project)
        }
    }

    private var filteredLocations: [Location] {
        if searchText.isEmpty {
            return project.locations
        }
        return project.locations.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private func deleteLocation(_ location: Location) {
        project.locations.removeAll { $0.id == location.id }
        if selectedLocation?.id == location.id {
            selectedLocation = nil
        }
    }
}

// MARK: - Location List Row

private struct LocationListRow: View {
    let location: Location

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: locationIcon(for: location))
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(location.name)
                    .font(.body)

                Text(location.locationType.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func locationIcon(for location: Location) -> String {
        switch location.locationType.lowercased() {
        case "indoor": return "building.2.fill"
        case "outdoor": return "sun.max.fill"
        default: return "map.fill"
        }
    }
}

// MARK: - Add Location Sheet

private struct AddLocationSheet: View {
    @Binding var project: Project
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var locationType = "mixed"
    @State private var description = ""

    private let locationTypes = ["indoor", "outdoor", "mixed"]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Location")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Add") { addLocation() }
                    .disabled(name.isEmpty)
                    .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            Form {
                TextField("Name", text: $name)

                Picker("Type", selection: $locationType) {
                    ForEach(locationTypes, id: \.self) { type in
                        Text(type.capitalized).tag(type)
                    }
                }

                TextField("Description", text: $description, axis: .vertical)
                    .lineLimit(3...6)
            }
            .padding()
        }
        .frame(width: 400, height: 300)
    }

    private func addLocation() {
        let newLocation = Location(
            name: name,
            description: description,
            locationType: locationType
        )
        project.locations.append(newLocation)
        dismiss()
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

//
// StoryDesignView+Components.swift
//
// Extracted from StoryDesignView.swift (WS9.1 tier decomposition).
//

import SwiftUI
import DirectorsChairCore
import AppKit
import UniformTypeIdentifiers


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
        case .costume: return "Wardrobe"
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
        case .costume: return "checklist"
        case .traits: return "chart.pie.fill"
        case .biography: return "book.fill"
        case .relationships: return "person.2.fill"
        case .voice: return "waveform"
        case .scenes: return "film"
        }
    }
}

// MARK: - Tab Button

struct TabButton: View {
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
    @State var searchText = ""
    @State var showAddLocationSheet = false

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

    var filteredLocations: [Location] {
        if searchText.isEmpty {
            return project.locations
        }
        return project.locations.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    func deleteLocation(_ location: Location) {
        project.locations.removeAll { $0.id == location.id }
        if selectedLocation?.id == location.id {
            selectedLocation = nil
        }
    }
}

// MARK: - Location List Row

struct LocationListRow: View {
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

    func locationIcon(for location: Location) -> String {
        switch location.locationType.lowercased() {
        case "indoor": return "building.2.fill"
        case "outdoor": return "sun.max.fill"
        default: return "map.fill"
        }
    }
}

// MARK: - Add Location Sheet

struct AddLocationSheet: View {
    @Binding var project: Project
    @Environment(\.dismiss) private var dismiss

    @State var name = ""
    @State var locationType = "mixed"
    @State var description = ""

    let locationTypes = ["indoor", "outdoor", "mixed"]

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

    func addLocation() {
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

struct CharacterScenesView: View {
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

    var scenesWithCharacter: [SceneInfo] {
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

struct SceneInfo: Identifiable {
    let id = UUID()
    let sequenceName: String
    let sceneName: String
    let dialogueCount: Int
    let sampleDialogues: [String]
}

#Preview {
    struct PreviewWrapper: View {
        @State var project = Project(
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

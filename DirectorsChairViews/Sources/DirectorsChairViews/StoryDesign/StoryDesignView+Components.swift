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
    @FocusState private var nameFocused: Bool

    /// (stored value, label, symbol) — the same three kinds the sidebar icons use.
    let locationTypes: [(String, String, String)] = [
        ("indoor", "Indoor", "building.2.fill"),
        ("outdoor", "Outdoor", "sun.max.fill"),
        ("mixed", "Mixed", "map.fill"),
    ]

    private var canAdd: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            // Header — icon badge, title, what this does
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color.green.opacity(0.15))
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.green)
                }
                .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("New Location")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Add a place to this project — you can add pictures and variations after.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                // Name
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("Name", icon: "textformat")
                    TextField("e.g. Outside the mini van", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .padding(8)
                        .background(Color(nsColor: .quaternarySystemFill))
                        .cornerRadius(6)
                        .focused($nameFocused)
                        .onSubmit { if canAdd { addLocation() } }
                        .accessibilityIdentifier("add-location-name")
                }

                // Type — three cards, one choice
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("Type", icon: "square.grid.2x2")
                    HStack(spacing: 8) {
                        ForEach(locationTypes, id: \.0) { type in
                            Button {
                                locationType = type.0
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: type.2)
                                        .font(.system(size: 11))
                                    Text(type.1)
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(locationType == type.0
                                              ? Color.accentColor.opacity(0.18)
                                              : Color(nsColor: .quaternarySystemFill))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(locationType == type.0 ? Color.accentColor : Color.clear, lineWidth: 1)
                                )
                                .foregroundColor(locationType == type.0 ? .accentColor : .primary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("add-location-type-\(type.0)")
                        }
                    }
                }

                // Description
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("Description", icon: "text.alignleft")
                    ZStack(alignment: .topLeading) {
                        if description.isEmpty {
                            Text("What the place looks like, the mood, the time of day it's used…")
                                .font(.system(size: 13))
                                .foregroundColor(Color(nsColor: .placeholderTextColor))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .allowsHitTesting(false)
                        }
                        CharacterMentionTextEditor(text: $description, characters: project.characters, locations: project.locations, props: project.props, continuityShots: [], placeholder: "", font: .system(size: 13), foregroundColor: .primary)
                            .font(.system(size: 13))
                            .scrollContentBackground(.hidden)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .frame(height: 96)
                            .accessibilityIdentifier("add-location-description")
                    }
                    .background(Color(nsColor: .quaternarySystemFill))
                    .cornerRadius(6)
                }
            }
            .padding(20)

            Divider()

            // Footer — actions where every other sheet in the app keeps them
            HStack {
                Text("You can rename or retype the location later from its page.")
                    .font(.system(size: 10))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .keyboardShortcut(.cancelAction)
                Button(action: addLocation) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 12))
                        Text("Add Location")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor))
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .disabled(!canAdd)
                .opacity(canAdd ? 1 : 0.5)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("add-location-confirm")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 460)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { nameFocused = true }
    }

    private func fieldLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
    }

    func addLocation() {
        guard canAdd else { return }
        let newLocation = Location(
            name: name.trimmingCharacters(in: .whitespaces),
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

// DirectorsChairViews/Sources/DirectorsChairViews/StoryDesign/CharacterListSidebar.swift
//
// Left sidebar showing character list with search and management

import SwiftUI
import DirectorsChairCore

/// Left sidebar for character list with search and management
public struct CharacterListSidebar: View {
    @Binding var project: Project
    @Binding var selectedCharacter: Character?
    let projectBasePath: URL?
    @State private var searchText = ""
    @State private var showAddCharacterSheet = false
    @State private var showDeleteConfirmation = false

    public init(project: Binding<Project>, selectedCharacter: Binding<Character?>, projectBasePath: URL? = nil) {
        self._project = project
        self._selectedCharacter = selectedCharacter
        self.projectBasePath = projectBasePath
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.accentColor)
                Text("CHARACTERS")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(1.2)
                Text("\(project.characters.count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentColor.opacity(0.7)))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(nsColor: .quaternarySystemFill))
            .cornerRadius(8)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            // Character list
            List(selection: $selectedCharacter) {
                ForEach(filteredCharacters) { character in
                    CharacterListRow(character: character, projectBasePath: projectBasePath)
                        .tag(character)
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                deleteCharacter(character)
                            }
                        }
                }
            }
            .listStyle(.sidebar)

            Divider()

            // Action buttons
            VStack(spacing: 6) {
                SidebarActionButton(
                    label: "Detect Characters",
                    icon: "sparkle.magnifyingglass",
                    color: .accentColor,
                    isProminent: true
                ) {
                    detectNewCharacters()
                }
                .help("Scan dialogues and auto-detect new characters")

                SidebarActionButton(
                    label: "Add Character",
                    icon: "plus.circle.fill",
                    color: .green
                ) {
                    showAddCharacterSheet = true
                }
                .help("Add a new character to the project")

                SidebarActionButton(
                    label: "Delete Selected",
                    icon: "trash",
                    color: .red,
                    isDisabled: selectedCharacter == nil
                ) {
                    showDeleteConfirmation = true
                }
                .help("Delete the selected character")
            }
            .padding(12)
        }
        .frame(minWidth: 200, maxWidth: 280)
        .sheet(isPresented: $showAddCharacterSheet) {
            AddCharacterSheet(project: $project)
        }
        .alert("Delete Character", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let character = selectedCharacter {
                    deleteCharacter(character)
                }
            }
        } message: {
            if let character = selectedCharacter {
                Text("Are you sure you want to delete '\(character.name)'? This will remove all dialogue assignments.")
            }
        }
    }

    private var filteredCharacters: [Character] {
        if searchText.isEmpty {
            return project.characters
        }
        return project.characters.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private func detectNewCharacters() {
        // Detect unique character names from all dialogues
        var characterNames = Set<String>()
        for sequence in project.sequences {
            for scene in sequence.scenes {
                for dialogue in scene.dialogues {
                    characterNames.insert(dialogue.character)
                }
            }
        }

        // Add new characters that don't exist yet
        let existingNames = Set(project.characters.map(\.name))
        let newNames = characterNames.subtracting(existingNames)

        for name in newNames where !name.isEmpty {
            let newCharacter = Character(name: name, role: "Supporting")
            project.characters.append(newCharacter)
        }
    }

    private func deleteCharacter(_ character: Character) {
        project.characters.removeAll { $0.id == character.id }
        if selectedCharacter?.id == character.id {
            selectedCharacter = nil
        }
    }
}

// MARK: - Character List Row

private struct CharacterListRow: View {
    let character: Character
    let projectBasePath: URL?

    var body: some View {
        HStack(spacing: 10) {
            // Character avatar with thumbnail
            CharacterAvatarView(
                character: character,
                characterName: character.name,
                size: 32,
                projectBasePath: projectBasePath
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(character.name)
                    .font(.body)

                Text(character.role)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Sidebar Action Button

private struct SidebarActionButton: View {
    let label: String
    let icon: String
    let color: Color
    var isProminent: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(isProminent ? .white : color)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isProminent ? .white : (isHovered ? .primary : .secondary))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isProminent
                        ? color.opacity(isHovered ? 0.9 : 0.8)
                        : (isHovered ? Color(nsColor: .quaternarySystemFill) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.4 : 1)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Add Character Sheet

private struct AddCharacterSheet: View {
    @Binding var project: Project
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var role = "Supporting"
    @State private var color = "#4A90D9"

    private let roles = ["Protagonist", "Antagonist", "Supporting", "Minor", "Extra"]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Character")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                Button(action: addCharacter) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 12))
                        Text("Add")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor))
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .disabled(name.isEmpty)
                .opacity(name.isEmpty ? 0.5 : 1)
            }
            .padding(16)

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                // Name
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("Name")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    TextField("Character name", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .padding(8)
                        .background(Color(nsColor: .quaternarySystemFill))
                        .cornerRadius(6)
                }

                // Role chips
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "theatermask.and.paintbrush")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("Role")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 6) {
                        ForEach(roles, id: \.self) { r in
                            Button {
                                role = r
                            } label: {
                                Text(r)
                                    .font(.system(size: 11, weight: .medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(role == r ? Color.accentColor : Color(nsColor: .quaternarySystemFill))
                                    )
                                    .foregroundColor(role == r ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Color
                HStack(spacing: 10) {
                    ColorPicker("", selection: Binding(
                        get: { Color(hex: color) },
                        set: { color = $0.hexString }
                    ))
                    .labelsHidden()
                    .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dialogue Color")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(color)
                            .font(.system(size: 11))
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding(16)

            Spacer()
        }
        .frame(width: 440, height: 280)
    }

    private func addCharacter() {
        let newCharacter = Character(
            name: name,
            role: role,
            color: color
        )
        project.characters.append(newCharacter)
        dismiss()
    }
}

// Color extensions are in Shared/ColorExtensions.swift

#Preview {
    struct PreviewWrapper: View {
        @State private var project = Project(
            name: "Test",
            characters: [
                Character(name: "John", role: "Protagonist", color: "#4A90D9"),
                Character(name: "Jane", role: "Supporting", color: "#D94A90"),
                Character(name: "Bob", role: "Antagonist", color: "#90D94A")
            ]
        )
        @State private var selectedCharacter: Character?

        var body: some View {
            CharacterListSidebar(project: $project, selectedCharacter: $selectedCharacter)
        }
    }

    return PreviewWrapper()
        .frame(width: 250, height: 500)
}

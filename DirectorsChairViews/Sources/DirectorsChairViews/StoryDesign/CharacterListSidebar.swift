// DirectorsChairViews/Sources/DirectorsChairViews/StoryDesign/CharacterListSidebar.swift
//
// Left sidebar showing character list with search and management

import SwiftUI
import DirectorsChairCore

/// Left sidebar for character list with search and management
public struct CharacterListSidebar: View {
    @Binding var project: Project
    @Binding var selectedCharacter: Character?
    @State private var searchText = ""
    @State private var showAddCharacterSheet = false
    @State private var showDeleteConfirmation = false

    public init(project: Binding<Project>, selectedCharacter: Binding<Character?>) {
        self._project = project
        self._selectedCharacter = selectedCharacter
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Characters")
                    .font(.headline)
                Text("(\(project.characters.count))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()

            // Search
            TextField("Search characters...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .padding(.bottom, 8)

            // Character list
            List(selection: $selectedCharacter) {
                ForEach(filteredCharacters) { character in
                    CharacterListRow(character: character)
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
            VStack(spacing: 8) {
                Button {
                    detectNewCharacters()
                } label: {
                    Label("Detect Characters", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity)
                }

                Button {
                    showAddCharacterSheet = true
                } label: {
                    Label("Add Character", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete Selected", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .disabled(selectedCharacter == nil)
            }
            .padding()
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

    var body: some View {
        HStack {
            // Color indicator
            Circle()
                .fill(Color(hex: character.color))
                .frame(width: 16, height: 16)

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
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Add") { addCharacter() }
                    .disabled(name.isEmpty)
                    .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            Form {
                TextField("Name", text: $name)

                Picker("Role", selection: $role) {
                    ForEach(roles, id: \.self) { role in
                        Text(role).tag(role)
                    }
                }

                ColorPicker("Color", selection: Binding(
                    get: { Color(hex: color) },
                    set: { color = $0.hexString }
                ))
            }
            .padding()
        }
        .frame(width: 400, height: 250)
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

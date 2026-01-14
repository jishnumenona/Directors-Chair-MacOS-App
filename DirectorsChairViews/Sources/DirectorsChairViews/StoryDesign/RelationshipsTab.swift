// DirectorsChairViews/Sources/DirectorsChairViews/StoryDesign/RelationshipsTab.swift
//
// Relationships tab - character relationships with other characters

import SwiftUI
import DirectorsChairCore

/// Relationships tab - shows and manages relationships with other characters
public struct RelationshipsTab: View {
    @Binding var character: Character
    let allCharacters: [Character]
    @State private var showAddRelationshipSheet = false
    @State private var newRelationshipCharacter: String = ""
    @State private var newRelationshipDescription: String = ""

    public init(character: Binding<Character>, allCharacters: [Character]) {
        self._character = character
        self.allCharacters = allCharacters
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Relationships")
                    .font(.headline)
                Spacer()
                Button {
                    showAddRelationshipSheet = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
            .padding()

            Divider()

            if let relationships = character.relationships, !relationships.isEmpty {
                // Relationship list
                List {
                    ForEach(Array(relationships.keys.sorted()), id: \.self) { characterName in
                        if let description = relationships[characterName] {
                            RelationshipRow(
                                characterName: characterName,
                                description: description,
                                relatedCharacter: allCharacters.first { $0.name == characterName },
                                onEdit: {
                                    newRelationshipCharacter = characterName
                                    newRelationshipDescription = description
                                    showAddRelationshipSheet = true
                                },
                                onDelete: {
                                    character.relationships?[characterName] = nil
                                }
                            )
                        }
                    }
                }
            } else {
                // Empty state
                ContentUnavailableView(
                    "No Relationships",
                    systemImage: "person.2.slash",
                    description: Text("Add relationships to other characters in the project")
                )
            }
        }
        .sheet(isPresented: $showAddRelationshipSheet) {
            AddRelationshipSheet(
                character: $character,
                allCharacters: allCharacters.filter { $0.id != character.id },
                initialCharacter: newRelationshipCharacter,
                initialDescription: newRelationshipDescription,
                onDismiss: {
                    newRelationshipCharacter = ""
                    newRelationshipDescription = ""
                    showAddRelationshipSheet = false
                }
            )
        }
    }
}

// MARK: - Relationship Row

private struct RelationshipRow: View {
    let characterName: String
    let description: String
    let relatedCharacter: Character?
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            CharacterAvatarView(
                character: relatedCharacter,
                characterName: characterName,
                size: 40
            )

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(characterName)
                    .font(.headline)

                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(3)

                if let role = relatedCharacter?.role {
                    Text(role)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }

            Spacer()

            // Actions
            HStack(spacing: 8) {
                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.plain)

                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Add Relationship Sheet

private struct AddRelationshipSheet: View {
    @Binding var character: Character
    let allCharacters: [Character]
    @State private var selectedCharacterName: String
    @State private var relationshipDescription: String
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss

    init(
        character: Binding<Character>,
        allCharacters: [Character],
        initialCharacter: String,
        initialDescription: String,
        onDismiss: @escaping () -> Void
    ) {
        self._character = character
        self.allCharacters = allCharacters
        self._selectedCharacterName = State(initialValue: initialCharacter.isEmpty ? (allCharacters.first?.name ?? "") : initialCharacter)
        self._relationshipDescription = State(initialValue: initialDescription)
        self.onDismiss = onDismiss
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Relationship")
                    .font(.headline)
                Spacer()
                Button("Cancel") {
                    onDismiss()
                }
                Button("Save") {
                    saveRelationship()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedCharacterName.isEmpty || relationshipDescription.isEmpty)
            }
            .padding()

            Divider()

            Form {
                // Character picker
                Picker("Character", selection: $selectedCharacterName) {
                    ForEach(allCharacters) { char in
                        HStack {
                            Circle()
                                .fill(Color(hex: char.color))
                                .frame(width: 12, height: 12)
                            Text(char.name)
                        }
                        .tag(char.name)
                    }
                }

                // Relationship type suggestions
                Section("Quick Templates") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(relationshipTemplates, id: \.self) { template in
                                Button(template) {
                                    relationshipDescription = template
                                }
                                .buttonStyle(.bordered)
                                .font(.caption)
                            }
                        }
                    }
                }

                // Description
                Section("Relationship Description") {
                    TextEditor(text: $relationshipDescription)
                        .frame(minHeight: 100)
                }
            }
            .padding()
        }
        .frame(width: 500, height: 400)
    }

    private let relationshipTemplates = [
        "Best friend",
        "Romantic partner",
        "Rival",
        "Mentor",
        "Student/Mentee",
        "Family member",
        "Colleague",
        "Enemy",
        "Ex-partner",
        "Business partner"
    ]

    private func saveRelationship() {
        if character.relationships == nil {
            character.relationships = [:]
        }
        character.relationships?[selectedCharacterName] = relationshipDescription
        onDismiss()
    }
}

#Preview {
    RelationshipsTab(
        character: .constant(Character(
            name: "John",
            role: "Protagonist",
            relationships: [
                "Jane": "Love interest. Met during the investigation and developed feelings despite initial distrust.",
                "Bob": "Childhood friend turned rival. Their friendship ended when Bob joined the wrong side.",
                "Sarah": "Trusted partner and confidant. The only person John truly trusts."
            ]
        )),
        allCharacters: [
            Character(name: "John", role: "Protagonist", color: "#4A90D9"),
            Character(name: "Jane", role: "Supporting", color: "#D94A90"),
            Character(name: "Bob", role: "Antagonist", color: "#90D94A"),
            Character(name: "Sarah", role: "Supporting", color: "#D9904A")
        ]
    )
    .frame(width: 600, height: 500)
}

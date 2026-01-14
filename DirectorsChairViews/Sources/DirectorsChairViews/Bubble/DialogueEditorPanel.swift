// DirectorsChairViews/Sources/DirectorsChairViews/Bubble/DialogueEditorPanel.swift
//
// Right panel for editing selected dialogue

import SwiftUI
import DirectorsChairCore

/// Right panel for editing selected dialogue
///
/// Shows:
/// - Character picker
/// - Text editor (rich text)
/// - Tag editor (add/remove tags)
/// - TTS controls (voice selection, generate, play)
/// - Duration override
/// - Save/Cancel buttons
public struct DialogueEditorPanel: View {
    let dialogue: Dialogue
    let characters: [Character]
    let projectBasePath: URL?
    let onSave: (Dialogue) -> Void
    let onCancel: () -> Void

    @State private var editedCharacter: String
    @State private var editedText: String
    @State private var editedTags: [String]
    @State private var editedCostumes: [String]
    @State private var editedEffects: [String]
    @State private var editedManualDuration: Double?
    @State private var newTag: String = ""

    public init(
        dialogue: Dialogue,
        characters: [Character],
        projectBasePath: URL?,
        onSave: @escaping (Dialogue) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.dialogue = dialogue
        self.characters = characters
        self.projectBasePath = projectBasePath
        self.onSave = onSave
        self.onCancel = onCancel

        self._editedCharacter = State(initialValue: dialogue.character)
        self._editedText = State(initialValue: dialogue.text)
        self._editedTags = State(initialValue: dialogue.tags)
        self._editedCostumes = State(initialValue: dialogue.costumes)
        self._editedEffects = State(initialValue: dialogue.effects)
        self._editedManualDuration = State(initialValue: dialogue.manualDuration)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Character section
                    characterSection

                    Divider()

                    // Dialogue text section
                    dialogueTextSection

                    Divider()

                    // Tags section
                    tagsSection

                    Divider()

                    // Audio section
                    audioSection

                    Divider()

                    // Costumes & Effects
                    costumesEffectsSection
                }
                .padding()
            }

            Divider()

            // Action buttons
            actionButtons
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text("Edit Dialogue")
                .font(.headline)

            Spacer()

            Text("#\(dialogue.chronologyNumber)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    // MARK: - Character Section

    private var characterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Character")
                .font(.subheadline)
                .fontWeight(.semibold)

            Picker("Character", selection: $editedCharacter) {
                ForEach(characters) { character in
                    HStack {
                        Circle()
                            .fill(Color(hex: character.color))
                            .frame(width: 12, height: 12)
                        Text(character.name)
                    }
                    .tag(character.name)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
    }

    // MARK: - Dialogue Text Section

    private var dialogueTextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dialogue Text")
                .font(.subheadline)
                .fontWeight(.semibold)

            TextEditor(text: $editedText)
                .font(.body)
                .frame(minHeight: 100, maxHeight: 200)
                .padding(4)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
    }

    // MARK: - Tags Section

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags")
                .font(.subheadline)
                .fontWeight(.semibold)

            // Existing tags
            FlowLayout(spacing: 6) {
                ForEach(editedTags, id: \.self) { tag in
                    HStack(spacing: 4) {
                        Text(tag)
                            .font(.caption)
                        Button {
                            editedTags.removeAll { $0 == tag }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(12)
                }
            }

            // Add new tag
            HStack {
                TextField("Add tag...", text: $newTag)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        addTag()
                    }

                Button("Add") {
                    addTag()
                }
                .disabled(newTag.isEmpty)
            }
        }
    }

    // MARK: - Audio Section

    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Audio")
                .font(.subheadline)
                .fontWeight(.semibold)

            // Duration
            HStack {
                Text("Duration:")
                    .font(.caption)

                TextField("Auto", value: $editedManualDuration, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)

                Text("seconds")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Audio file info
            if let audioPath = dialogue.audioFilePath {
                HStack {
                    Image(systemName: "waveform")
                        .foregroundColor(.green)
                    Text(URL(fileURLWithPath: audioPath).lastPathComponent)
                        .font(.caption)
                        .lineLimit(1)

                    Spacer()

                    Button {
                        // TODO: Play audio
                    } label: {
                        Image(systemName: "play.fill")
                    }
                    .buttonStyle(.plain)

                    Button {
                        // TODO: Clear audio
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                }
            } else {
                HStack {
                    Text("No audio file")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button("Generate TTS") {
                        // TODO: Generate TTS via Agent 3's service
                    }
                    .font(.caption)

                    Button("Choose File") {
                        // TODO: File picker
                    }
                    .font(.caption)
                }
            }
        }
    }

    // MARK: - Costumes & Effects Section

    private var costumesEffectsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Costumes
            VStack(alignment: .leading, spacing: 4) {
                Text("Costumes")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                TextField("Comma separated", text: Binding(
                    get: { editedCostumes.joined(separator: ", ") },
                    set: { editedCostumes = $0.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
                ))
                .textFieldStyle(.roundedBorder)
            }

            // Effects
            VStack(alignment: .leading, spacing: 4) {
                Text("Effects")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                TextField("Comma separated", text: Binding(
                    get: { editedEffects.joined(separator: ", ") },
                    set: { editedEffects = $0.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
                ))
                .textFieldStyle(.roundedBorder)
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack {
            Button("Cancel") {
                onCancel()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            Button("Save") {
                saveChanges()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Actions

    private func addTag() {
        let tag = newTag.trimmingCharacters(in: .whitespaces)
        if !tag.isEmpty && !editedTags.contains(tag) {
            editedTags.append(tag)
            newTag = ""
        }
    }

    private func saveChanges() {
        var updated = dialogue
        updated.character = editedCharacter
        updated.text = editedText
        updated.tags = editedTags
        updated.costumes = editedCostumes
        updated.effects = editedEffects
        updated.manualDuration = editedManualDuration
        onSave(updated)
    }
}

// MARK: - Flow Layout

/// A layout that arranges views in a flowing horizontal layout, wrapping to new lines as needed
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layoutSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layoutSubviews(proposal: proposal, subviews: subviews)

        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                          proposal: .unspecified)
        }
    }

    private func layoutSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        let totalWidth = positions.map { $0.x }.max() ?? 0
        let totalHeight = currentY + lineHeight

        return (CGSize(width: totalWidth, height: totalHeight), positions)
    }
}

#Preview {
    DialogueEditorPanel(
        dialogue: Dialogue(
            character: "John",
            text: "Hello, how are you doing today?",
            tags: ["friendly", "greeting"],
            chronologyNumber: 1
        ),
        characters: [
            Character(name: "John", role: "Protagonist", color: "#4A90D9"),
            Character(name: "Jane", role: "Supporting", color: "#D94A90")
        ],
        projectBasePath: nil,
        onSave: { _ in },
        onCancel: {}
    )
    .frame(width: 350, height: 600)
}

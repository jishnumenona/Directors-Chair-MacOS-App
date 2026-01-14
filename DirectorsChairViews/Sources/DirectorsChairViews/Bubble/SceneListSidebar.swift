// DirectorsChairViews/Sources/DirectorsChairViews/Bubble/SceneListSidebar.swift
//
// Sidebar showing scenes grouped by sequence for navigation

import SwiftUI
import DirectorsChairCore

/// Type alias to avoid ambiguity with SwiftUI.Scene
public typealias DCScene = DirectorsChairCore.Scene

/// Sidebar showing scenes grouped by sequence
public struct SceneListSidebar: View {
    @Binding var project: Project
    @Binding var selectedScene: DCScene?

    public init(project: Binding<Project>, selectedScene: Binding<DCScene?>) {
        self._project = project
        self._selectedScene = selectedScene
    }

    public var body: some View {
        List {
            ForEach(project.sequences) { sequence in
                Section {
                    ForEach(sequence.scenes) { scene in
                        SceneRow(
                            scene: scene,
                            isSelected: selectedScene?.id == scene.id,
                            dialogueCount: scene.dialogues.count
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedScene = scene
                        }
                    }
                } header: {
                    SequenceHeader(sequence: sequence)
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
    }
}

// MARK: - Sequence Header

private struct SequenceHeader: View {
    let sequence: Sequence

    var body: some View {
        HStack {
            Image(systemName: "folder.fill")
                .foregroundColor(.orange)
            Text(sequence.name)
                .font(.headline)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Scene Row

private struct SceneRow: View {
    let scene: DCScene
    let isSelected: Bool
    let dialogueCount: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(scene.name)
                    .font(.body)
                    .foregroundColor(isSelected ? .accentColor : .primary)
                    .fontWeight(isSelected ? .semibold : .regular)

                HStack(spacing: 8) {
                    // Dialogue count
                    Label("\(dialogueCount)", systemImage: "text.bubble")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Location (if any)
                    if let location = scene.location, !location.isEmpty {
                        Label(location, systemImage: "mappin")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Production status indicator
            ProductionStatusBadge(status: scene.productionStatus)
        }
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(4)
    }
}

// MARK: - Production Status Badge

private struct ProductionStatusBadge: View {
    let status: String

    var body: some View {
        Text(status)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(4)
    }

    private var statusColor: Color {
        switch status.lowercased() {
        case "planning": return .gray
        case "scheduled": return .blue
        case "ready": return .cyan
        case "shooting": return .orange
        case "shot": return .green
        case "complete": return .purple
        default: return .gray
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var project = Project(
            name: "Test Project",
            sequences: [
                Sequence(
                    name: "Act 1",
                    scenes: [
                        DCScene(name: "Scene 1 - Opening", dialogues: [
                            Dialogue(character: "John", text: "Hello"),
                            Dialogue(character: "Jane", text: "Hi")
                        ], location: "Coffee Shop", productionStatus: "Planning"),
                        DCScene(name: "Scene 2 - Discovery", dialogues: [], location: "Office", productionStatus: "Scheduled")
                    ]
                ),
                Sequence(
                    name: "Act 2",
                    scenes: [
                        DCScene(name: "Scene 3 - Confrontation", dialogues: [], productionStatus: "Shooting")
                    ]
                )
            ]
        )
        @State private var selectedScene: DCScene?

        var body: some View {
            SceneListSidebar(project: $project, selectedScene: $selectedScene)
        }
    }

    return PreviewWrapper()
        .frame(width: 250, height: 400)
}

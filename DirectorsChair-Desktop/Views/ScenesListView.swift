//
//  ScenesListView.swift
//  DirectorsChair-Desktop
//
//  Phase 8E: Project Management
//  Scene list with filtering and search
//

import SwiftUI
import DirectorsChairCore

struct ScenesListView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var projectViewModel: ProjectViewModel

    @State private var searchText = ""
    @State private var selectedSequenceFilter: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            ScenesToolbar(
                searchText: $searchText,
                selectedSequenceFilter: $selectedSequenceFilter,
                sequences: projectViewModel.sequences
            )

            Divider()

            // Scene List
            if filteredScenes.isEmpty {
                EmptySceneListView()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredScenes) { scene in
                            SceneRowView(scene: scene) {
                                coordinator.selectScene(scene)
                                coordinator.navigateTo(.bubble)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var filteredScenes: [DirectorsChairCore.Scene] {
        var scenes = projectViewModel.allScenes

        // Filter by sequence
        if let sequenceId = selectedSequenceFilter {
            scenes = scenes.filter { scene in
                projectViewModel.sequences.contains { sequence in
                    sequence.id == sequenceId && sequence.scenes.contains { $0.id == scene.id }
                }
            }
        }

        // Search filter
        if !searchText.isEmpty {
            scenes = scenes.filter { scene in
                scene.name.localizedCaseInsensitiveContains(searchText) ||
                scene.heading.localizedCaseInsensitiveContains(searchText) ||
                scene.synopsis.localizedCaseInsensitiveContains(searchText)
            }
        }

        return scenes
    }
}

// MARK: - Scenes Toolbar

struct ScenesToolbar: View {
    @Binding var searchText: String
    @Binding var selectedSequenceFilter: String?
    let sequences: [DirectorsChairCore.Sequence]

    var body: some View {
        HStack(spacing: 12) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search scenes...", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)

            // Sequence filter
            Menu {
                Button("All Sequences") {
                    selectedSequenceFilter = nil
                }

                Divider()

                ForEach(sequences) { sequence in
                    Button(sequence.name) {
                        selectedSequenceFilter = sequence.id
                    }
                }
            } label: {
                HStack {
                    Text(selectedSequenceName)
                    Image(systemName: "chevron.down")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
            }
            .frame(width: 200)
        }
        .padding()
    }

    private var selectedSequenceName: String {
        if let id = selectedSequenceFilter,
           let sequence = sequences.first(where: { $0.id == id }) {
            return sequence.name
        }
        return "All Sequences"
    }
}

// MARK: - Scene Row View

struct SceneRowView: View {
    let scene: DirectorsChairCore.Scene
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Scene icon
                Image(systemName: "film")
                    .font(.system(size: 24))
                    .foregroundColor(.green)
                    .frame(width: 40)

                // Scene info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(scene.sceneNumber)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        Text(scene.heading)
                            .font(.system(size: 16, weight: .medium))
                    }

                    if !scene.synopsis.isEmpty {
                        Text(scene.synopsis)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    // Scene stats
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.left")
                                .font(.caption2)
                            Text("\(scene.dialogues.count)")
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)

                        HStack(spacing: 4) {
                            Image(systemName: "figure.walk")
                                .font(.caption2)
                            Text("\(scene.actions.count)")
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)

                        if !scene.shots.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "camera")
                                    .font(.caption2)
                                Text("\(scene.shots.count)")
                                    .font(.caption2)
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty State

struct EmptySceneListView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "film.stack")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Scenes")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Scenes will appear here as you create them")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Preview

#Preview {
    ScenesListView()
        .environmentObject(AppCoordinator())
        .environmentObject(ProjectViewModel())
}

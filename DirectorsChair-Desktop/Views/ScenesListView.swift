//
//  ScenesListView.swift
//  DirectorsChair-Desktop
//
//  Phase 8E: Project Management
//  Scene list with filtering, search, and connections
//

import SwiftUI
import DirectorsChairCore
import DirectorsChairViews

// MARK: - Scene Tab

enum SceneViewTab: String, CaseIterable {
    case scenes = "Scenes"
    case connections = "Connections"

    var icon: String {
        switch self {
        case .scenes: return "film.stack"
        case .connections: return "link"
        }
    }
}

struct ScenesListView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var projectViewModel: ProjectViewModel

    @State private var searchText = ""
    @State private var selectedSequenceFilter: String? = nil

    /// Scene tab state bridged to coordinator for navigation history
    private var selectedTab: SceneViewTab {
        get { SceneViewTab(rawValue: coordinator.selectedSceneTab) ?? .scenes }
        nonmutating set { coordinator.selectedSceneTab = newValue.rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab Picker
            tabPicker

            Divider()

            // Tab Content
            switch selectedTab {
            case .scenes:
                scenesListContent
            case .connections:
                connectionsContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack {
            ForEach(SceneViewTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                        Text(tab.rawValue)
                    }
                    .font(.subheadline)
                    .fontWeight(selectedTab == tab ? .semibold : .regular)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(selectedTab == tab ? Color.accentColor.opacity(0.1) : Color.clear)
                    .foregroundColor(selectedTab == tab ? .accentColor : .primary)
                }
                .buttonStyle(.plain)
                .overlay(alignment: .bottom) {
                    if selectedTab == tab {
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(height: 2)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Scenes List Content

    private var scenesListContent: some View {
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
    }

    // MARK: - Connections Content

    private var connectionsContent: some View {
        VStack(spacing: 0) {
            // Connection view - uses coordinator.selectedScene from navigator panel
            if let scene = coordinator.selectedScene {
                SceneConnectionView(
                    dialogues: scene.dialogues,
                    actions: scene.actions,
                    narrations: scene.narrations,
                    shots: scene.shots,
                    characters: projectViewModel.characters,
                    projectBasePath: projectViewModel.projectPath?.deletingLastPathComponent(),
                    onShotsChanged: { updatedShots in
                        updateShotsForScene(scene, updatedShots: updatedShots)
                    },
                    onShotDoubleClicked: { shot in
                        coordinator.selectShot(shot)
                    },
                    onScriptItemDoubleClicked: { scriptItem in
                        coordinator.selectScene(scene)
                        coordinator.highlightBubbleItem(
                            id: scriptItem.id,
                            type: scriptItem.itemType.rawValue.lowercased(),
                            sceneName: scene.name
                        )
                        coordinator.navigateTo(.bubble)
                    }
                )
            } else {
                // Prompt to select a scene from navigator
                VStack(spacing: 16) {
                    Image(systemName: "link.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("Select a Scene")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Select a scene from the Navigator panel to manage shot connections")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
        .onAppear {
            // Auto-select first scene if none selected
            if coordinator.selectedScene == nil {
                coordinator.selectedScene = projectViewModel.allScenes.first
            }
        }
    }

    // MARK: - Helpers

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
                scene.description.localizedCaseInsensitiveContains(searchText) ||
                scene.notes.localizedCaseInsensitiveContains(searchText)
            }
        }

        return scenes
    }

    private func updateShotsForScene(_ scene: DirectorsChairCore.Scene, updatedShots: [Shot]) {
        // Find and update the scene in the project
        for seqIndex in projectViewModel.project.sequences.indices {
            if let sceneIndex = projectViewModel.project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id }) {
                projectViewModel.project.sequences[seqIndex].scenes[sceneIndex].shots = updatedShots
                projectViewModel.isDirty = true

                // Update the coordinator's selected scene reference
                coordinator.selectedScene = projectViewModel.project.sequences[seqIndex].scenes[sceneIndex]

                // Notify other views
                coordinator.notifyProjectChanged()
                return
            }
        }
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
                        Text(scene.name)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        Text(scene.description)
                            .font(.system(size: 16, weight: .medium))
                    }

                    if !scene.notes.isEmpty {
                        Text(scene.notes)
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

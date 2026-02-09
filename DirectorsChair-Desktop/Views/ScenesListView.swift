//
//  ScenesListView.swift
//  DirectorsChair-Desktop
//
//  Phase 8E: Project Management
//  Scene card grid with detail page and connections
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
    @State private var detailScene: DirectorsChairCore.Scene? = nil

    /// Scene tab state bridged to coordinator for navigation history
    private var selectedTab: SceneViewTab {
        get { SceneViewTab(rawValue: coordinator.selectedSceneTab) ?? .scenes }
        nonmutating set { coordinator.selectedSceneTab = newValue.rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Only show tab picker when not in detail view
            if detailScene == nil {
                tabPicker
                Divider()
            }

            // Tab Content
            switch selectedTab {
            case .scenes:
                if let scene = detailScene {
                    SceneDetailView(
                        scene: scene,
                        characters: projectViewModel.characters,
                        projectBasePath: projectViewModel.projectPath?.deletingLastPathComponent(),
                        onBack: { detailScene = nil },
                        onOpenBubble: { s in
                            coordinator.selectScene(s)
                            coordinator.navigateTo(.bubble)
                        },
                        onOpenShotList: { s in
                            coordinator.selectScene(s)
                            coordinator.navigateTo(.shotList)
                        },
                        onImageGenerated: { relativePath in
                            updateSceneOverviewImage(scene, relativePath: relativePath)
                        },
                        onPromptUsed: { prompt in
                            updateSceneOverviewPrompt(scene, prompt: prompt)
                        }
                    )
                } else {
                    scenesGridContent
                }
            case .connections:
                connectionsContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
        .onChange(of: coordinator.selectedScene) { _, newScene in
            // Sync detail view when scene selected from navigator
            if let newScene = newScene, selectedTab == .scenes {
                detailScene = newScene
            }
        }
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

    // MARK: - Scenes Grid Content

    private var scenesGridContent: some View {
        VStack(spacing: 0) {
            // Toolbar
            ScenesToolbar(
                searchText: $searchText,
                selectedSequenceFilter: $selectedSequenceFilter,
                sequences: projectViewModel.sequences
            )

            Divider()

            // Scene Card Grid
            if filteredScenes.isEmpty {
                EmptySceneListView()
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 300), spacing: 16)],
                        spacing: 16
                    ) {
                        ForEach(filteredScenes) { scene in
                            SceneCardView(
                                scene: scene,
                                characters: projectViewModel.characters,
                                projectBasePath: projectViewModel.projectPath?.deletingLastPathComponent(),
                                onImageGenerated: { relativePath in
                                    updateSceneOverviewImage(scene, relativePath: relativePath)
                                },
                                onPromptUsed: { prompt in
                                    updateSceneOverviewPrompt(scene, prompt: prompt)
                                }
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                detailScene = scene
                                coordinator.selectScene(scene)
                            }
                        }
                    }
                    .padding(16)
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
                .id(scene.id)
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

    private func updateSceneOverviewImage(_ scene: DirectorsChairCore.Scene, relativePath: String) {
        for seqIndex in projectViewModel.project.sequences.indices {
            if let sceneIndex = projectViewModel.project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id }) {
                projectViewModel.project.sequences[seqIndex].scenes[sceneIndex].sceneOverviewImage = relativePath
                projectViewModel.isDirty = true

                // Update coordinator's scene reference so detail view also sees it
                coordinator.selectedScene = projectViewModel.project.sequences[seqIndex].scenes[sceneIndex]
                coordinator.notifyProjectChanged()

                // Force save to ensure persistence across navigation
                Task { await projectViewModel.forceSave() }
                return
            }
        }
    }

    private func updateSceneOverviewPrompt(_ scene: DirectorsChairCore.Scene, prompt: String) {
        for seqIndex in projectViewModel.project.sequences.indices {
            if let sceneIndex = projectViewModel.project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id }) {
                projectViewModel.project.sequences[seqIndex].scenes[sceneIndex].sceneOverviewPrompt = prompt
                projectViewModel.isDirty = true
                Task { await projectViewModel.forceSave() }
                return
            }
        }
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

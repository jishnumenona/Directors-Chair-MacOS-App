//
//  OutlineTab.swift
//  DirectorsChair-Desktop
//
//  Phase 8B: Navigation & Sidebar
//  Hierarchical outline of sequences, scenes, and shots
//

import SwiftUI
import DirectorsChairCore

struct OutlineTab: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var projectViewModel: ProjectViewModel

    var body: some View {
        ScrollView {
            if projectViewModel.hasProject {
                if projectViewModel.sequences.isEmpty {
                    EmptyOutlineView()
                } else {
                    OutlineList()
                }
            } else {
                NoProjectView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Outline List

struct OutlineList: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @State private var isAddingSequence = false
    @State private var newSequenceName = ""
    @FocusState private var isSequenceFieldFocused: Bool

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 4) {
            ForEach(projectViewModel.sequences) { sequence in
                SequenceRow(sequence: sequence)
            }

            // Inline add sequence row
            if isAddingSequence {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                        .frame(width: 12)

                    Image(systemName: "film.stack")
                        .foregroundColor(.blue.opacity(0.5))

                    TextField("Sequence name", text: $newSequenceName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .medium))
                        .focused($isSequenceFieldFocused)
                        .onSubmit {
                            commitNewSequence()
                        }
                        .onExitCommand {
                            cancelAddSequence()
                        }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.08))
                .cornerRadius(6)
            } else {
                Button(action: {
                    isAddingSequence = true
                    newSequenceName = ""
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isSequenceFieldFocused = true
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.caption)
                            .frame(width: 12)

                        Text("New Sequence")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }

    private func commitNewSequence() {
        let name = newSequenceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            cancelAddSequence()
            return
        }

        let newSequence = DirectorsChairCore.Sequence(name: name)
        projectViewModel.addSequence(newSequence)
        coordinator.selectSequence(newSequence)
        coordinator.notifyProjectChanged()

        isAddingSequence = false
        newSequenceName = ""
    }

    private func cancelAddSequence() {
        isAddingSequence = false
        newSequenceName = ""
    }
}

// MARK: - Sequence Row

struct SequenceRow: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var projectViewModel: ProjectViewModel
    let sequence: DirectorsChairCore.Sequence
    @State private var isExpanded = true
    @State private var isAddingScene = false
    @State private var newSceneName = ""
    @State private var showDeleteConfirmation = false
    @FocusState private var isSceneFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Sequence Header
            Button(action: {
                coordinator.selectSequence(sequence)
            }) {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .frame(width: 12)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isExpanded.toggle()
                            }
                        }

                    Image(systemName: "film.stack")
                        .foregroundColor(.blue)

                    Text(sequence.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)

                    Spacer()

                    Text("\(sequence.scenes.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    coordinator.selectedSequence?.id == sequence.id ?
                    Color.accentColor.opacity(0.15) : Color.clear
                )
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete Sequence", systemImage: "trash")
                }
            }

            // Scenes and inline add (collapsible)
            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(sequence.scenes) { scene in
                        SceneRow(scene: scene, sequenceId: sequence.id)
                    }

                    // Inline add scene row
                    if isAddingScene {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.caption2)
                                .foregroundColor(.accentColor)
                                .frame(width: 10)

                            Image(systemName: "film")
                                .font(.caption)
                                .foregroundColor(.green.opacity(0.5))

                            TextField("Scene name", text: $newSceneName)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12))
                                .focused($isSceneFieldFocused)
                                .onSubmit {
                                    commitNewScene()
                                }
                                .onExitCommand {
                                    cancelAddScene()
                                }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.accentColor.opacity(0.08))
                        .cornerRadius(6)
                    } else {
                        Button(action: {
                            isAddingScene = true
                            newSceneName = ""
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isSceneFieldFocused = true
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.caption2)
                                    .frame(width: 10)

                                Text("New Scene")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, 24)
            }
        }
        .alert("Delete \"\(sequence.name)\"?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if coordinator.selectedSequence?.id == sequence.id {
                    coordinator.clearSelections()
                } else if let selectedScene = coordinator.selectedScene,
                          sequence.scenes.contains(where: { $0.id == selectedScene.id }) {
                    coordinator.clearSelections()
                }
                projectViewModel.removeSequence(sequence)
                coordinator.notifyProjectChanged()
            }
        } message: {
            Text("This will delete all \(sequence.scenes.count) scene(s) inside it. This cannot be undone.")
        }
    }

    private func commitNewScene() {
        let name = newSceneName.trimmingCharacters(in: .whitespacesAndNewlines)
        let sceneIndex = sequence.scenes.count + 1
        let sceneName: String
        if name.isEmpty {
            sceneName = "Scene \(sceneIndex)"
        } else {
            sceneName = "Scene \(sceneIndex) - \(name)"
        }

        let newScene = DirectorsChairCore.Scene(name: sceneName, productionStatus: "Planning")
        projectViewModel.addScene(newScene, toSequenceId: sequence.id)
        coordinator.selectScene(newScene)
        coordinator.notifyProjectChanged()

        isAddingScene = false
        newSceneName = ""
    }

    private func cancelAddScene() {
        isAddingScene = false
        newSceneName = ""
    }
}

// MARK: - Scene Row

struct SceneRow: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var projectViewModel: ProjectViewModel
    let scene: DirectorsChairCore.Scene
    let sequenceId: String
    @State private var isExpanded = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Scene Header
            HStack(spacing: 6) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption2)
                    .frame(width: 10)
                    .opacity(scene.shots.isEmpty ? 0.3 : 1.0)
                    .onTapGesture {
                        if !scene.shots.isEmpty {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isExpanded.toggle()
                            }
                        }
                    }

                Image(systemName: "film")
                    .font(.caption)
                    .foregroundColor(.green)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(scene.name)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)

                        Text(scene.description)
                            .font(.system(size: 12))
                            .lineLimit(1)
                    }

                    if !scene.notes.isEmpty {
                        Text(scene.notes)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if !scene.shots.isEmpty {
                    Text("\(scene.shots.count)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                coordinator.selectedScene?.id == scene.id ?
                Color.accentColor.opacity(0.15) : Color.clear
            )
            .cornerRadius(6)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                coordinator.selectScene(scene)
                coordinator.navigateTo(.bubble)
            }
            .onTapGesture(count: 1) {
                coordinator.selectScene(scene)
            }
            .contextMenu {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete Scene", systemImage: "trash")
                }
            }

            // Shots (collapsible)
            if isExpanded && !scene.shots.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(scene.shots) { shot in
                        ShotRow(shot: shot)
                    }
                }
                .padding(.leading, 20)
            }
        }
        .alert("Delete \"\(scene.name)\"?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if coordinator.selectedScene?.id == scene.id {
                    coordinator.clearSelections()
                }
                projectViewModel.removeScene(scene, fromSequenceId: sequenceId)
                coordinator.notifyProjectChanged()
            }
        } message: {
            Text("This cannot be undone.")
        }
    }
}

// MARK: - Shot Row

struct ShotRow: View {
    @EnvironmentObject var coordinator: AppCoordinator
    let shot: Shot

    var body: some View {
        Button(action: {
            coordinator.selectShot(shot)
        }) {
            HStack(spacing: 6) {
                Image(systemName: "camera.fill")
                    .font(.caption2)
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(String(shot.shotId))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)

                        Text(shot.shotType)
                            .font(.system(size: 11))
                    }

                    if !shot.description.isEmpty {
                        Text(shot.description)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                coordinator.selectedShot?.id == shot.id ?
                Color.accentColor.opacity(0.15) : Color.clear
            )
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty States

struct EmptyOutlineView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var projectViewModel: ProjectViewModel

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "film.stack")
                .font(.system(size: 36))
                .foregroundColor(.secondary)

            Text("No Sequences")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Add sequences to organize your scenes")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: {
                let newSequence = DirectorsChairCore.Sequence(name: "Act 1")
                projectViewModel.addSequence(newSequence)
                coordinator.selectSequence(newSequence)
                coordinator.notifyProjectChanged()
            }) {
                Label("Create Sequence", systemImage: "plus")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

struct NoProjectView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 36))
                .foregroundColor(.secondary)

            Text("No Project")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Open or create a project to begin")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

// MARK: - Preview

#Preview {
    OutlineTab()
        .environmentObject(AppCoordinator())
        .environmentObject(ProjectViewModel())
        .frame(width: 300, height: 600)
}

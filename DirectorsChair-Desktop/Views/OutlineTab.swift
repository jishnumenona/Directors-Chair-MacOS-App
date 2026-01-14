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

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 4) {
            ForEach(projectViewModel.sequences) { sequence in
                SequenceRow(sequence: sequence)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Sequence Row

struct SequenceRow: View {
    @EnvironmentObject var coordinator: AppCoordinator
    let sequence: DirectorsChairCore.Sequence
    @State private var isExpanded = true

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

            // Scenes (collapsible)
            if isExpanded && !sequence.scenes.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(sequence.scenes) { scene in
                        SceneRow(scene: scene)
                    }
                }
                .padding(.leading, 24)
            }
        }
    }
}

// MARK: - Scene Row

struct SceneRow: View {
    @EnvironmentObject var coordinator: AppCoordinator
    let scene: DirectorsChairCore.Scene
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Scene Header
            Button(action: {
                coordinator.selectScene(scene)
            }) {
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
                            Text(scene.sceneNumber)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)

                            Text(scene.heading)
                                .font(.system(size: 12))
                                .lineLimit(1)
                        }

                        if !scene.synopsis.isEmpty {
                            Text(scene.synopsis)
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
            }
            .buttonStyle(.plain)

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
                        Text(shot.shotNumber)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)

                        Text(shot.shotType.rawValue)
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
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "film.stack")
                .font(.system(size: 36))
                .foregroundColor(.secondary)

            Text("No Sequences")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Add sequences to see the outline")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
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

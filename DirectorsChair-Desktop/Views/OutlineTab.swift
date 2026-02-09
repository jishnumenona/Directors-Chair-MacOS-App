//
//  OutlineTab.swift
//  DirectorsChair-Desktop
//
//  Phase 8B: Navigation & Sidebar
//  Hierarchical outline of sequences, scenes, and shots
//

import SwiftUI
import DirectorsChairCore
import DirectorsChairViews

struct OutlineTab: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var timelineViewModel: TimelineViewModel

    var body: some View {
        ScrollView {
            if projectViewModel.hasProject {
                if projectViewModel.sequences.isEmpty {
                    EmptyOutlineView()
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        OutlineList()
                    }
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

    /// Whether this scene contains the currently selected shot
    private var containsSelectedShot: Bool {
        guard let selected = coordinator.selectedShot else { return false }
        return scene.shots.contains(where: { $0.id == selected.id })
    }

    /// Parse location string like "INT. KITCHEN - DAY" into (location, time)
    private var locationParts: (location: String, time: String?) {
        let loc = (scene.location ?? "").uppercased()
        // Strip INT./EXT. prefix
        var stripped = loc
        for prefix in ["INT./EXT. ", "INT/EXT. ", "INT. ", "EXT. ", "INT/EXT ", "INT ", "EXT "] {
            if stripped.hasPrefix(prefix) {
                stripped = String(stripped.dropFirst(prefix.count))
                break
            }
        }
        // Split on " - " to get location and time
        if let dashRange = stripped.range(of: " - ") {
            let place = String(stripped[stripped.startIndex..<dashRange.lowerBound])
            let time = String(stripped[dashRange.upperBound...])
            return (place.capitalized, time.capitalized)
        }
        return (stripped.capitalized, nil)
    }

    /// Build a tooltip with full scene details
    private var sceneTooltip: String {
        var parts: [String] = []
        parts.append(scene.name)
        if let loc = scene.location, !loc.isEmpty {
            parts.append(loc)
        }
        if !scene.description.isEmpty {
            parts.append(scene.description)
        }
        if !scene.notes.isEmpty {
            parts.append("Notes: \(scene.notes)")
        }
        if !scene.shots.isEmpty {
            parts.append("\(scene.shots.count) shot(s)")
        }
        return parts.joined(separator: "\n")
    }

    /// Extract the scene number portion from the name (e.g. "Scene 3" from "Scene 3 - Kitchen")
    private var sceneNumber: String {
        let name = scene.name
        // If name starts with "Scene N", extract that part
        if let range = name.range(of: #"^Scene\s+\d+"#, options: .regularExpression) {
            return String(name[range])
        }
        return name
    }

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
                    Text(sceneNumber)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    HStack(spacing: 3) {
                        Text(locationParts.location)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)

                        if let time = locationParts.time {
                            Text("·")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text(time)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
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
            .help(sceneTooltip)
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
        .onChange(of: coordinator.selectedShot?.id) { _, _ in
            if containsSelectedShot && !isExpanded {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded = true
                }
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

// MARK: - Markers Section

// MARK: - Markers Tab

struct MarkersTab: View {
    @EnvironmentObject var timelineViewModel: TimelineViewModel
    @State private var editingMarkerId: UUID? = nil
    @State private var editLabel: String = ""
    @State private var editIcon: String = "flag.fill"
    @State private var editColor: String = "#FF5F5F"

    private let iconOptions = ["flag.fill", "star.fill", "bolt.fill", "lightbulb.fill",
                               "camera.fill", "music.note", "exclamationmark.triangle.fill",
                               "bookmark.fill", "mappin", "heart.fill", "bell.fill", "tag.fill"]
    private let colorOptions = ["#FF5F5F", "#FF9500", "#FFDF5F", "#34C759",
                                "#4A8FBF", "#9966CC", "#FF6B9D"]

    var body: some View {
        if timelineViewModel.userMarkers.isEmpty {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "flag")
                    .font(.system(size: 28))
                    .foregroundColor(.secondary)
                Text("No Markers")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                Text("Right-click the timeline ruler to add a marker.")
                    .font(.system(size: 11))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding()
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(timelineViewModel.userMarkers.sorted(by: { $0.time < $1.time })) { marker in
                        MarkerRow(marker: marker) {
                            timelineViewModel.scrollToTime(marker.time)
                        }
                        .contextMenu {
                            Button {
                                editingMarkerId = marker.id
                                editLabel = marker.label
                                editIcon = marker.icon
                                editColor = marker.color
                            } label: {
                                Label("Edit Marker...", systemImage: "pencil")
                            }
                            Divider()
                            Button(role: .destructive) {
                                timelineViewModel.deleteUserMarker(id: marker.id)
                            } label: {
                                Label("Delete Marker", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .popover(item: $editingMarkerId) { markerId in
                MarkerEditPanel(
                    label: $editLabel,
                    icon: $editIcon,
                    color: $editColor,
                    iconOptions: iconOptions,
                    colorOptions: colorOptions,
                    onSave: {
                        timelineViewModel.updateUserMarker(id: markerId, label: editLabel, icon: editIcon, color: editColor)
                        editingMarkerId = nil
                    },
                    onCancel: {
                        editingMarkerId = nil
                    }
                )
            }
        }
    }
}

// Make UUID work with .popover(item:)
extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
}

private struct MarkerEditPanel: View {
    @Binding var label: String
    @Binding var icon: String
    @Binding var color: String
    let iconOptions: [String]
    let colorOptions: [String]
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Edit Marker")
                .font(.system(size: 13, weight: .semibold))

            TextField("Name", text: $label)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))

            // Icon picker
            Text("Icon")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(28), spacing: 4), count: 6), spacing: 4) {
                ForEach(iconOptions, id: \.self) { iconName in
                    Button {
                        icon = iconName
                    } label: {
                        Image(systemName: iconName)
                            .font(.system(size: 12))
                            .frame(width: 24, height: 24)
                            .background(icon == iconName ? Color.accentColor.opacity(0.3) : Color.clear)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Color picker
            Text("Color")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            HStack(spacing: 6) {
                ForEach(colorOptions, id: \.self) { hex in
                    Button {
                        color = hex
                    } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 18, height: 18)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: color == hex ? 2 : 0)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save", action: onSave)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 240)
    }
}

struct MarkerRow: View {
    let marker: TimelineMarker
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: marker.icon)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: marker.color))
                    .frame(width: 16, height: 16)

                VStack(alignment: .leading, spacing: 1) {
                    Text(marker.label)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)

                    Text(formatMarkerTime(marker.time))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Circle()
                    .fill(Color(hex: marker.color))
                    .frame(width: 8, height: 8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func formatMarkerTime(_ t: CGFloat) -> String {
        let totalSec = Int(t)
        let minutes = totalSec / 60
        let secs = totalSec % 60
        let frac = Int((t - CGFloat(totalSec)) * 10)
        return String(format: "%02d:%02d.%d", minutes, secs, frac)
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
        .environmentObject(TimelineViewModel())
        .frame(width: 300, height: 600)
}

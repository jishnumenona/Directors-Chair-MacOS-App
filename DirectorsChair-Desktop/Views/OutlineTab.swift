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
    @State private var refreshToken = UUID()

    /// Expansion state lives here so it survives .id(refreshToken) recreation.
    /// Sequences default to expanded, so we track which are collapsed.
    @State private var collapsedSequenceIds: Set<String> = []
    /// Scenes default to collapsed, so we track which are expanded.
    @State private var expandedSceneIds: Set<String> = []

    var body: some View {
        ScrollView {
            if projectViewModel.hasProject {
                if projectViewModel.sequences.isEmpty {
                    EmptyOutlineView()
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        OutlineList(
                            collapsedSequenceIds: $collapsedSequenceIds,
                            expandedSceneIds: $expandedSceneIds
                        )
                    }
                    .id(refreshToken)
                }
            } else {
                NoProjectView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(coordinator.projectEvents) { event in
            guard event != .production else { return }
            debugLog("📋 OutlineTab: projectChanged received, sequences=\(projectViewModel.project.sequences.count), scenes=\(projectViewModel.project.sequences.flatMap(\.scenes).count)")
            PerfCounters.shared.increment("event.OutlineTab.teardown")
            refreshToken = UUID()
        }
        .onChange(of: coordinator.selectedShot?.id) { _, _ in
            // Auto-expand the scene containing the selected shot
            guard let selectedShot = coordinator.selectedShot else { return }
            for sequence in projectViewModel.sequences {
                for scene in sequence.scenes {
                    if scene.shots.contains(where: { $0.id == selectedShot.id }) {
                        collapsedSequenceIds.remove(sequence.id)
                        expandedSceneIds.insert(scene.id)
                        return
                    }
                }
            }
        }
    }
}

// MARK: - Outline List

struct OutlineList: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @Binding var collapsedSequenceIds: Set<String>
    @Binding var expandedSceneIds: Set<String>
    @State private var isAddingSequence = false
    @State private var newSequenceName = ""
    @FocusState private var isSequenceFieldFocused: Bool

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 4) {
            ForEach(projectViewModel.sequences) { sequence in
                SequenceRow(
                    sequence: sequence,
                    collapsedSequenceIds: $collapsedSequenceIds,
                    expandedSceneIds: $expandedSceneIds
                )
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
    @EnvironmentObject var timelineViewModel: TimelineViewModel
    let sequence: DirectorsChairCore.Sequence
    @Binding var collapsedSequenceIds: Set<String>
    @Binding var expandedSceneIds: Set<String>
    @State private var isAddingScene = false
    @State private var newSceneName = ""
    @State private var showDeleteConfirmation = false
    @FocusState private var isSceneFieldFocused: Bool

    private var isExpanded: Bool { !collapsedSequenceIds.contains(sequence.id) }

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
                                if isExpanded {
                                    collapsedSequenceIds.insert(sequence.id)
                                } else {
                                    collapsedSequenceIds.remove(sequence.id)
                                }
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
            .accessibilityIdentifier("sequence-row-\(sequence.id)")
            .contextMenu {
                Button {
                    // Find the first scene in this sequence and seek to its boundary
                    if let firstScene = sequence.scenes.first,
                       let boundary = timelineViewModel.sceneBoundaries.first(where: { $0.name == firstScene.name }) {
                        timelineViewModel.playheadActive = true
                        timelineViewModel.playheadTime = boundary.time
                        timelineViewModel.onPlayheadSeeked?(boundary.time)
                        timelineViewModel.scrollToTime(boundary.time)
                    }
                } label: {
                    Label("Move Playhead Here", systemImage: "timeline.selection")
                }

                Button {
                    coordinator.requestTimelineAnalysis(scope: .sequence(sequence))
                } label: {
                    Label("Analyze Timeline...", systemImage: "wand.and.stars")
                }

                Divider()

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
                        SceneRow(scene: scene, sequenceId: sequence.id, expandedSceneIds: $expandedSceneIds)
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
        let sceneIndex = projectViewModel.project.sequences.flatMap(\.scenes).count + 1
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
    @EnvironmentObject var timelineViewModel: TimelineViewModel
    let scene: DirectorsChairCore.Scene
    let sequenceId: String
    @Binding var expandedSceneIds: Set<String>
    @State private var showDeleteConfirmation = false
    @State private var isAddingShot = false
    @State private var newShotName = ""
    @State private var isRenaming = false
    @State private var renameText = ""
    @FocusState private var isShotFieldFocused: Bool
    @FocusState private var isRenameFieldFocused: Bool

    private var isExpanded: Bool { expandedSceneIds.contains(scene.id) }

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

    /// Extract the descriptive suffix from the scene name (e.g. "Kitchen" from "Scene 3 - Kitchen")
    private var sceneNameSuffix: String? {
        let name = scene.name
        if let dashRange = name.range(of: " - ") {
            let suffix = String(name[dashRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            return suffix.isEmpty ? nil : suffix
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Scene Header
            if isRenaming {
                HStack(spacing: 6) {
                    Image(systemName: "film")
                        .font(.caption)
                        .foregroundColor(.green)

                    TextField("Scene name", text: $renameText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .focused($isRenameFieldFocused)
                        .onSubmit {
                            commitRename()
                        }
                        .onExitCommand {
                            cancelRename()
                        }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.accentColor.opacity(0.08))
                .cornerRadius(6)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .frame(width: 10)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if isExpanded {
                                    expandedSceneIds.remove(scene.id)
                                } else {
                                    expandedSceneIds.insert(scene.id)
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

                        if !locationParts.location.isEmpty {
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
                        } else if let suffix = sceneNameSuffix {
                            Text(suffix)
                                .font(.system(size: 12, weight: .medium))
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
                .help(sceneTooltip)
                .accessibilityIdentifier("scene-row-\(scene.id)")
                .onTapGesture(count: 2) {
                    coordinator.selectScene(scene)
                    if NSEvent.modifierFlags.contains(.command) {
                        coordinator.navigateTo(.bubble)
                    } else {
                        coordinator.navigateTo(.scenes)
                    }
                }
                .onTapGesture(count: 1) {
                    coordinator.selectScene(scene)
                }
                .contextMenu {
                    Button {
                        renameText = scene.name
                        isRenaming = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isRenameFieldFocused = true
                        }
                    } label: {
                        Label("Rename Scene", systemImage: "pencil")
                    }

                    Divider()

                    Button {
                        if let boundary = timelineViewModel.sceneBoundaries.first(where: { $0.name == scene.name }) {
                            timelineViewModel.playheadActive = true
                            timelineViewModel.playheadTime = boundary.time
                            timelineViewModel.onPlayheadSeeked?(boundary.time)
                            timelineViewModel.scrollToTime(boundary.time)
                        }
                    } label: {
                        Label("Move Playhead Here", systemImage: "timeline.selection")
                    }

                    Button {
                        if let seqIdx = projectViewModel.project.sequences.firstIndex(where: { $0.id == sequenceId }),
                           let scnIdx = projectViewModel.project.sequences[seqIdx].scenes.firstIndex(where: { $0.id == scene.id }) {
                            coordinator.requestTimelineAnalysis(scope: .scene(scene, sequenceIndex: seqIdx, sceneIndex: scnIdx))
                        }
                    } label: {
                        Label("Analyze Timeline...", systemImage: "wand.and.stars")
                    }

                    Divider()

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Scene", systemImage: "trash")
                    }
                }
            }

            // Shots (collapsible)
            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(scene.shots) { shot in
                        ShotRow(shot: shot, sceneId: scene.id, sequenceId: sequenceId)
                    }

                    // New Shot inline add
                    if isAddingShot {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.caption2)
                                .foregroundColor(.accentColor)
                                .frame(width: 10)
                            Image(systemName: "camera")
                                .font(.caption2)
                                .foregroundColor(.purple.opacity(0.5))
                            TextField("Shot description", text: $newShotName)
                                .textFieldStyle(.plain)
                                .font(.system(size: 11, weight: .medium))
                                .focused($isShotFieldFocused)
                                .onSubmit { commitNewShot() }
                                .onExitCommand { cancelAddShot() }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.08))
                        .cornerRadius(6)
                    } else {
                        Button(action: {
                            isAddingShot = true
                            newShotName = ""
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isShotFieldFocused = true
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.caption2)
                                    .frame(width: 10)
                                Text("New Shot")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
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

    private func commitNewShot() {
        let desc = newShotName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !desc.isEmpty else {
            cancelAddShot()
            return
        }
        let nextId = projectViewModel.project.nextShotDisplayNumber
        let newShot = Shot(shotId: nextId, description: desc)
        projectViewModel.addShot(newShot, toSceneId: scene.id, inSequenceId: sequenceId)
        coordinator.selectShot(newShot)
        coordinator.notifyProjectChanged()
        isAddingShot = false
        newShotName = ""
        // Auto-expand to show the new shot
        expandedSceneIds.insert(scene.id)
    }

    private func cancelAddShot() {
        isAddingShot = false
        newShotName = ""
    }

    private func commitRename() {
        let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            cancelRename()
            return
        }
        projectViewModel.renameScene(scene.id, inSequenceId: sequenceId, newName: name)
        coordinator.notifyProjectChanged()
        isRenaming = false
        renameText = ""
    }

    private func cancelRename() {
        isRenaming = false
        renameText = ""
    }
}

// MARK: - Shot Row

struct ShotRow: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var timelineViewModel: TimelineViewModel
    let shot: Shot
    let sceneId: String
    let sequenceId: String
    @State private var showDeleteConfirmation = false

    /// Resolve the shot's status string to a ShotStatus enum for icon/color
    private var shotStatus: ShotStatus {
        ShotStatus(rawValue: shot.status) ?? .planning
    }

    var body: some View {
        Button(action: {
            coordinator.selectShot(shot)
        }) {
            HStack(spacing: 6) {
                Image(systemName: shotStatus.systemImage)
                    .font(.caption2)
                    .foregroundColor(shotStatus.color)

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

                if shot.videoPath != nil {
                    Image(systemName: "video.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.purple.opacity(0.7))
                } else if shot.previewImage != nil {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.green.opacity(0.7))
                }
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
        .accessibilityIdentifier("shot-row-\(shot.id)")
        .contextMenu {
            Button {
                if let shotLabel = timelineViewModel.shotLabels.first(where: { $0.shotId == shot.shotId }) {
                    timelineViewModel.playheadActive = true
                    timelineViewModel.playheadTime = shotLabel.time
                    timelineViewModel.onPlayheadSeeked?(shotLabel.time)
                    timelineViewModel.scrollToTime(shotLabel.time)
                }
            } label: {
                Label("Move Playhead Here", systemImage: "timeline.selection")
            }

            Button {
                // Find the scene containing this shot
                for (seqIdx, sequence) in projectViewModel.project.sequences.enumerated() {
                    for (scnIdx, scene) in sequence.scenes.enumerated() {
                        if scene.shots.contains(where: { $0.id == shot.id }) {
                            coordinator.requestTimelineAnalysis(scope: .shot(shot, scene: scene, sequenceIndex: seqIdx, sceneIndex: scnIdx))
                            return
                        }
                    }
                }
            } label: {
                Label("Analyze Timeline...", systemImage: "wand.and.stars")
            }

            Divider()

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete Shot", systemImage: "trash")
            }
        }
        .alert("Delete Shot \(shot.shotId)?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if coordinator.selectedShot?.id == shot.id {
                    coordinator.selectedShot = nil
                }
                projectViewModel.removeShot(shot, fromSceneId: sceneId, inSequenceId: sequenceId)
                coordinator.notifyProjectChanged()
            }
        } message: {
            Text("This cannot be undone.")
        }
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

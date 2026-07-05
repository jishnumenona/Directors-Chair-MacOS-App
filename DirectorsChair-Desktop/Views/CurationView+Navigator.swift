//
// CurationView+Navigator.swift
//
// Extracted from CurationView.swift (WS9.1 god-file decomposition).
// Members moved verbatim into an extension; private -> internal.
//

import SwiftUI
import AVKit
import DirectorsChairCore
import DirectorsChairViews

extension CurationView {

    // MARK: - Navigator Panel

    var navigatorPanel: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                // Title
                HStack(spacing: 8) {
                    Image(systemName: "film.stack.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.accentColor)
                    Text("FOOTAGE")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.2)
                        .foregroundColor(.white.opacity(0.9))

                    Spacer()

                    // Stats
                    let totalTakes = project.sequences.flatMap { $0.scenes }.flatMap { $0.shots }.flatMap { $0.takes }.count
                    let circled = project.sequences.flatMap { $0.scenes }.flatMap { $0.shots }.flatMap { $0.takes }.filter { $0.rating == .circle }.count
                    if totalTakes > 0 {
                        HStack(spacing: 8) {
                            Text("\(totalTakes)")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("takes")
                                .font(.system(size: 9))
                                .foregroundColor(.gray)

                            if circled > 0 {
                                HStack(spacing: 3) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 8))
                                        .foregroundColor(.green)
                                    Text("\(circled)")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                }

                // Search
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10))
                        .foregroundColor(.gray.opacity(0.5))
                    TextField("Search takes, notes, tags...", text: $viewModel.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color(hex: "#252525"))
                .cornerRadius(8)

                // Rating filter + Compare toggle
                HStack(spacing: 5) {
                    filterPill(nil, label: "All", icon: "film.stack")
                    filterPill(.circle, label: "Circle", icon: "checkmark.circle.fill")
                    filterPill(.alt, label: "Alt", icon: "arrow.triangle.branch")
                    filterPill(.ng, label: "NG", icon: "xmark.circle.fill")

                    Spacer(minLength: 4)

                    // Compare mode toggle
                    Button {
                        isCompareMode.toggle()
                        if isCompareMode {
                            // Auto-populate left side with current selection
                            compareLeftTake = viewModel.selectedTake
                            compareLeftShot = viewModel.selectedShot
                            compareLeftScene = viewModel.selectedScene
                            setupComparePlayer(side: .left)
                        } else {
                            tearDownComparePlayers()
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "square.split.2x1.fill")
                                .font(.system(size: 8))
                            Text("Compare")
                                .font(.system(size: 8, weight: isCompareMode ? .semibold : .medium))
                                .lineLimit(1)
                                .fixedSize()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .foregroundColor(isCompareMode ? .white : .gray)
                        .background(Capsule().fill(isCompareMode ? Color.accentColor : Color(hex: "#3A3A3A")))
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                }
            }
            .padding(14)

            Divider().opacity(0.3)

            // Scene tree
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 1) {
                        let scenes = viewModel.filteredScenes(from: project)

                        if scenes.isEmpty {
                            emptyNavigator
                        } else {
                            ForEach(scenes, id: \.name) { scene in
                                sceneSection(scene)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
                .onChange(of: viewModel.selectedTake?.id) { _, newId in
                    if let id = newId {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
                .onAppear {
                    if let id = viewModel.selectedTake?.id {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(id, anchor: .center)
                            }
                        }
                    }
                }
            }

            Divider().opacity(0.3)

            // Action bar
            actionBar
        }
        .background(Color(hex: "#1E1E1E"))
    }

    // MARK: - Filter Pill

    func filterPill(_ rating: TakeRating?, label: String, icon: String) -> some View {
        let isSelected = viewModel.filterRating == rating

        return Button { viewModel.filterRating = rating } label: {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 8))
                Text(label)
                    .font(.system(size: 8, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .foregroundColor(isSelected ? .white : rating != nil ? ratingColor(rating!) : .gray)
            .background(
                Capsule()
                    .fill(isSelected ? (rating != nil ? ratingColor(rating!) : Color.accentColor) : Color(hex: "#3A3A3A"))
            )
        }
        .buttonStyle(.plain)
        .fixedSize()
    }

    // MARK: - Scene Tree

    func sceneSection(_ scene: DCScene) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Scene header
            HStack(spacing: 8) {
                Image(systemName: "film.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.accentColor)

                Text(scene.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                let tc = scene.shots.flatMap(\.takes).count
                let cc = scene.shots.flatMap(\.takes).filter { $0.rating == .circle }.count
                HStack(spacing: 6) {
                    Text("\(tc)")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(.gray)
                    if cc > 0 {
                        HStack(spacing: 2) {
                            Circle().fill(Color.green).frame(width: 4, height: 4)
                            Text("\(cc)")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.green.opacity(0.7))
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(hex: "#252525"))

            // Shots
            ForEach(scene.shots, id: \.shotId) { shot in
                shotSection(shot, in: scene)
            }
        }
    }

    func shotSection(_ shot: Shot, in scene: DCScene) -> some View {
        let status = ShotStatus(rawValue: shot.status) ?? .planning

        return VStack(alignment: .leading, spacing: 0) {
            // Shot row — double-click to navigate to shot in Shot List
            HStack(spacing: 6) {
                Image(systemName: status.systemImage)
                    .font(.system(size: 8))
                    .foregroundColor(status.color.opacity(0.7))

                Text("Shot #\(shot.shotId)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))

                if !shot.description.isEmpty {
                    Text("— \(shot.description)")
                        .font(.system(size: 9))
                        .foregroundColor(.gray.opacity(0.5))
                        .lineLimit(1)
                }

                Spacer()

                // Status pill
                Text(status.rawValue)
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundColor(status.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(status.color.opacity(0.15)))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                coordinator.selectScene(scene)
                coordinator.selectShot(shot)
                coordinator.navigateTo(.shotList)
            }
            .onTapGesture(count: 1) {
                // Single-click selects the shot in the curation sidebar
                viewModel.selectedShot = shot
                viewModel.selectedScene = scene
                // Select the first take if available, otherwise clear
                if let firstTake = shot.takes.sorted(by: { $0.takeNumber < $1.takeNumber }).first {
                    viewModel.selectedTake = firstTake
                } else {
                    viewModel.selectedTake = nil
                }
            }

            // Takes (sorted + filtered)
            let sortedTakes = viewModel.sortedTakes(shot.takes)
            let displayTakes = viewModel.showOnlyUnmatched
                ? sortedTakes.filter { $0.capturedVideoPath != nil && $0.cameraSourceFileName == nil }
                : sortedTakes
            ForEach(displayTakes) { take in
                takeNavigatorRow(take, shot: shot, scene: scene)
                    .id(take.id)
            }
        }
    }

    func takeNavigatorRow(_ take: Take, shot: Shot, scene: DCScene) -> some View {
        let isSelected = viewModel.selectedTake?.id == take.id

        return Button {
            viewModel.selectedTake = take
            viewModel.selectedShot = shot
            viewModel.selectedScene = scene
        } label: {
            HStack(spacing: 8) {
                // Rating color dot
                Circle()
                    .fill(ratingColor(take.rating))
                    .frame(width: 6, height: 6)

                // Take number
                Text("T\(take.takeNumber)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(isSelected ? .white : .gray)

                // Rating label
                Text(take.rating.rawValue)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(ratingColor(take.rating).opacity(isSelected ? 1 : 0.7))

                Spacer()

                // Compact timestamp for matching
                if let ts = take.startTimestamp {
                    Text(Self.curationCompactTimeFormatter.string(from: ts))
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(.accentColor.opacity(0.5))
                        .monospacedDigit()
                }

                // Duration
                if let dur = take.durationSeconds {
                    Text(viewModel.formatDuration(dur))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.gray.opacity(0.5))
                        .monospacedDigit()
                }

                // Connection status icons (compact)
                let navVideoColor: Color = {
                    if take.cameraSourceFileName != nil { return .green }
                    if take.hasCameraMetadata { return .yellow }
                    if !viewModel.cameraFiles.isEmpty { return .red }
                    if take.capturedVideoPath != nil { return .gray }
                    return .clear
                }()
                if navVideoColor != .clear {
                    Image(systemName: take.cameraSourceFileName != nil ? "video.fill" : "film.fill")
                        .font(.system(size: 7))
                        .foregroundColor(navVideoColor.opacity(0.6))
                }

                let navAudioColor: Color = {
                    if take.externalAudioFileName != nil { return .green }
                    if !viewModel.audioFiles.isEmpty { return .red }
                    return .clear
                }()
                if navAudioColor != .clear {
                    Image(systemName: "waveform")
                        .font(.system(size: 7))
                        .foregroundColor(navAudioColor.opacity(0.6))
                }

                let navSyncColor: Color = {
                    if take.isAudioVideoSynced == true { return .green }
                    if take.isAudioVideoSynced == false { return .red }
                    if take.cameraSourceFileName != nil && take.externalAudioFileName != nil { return .yellow }
                    return .clear
                }()
                if navSyncColor != .clear {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 7))
                        .foregroundColor(navSyncColor.opacity(0.6))
                }

                // Notes indicator
                if !take.notes.isEmpty {
                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 7))
                        .foregroundColor(.gray.opacity(0.3))
                }
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 5)
            .background(
                isSelected ? Color.accentColor.opacity(0.15) : Color.clear
            )
            .overlay(
                Rectangle()
                    .fill(isSelected ? Color.accentColor : Color.clear)
                    .frame(width: 2),
                alignment: .leading
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            // Compare mode: Choose as Take B
            if isCompareMode {
                Button {
                    setCompareTake(side: .right, take: take, shot: shot, scene: scene)
                } label: {
                    Label("Choose as Take B", systemImage: "b.square.fill")
                }

                Button {
                    setCompareTake(side: .left, take: take, shot: shot, scene: scene)
                } label: {
                    Label("Choose as Take A", systemImage: "a.square.fill")
                }

                Divider()
            }

            // Quick rating
            Button {
                updateTake(take, in: shot) { $0.rating = $0.rating == .circle ? .none : .circle }
            } label: {
                Label(take.rating == .circle ? "Remove Circle" : "Circle", systemImage: "checkmark.circle.fill")
            }
            Button {
                updateTake(take, in: shot) { $0.rating = $0.rating == .alt ? .none : .alt }
            } label: {
                Label(take.rating == .alt ? "Remove Alt" : "Alt", systemImage: "arrow.triangle.branch")
            }
            Button {
                updateTake(take, in: shot) { $0.rating = $0.rating == .ng ? .none : .ng }
            } label: {
                Label(take.rating == .ng ? "Remove NG" : "NG", systemImage: "xmark.circle.fill")
            }

            Divider()

            Button(role: .destructive) {
                deleteTake(take, in: shot)
            } label: {
                Label("Delete Take", systemImage: "trash")
            }
        }
    }

    // MARK: - Empty Navigator

    var emptyNavigator: some View {
        VStack(spacing: 10) {
            Image(systemName: "film.stack")
                .font(.system(size: 32))
                .foregroundColor(.gray.opacity(0.15))
            Text("No takes found")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray.opacity(0.4))
            Text("Record takes from the Shot List view")
                .font(.system(size: 9))
                .foregroundColor(.gray.opacity(0.25))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Action Bar

    var actionBar: some View {
        VStack(spacing: 8) {
            // Best takes
            Button {
                if let dir = projectDir { viewModel.generateBestTakesFolder(project: project, projectDir: dir) }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 10)).foregroundColor(.green)
                    Text("Generate Best Takes")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Image(systemName: "arrow.right").font(.system(size: 8)).foregroundColor(.gray.opacity(0.3))
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color(hex: "#2A2A2A")).cornerRadius(8)
            }
            .buttonStyle(.plain)

            // Curated structure
            Button {
                if let dir = projectDir { viewModel.generateCuratedStructure(project: project, projectDir: dir) }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "link").font(.system(size: 10)).foregroundColor(.accentColor)
                    Text("Curated Symlinks")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Image(systemName: "arrow.right").font(.system(size: 8)).foregroundColor(.gray.opacity(0.3))
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color(hex: "#2A2A2A")).cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.cameraSourceDirectory == nil)
            .opacity(viewModel.cameraSourceDirectory == nil ? 0.4 : 1)

            // Open in Finder
            Button {
                if let dir = projectDir {
                    let footageDir = dir.appendingPathComponent("footage")
                    try? FileManager.default.createDirectory(at: footageDir, withIntermediateDirectories: true)
                    NSWorkspace.shared.open(footageDir)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill").font(.system(size: 10)).foregroundColor(.secondary)
                    Text("Open Footage Folder")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color(hex: "#2A2A2A")).cornerRadius(8)
            }
            .buttonStyle(.plain)

            if viewModel.isGeneratingLinks {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.6)
                    Text("Generating...").font(.system(size: 9)).foregroundColor(.gray)
                }
            }
        }
        .padding(14)
    }
}

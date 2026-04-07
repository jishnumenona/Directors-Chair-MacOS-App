// CurationView.swift
// DirectorsChair-Desktop
//
// Post-production footage curation — cinematic review interface
// Scene/shot/take hierarchy with inline rating, video preview, camera mapping

import SwiftUI
import AVKit
import DirectorsChairCore
import DirectorsChairViews

// MARK: - Curation Tab Enum

enum CurationTab: String, CaseIterable {
    case curation
    case mapping

    var displayName: String {
        switch self {
        case .curation: return "Curation"
        case .mapping: return "Mapping"
        }
    }

    var icon: String {
        switch self {
        case .curation: return "film.stack.fill"
        case .mapping: return "externaldrive.connected.to.line.below.fill"
        }
    }
}

struct CurationView: View {
    @Binding var project: Project
    let projectDir: URL?
    @StateObject private var viewModel = CurationViewModel()
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var isVideoFullScreen: Bool = false
    @State private var fullScreenVideoURL: URL?
    @State private var selectedTab: CurationTab = .curation

    // Compare mode
    @State private var isCompareMode: Bool = false
    @State private var isCompareFullScreen: Bool = false
    @State private var compareLeftTake: Take?
    @State private var compareLeftShot: Shot?
    @State private var compareLeftScene: DCScene?
    @State private var compareRightTake: Take?
    @State private var compareRightShot: Shot?
    @State private var compareRightScene: DCScene?
    @State private var compareSyncPlayback: Bool = true
    @State private var compareLeftPlayer: AVPlayer?
    @State private var compareRightPlayer: AVPlayer?

    // Clipboard copy feedback
    @State private var copiedMetadataLabel: String?
    @State private var hoveredMetadataLabel: String?

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            curationTabBar

            // Tab content
            ZStack {
                switch selectedTab {
                case .curation:
                    curationTabContent
                case .mapping:
                    mappingTabContent
                }

                // Full-screen compare overlay
                if isCompareFullScreen {
                    fullScreenComparePanel
                        .transition(.opacity)
                        .zIndex(100)
                }
            }
        }
        .background(Color(hex: "#1A1A1A"))
        .sheet(isPresented: $isVideoFullScreen) {
            fullScreenVideoPlayer
                .frame(minWidth: 900, minHeight: 600)
        }
        .onAppear {
            // If navigated here with a specific shot selected (e.g. from Shot List → Curate)
            if let targetShot = coordinator.selectedShot {
                // Find the scene containing this shot
                for sequence in project.sequences {
                    for scene in sequence.scenes {
                        if let match = scene.shots.first(where: { $0.id == targetShot.id }) {
                            viewModel.selectedScene = scene
                            viewModel.selectedShot = match
                            if let firstTake = match.takes.sorted(by: { $0.takeNumber < $1.takeNumber }).first {
                                viewModel.selectedTake = firstTake
                            }
                            coordinator.selectedShot = nil
                            return
                        }
                    }
                }
            }
        }
        .onChange(of: isCompareFullScreen) { newValue in
            DispatchQueue.main.async {
                guard let window = NSApp.keyWindow else { return }
                let isFS = window.styleMask.contains(.fullScreen)
                if newValue && !isFS {
                    window.toggleFullScreen(nil)
                } else if !newValue && isFS {
                    window.toggleFullScreen(nil)
                }
            }
        }
        .onChange(of: viewModel.selectedTake?.id) { _ in
            // Auto-extract camera metadata when selecting a take with video but no metadata
            if let take = viewModel.selectedTake,
               take.capturedVideoPath != nil,
               !take.hasCameraMetadata,
               let dir = projectDir {
                Task {
                    if let metadata = await viewModel.extractCameraMetadata(for: take, projectDir: dir),
                       metadata.hasData,
                       let shot = viewModel.selectedShot {
                        updateTake(take, in: shot) { t in
                            metadata.apply(to: &t)
                        }
                    }
                }
            }

            // Auto-detect audio cues when selecting a take with video but no cue detection
            if let take = viewModel.selectedTake {
                print("[CurationView] onChange take: \(take.id), videoPath: \(take.capturedVideoPath ?? "nil"), hasAudioCueDetection: \(take.hasAudioCueDetection), projectDir: \(projectDir?.path ?? "nil")")
                if take.capturedVideoPath != nil,
                   !take.hasAudioCueDetection,
                   let dir = projectDir {
                    print("[CurationView] Triggering auto-detect for take \(take.takeNumber)")
                    Task {
                        if let result = await viewModel.detectAudioCues(for: take, projectDir: dir) {
                            print("[CurationView] Detection result: hasResults=\(result.hasResults), action=\(result.actionTimestamp ?? -1), cut=\(result.cutTimestamp ?? -1)")
                            if result.hasResults, let shot = viewModel.selectedShot {
                                updateTake(take, in: shot) { t in
                                    result.apply(to: &t)
                                }
                            }
                        } else {
                            print("[CurationView] Detection returned nil")
                        }
                    }
                }

                // Auto-detect sync tones when take has video but no sync detection
                if take.capturedVideoPath != nil,
                   !take.hasSyncToneDetection,
                   let dir = projectDir {
                    Task {
                        if let result = await viewModel.detectSyncTones(for: take, projectDir: dir),
                           result.hasResults,
                           let shot = viewModel.selectedShot {
                            updateTake(take, in: shot) { t in
                                result.apply(to: &t)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Full Screen Video Player

    private var fullScreenVideoPlayer: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let url = fullScreenVideoURL, FileManager.default.fileExists(atPath: url.path) {
                VideoPlayer(player: AVPlayer(url: url))
                    .ignoresSafeArea()
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "video.slash.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.2))
                    Text("Video not available")
                        .font(.system(size: 14))
                        .foregroundColor(.gray.opacity(0.4))
                }
            }

            // Close overlay
            VStack {
                HStack {
                    Spacer()
                    Button { isVideoFullScreen = false } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Exit")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.black.opacity(0.7)))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape, modifiers: [])
                    .padding(20)
                }
                Spacer()
            }
        }
    }

    // MARK: - Full Screen Compare Panel

    private var fullScreenComparePanel: some View {
        VStack(spacing: 0) {
            // Compact toolbar — hover-visible at top
            HStack(spacing: 12) {
                Image(systemName: "square.split.2x1.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.accentColor)
                Text("COMPARE")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(.gray)

                Spacer()

                // Sync toggle
                Button {
                    compareSyncPlayback.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: compareSyncPlayback ? "link" : "link.badge.plus")
                            .font(.system(size: 10))
                        Text(compareSyncPlayback ? "Synced" : "Independent")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .foregroundColor(compareSyncPlayback ? .white : .gray)
                    .background(Capsule().fill(compareSyncPlayback ? Color.accentColor.opacity(0.6) : Color(hex: "#3A3A3A")))
                }
                .buttonStyle(.plain)

                Button { comparePlayPause() } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Circle().fill(Color.accentColor))
                }
                .buttonStyle(.plain)

                Button { compareSeekToStart() } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                        .padding(8)
                        .background(Circle().fill(Color(hex: "#3A3A3A")))
                }
                .buttonStyle(.plain)

                Button { isCompareFullScreen = false } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Exit Full Screen")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.red.opacity(0.6)))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.black)

            // Side-by-side panels — maximized
            HStack(spacing: 1) {
                fullScreenCompareSide(
                    side: .left,
                    take: compareLeftTake,
                    shot: compareLeftShot,
                    scene: compareLeftScene,
                    player: compareLeftPlayer
                )

                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 1)

                fullScreenCompareSide(
                    side: .right,
                    take: compareRightTake,
                    shot: compareRightShot,
                    scene: compareRightScene,
                    player: compareRightPlayer
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .edgesIgnoringSafeArea(.all)
    }

    private func fullScreenCompareSide(side: CompareSide, take: Take?, shot: Shot?, scene: DCScene?, player: AVPlayer?) -> some View {
        VStack(spacing: 0) {
            // Compact label bar
            HStack(spacing: 8) {
                Text(side == .left ? "A" : "B")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(side == .left ? Color.accentColor : Color.orange))

                if let take, let shot, let scene {
                    Circle()
                        .fill(ratingColor(take.rating))
                        .frame(width: 7, height: 7)
                    Text("\(scene.name) > Shot #\(shot.shotId) > T\(take.takeNumber)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text("— \(take.rating.rawValue)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(ratingColor(take.rating))
                } else {
                    Text(side == .left ? "Select Take A" : "Right-click a take to select")
                        .font(.system(size: 11))
                        .foregroundColor(.gray.opacity(0.5))
                }

                Spacer()

                if let take {
                    Text(viewModel.formatDuration(take.durationSeconds))
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(hex: "#111111"))

            // Video — fills all available space
            ZStack {
                Color.black

                if let player {
                    VideoPlayer(player: player)
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: side == .left ? "a.square" : "b.square")
                            .font(.system(size: 40))
                            .foregroundColor(.gray.opacity(0.15))
                        Text(side == .left ? "Select Take A" : "Select Take B")
                            .font(.system(size: 12))
                            .foregroundColor(.gray.opacity(0.3))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Compact metadata bar
            if let take, let shot {
                HStack(spacing: 8) {
                    // Inline rating chips
                    compareRatingChip(take: take, shot: shot, rating: .circle)
                    compareRatingChip(take: take, shot: shot, rating: .alt)
                    compareRatingChip(take: take, shot: shot, rating: .ng)

                    Spacer()

                    if let ts = take.formattedStartTimestamp {
                        HStack(spacing: 3) {
                            Image(systemName: "clock").font(.system(size: 8)).foregroundColor(.gray.opacity(0.4))
                            Text(ts)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.gray.opacity(0.6))
                                .monospacedDigit()
                        }
                    }

                    if !take.notes.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "note.text").font(.system(size: 8)).foregroundColor(.gray.opacity(0.4))
                            Text(take.notes)
                                .font(.system(size: 9))
                                .foregroundColor(.gray.opacity(0.6))
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(hex: "#111111"))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Tab Bar

    private var curationTabBar: some View {
        HStack(spacing: 0) {
            ForEach(CurationTab.allCases, id: \.self) { tab in
                Button { selectedTab = tab } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                        Text(tab.displayName)
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
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Curation Tab Content

    private var curationTabContent: some View {
        HStack(spacing: 0) {
            navigatorPanel
                .frame(width: 300)

            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.3))
                .frame(width: 1)

            detailPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Mapping Tab Content

    private var mappingTabContent: some View {
        VStack(spacing: 0) {
            mediaSourcesPanel
                .fixedSize(horizontal: false, vertical: true)

            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.2))
                .frame(height: 1)

            // Mapping detail — show all takes with their match status
            mappingDetailView
                .frame(maxHeight: .infinity)
        }
    }

    private var mappingDetailView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Column headers
                HStack(spacing: 0) {
                    Text("STATUS")
                        .frame(width: 70, alignment: .leading)
                    Text("TAKE")
                        .frame(width: 110, alignment: .leading)
                    Text("CLIP NAME")
                        .frame(width: 90, alignment: .leading)
                    Text("TIMESTAMP")
                        .frame(width: 130, alignment: .leading)
                    Text("VIDEO")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("AUDIO")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("")
                        .frame(width: 24)
                    Text("SYNC")
                        .frame(width: 36, alignment: .center)
                    Text("ACTIONS")
                        .frame(width: 70, alignment: .center)
                }
                .font(.system(size: 8, weight: .bold))
                .tracking(1.0)
                .foregroundColor(.gray.opacity(0.4))
                .padding(.horizontal, 32).padding(.vertical, 6)
                .background(Color(hex: "#1E1E1E"))
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
                }

                let allScenes = project.sequences.flatMap { $0.scenes }
                ForEach(allScenes, id: \.name) { scene in
                    let shotsWithTakes = scene.shots.filter { !$0.takes.isEmpty }
                    if !shotsWithTakes.isEmpty {
                        // Scene header
                        HStack(spacing: 8) {
                            Image(systemName: "film.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.accentColor.opacity(0.5))
                            Text(scene.name)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))

                            Spacer()

                            // Per-scene mapping stats
                            let sceneTakes = shotsWithTakes.flatMap { $0.takes }
                            let videoMapped = sceneTakes.filter { $0.cameraSourceFileName != nil }.count
                            let audioMapped = sceneTakes.filter { $0.externalAudioFileName != nil || $0.useAudioFromVideo }.count
                            let sceneReady = videoMapped == sceneTakes.count && audioMapped == sceneTakes.count && !sceneTakes.isEmpty
                            HStack(spacing: 8) {
                                if sceneReady {
                                    HStack(spacing: 3) {
                                        Image(systemName: "checkmark.seal.fill").font(.system(size: 8))
                                        Text("Ready")
                                            .font(.system(size: 9, weight: .semibold))
                                    }
                                    .foregroundColor(.green)
                                } else {
                                    mappingStatusPill(mapped: videoMapped, total: sceneTakes.count, icon: "video.fill", color: .accentColor)
                                    mappingStatusPill(mapped: audioMapped, total: sceneTakes.count, icon: "waveform", color: .blue)
                                }
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color(hex: "#1E1E1E"))

                        ForEach(shotsWithTakes) { shot in
                            // Shot subheader with shot-level status
                            let shotTakes = viewModel.sortedTakes(shot.takes)
                            let shotVideoMapped = shotTakes.filter { $0.cameraSourceFileName != nil }.count
                            let shotAudioMapped = shotTakes.filter { $0.externalAudioFileName != nil || $0.useAudioFromVideo }.count
                            let shotReady = shotVideoMapped == shotTakes.count && shotAudioMapped == shotTakes.count && !shotTakes.isEmpty
                            HStack(spacing: 6) {
                                // Shot ready indicator
                                Image(systemName: shotReady ? "checkmark.circle.fill" : "circle.dotted")
                                    .font(.system(size: 9))
                                    .foregroundColor(shotReady ? .green : .gray.opacity(0.3))

                                Image(systemName: "camera.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(.gray.opacity(0.4))
                                Text("Shot #\(shot.shotId)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.6))
                                if !shot.description.isEmpty {
                                    Text("— \(shot.description)")
                                        .font(.system(size: 9))
                                        .foregroundColor(.gray.opacity(0.3))
                                        .lineLimit(1)
                                }

                                Spacer()

                                if shotReady {
                                    Text("Ready")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(.green)
                                        .padding(.horizontal, 8).padding(.vertical, 2)
                                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.green.opacity(0.1)))
                                } else {
                                    mappingStatusPill(mapped: shotVideoMapped, total: shotTakes.count, icon: "video.fill", color: .accentColor)
                                    mappingStatusPill(mapped: shotAudioMapped, total: shotTakes.count, icon: "waveform", color: .blue)
                                }
                            }
                            .padding(.horizontal, 24).padding(.vertical, 5)
                            .background(Color(hex: "#1C1C1C"))

                            ForEach(shotTakes) { take in
                                mappingTakeRow(take: take, shot: shot, scene: scene)
                            }
                        }
                    }
                }

                if allScenes.flatMap({ $0.shots }).flatMap({ $0.takes }).isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "tray")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.12))
                        Text("No takes to map")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray.opacity(0.4))
                        Text("Record takes from the Shot List view first")
                            .font(.system(size: 11))
                            .foregroundColor(.gray.opacity(0.2))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                }
            }
        }
        .background(Color(hex: "#1A1A1A"))
    }

    private func mappingStatusPill(mapped: Int, total: Int, icon: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 7))
            Text("\(mapped)/\(total)")
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
        }
        .foregroundColor(mapped == total && mapped > 0 ? color : .gray.opacity(0.3))
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(RoundedRectangle(cornerRadius: 4).fill(
            mapped == total && mapped > 0 ? color.opacity(0.1) : Color.white.opacity(0.03)
        ))
    }

    private func takeReadyStatus(_ take: Take) -> (label: String, color: Color, icon: String) {
        let hasVideo = take.cameraSourceFileName != nil
        let hasAudio = take.externalAudioFileName != nil || take.useAudioFromVideo
        if hasVideo && hasAudio {
            return ("Ready", .green, "checkmark.circle.fill")
        } else if hasVideo || hasAudio {
            return ("Partial", .yellow, "exclamationmark.circle.fill")
        } else {
            return ("Pending", .gray.opacity(0.4), "circle.dotted")
        }
    }

    private func mappingTakeRow(take: Take, shot: Shot, scene: DCScene) -> some View {
        let status = takeReadyStatus(take)
        return HStack(spacing: 0) {
            // Status
            HStack(spacing: 4) {
                Image(systemName: status.icon)
                    .font(.system(size: 9))
                Text(status.label)
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundColor(status.color)
            .frame(width: 70, alignment: .leading)

            // Take info
            HStack(spacing: 6) {
                Circle()
                    .fill(ratingColor(take.rating))
                    .frame(width: 6, height: 6)
                Text("T\(take.takeNumber)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                Text(take.rating.rawValue)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(ratingColor(take.rating).opacity(0.7))
            }
            .frame(width: 110, alignment: .leading)

            // Camera clip name (OCR-extracted)
            if let clipName = take.cameraClipName {
                Text(clipName)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.orange.opacity(0.8))
                    .frame(width: 90, alignment: .leading)
            } else {
                Text("—")
                    .font(.system(size: 9))
                    .foregroundColor(.gray.opacity(0.2))
                    .frame(width: 90, alignment: .leading)
            }

            // Timestamp
            if let ts = take.startTimestamp {
                Text(Take.formatForCameraMatch(ts))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.accentColor.opacity(0.5))
                    .frame(width: 130, alignment: .leading)
            } else {
                Text("—")
                    .font(.system(size: 9))
                    .foregroundColor(.gray.opacity(0.2))
                    .frame(width: 130, alignment: .leading)
            }

            // Video status
            HStack(spacing: 3) {
                if let name = take.cameraSourceFileName {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.green)
                    Text(name)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.green.opacity(0.85))
                        .lineLimit(1)

                    // Copy path
                    if let url = viewModel.cameraFileURL(for: name) {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(url.path, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 7, weight: .medium))
                                .foregroundColor(.gray.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                        .help("Copy path")

                        // Reveal in Finder
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        } label: {
                            Image(systemName: "folder")
                                .font(.system(size: 7, weight: .medium))
                                .foregroundColor(.gray.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                        .help("Reveal in Finder")
                    }
                } else {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 9))
                        .foregroundColor(.red.opacity(0.4))
                    Text("Not mapped")
                        .font(.system(size: 9))
                        .foregroundColor(.red.opacity(0.4))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Audio status
            HStack(spacing: 3) {
                if take.useAudioFromVideo {
                    Image(systemName: "video.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.purple)
                    Text("From video")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.purple.opacity(0.85))
                } else if let name = take.externalAudioFileName {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.blue)
                    Text(name)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.blue.opacity(0.85))
                        .lineLimit(1)

                    // Copy path
                    if let url = viewModel.audioFileURL(for: name) {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(url.path, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 7, weight: .medium))
                                .foregroundColor(.gray.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                        .help("Copy path")

                        // Reveal in Finder
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        } label: {
                            Image(systemName: "folder")
                                .font(.system(size: 7, weight: .medium))
                                .foregroundColor(.gray.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                        .help("Reveal in Finder")
                    }
                } else {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 9))
                        .foregroundColor(.red.opacity(0.4))
                    Text("Not mapped")
                        .font(.system(size: 9))
                        .foregroundColor(.red.opacity(0.4))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Audio from video toggle
            Menu {
                if take.useAudioFromVideo {
                    Button {
                        updateTake(take, in: shot) { $0.useAudioFromVideo = false }
                    } label: {
                        Label("Use External Audio", systemImage: "waveform")
                    }
                } else {
                    Button {
                        updateTake(take, in: shot) {
                            $0.useAudioFromVideo = true
                            $0.externalAudioFileName = nil
                        }
                    } label: {
                        Label("Use Audio from Video", systemImage: "video.fill")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 10))
                    .foregroundColor(.gray.opacity(0.3))
                    .frame(width: 24, height: 20)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            // Sync status
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 8))
                .foregroundColor({
                    if take.isAudioVideoSynced == true { return Color.green }
                    if take.isAudioVideoSynced == false { return Color.red }
                    if take.useAudioFromVideo { return Color.green }
                    if take.cameraSourceFileName != nil && take.externalAudioFileName != nil { return Color.yellow }
                    return Color.gray.opacity(0.15)
                }())
                .frame(width: 36, alignment: .center)

            // Per-row actions: map / remap / clear
            HStack(spacing: 4) {
                let hasVideo = take.cameraSourceFileName != nil
                let hasAudio = take.externalAudioFileName != nil || take.useAudioFromVideo

                // Map / Remap button
                Button {
                    // Try video match
                    if let videoMatch = viewModel.matchSingleTake(take) {
                        updateTake(take, in: shot) { $0.cameraSourceFileName = videoMatch }
                    }
                    // Try audio match (only if not using audio from video)
                    if !take.useAudioFromVideo {
                        if let audioMatch = viewModel.matchSingleTakeAudio(take) {
                            updateTake(take, in: shot) { $0.externalAudioFileName = audioMatch }
                        }
                    }
                } label: {
                    Image(systemName: hasVideo || hasAudio ? "arrow.triangle.2.circlepath" : "link")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.accentColor.opacity(0.7))
                        .frame(width: 22, height: 20)
                }
                .buttonStyle(.plain)
                .help(hasVideo || hasAudio ? "Remap this take" : "Map this take")

                // Clear mapping
                if hasVideo || (take.externalAudioFileName != nil) {
                    Button {
                        updateTake(take, in: shot) {
                            $0.cameraSourceFileName = nil
                            $0.externalAudioFileName = nil
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(.gray.opacity(0.4))
                            .frame(width: 22, height: 20)
                    }
                    .buttonStyle(.plain)
                    .help("Clear all mappings for this take")
                }
            }
            .frame(width: 70, alignment: .center)
        }
        .padding(.horizontal, 32).padding(.vertical, 5)
        .background(Color(hex: "#1A1A1A"))
    }

    // MARK: - Media Sources Panel

    private var mediaSourcesPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "externaldrive.connected.to.line.below.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                Text("MEDIA SOURCES")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(.gray)

                Spacer()

                // Match stats
                let matched = viewModel.matchedTakeCount(in: project)
                let unmatched = viewModel.unmatchedTakeCount(in: project)
                let total = matched + unmatched
                if total > 0 {
                    HStack(spacing: 6) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2.5)
                                    .fill(Color.white.opacity(0.06))
                                RoundedRectangle(cornerRadius: 2.5)
                                    .fill(matched == total ? Color.green : Color.accentColor)
                                    .frame(width: max(0, geo.size.width * CGFloat(matched) / CGFloat(total)))
                            }
                        }
                        .frame(width: 40, height: 5)

                        Text("\(matched)/\(total)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(matched == total ? .green : .gray)
                        Text("matched")
                            .font(.system(size: 8))
                            .foregroundColor(.gray.opacity(0.4))
                    }
                }

                // Rescan
                if !viewModel.mediaSources.isEmpty {
                    Button { viewModel.rescanAllSources() } label: {
                        Image(systemName: viewModel.isScanning ? "progress.indicator" : "arrow.clockwise")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.gray.opacity(0.5))
                            .frame(width: 24, height: 24)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color(hex: "#2A2A2A")))
                    }
                    .buttonStyle(.plain)
                    .help("Rescan all sources")
                }

                // Sort & filter
                Menu {
                    ForEach(CurationSortOrder.allCases, id: \.self) { order in
                        Button {
                            viewModel.sortOrder = order
                        } label: {
                            if viewModel.sortOrder == order {
                                Label(order.rawValue, systemImage: "checkmark")
                            } else {
                                Text(order.rawValue)
                            }
                        }
                    }
                    Divider()
                    Button {
                        viewModel.showOnlyUnmatched.toggle()
                    } label: {
                        if viewModel.showOnlyUnmatched {
                            Label("Show All Takes", systemImage: "line.3.horizontal.decrease.circle")
                        } else {
                            Label("Show Unmatched Only", systemImage: "exclamationmark.triangle")
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(viewModel.sortOrder != .takeNumber || viewModel.showOnlyUnmatched ? .accentColor : .gray.opacity(0.5))
                        .frame(width: 24, height: 24)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color(hex: "#2A2A2A")))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Sort & filter")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            // Sources in two columns
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    mediaSourceColumn(
                        label: "VIDEO",
                        icon: "video.fill",
                        color: .accentColor,
                        sources: viewModel.mediaSources.filter { $0.type == .video },
                        fileCount: viewModel.totalVideoFiles,
                        addLabel: "Add camera folder",
                        onAdd: { viewModel.addVideoSource() }
                    )

                    Rectangle()
                        .fill(Color.white.opacity(0.04))
                        .frame(width: 1)

                    mediaSourceColumn(
                        label: "AUDIO",
                        icon: "waveform",
                        color: .blue,
                        sources: viewModel.mediaSources.filter { $0.type == .audio },
                        fileCount: viewModel.totalAudioFiles,
                        addLabel: "Add audio folder",
                        onAdd: { viewModel.addAudioSource() }
                    )
                }

                // Match actions
                if !viewModel.cameraFiles.isEmpty || !viewModel.audioFiles.isEmpty {
                    HStack(spacing: 8) {
                        if !viewModel.cameraFiles.isEmpty {
                            Button {
                                let results = viewModel.autoMatchByTimestamp(project: project)
                                if !results.isEmpty {
                                    viewModel.applyAutoMatchResults(results, project: &project)
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "clock.arrow.2.circlepath").font(.system(size: 9, weight: .semibold))
                                    Text("Auto-Match by Timestamp").font(.system(size: 10, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor))
                            }
                            .buttonStyle(.plain)

                            let hasClipNames = project.sequences.flatMap { $0.scenes }.flatMap { $0.shots }.flatMap { $0.takes }.contains { $0.cameraClipName != nil }
                            if hasClipNames {
                                Button {
                                    let results = viewModel.autoMatchByClipName(project: project)
                                    if !results.isEmpty {
                                        viewModel.applyAutoMatchResults(results, project: &project)
                                    }
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: "text.magnifyingglass").font(.system(size: 9, weight: .semibold))
                                        Text("Match by Clip Name").font(.system(size: 10, weight: .medium))
                                    }
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding(.horizontal, 14).padding(.vertical, 7)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: "#2A2A2A")))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Spacer()

                        // Remap all — re-run matching after adding new sources
                        Button {
                            viewModel.rescanAllSources()
                            // Re-run both matching strategies
                            let tsResults = viewModel.autoMatchByTimestamp(project: project)
                            if !tsResults.isEmpty {
                                viewModel.applyAutoMatchResults(tsResults, project: &project)
                            }
                            let clipResults = viewModel.autoMatchByClipName(project: project)
                            if !clipResults.isEmpty {
                                viewModel.applyAutoMatchResults(clipResults, project: &project)
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 9, weight: .semibold))
                                Text("Remap All").font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: "#2A2A2A")))
                        }
                        .buttonStyle(.plain)
                        .help("Rescan sources and re-run all matching")
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
        .background(Color(hex: "#1E1E1E"))
    }

    // MARK: - Media Source Column

    private func mediaSourceColumn(
        label: String,
        icon: String,
        color: Color,
        sources: [MediaSource],
        fileCount: Int,
        addLabel: String,
        onAdd: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Column header
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundColor(color.opacity(0.7))
                Text(label)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(.gray.opacity(0.5))

                Spacer()

                if fileCount > 0 {
                    Text("\(fileCount) files")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(color.opacity(0.5))
                }
            }

            // Source rows
            ForEach(sources) { source in
                mediaSourceRow(source: source, color: color)
            }

            // Add button
            Button(action: onAdd) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 8, weight: .bold))
                    Text(sources.isEmpty ? addLabel : "Add source")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(color.opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(color.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Media Source Row

    private func mediaSourceRow(source: MediaSource, color: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: source.type == .video ? "sdcard.fill" : "mic.fill")
                .font(.system(size: 9))
                .foregroundColor(color.opacity(0.6))
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 1) {
                Text(source.label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Text("\(source.fileCount) files")
                        .font(.system(size: 8))
                        .foregroundColor(color.opacity(0.45))
                    if let t = source.lastScanned {
                        Text(t, style: .relative)
                            .font(.system(size: 8))
                            .foregroundColor(.gray.opacity(0.25))
                    }
                }
            }

            Spacer()

            Button { NSWorkspace.shared.open(source.url) } label: {
                Image(systemName: "folder")
                    .font(.system(size: 8))
                    .foregroundColor(.gray.opacity(0.3))
            }
            .buttonStyle(.plain)
            .help("Reveal in Finder")

            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    viewModel.removeSource(source)
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.gray.opacity(0.2))
            }
            .buttonStyle(.plain)
            .help("Remove source")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 7).fill(Color(hex: "#252525")))
    }

    // MARK: - Navigator Panel

    private var navigatorPanel: some View {
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

    private func filterPill(_ rating: TakeRating?, label: String, icon: String) -> some View {
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

    private func sceneSection(_ scene: DCScene) -> some View {
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

    private func shotSection(_ shot: Shot, in scene: DCScene) -> some View {
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

    private func takeNavigatorRow(_ take: Take, shot: Shot, scene: DCScene) -> some View {
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

    private var emptyNavigator: some View {
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

    private var actionBar: some View {
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

    // MARK: - Detail Panel

    private var detailPanel: some View {
        Group {
            if isCompareMode {
                if isCompareFullScreen {
                    Color.clear // Compare is shown in sheet
                } else {
                    comparePanel
                }
            } else if let take = viewModel.selectedTake, let shot = viewModel.selectedShot, let scene = viewModel.selectedScene {
                takeReviewView(take: take, shot: shot, scene: scene)
            } else if let shot = viewModel.selectedShot, shot.takes.isEmpty {
                noTakesDetailView(shot: shot)
            } else {
                emptyDetailView
            }
        }
    }

    private var emptyDetailView: some View {
        VStack(spacing: 14) {
            Image(systemName: "play.rectangle")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.12))
            Text("Select a take to review")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray.opacity(0.4))
            Text("Choose from the scene tree on the left")
                .font(.system(size: 11))
                .foregroundColor(.gray.opacity(0.2))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#1A1A1A"))
    }

    private func noTakesDetailView(shot: Shot) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "film")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.12))
            Text("No takes yet")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray.opacity(0.4))
            Text("Shot #\(shot.shotId) has no recorded takes")
                .font(.system(size: 11))
                .foregroundColor(.gray.opacity(0.25))
            Text("Record takes from the Shot List view")
                .font(.system(size: 10))
                .foregroundColor(.gray.opacity(0.2))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#1A1A1A"))
    }

    // MARK: - Take Review View

    private func takeReviewView(take: Take, shot: Shot, scene: DCScene) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Hero header
                heroHeader(take: take, shot: shot, scene: scene)

                // Video preview
                videoPreview(take: take)

                // Audio cue detection timeline
                audioCueTimeline(take: take, shot: shot)

                // Two-column: Rating + Metadata
                HStack(alignment: .top, spacing: 16) {
                    // Rating card
                    ratingCard(take: take, shot: shot)

                    // Metadata card
                    metadataCard(take: take)
                }

                // Notes
                notesCard(take: take, shot: shot)

                // Camera footage metadata (OCR-extracted)
                cameraFootageMetadataCard(take: take, shot: shot)

                // Camera source
                cameraSourceCard(take: take, shot: shot)

                // External audio
                externalAudioCard(take: take, shot: shot)

                // Tags
                tagsCard(take: take, shot: shot)
            }
            .padding(24)
        }
        .background(Color(hex: "#1A1A1A"))
    }

    // MARK: - Hero Header

    private func heroHeader(take: Take, shot: Shot, scene: DCScene) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // Big take number
            VStack(spacing: 2) {
                Text("\(take.takeNumber)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("TAKE")
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(1.5)
                    .foregroundColor(.gray.opacity(0.5))
            }
            .frame(width: 64, height: 64)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ratingColor(take.rating).opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ratingColor(take.rating).opacity(0.3), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 4) {
                // Shot description
                HStack(spacing: 8) {
                    Text("Shot #\(shot.shotId)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)

                    // Status icons
                    takeStatusIcons(take: take)
                }

                Text(scene.name)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)

                if !shot.description.isEmpty {
                    Text(shot.description)
                        .font(.system(size: 10))
                        .foregroundColor(.gray.opacity(0.6))
                        .lineLimit(2)
                }
            }

            Spacer()

            // Quick actions
            HStack(spacing: 6) {
                if let videoPath = take.capturedVideoPath, let dir = projectDir {
                    let fullURL = dir.appendingPathComponent(videoPath)
                    Button { NSWorkspace.shared.open(fullURL) } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill").font(.system(size: 9))
                            Text("Play").font(.system(size: 10, weight: .medium))
                        }
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(Color.accentColor))
                        .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)

                    Button { NSWorkspace.shared.activateFileViewerSelecting([fullURL]) } label: {
                        Image(systemName: "folder")
                            .font(.system(size: 10))
                            .padding(7)
                            .background(Circle().fill(Color(hex: "#3A3A3A")))
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }

                // Navigate to Shot List → Takes section
                Button {
                    coordinator.scrollToShotSection = "takes"
                    coordinator.selectShot(shot)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "camera.viewfinder").font(.system(size: 9))
                        Text("Shot List").font(.system(size: 10, weight: .medium))
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(Color(hex: "#3A3A3A")))
                    .foregroundColor(.gray)
                }
                .buttonStyle(.plain)

                // Delete take
                Button { deleteTake(take, in: shot) } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .padding(7)
                        .background(Circle().fill(Color(hex: "#3A3A3A")))
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Take Status Icons

    private enum ConnectionStatus {
        case connected   // green — file mapped
        case partial     // yellow — metadata extracted / dir browsed but not mapped
        case unmatched   // red — browsed but no match found
        case inactive    // gray — nothing done

        var color: Color {
            switch self {
            case .connected: return .green
            case .partial: return .yellow
            case .unmatched: return .red
            case .inactive: return .gray
            }
        }
    }

    /// Shows connection status icons for camera file, audio file, and sync state
    private func takeStatusIcons(take: Take) -> some View {
        HStack(spacing: 5) {
            // Video status
            let videoStatus: ConnectionStatus = {
                if take.cameraSourceFileName != nil && !(take.cameraSourceFileName!.isEmpty) {
                    return .connected
                } else if take.hasCameraMetadata {
                    return .partial
                } else if !viewModel.cameraFiles.isEmpty {
                    return .unmatched
                }
                return .inactive
            }()
            statusBadge(
                icon: "video.fill",
                status: videoStatus,
                label: {
                    switch videoStatus {
                    case .connected: return "Camera file linked: \(take.cameraSourceFileName ?? "")"
                    case .partial: return "Metadata extracted — no camera file mapped"
                    case .unmatched: return "Camera files browsed — no match"
                    case .inactive: return "No camera file"
                    }
                }()
            )

            // Audio status
            let audioStatus: ConnectionStatus = {
                if take.useAudioFromVideo {
                    return .connected
                } else if take.externalAudioFileName != nil && !(take.externalAudioFileName!.isEmpty) {
                    return .connected
                } else if !viewModel.audioFiles.isEmpty {
                    return .unmatched
                }
                return .inactive
            }()
            statusBadge(
                icon: take.useAudioFromVideo ? "video.fill" : "waveform",
                status: audioStatus,
                label: {
                    if take.useAudioFromVideo { return "Audio sourced from video file" }
                    switch audioStatus {
                    case .connected: return "Audio linked: \(take.externalAudioFileName ?? "")"
                    case .partial: return "Audio detected — not mapped"
                    case .unmatched: return "Audio files browsed — no match"
                    case .inactive: return "No audio file"
                    }
                }()
            )

            // Sync status (placeholder)
            let syncStatus: ConnectionStatus = {
                if take.useAudioFromVideo { return .connected }
                if let synced = take.isAudioVideoSynced {
                    return synced ? .connected : .unmatched
                }
                if take.cameraSourceFileName != nil && take.externalAudioFileName != nil {
                    return .partial
                }
                return .inactive
            }()
            statusBadge(
                icon: "arrow.triangle.2.circlepath",
                status: syncStatus,
                label: {
                    if take.useAudioFromVideo { return "Audio from video — always synced" }
                    switch syncStatus {
                    case .connected: return "Audio & video synced"
                    case .partial: return "Sync not checked"
                    case .unmatched: return "Not synced"
                    case .inactive: return "Sync unavailable"
                    }
                }()
            )
        }
    }

    private func statusBadge(icon: String, status: ConnectionStatus, label: String) -> some View {
        let color = status.color
        let isActive = status != .inactive
        return Image(systemName: icon)
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(isActive ? color : .gray.opacity(0.2))
            .frame(width: 20, height: 20)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isActive ? color.opacity(0.15) : Color(hex: "#2A2A2A"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(isActive ? color.opacity(0.4) : Color.clear, lineWidth: 1)
            )
            .help(label)
    }

    // MARK: - Video Preview

    private func videoPreview(take: Take) -> some View {
        Group {
            if let videoPath = take.capturedVideoPath, let dir = projectDir {
                let fullURL = dir.appendingPathComponent(videoPath)
                if FileManager.default.fileExists(atPath: fullURL.path) {
                    ZStack(alignment: .topTrailing) {
                        VideoPlayer(player: AVPlayer(url: fullURL))
                            .aspectRatio(16/9, contentMode: .fit)
                            .frame(maxHeight: 400)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                            )

                        // Full screen button
                        Button {
                            fullScreenVideoURL = fullURL
                            isVideoFullScreen = true
                        } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(8)
                                .background(Circle().fill(Color.black.opacity(0.7)))
                        }
                        .buttonStyle(.plain)
                        .padding(12)
                    }
                } else {
                    videoPlaceholder
                }
            } else {
                videoPlaceholder
            }
        }
    }

    private var videoPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black)
                .aspectRatio(16/9, contentMode: .fit)
                .frame(maxHeight: 300)

            VStack(spacing: 8) {
                Image(systemName: "video.slash.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.gray.opacity(0.15))
                Text("No video file")
                    .font(.system(size: 10))
                    .foregroundColor(.gray.opacity(0.3))
            }
        }
    }

    // MARK: - Audio Cue Timeline

    private func audioCueTimeline(take: Take, shot: Shot) -> some View {
        Group {
            if take.capturedVideoPath != nil {
                VStack(alignment: .leading, spacing: 14) {
                    // Header
                    HStack(spacing: 6) {
                        Image(systemName: "waveform")
                            .font(.system(size: 11))
                            .foregroundColor(.accentColor)
                        Text("AUDIO CUES")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.2)
                            .foregroundColor(.gray)

                        Spacer()

                        // Detection status / button
                        if viewModel.isDetectingCues {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                Text(detectionStatusText)
                                    .font(.system(size: 9))
                                    .foregroundColor(.gray)
                            }
                        } else {
                            Button {
                                guard let dir = projectDir else { return }
                                Task {
                                    if let result = await viewModel.detectAudioCues(for: take, projectDir: dir),
                                       result.hasResults {
                                        updateTake(take, in: shot) { t in
                                            result.apply(to: &t)
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: take.hasAudioCueDetection ? "arrow.clockwise" : "waveform.badge.magnifyingglass")
                                        .font(.system(size: 9))
                                    Text(take.hasAudioCueDetection ? "Re-detect" : "Detect Cues")
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Color(hex: "#3A3A3A")))
                                .foregroundColor(.gray)
                            }
                            .buttonStyle(.plain)

                            // Detect Sync button
                            if viewModel.isDetectingSyncTones {
                                HStack(spacing: 6) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Detecting sync...")
                                        .font(.system(size: 9))
                                        .foregroundColor(.purple)
                                }
                            } else {
                                Button {
                                    guard let dir = projectDir else { return }
                                    Task {
                                        if let result = await viewModel.detectSyncTones(for: take, projectDir: dir),
                                           result.hasResults {
                                            updateTake(take, in: shot) { t in
                                                result.apply(to: &t)
                                            }
                                            // Also try computing offset if camera footage is mapped
                                            if let offset = await viewModel.computeSyncOffset(for: take, projectDir: dir) {
                                                updateTake(take, in: shot) { t in
                                                    t.syncOffset = offset
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: take.hasSyncToneDetection ? "arrow.clockwise" : "waveform.badge.plus")
                                            .font(.system(size: 9))
                                        Text(take.hasSyncToneDetection ? "Re-detect Sync" : "Detect Sync")
                                            .font(.system(size: 10, weight: .medium))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(Color.purple.opacity(0.3)))
                                    .foregroundColor(.purple)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if take.hasAudioCueDetection || take.hasSyncToneDetection {
                        // Visual timeline bar
                        audioCueTimelineBar(take: take)

                        // Timestamp readout
                        audioCueTimestampReadout(take: take)
                    } else if !viewModel.isDetectingCues && !viewModel.isDetectingSyncTones {
                        // Empty state
                        HStack {
                            Spacer()
                            VStack(spacing: 6) {
                                Image(systemName: "waveform.slash")
                                    .font(.system(size: 20))
                                    .foregroundColor(.gray.opacity(0.2))
                                Text("No cues detected yet")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray.opacity(0.3))
                            }
                            .padding(.vertical, 12)
                            Spacer()
                        }
                    }
                }
                .padding(14)
                .background(Color(hex: "#252525"))
                .cornerRadius(10)
            }
        }
    }

    private var detectionStatusText: String {
        switch viewModel.detectionStatus {
        case .idle: return "Starting..."
        case .extractingAudio: return "Extracting audio..."
        case .recognizingSpeech(let progress): return "Recognizing speech \(Int(progress * 100))%..."
        case .analyzing: return "Analyzing words..."
        case .completed: return "Done"
        case .failed(let msg): return "Failed: \(msg)"
        }
    }

    private func audioCueTimelineBar(take: Take) -> some View {
        let duration = take.durationSeconds ?? 1.0

        return GeometryReader { geo in
            let width = geo.size.width

            ZStack(alignment: .leading) {
                // Background bar (full duration)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hex: "#1A1A1A"))
                    .frame(height: 32)

                // Highlighted region between action and cut
                if let actionTime = take.actionTimestamp, let cutTime = take.cutTimestamp, cutTime > actionTime {
                    let startX = CGFloat(actionTime / duration) * width
                    let endX = CGFloat(cutTime / duration) * width
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: max(endX - startX, 2), height: 32)
                        .offset(x: startX)
                }

                // Action marker (green vertical line)
                if let actionTime = take.actionTimestamp {
                    let xPos = CGFloat(actionTime / duration) * width
                    VStack(spacing: 2) {
                        Text("ACTION")
                            .font(.system(size: 7, weight: .bold))
                            .tracking(0.5)
                            .foregroundColor(.green)
                        Rectangle()
                            .fill(Color.green)
                            .frame(width: 2, height: 20)
                    }
                    .offset(x: xPos - 16)
                }

                // Cut marker (red vertical line)
                if let cutTime = take.cutTimestamp {
                    let xPos = CGFloat(cutTime / duration) * width
                    VStack(spacing: 2) {
                        Text("CUT")
                            .font(.system(size: 7, weight: .bold))
                            .tracking(0.5)
                            .foregroundColor(.red)
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: 2, height: 20)
                    }
                    .offset(x: xPos - 8)
                }

                // Sync tone markers (purple vertical lines)
                if let syncTimestamps = take.syncToneTimestamps {
                    ForEach(Array(syncTimestamps.enumerated()), id: \.offset) { _, syncTime in
                        let xPos = CGFloat(syncTime / duration) * width
                        VStack(spacing: 2) {
                            Text("SYNC")
                                .font(.system(size: 7, weight: .bold))
                                .tracking(0.5)
                                .foregroundColor(.purple)
                            Rectangle()
                                .fill(Color.purple)
                                .frame(width: 2, height: 20)
                        }
                        .offset(x: xPos - 10)
                    }
                }
            }
        }
        .frame(height: 44)
    }

    private func audioCueTimestampReadout(take: Take) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                // Action info
                HStack(spacing: 6) {
                    Circle()
                        .fill(take.actionTimestamp != nil ? Color.green : Color.gray.opacity(0.3))
                        .frame(width: 7, height: 7)

                    if let actionTime = take.actionTimestamp {
                        Text("Action at \(viewModel.formatCueTimestamp(actionTime))")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))

                        if let word = take.detectedActionWord, word.lowercased() != "action" {
                            Text("(\"\(word)\")")
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                        }

                        if let conf = take.actionConfidence {
                            Text("\(Int(conf * 100))%")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(.green.opacity(0.7))
                        }
                    } else {
                        Text("Action: not detected")
                            .font(.system(size: 10))
                            .foregroundColor(.gray.opacity(0.5))
                    }
                }

                Spacer()

                // Cut info
                HStack(spacing: 6) {
                    Circle()
                        .fill(take.cutTimestamp != nil ? Color.red : Color.gray.opacity(0.3))
                        .frame(width: 7, height: 7)

                    if let cutTime = take.cutTimestamp {
                        Text("Cut at \(viewModel.formatCueTimestamp(cutTime))")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))

                        if let word = take.detectedCutWord, word.lowercased() != "cut" {
                            Text("(\"\(word)\")")
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                        }

                        if let conf = take.cutConfidence {
                            Text("\(Int(conf * 100))%")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(.red.opacity(0.7))
                        }
                    } else {
                        Text("Cut: not detected")
                            .font(.system(size: 10))
                            .foregroundColor(.gray.opacity(0.5))
                    }
                }
            }

            // Useful duration
            if let useful = take.usefulDuration {
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .font(.system(size: 9))
                        .foregroundColor(.accentColor)
                    Text("Useful: \(viewModel.formatCueTimestamp(useful))")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.accentColor)
                }
            }

            // Sync tone info
            if let syncTimestamps = take.syncToneTimestamps, !syncTimestamps.isEmpty {
                Divider().opacity(0.3)

                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.purple)
                            .frame(width: 7, height: 7)

                        Text("Sync at \(syncTimestamps.map { viewModel.formatCueTimestamp($0) }.joined(separator: ", "))")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))

                        if let bestConf = take.bestSyncConfidence {
                            Text("\(Int(bestConf * 100))%")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(.purple.opacity(0.7))
                        }
                    }

                    Spacer()

                    // Sync offset display
                    if let offset = take.syncOffset {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left.and.right")
                                .font(.system(size: 8))
                                .foregroundColor(.purple)
                            Text(String(format: "%+.3fs", offset))
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.purple)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Rating Card

    private func ratingCard(take: Take, shot: Shot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.accentColor)
                Text("RATING")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(.gray)
            }

            // Large rating buttons — vertical stack
            VStack(spacing: 6) {
                ratingButton(take: take, shot: shot, rating: .circle, color: .green, description: "Best / Print take")
                ratingButton(take: take, shot: shot, rating: .alt, color: .orange, description: "Backup alternative")
                ratingButton(take: take, shot: shot, rating: .ng, color: .red, description: "No good")
            }
        }
        .padding(14)
        .background(Color(hex: "#252525"))
        .cornerRadius(10)
        .frame(maxWidth: .infinity)
    }

    private func ratingButton(take: Take, shot: Shot, rating: TakeRating, color: Color, description: String) -> some View {
        let isSelected = take.rating == rating

        return Button {
            updateTake(take, in: shot) { $0.rating = isSelected ? .none : rating }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: rating.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? .white : color)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(rating.rawValue)
                        .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(isSelected ? .white : .primary)
                    Text(description)
                        .font(.system(size: 8))
                        .foregroundColor(isSelected ? .white.opacity(0.7) : .gray.opacity(0.5))
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? color : Color(hex: "#3A3A3A"))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Metadata Card

    private func metadataCard(take: Take) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.accentColor)
                Text("METADATA")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(.gray)
            }

            // Duration — hero number
            VStack(alignment: .leading, spacing: 2) {
                Text("Duration")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.gray)
                    .textCase(.uppercase)
                Text(viewModel.formatDuration(take.durationSeconds))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
            }

            Divider().opacity(0.3)

            // Record Start — camera-compatible timestamp for matching with camera file metadata
            VStack(alignment: .leading, spacing: 3) {
                Text("REC START — CAMERA MATCH TIMESTAMP")
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(0.6)
                    .foregroundColor(.gray.opacity(0.5))

                HStack(spacing: 8) {
                    Text(take.formattedStartTimestamp ?? "—")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .monospacedDigit()

                    if take.formattedStartTimestamp != nil {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(take.formattedStartTimestamp!, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.clipboard")
                                .font(.system(size: 9))
                                .foregroundColor(.gray.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Record End
            VStack(alignment: .leading, spacing: 3) {
                Text("REC END")
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(0.6)
                    .foregroundColor(.gray.opacity(0.5))

                Text(take.formattedEndTimestamp ?? "—")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                    .monospacedDigit()
            }
        }
        .padding(14)
        .background(Color(hex: "#252525"))
        .cornerRadius(10)
        .frame(maxWidth: .infinity)
    }

    private func metadataRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.gray.opacity(0.5))
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
                .monospacedDigit()
        }
    }

    // MARK: - Notes Card

    private func notesCard(take: Take, shot: Shot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "note.text")
                    .font(.system(size: 11))
                    .foregroundColor(.accentColor)
                Text("NOTES")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(.gray)
            }

            TextField("Director's notes, performance comments...", text: Binding(
                get: { take.notes },
                set: { newValue in updateTake(take, in: shot) { $0.notes = newValue } }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .padding(10)
            .background(Color(hex: "#1E1E1E"))
            .cornerRadius(6)
        }
        .padding(14)
        .background(Color(hex: "#252525"))
        .cornerRadius(10)
    }

    // MARK: - Camera Footage Metadata Card

    private func cameraFootageMetadataCard(take: Take, shot: Shot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "camera.aperture")
                    .font(.system(size: 11))
                    .foregroundColor(.accentColor)
                Text("CAMERA FOOTAGE METADATA")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(.gray)

                Spacer()

                if viewModel.isExtractingMetadata {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                } else {
                    Button {
                        guard let dir = projectDir else { return }
                        Task {
                            if let metadata = await viewModel.extractCameraMetadata(for: take, projectDir: dir),
                               metadata.hasData {
                                updateTake(take, in: shot) { t in
                                    metadata.apply(to: &t)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "eye.viewfinder").font(.system(size: 9))
                            Text("Extract from Video").font(.system(size: 9, weight: .medium))
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(Color.accentColor))
                        .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(take.capturedVideoPath == nil)
                    .opacity(take.capturedVideoPath == nil ? 0.4 : 1)
                }
            }

            if take.hasCameraMetadata {
                let columns = [GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: columns, spacing: 8) {
                    cameraMetadataCell(icon: "doc.text", label: "Clip Name", value: take.cameraClipName, highlight: true)
                    cameraMetadataCell(icon: "rectangle.split.2x2", label: "Resolution", value: take.cameraResolution)
                    cameraMetadataCell(icon: "speedometer", label: "Frame Rate", value: take.cameraFrameRate)
                    cameraMetadataCell(icon: "sun.max", label: "ISO", value: take.cameraISO)
                    cameraMetadataCell(icon: "camera.aperture", label: "Aperture", value: take.cameraAperture)
                    cameraMetadataCell(icon: "thermometer.medium", label: "White Balance", value: take.cameraWhiteBalance)
                    cameraMetadataCell(icon: "clock", label: "Timecode", value: take.cameraTimecode)
                    cameraMetadataCell(icon: "slider.horizontal.3", label: "LUT / Gamma", value: take.cameraLUT)
                    cameraMetadataCell(icon: "scope", label: "Focus Mode", value: take.cameraFocusMode)
                }
            } else {
                VStack(spacing: 6) {
                    Text("No camera metadata extracted")
                        .font(.system(size: 11))
                        .foregroundColor(.gray.opacity(0.4))
                    Text("Click \"Extract from Video\" to read viewfinder overlay via OCR")
                        .font(.system(size: 9))
                        .foregroundColor(.gray.opacity(0.3))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
        .padding(14)
        .background(Color(hex: "#252525"))
        .cornerRadius(10)
    }

    @ViewBuilder
    private func cameraMetadataCell(icon: String, label: String, value: String?, highlight: Bool = false) -> some View {
        if let value {
            let isCopied = copiedMetadataLabel == label

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
                copiedMetadataLabel = label
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    if copiedMetadataLabel == label { copiedMetadataLabel = nil }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isCopied ? "checkmark.circle.fill" : icon)
                        .font(.system(size: 10))
                        .foregroundColor(isCopied ? .green : (highlight ? .accentColor : .gray.opacity(0.5)))
                        .frame(width: 14)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(label.uppercased())
                            .font(.system(size: 7, weight: .semibold))
                            .tracking(0.8)
                            .foregroundColor(.gray.opacity(0.5))
                        Text(value)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(highlight ? .accentColor : .white)
                    }

                    Spacer()
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: "#1E1E1E")))
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                hoveredMetadataLabel = hovering ? label : nil
                if hovering { NSCursor.pointingHand.push() }
                else { NSCursor.pop() }
            }
            .overlay(alignment: .top) {
                if hoveredMetadataLabel == label || isCopied {
                    Text(isCopied ? "Copied!" : "Click to copy")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(isCopied ? .green : .white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color(hex: "#333333"))
                                .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                        )
                        .offset(y: -28)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.15), value: isCopied)
                }
            }
        }
    }

    // MARK: - Camera Source Card

    private func cameraSourceCard(take: Take, shot: Shot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sdcard.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.accentColor)
                Text("CAMERA SOURCE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(.gray)

                Spacer()

                // Auto-match by timestamp
                if !viewModel.cameraFiles.isEmpty {
                    Button {
                        let results = viewModel.autoMatchByTimestamp(project: project)
                        if !results.isEmpty {
                            viewModel.applyAutoMatchResults(results, project: &project)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.arrow.2.circlepath").font(.system(size: 9))
                            Text("Auto-Match").font(.system(size: 9, weight: .medium))
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(Color.accentColor))
                        .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)

                    // Match by clip name — only when OCR data exists
                    let hasAnyClipName = project.sequences.flatMap { $0.scenes }.flatMap { $0.shots }.flatMap { $0.takes }.contains { $0.cameraClipName != nil }
                    if hasAnyClipName {
                        Button {
                            let results = viewModel.autoMatchByClipName(project: project)
                            if !results.isEmpty {
                                viewModel.applyAutoMatchResults(results, project: &project)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "text.magnifyingglass").font(.system(size: 9))
                                Text("Clip Name").font(.system(size: 9, weight: .medium))
                            }
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Capsule().fill(Color(hex: "#3A3A3A")))
                            .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button { viewModel.selectCameraSourceDirectory() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.badge.plus").font(.system(size: 9))
                        Text("Browse").font(.system(size: 9, weight: .medium))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(Color(hex: "#3A3A3A")))
                    .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }

            // Current mapping
            HStack(spacing: 8) {
                Image(systemName: take.cameraSourceFileName != nil ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.system(size: 12))
                    .foregroundColor(take.cameraSourceFileName != nil ? .green : .gray.opacity(0.3))

                if let name = take.cameraSourceFileName, !name.isEmpty {
                    Text(name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                } else {
                    Text("No camera file mapped")
                        .font(.system(size: 11))
                        .foregroundColor(.gray.opacity(0.4))
                }

                Spacer()
            }

            // Camera files grid
            if !viewModel.cameraFiles.isEmpty {
                Divider().opacity(0.2)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.cameraFiles) { file in
                            let isMapped = file.mappedToTakeId == take.id

                            Button {
                                mapCameraFileToCurrentTake(file, take: take, shot: shot)
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: isMapped ? "film.fill" : "film")
                                        .font(.system(size: 14))
                                        .foregroundColor(isMapped ? .green : .gray.opacity(0.5))

                                    Text(file.fileName)
                                        .font(.system(size: 8, weight: .medium))
                                        .foregroundColor(.white.opacity(0.8))
                                        .lineLimit(1)

                                    Text(viewModel.formatFileSize(file.fileSize))
                                        .font(.system(size: 7))
                                        .foregroundColor(.gray.opacity(0.4))

                                    // Camera file creation date in same format as take timestamp
                                    if let created = file.creationDate {
                                        Text(Take.formatForCameraMatch(created))
                                            .font(.system(size: 7, weight: .medium, design: .monospaced))
                                            .foregroundColor(.accentColor.opacity(0.7))
                                            .lineLimit(1)
                                            .monospacedDigit()
                                    }
                                }
                                .frame(width: 90)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(isMapped ? Color.green.opacity(0.1) : Color(hex: "#2A2A2A"))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isMapped ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(height: 80)
            }
        }
        .padding(14)
        .background(Color(hex: "#252525"))
        .cornerRadius(10)
    }

    // MARK: - External Audio Card

    private func externalAudioCard(take: Take, shot: Shot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "waveform")
                    .font(.system(size: 11))
                    .foregroundColor(.accentColor)
                Text("EXTERNAL AUDIO")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(.gray)

                Spacer()

                // "Audio from Video" toggle
                Button {
                    updateTake(take, in: shot) {
                        $0.useAudioFromVideo.toggle()
                        if $0.useAudioFromVideo { $0.externalAudioFileName = nil }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: take.useAudioFromVideo ? "checkmark.circle.fill" : "video.fill")
                            .font(.system(size: 9))
                        Text("Audio from Video")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(take.useAudioFromVideo ? Color.purple.opacity(0.2) : Color(hex: "#3A3A3A")))
                    .foregroundColor(take.useAudioFromVideo ? .purple : .gray)
                    .overlay(Capsule().stroke(take.useAudioFromVideo ? Color.purple.opacity(0.4) : Color.clear, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help("Use audio track from the video file instead of external audio")

                if !take.useAudioFromVideo {
                    Button { viewModel.selectAudioDirectory() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "folder.badge.plus").font(.system(size: 9))
                            Text("Browse").font(.system(size: 9, weight: .medium))
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(Color(hex: "#3A3A3A")))
                        .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Current mapping
            if take.useAudioFromVideo {
                HStack(spacing: 8) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.purple)
                    Text("Audio sourced from video file")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.purple.opacity(0.8))
                    Spacer()
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: take.externalAudioFileName != nil ? "checkmark.circle.fill" : "circle.dashed")
                        .font(.system(size: 12))
                        .foregroundColor(take.externalAudioFileName != nil ? .green : .gray.opacity(0.3))

                    if let name = take.externalAudioFileName, !name.isEmpty {
                        Text(name)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)

                        Spacer()

                        Button {
                            viewModel.clearAudioMapping(for: take, inShot: shot, project: &project)
                            if let updatedTake = findTake(take.id, inShot: shot) {
                                viewModel.selectedTake = updatedTake
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.gray.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("No external audio mapped")
                            .font(.system(size: 11))
                            .foregroundColor(.gray.opacity(0.4))

                        Spacer()
                    }
                }
            }

            // Audio files grid
            if !take.useAudioFromVideo && !viewModel.audioFiles.isEmpty {
                Divider().opacity(0.2)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.audioFiles) { file in
                            let isMapped = take.externalAudioFileName == file.fileName

                            Button {
                                viewModel.mapAudioFile(file, toTake: take, inShot: shot, project: &project)
                                if let updatedTake = findTake(take.id, inShot: shot) {
                                    viewModel.selectedTake = updatedTake
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: isMapped ? "waveform.circle.fill" : "waveform")
                                        .font(.system(size: 14))
                                        .foregroundColor(isMapped ? .green : .gray.opacity(0.5))

                                    Text(file.fileName)
                                        .font(.system(size: 8, weight: .medium))
                                        .foregroundColor(.white.opacity(0.8))
                                        .lineLimit(1)

                                    Text(viewModel.formatFileSize(file.fileSize))
                                        .font(.system(size: 7))
                                        .foregroundColor(.gray.opacity(0.4))

                                    if let created = file.creationDate {
                                        Text(Take.formatForCameraMatch(created))
                                            .font(.system(size: 7, weight: .medium, design: .monospaced))
                                            .foregroundColor(.accentColor.opacity(0.7))
                                            .lineLimit(1)
                                            .monospacedDigit()
                                    }
                                }
                                .frame(width: 90)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(isMapped ? Color.green.opacity(0.1) : Color(hex: "#2A2A2A"))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isMapped ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(height: 80)
            }
        }
        .padding(14)
        .background(Color(hex: "#252525"))
        .cornerRadius(10)
    }

    /// Helper to find a take in the project after mutation
    private func findTake(_ takeId: String, inShot shot: Shot) -> Take? {
        for seq in project.sequences {
            for scene in seq.scenes {
                for s in scene.shots where s.id == shot.id {
                    return s.takes.first { $0.id == takeId }
                }
            }
        }
        return nil
    }

    // MARK: - Tags Card

    private func tagsCard(take: Take, shot: Shot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.accentColor)
                Text("TAGS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(.gray)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(take.tags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text(tag)
                                .font(.system(size: 10, weight: .medium))
                            Button {
                                updateTake(take, in: shot) { $0.tags.removeAll { $0 == tag } }
                            } label: {
                                Image(systemName: "xmark").font(.system(size: 7, weight: .bold))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .foregroundColor(.white)
                        .background(Capsule().fill(Color.accentColor.opacity(0.6)))
                    }

                    // Add tag inline
                    HStack(spacing: 4) {
                        Image(systemName: "plus").font(.system(size: 8)).foregroundColor(.gray)
                        TextField("add tag", text: Binding(
                            get: { "" },
                            set: { newValue in
                                if newValue.last == "\n" || newValue.last == " " {
                                    let tag = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !tag.isEmpty {
                                        updateTake(take, in: shot) {
                                            if !$0.tags.contains(tag) { $0.tags.append(tag) }
                                        }
                                    }
                                }
                            }
                        ))
                        .textFieldStyle(.plain)
                        .font(.system(size: 9))
                        .frame(width: 50)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(Color(hex: "#3A3A3A")))
                }
            }
        }
        .padding(14)
        .background(Color(hex: "#252525"))
        .cornerRadius(10)
    }

    // MARK: - Compare Panel

    private enum CompareSide { case left, right }

    private var comparePanel: some View {
        VStack(spacing: 0) {
            // Compare toolbar
            HStack(spacing: 12) {
                Image(systemName: "square.split.2x1.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                Text("COMPARE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(.gray)

                Spacer()

                // Sync playback toggle
                Button {
                    compareSyncPlayback.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: compareSyncPlayback ? "link" : "link.badge.plus")
                            .font(.system(size: 9))
                        Text(compareSyncPlayback ? "Synced" : "Independent")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .foregroundColor(compareSyncPlayback ? .white : .gray)
                    .background(Capsule().fill(compareSyncPlayback ? Color.accentColor.opacity(0.6) : Color(hex: "#3A3A3A")))
                }
                .buttonStyle(.plain)

                // Play both
                Button { comparePlayPause() } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                        .padding(7)
                        .background(Circle().fill(Color.accentColor))
                }
                .buttonStyle(.plain)

                // Restart both
                Button { compareSeekToStart() } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                        .padding(7)
                        .background(Circle().fill(Color(hex: "#3A3A3A")))
                }
                .buttonStyle(.plain)

                // Full screen compare
                Button { isCompareFullScreen = true } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                        .padding(7)
                        .background(Circle().fill(Color(hex: "#3A3A3A")))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(hex: "#1E1E1E"))

            Divider().opacity(0.3)

            // Side-by-side panels
            HStack(spacing: 1) {
                compareSideView(
                    side: .left,
                    take: compareLeftTake,
                    shot: compareLeftShot,
                    scene: compareLeftScene,
                    player: compareLeftPlayer
                )

                // Center divider
                Rectangle()
                    .fill(Color(nsColor: .separatorColor).opacity(0.3))
                    .frame(width: 1)

                compareSideView(
                    side: .right,
                    take: compareRightTake,
                    shot: compareRightShot,
                    scene: compareRightScene,
                    player: compareRightPlayer
                )
            }
        }
        .background(Color(hex: "#1A1A1A"))
    }

    private func compareSideView(side: CompareSide, take: Take?, shot: Shot?, scene: DCScene?, player: AVPlayer?) -> some View {
        VStack(spacing: 0) {
            // Take selector
            compareTakeSelector(side: side, currentTake: take, currentShot: shot, currentScene: scene)

            // Video player
            ZStack {
                Color.black

                if let player {
                    VideoPlayer(player: player)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: side == .left ? "a.square" : "b.square")
                            .font(.system(size: 32))
                            .foregroundColor(.gray.opacity(0.15))
                        Text(side == .left ? "Select Take A" : "Select Take B")
                            .font(.system(size: 11))
                            .foregroundColor(.gray.opacity(0.3))
                        Text(side == .left ? "Use the dropdown above" : "Right-click a take in the sidebar")
                            .font(.system(size: 9))
                            .foregroundColor(.gray.opacity(0.2))
                    }
                }
            }
            .aspectRatio(16/9, contentMode: .fit)
            .cornerRadius(6)
            .padding(.horizontal, 10)
            .padding(.top, 8)

            // Take info + rating
            if let take, let shot {
                compareInfoBar(take: take, shot: shot, scene: scene, side: side)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func compareTakeSelector(side: CompareSide, currentTake: Take?, currentShot: Shot?, currentScene: DCScene?) -> some View {
        HStack(spacing: 8) {
            // Side label
            Text(side == .left ? "A" : "B")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(side == .left ? Color.accentColor : Color.orange))

            if side == .left {
                // Left side: keep the dropdown Menu for Take A
                Menu {
                    let allScenes = project.sequences.flatMap { $0.scenes }
                    ForEach(allScenes, id: \.name) { scene in
                        if !scene.shots.flatMap(\.takes).isEmpty {
                            Menu(scene.name) {
                                ForEach(scene.shots, id: \.shotId) { shot in
                                    if !shot.takes.isEmpty {
                                        Menu("Shot #\(shot.shotId) — \(shot.shotType)") {
                                            ForEach(shot.takes.sorted(by: { $0.takeNumber < $1.takeNumber })) { take in
                                                Button {
                                                    setCompareTake(side: .left, take: take, shot: shot, scene: scene)
                                                } label: {
                                                    HStack {
                                                        if compareLeftTake?.id == take.id {
                                                            Image(systemName: "checkmark")
                                                        }
                                                        Label("Take \(take.takeNumber) — \(take.rating.rawValue)", systemImage: take.rating.icon)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    compareTakeLabel(take: currentTake, shot: currentShot, scene: currentScene, showChevron: true)
                }
                .menuStyle(.borderlessButton)
            } else {
                // Right side: read-only label — use right-click in sidebar to select
                compareTakeLabel(take: currentTake, shot: currentShot, scene: currentScene, showChevron: false)
            }

            Spacer()

            // Swap button (only on left side)
            if side == .left {
                Button { swapCompareSides() } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.gray.opacity(0.5))
                        .padding(6)
                        .background(Circle().fill(Color(hex: "#3A3A3A")))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(hex: "#222222"))
    }

    private func compareTakeLabel(take: Take?, shot: Shot?, scene: DCScene?, showChevron: Bool) -> some View {
        HStack(spacing: 6) {
            if let take, let shot, let scene {
                Circle()
                    .fill(ratingColor(take.rating))
                    .frame(width: 6, height: 6)
                Text("\(scene.name) > Shot #\(shot.shotId) > T\(take.takeNumber)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
            } else {
                Text(showChevron ? "Choose a take..." : "Right-click a take in the sidebar")
                    .font(.system(size: 10))
                    .foregroundColor(.gray.opacity(0.5))
            }
            if showChevron {
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(hex: "#2A2A2A"))
        .cornerRadius(6)
    }

    private func compareInfoBar(take: Take, shot: Shot, scene: DCScene?, side: CompareSide) -> some View {
        VStack(spacing: 8) {
            // Rating chips
            HStack(spacing: 4) {
                compareRatingChip(take: take, shot: shot, rating: .circle)
                compareRatingChip(take: take, shot: shot, rating: .alt)
                compareRatingChip(take: take, shot: shot, rating: .ng)

                Spacer()

                // Duration
                Text(viewModel.formatDuration(take.durationSeconds))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .monospacedDigit()
            }

            // Metadata row
            HStack(spacing: 12) {
                if let ts = take.formattedStartTimestamp {
                    HStack(spacing: 4) {
                        Image(systemName: "clock").font(.system(size: 8)).foregroundColor(.gray.opacity(0.4))
                        Text(ts)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.6))
                            .monospacedDigit()
                    }
                }

                if !take.notes.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "note.text").font(.system(size: 8)).foregroundColor(.gray.opacity(0.4))
                        Text(take.notes)
                            .font(.system(size: 9))
                            .foregroundColor(.gray.opacity(0.6))
                            .lineLimit(1)
                    }
                }

                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func compareRatingChip(take: Take, shot: Shot, rating: TakeRating) -> some View {
        let isSelected = take.rating == rating

        return Button {
            updateTake(take, in: shot) { $0.rating = isSelected ? .none : rating }
            // Refresh compare selections with updated take
            refreshCompareSelections()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: rating.icon).font(.system(size: 8))
                Text(rating.rawValue).font(.system(size: 9, weight: isSelected ? .semibold : .medium))
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .foregroundColor(isSelected ? .white : ratingColor(rating))
            .background(Capsule().fill(isSelected ? ratingColor(rating) : Color(hex: "#3A3A3A")))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Compare Actions

    private func setCompareTake(side: CompareSide, take: Take, shot: Shot, scene: DCScene) {
        switch side {
        case .left:
            compareLeftTake = take
            compareLeftShot = shot
            compareLeftScene = scene
            setupComparePlayer(side: .left)
        case .right:
            compareRightTake = take
            compareRightShot = shot
            compareRightScene = scene
            setupComparePlayer(side: .right)
        }
    }

    private func setupComparePlayer(side: CompareSide) {
        guard let dir = projectDir else { return }
        let take = side == .left ? compareLeftTake : compareRightTake
        guard let videoPath = take?.capturedVideoPath else {
            if side == .left { compareLeftPlayer = nil } else { compareRightPlayer = nil }
            return
        }
        let url = dir.appendingPathComponent(videoPath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            if side == .left { compareLeftPlayer = nil } else { compareRightPlayer = nil }
            return
        }
        let player = AVPlayer(url: url)
        if side == .left { compareLeftPlayer = player } else { compareRightPlayer = player }
    }

    private func swapCompareSides() {
        let tempTake = compareLeftTake
        let tempShot = compareLeftShot
        let tempScene = compareLeftScene
        let tempPlayer = compareLeftPlayer

        compareLeftTake = compareRightTake
        compareLeftShot = compareRightShot
        compareLeftScene = compareRightScene
        compareLeftPlayer = compareRightPlayer

        compareRightTake = tempTake
        compareRightShot = tempShot
        compareRightScene = tempScene
        compareRightPlayer = tempPlayer
    }

    private func comparePlayPause() {
        if let lp = compareLeftPlayer {
            if lp.rate > 0 { lp.pause() } else { lp.play() }
        }
        if compareSyncPlayback, let rp = compareRightPlayer {
            if rp.rate > 0 { rp.pause() } else { rp.play() }
        }
    }

    private func compareSeekToStart() {
        compareLeftPlayer?.seek(to: .zero)
        if compareSyncPlayback {
            compareRightPlayer?.seek(to: .zero)
        }
    }

    private func tearDownComparePlayers() {
        compareLeftPlayer?.pause()
        compareRightPlayer?.pause()
        compareLeftPlayer = nil
        compareRightPlayer = nil
    }

    private func refreshCompareSelections() {
        // Re-fetch takes from the project after a rating change
        if let leftId = compareLeftTake?.id, let leftShotId = compareLeftShot?.shotId {
            for seq in project.sequences {
                for scene in seq.scenes {
                    for shot in scene.shots where shot.shotId == leftShotId {
                        if let take = shot.takes.first(where: { $0.id == leftId }) {
                            compareLeftTake = take
                            compareLeftShot = shot
                            compareLeftScene = scene
                        }
                    }
                }
            }
        }
        if let rightId = compareRightTake?.id, let rightShotId = compareRightShot?.shotId {
            for seq in project.sequences {
                for scene in seq.scenes {
                    for shot in scene.shots where shot.shotId == rightShotId {
                        if let take = shot.takes.first(where: { $0.id == rightId }) {
                            compareRightTake = take
                            compareRightShot = shot
                            compareRightScene = scene
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func ratingColor(_ rating: TakeRating) -> Color {
        switch rating {
        case .none: return .gray
        case .circle: return .green
        case .alt: return .orange
        case .ng: return .red
        }
    }

    /// Compact time-only formatter for navigator sidebar (HH:mm:ss)
    private static let curationCompactTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private func mapCameraFileToCurrentTake(_ file: CameraFile, take: Take, shot: Shot) {
        viewModel.mapCameraFile(file, toTake: take, inShot: shot, project: &project)
        viewModel.selectedTake = take
    }

    private func updateTake(_ take: Take, in shot: Shot, modify: (inout Take) -> Void) {
        for seqIdx in project.sequences.indices {
            for sceneIdx in project.sequences[seqIdx].scenes.indices {
                for shotIdx in project.sequences[seqIdx].scenes[sceneIdx].shots.indices {
                    let s = project.sequences[seqIdx].scenes[sceneIdx].shots[shotIdx]
                    if s.id == shot.id {
                        for takeIdx in project.sequences[seqIdx].scenes[sceneIdx].shots[shotIdx].takes.indices {
                            if project.sequences[seqIdx].scenes[sceneIdx].shots[shotIdx].takes[takeIdx].id == take.id {
                                modify(&project.sequences[seqIdx].scenes[sceneIdx].shots[shotIdx].takes[takeIdx])
                                viewModel.selectedTake = project.sequences[seqIdx].scenes[sceneIdx].shots[shotIdx].takes[takeIdx]
                            }
                        }
                        project.sequences[seqIdx].scenes[sceneIdx].shots[shotIdx].updateStatusFromTakes()
                    }
                }
            }
        }
    }

    private func deleteTake(_ take: Take, in shot: Shot) {
        for seqIdx in project.sequences.indices {
            for sceneIdx in project.sequences[seqIdx].scenes.indices {
                for shotIdx in project.sequences[seqIdx].scenes[sceneIdx].shots.indices {
                    let s = project.sequences[seqIdx].scenes[sceneIdx].shots[shotIdx]
                    if s.id == shot.id {
                        project.sequences[seqIdx].scenes[sceneIdx].shots[shotIdx].takes.removeAll { $0.id == take.id }
                        project.sequences[seqIdx].scenes[sceneIdx].shots[shotIdx].updateStatusFromTakes()
                        // Clear selection if the deleted take was selected
                        if viewModel.selectedTake?.id == take.id {
                            let remaining = project.sequences[seqIdx].scenes[sceneIdx].shots[shotIdx].takes
                            viewModel.selectedTake = remaining.first
                            if remaining.isEmpty {
                                viewModel.selectedShot = nil
                                viewModel.selectedScene = nil
                            }
                        }
                        return
                    }
                }
            }
        }
    }
}

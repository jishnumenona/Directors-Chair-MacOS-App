//
// CurationView+Detail.swift
//
// Extracted from CurationView.swift (WS9.1 god-file decomposition).
// Members moved verbatim into an extension; private -> internal.
//

import SwiftUI
import AVKit
import DirectorsChairCore
import DirectorsChairViews

extension CurationView {

    // MARK: - Detail Panel

    var detailPanel: some View {
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

    var emptyDetailView: some View {
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

    func noTakesDetailView(shot: Shot) -> some View {
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

    func takeReviewView(take: Take, shot: Shot, scene: DCScene) -> some View {
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

    func heroHeader(take: Take, shot: Shot, scene: DCScene) -> some View {
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

    enum ConnectionStatus {
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
    func takeStatusIcons(take: Take) -> some View {
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

    func statusBadge(icon: String, status: ConnectionStatus, label: String) -> some View {
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

    func videoPreview(take: Take) -> some View {
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

    var videoPlaceholder: some View {
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

    func audioCueTimeline(take: Take, shot: Shot) -> some View {
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

    var detectionStatusText: String {
        switch viewModel.detectionStatus {
        case .idle: return "Starting..."
        case .extractingAudio: return "Extracting audio..."
        case .recognizingSpeech(let progress): return "Recognizing speech \(Int(progress * 100))%..."
        case .analyzing: return "Analyzing words..."
        case .completed: return "Done"
        case .failed(let msg): return "Failed: \(msg)"
        }
    }

    func audioCueTimelineBar(take: Take) -> some View {
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

    func audioCueTimestampReadout(take: Take) -> some View {
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
}

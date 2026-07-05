//
// CurationView+Compare.swift
//
// Extracted from CurationView.swift (WS9.1 god-file decomposition).
// Members moved verbatim into an extension; private -> internal.
//

import SwiftUI
import AVKit
import DirectorsChairCore
import DirectorsChairViews

extension CurationView {

    var comparePanel: some View {
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

    func compareSideView(side: CompareSide, take: Take?, shot: Shot?, scene: DCScene?, player: AVPlayer?) -> some View {
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

    func compareTakeSelector(side: CompareSide, currentTake: Take?, currentShot: Shot?, currentScene: DCScene?) -> some View {
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

    func compareTakeLabel(take: Take?, shot: Shot?, scene: DCScene?, showChevron: Bool) -> some View {
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

    func compareInfoBar(take: Take, shot: Shot, scene: DCScene?, side: CompareSide) -> some View {
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

    func compareRatingChip(take: Take, shot: Shot, rating: TakeRating) -> some View {
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

    func setCompareTake(side: CompareSide, take: Take, shot: Shot, scene: DCScene) {
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

    func setupComparePlayer(side: CompareSide) {
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

    func swapCompareSides() {
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

    func comparePlayPause() {
        if let lp = compareLeftPlayer {
            if lp.rate > 0 { lp.pause() } else { lp.play() }
        }
        if compareSyncPlayback, let rp = compareRightPlayer {
            if rp.rate > 0 { rp.pause() } else { rp.play() }
        }
    }

    func compareSeekToStart() {
        compareLeftPlayer?.seek(to: .zero)
        if compareSyncPlayback {
            compareRightPlayer?.seek(to: .zero)
        }
    }

    func tearDownComparePlayers() {
        compareLeftPlayer?.pause()
        compareRightPlayer?.pause()
        compareLeftPlayer = nil
        compareRightPlayer = nil
    }

    func refreshCompareSelections() {
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

    func ratingColor(_ rating: TakeRating) -> Color {
        switch rating {
        case .none: return .gray
        case .circle: return .green
        case .alt: return .orange
        case .ng: return .red
        }
    }

    /// Compact time-only formatter for navigator sidebar (HH:mm:ss)
    static let curationCompactTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    func mapCameraFileToCurrentTake(_ file: CameraFile, take: Take, shot: Shot) {
        viewModel.mapCameraFile(file, toTake: take, inShot: shot, project: &project)
        viewModel.selectedTake = take
    }

    func updateTake(_ take: Take, in shot: Shot, modify: (inout Take) -> Void) {
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

    func deleteTake(_ take: Take, in shot: Shot) {
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

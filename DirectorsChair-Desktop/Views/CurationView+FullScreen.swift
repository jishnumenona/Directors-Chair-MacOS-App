//
// CurationView+FullScreen.swift
//
// Extracted from CurationView.swift (WS9.1 god-file decomposition).
// Members moved verbatim into an extension; private -> internal.
//

import SwiftUI
import AVKit
import DirectorsChairCore
import DirectorsChairViews

extension CurationView {

    // MARK: - Full Screen Video Player

    var fullScreenVideoPlayer: some View {
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

    var fullScreenComparePanel: some View {
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

    func fullScreenCompareSide(side: CompareSide, take: Take?, shot: Shot?, scene: DCScene?, player: AVPlayer?) -> some View {
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
}

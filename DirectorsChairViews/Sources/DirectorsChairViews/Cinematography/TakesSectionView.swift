// DirectorsChairViews/Sources/DirectorsChairViews/Cinematography/TakesSectionView.swift
//
// Takes management — horizontal filmstrip, live monitor, one-tap rating
// Matches KeyframeGallery / VideoSettingsCard design language

import SwiftUI
import AVFoundation
import AVKit
import DirectorsChairCore
import DirectorsChairServices

// Lightweight decode-only mirror of KeyMapping from the main app target
struct RemoteKeyInfo: Codable {
    let keyCode: UInt16
    let action: String
    let keyName: String
}

// MARK: - Takes Section View

public struct TakesSectionView: View {
    let shot: Shot
    let projectBasePath: URL?
    let onShotUpdated: (Shot) -> Void
    @ObservedObject var captureService: LiveCaptureService
    var onNavigateToCuration: ((Shot) -> Void)?

    @State var selectedTakeId: String?
    @State var newTagText: String = ""
    @State var isExpanded: Bool = true
    @State var hoveredTakeId: String?
    @State var isFullScreen: Bool = false
    @State var ratingFilter: TakeRating? = nil  // nil = show all

    // Debounced notes editing
    @State var editingNotes: String = ""
    @State var editingNotesTakeId: String?
    @State var notesDebounceTask: Task<Void, Never>?

    // Blind timestamp logging (no video source)
    @State var isTimestampMode: Bool = false   // user chose timestamp approach
    @State var isBlindLogging: Bool = false     // actively logging
    @State var blindLogStartTime: Date?
    @State var blindLogDuration: TimeInterval = 0
    @State var blindLogTakeId: String?
    @State var blindLogTimer: Timer?

    // Remote control armed state (drives record button color)
    @State var isRemoteArmed: Bool = false

    public init(
        shot: Shot,
        projectBasePath: URL?,
        onShotUpdated: @escaping (Shot) -> Void,
        captureService: LiveCaptureService,
        onNavigateToCuration: ((Shot) -> Void)? = nil
    ) {
        self.shot = shot
        self.projectBasePath = projectBasePath
        self.onShotUpdated = onShotUpdated
        self.captureService = captureService
        self.onNavigateToCuration = onNavigateToCuration
    }

    var sortedTakes: [Take] {
        shot.takes.sorted { $0.takeNumber < $1.takeNumber }
    }

    var filteredTakes: [Take] {
        guard let filter = ratingFilter else { return sortedTakes }
        return sortedTakes.filter { $0.rating == filter }
    }

    var selectedTake: Take? {
        guard let id = selectedTakeId else { return sortedTakes.first }
        return shot.takes.first { $0.id == id }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader

            if isExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    // Capture mode: live monitor, start monitoring, timestamp ready/active, or mode chooser
                    // Hide inline monitor when fullscreen is active (preview layer can only attach to one view)
                    if captureService.selectedDevice != nil && !isFullScreen {
                        liveMonitorCard
                    } else if isBlindLogging {
                        blindLoggingCard
                    } else if isTimestampMode {
                        timestampReadyCard
                    } else if captureService.defaultDevice != nil {
                        startMonitoringCard
                    } else {
                        captureModeChooser
                    }

                    // Review Bay (take strip + player + metadata)
                    if !shot.takes.isEmpty, let take = selectedTake {
                        takeReviewBay(take)
                    }

                    // Empty state (only when truly empty — no takes, no mode chosen)
                    if shot.takes.isEmpty && captureService.selectedDevice == nil && !isBlindLogging && !isTimestampMode && captureService.defaultDevice == nil {
                        emptyState
                    }

                }
                .padding(.top, 12)
            }
        }
        .padding(14)
        .background(Color(hex: "#252525"))
        .cornerRadius(10)
        .onAppear {
            // Just refresh available devices — don't auto-start the session.
            // The default device only pre-populates the picker; user starts preview explicitly.
            captureService.discoverDevices()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("remoteControl.startTakeRecording"))) { _ in
            handleRemoteStart()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("remoteControl.stopTakeRecording"))) { _ in
            handleRemoteStop()
        }
        .sheet(isPresented: $isFullScreen) {
            fullScreenMonitor
                .frame(minWidth: 1200, minHeight: 800)
        }
    }
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: [TakeRectCorner]) -> some View {
        clipShape(PartialRoundedRectangle(radius: radius, corners: corners))
    }
}

enum TakeRectCorner { case topLeft, topRight, bottomLeft, bottomRight }

struct PartialRoundedRectangle: Shape {
    var radius: CGFloat
    var corners: [TakeRectCorner]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tl = corners.contains(.topLeft) ? radius : 0
        let tr = corners.contains(.topRight) ? radius : 0
        let bl = corners.contains(.bottomLeft) ? radius : 0
        let br = corners.contains(.bottomRight) ? radius : 0

        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY + tr), radius: tr)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.maxX - br, y: rect.maxY), radius: br)
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.maxY - bl), radius: bl)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.minX + tl, y: rect.minY), radius: tl)
        return path
    }
}

// MARK: - Take Thumbnail View

/// Generates and displays a thumbnail from a video file
struct TakeThumbnailView: View {
    let videoURL: URL
    @State var thumbnail: NSImage?

    var body: some View {
        Group {
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color(hex: "#1A1A1A"))
                    .overlay(
                        Image(systemName: "film")
                            .font(.system(size: 14))
                            .foregroundColor(.gray.opacity(0.3))
                    )
            }
        }
        .onAppear { generateThumbnail() }
    }

    private func generateThumbnail() {
        Task {
            let asset = AVAsset(url: videoURL)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 240, height: 136)

            // Extract frame 2 seconds before end of video
            let duration = try await asset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)
            let targetSeconds = max(0, durationSeconds - 2.0)
            let time = CMTime(seconds: targetSeconds, preferredTimescale: 600)

            if let cgImage = try? await generator.image(at: time).image {
                await MainActor.run {
                    thumbnail = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                }
            }
        }
    }
}

// MARK: - Review Player View

/// Self-contained video player with transport bar, skip buttons, and seek bar with thumb knob
struct ReviewPlayerView: View {
    let videoURL: URL
    @State var player: AVPlayer?
    @State var isPlaying: Bool = false
    @State var currentTime: Double = 0
    @State var duration: Double = 0
    @State var timeObserver: Any?

    var body: some View {
        VStack(spacing: 0) {
            // Video viewport — clean, no overlaid controls
            ZStack {
                if let player {
                    TakeAVPlayerView(player: player)
                        .aspectRatio(16/9, contentMode: .fit)
                        .frame(maxHeight: 320)
                        .background(Color.black)
                } else {
                    Rectangle()
                        .fill(Color.black)
                        .aspectRatio(16/9, contentMode: .fit)
                        .frame(maxHeight: 320)
                        .overlay(ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)))
                }
            }
            .cornerRadius(8, corners: [.topLeft, .topRight])

            // Transport bar — below video, always accessible
            HStack(spacing: 10) {
                // Skip back 5s
                Button { skip(-5) } label: {
                    Image(systemName: "gobackward.5")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)

                // Play / Pause — prominent button
                Button { togglePlay() } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30)
                        .background(
                            Circle().fill(isPlaying ? Color.accentColor : Color(hex: "#3A3A3A"))
                        )
                }
                .buttonStyle(.plain)

                // Skip forward 5s
                Button { skip(5) } label: {
                    Image(systemName: "goforward.5")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)

                // Current time
                Text(formatTime(currentTime))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                    .monospacedDigit()
                    .frame(width: 38, alignment: .trailing)

                // Seek bar with visible thumb knob
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Track background
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: "#3A3A3A"))
                            .frame(height: 4)
                        // Filled portion
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.accentColor)
                            .frame(width: duration > 0 ? geo.size.width * CGFloat(currentTime / duration) : 0, height: 4)
                        // Thumb knob
                        if duration > 0 {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 10, height: 10)
                                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                                .offset(x: max(0, min(geo.size.width - 10, geo.size.width * CGFloat(currentTime / duration) - 5)))
                        }
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let fraction = max(0, min(1, value.location.x / geo.size.width))
                                let seekTime = fraction * duration
                                player?.seek(to: CMTime(seconds: seekTime, preferredTimescale: 600))
                                currentTime = seekTime
                            }
                    )
                }
                .frame(height: 20)

                // Duration
                Text(formatTime(duration))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.5))
                    .monospacedDigit()
                    .frame(width: 38, alignment: .leading)

                Spacer()

                // Open External
                Button {
                    NSWorkspace.shared.open(videoURL)
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 10))
                        .foregroundColor(.gray.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help("Open in external player")

                // Reveal in Finder
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([videoURL])
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 10))
                        .foregroundColor(.gray.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help("Reveal in Finder")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(hex: "#1A1A1A"))
            .cornerRadius(8, corners: [.bottomLeft, .bottomRight])
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(hex: "#3A3A3A"), lineWidth: 1)
        )
        .onAppear { setupPlayer() }
        .onDisappear { cleanupPlayer() }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("toggleShotVideoPlayback"))) { _ in
            togglePlay()
        }
    }

    private func setupPlayer() {
        let avPlayer = AVPlayer(url: videoURL)
        player = avPlayer
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            currentTime = time.seconds
        }
        Task {
            if let dur = try? await avPlayer.currentItem?.asset.load(.duration) {
                await MainActor.run { duration = dur.seconds.isFinite ? dur.seconds : 0 }
            }
        }
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: avPlayer.currentItem, queue: .main) { _ in
            isPlaying = false
            avPlayer.seek(to: .zero)
            currentTime = 0
        }
    }

    private func cleanupPlayer() {
        player?.pause()
        if let observer = timeObserver { player?.removeTimeObserver(observer) }
        player = nil
    }

    private func togglePlay() {
        guard let player else { return }
        if isPlaying { player.pause() } else { player.play() }
        isPlaying.toggle()
    }

    private func skip(_ seconds: Double) {
        guard let player else { return }
        let newTime = max(0, min(duration, currentTime + seconds))
        player.seek(to: CMTime(seconds: newTime, preferredTimescale: 600))
        currentTime = newTime
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Take AVPlayer NSView Wrapper

struct TakeAVPlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .none
        view.showsFullScreenToggleButton = false
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
    }
}


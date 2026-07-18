//
// ShotVideoGenerationSection+Playback.swift
//
// Extracted from ShotVideoGenerationSection.swift (WS9.1 god-file decomposition).
// Behaviour unchanged.
//

import SwiftUI
import AVKit
import AppKit
import UniformTypeIdentifiers
import DirectorsChairCore
import DirectorsChairServices


// MARK: - Video Player Card

struct VideoPlayerCard: View {
    let videoURL: URL
    let duration: Double
    @Binding var showingFullScreen: Bool
    let onRegenerate: () -> Void
    let onDownload: () -> Void
    var onShowInFinder: (() -> Void)?
    var onShowPrompt: (() -> Void)?
    @State private var player: AVPlayer?
    @State private var isPlaying: Bool = false
    @State private var currentTime: Double = 0
    @State private var videoDuration: Double = 0
    @State private var videoAspect: CGFloat?
    @State private var timeObserver: Any?

    /// Player surface height is derived from the clip's real aspect ratio but
    /// capped so portrait clips don't take over the shot detail column.
    private static let maxPlayerHeight: CGFloat = 420

    /// Display aspect (width/height) from a video track's natural size and
    /// preferred transform (rotation metadata swaps the axes). Pure — tested.
    static func displayAspectRatio(naturalSize: CGSize, preferredTransform: CGAffineTransform) -> CGFloat? {
        let transformed = naturalSize.applying(preferredTransform)
        let width = abs(transformed.width)
        let height = abs(transformed.height)
        guard width > 0, height > 0 else { return nil }
        return width / height
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                Text("VIDEO PREVIEW")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(.gray)
                Spacer()
                // File path pill
                Text(videoURL.lastPathComponent)
                    .font(.system(size: 9))
                    .foregroundColor(.gray.opacity(0.5))
                    .lineLimit(1)
            }

            // Video Player — sized to the clip's real aspect ratio (16:9 until
            // the track metadata loads), height-capped so portrait clips fit.
            ZStack {
                if let player = player {
                    NativeVideoPlayerView(player: player)
                        .allowsHitTesting(false)
                        .aspectRatio(videoAspect ?? (16.0 / 9.0), contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: Self.maxPlayerHeight)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(hex: "#3A3A3A"), lineWidth: 1)
                        )
                        .overlay(
                            // Transparent overlay for click-to-play/pause
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture { togglePlayback() }
                        )
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "#1A1A1A"))
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: Self.maxPlayerHeight)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        )
                }
            }

            // Transport Controls
            VStack(spacing: 6) {
                // Seek Bar
                HStack(spacing: 8) {
                    Text(formatTime(currentTime))
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 40, alignment: .trailing)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // Track background
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(hex: "#3A3A3A"))
                                .frame(height: 4)

                            // Progress
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.accentColor)
                                .frame(width: videoDuration > 0 ? geo.size.width * CGFloat(currentTime / videoDuration) : 0, height: 4)

                            // Scrubber handle
                            Circle()
                                .fill(Color.white)
                                .frame(width: 10, height: 10)
                                .offset(x: videoDuration > 0 ? geo.size.width * CGFloat(currentTime / videoDuration) - 5 : -5)
                        }
                        .frame(height: 10)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let fraction = max(0, min(1, value.location.x / geo.size.width))
                                    let seekTime = Double(fraction) * videoDuration
                                    player?.seek(to: CMTime(seconds: seekTime, preferredTimescale: 600))
                                    currentTime = seekTime
                                }
                        )
                    }
                    .frame(height: 10)

                    Text(formatTime(videoDuration))
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 40, alignment: .leading)
                }

                // Play/Pause + Action Buttons
                HStack(spacing: 8) {
                    // Playback controls
                    HStack(spacing: 4) {
                        Button(action: { seekBackward() }) {
                            Image(systemName: "gobackward.5")
                                .font(.system(size: 11))
                                .frame(width: 28, height: 28)
                                .background(Color(hex: "#3A3A3A"))
                                .foregroundColor(.white)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)

                        Button(action: { togglePlayback() }) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 13))
                                .frame(width: 34, height: 28)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)

                        Button(action: { seekForward() }) {
                            Image(systemName: "goforward.5")
                                .font(.system(size: 11))
                                .frame(width: 28, height: 28)
                                .background(Color(hex: "#3A3A3A"))
                                .foregroundColor(.white)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    // Action buttons
                    if onShowPrompt != nil {
                        actionBtn(icon: "text.quote", label: "Show Prompt") { onShowPrompt?() }
                    }
                    actionBtn(icon: "arrow.up.left.and.arrow.down.right", label: "Full Screen") { showingFullScreen = true }
                    actionBtn(icon: "folder", label: "Show in Finder") { onShowInFinder?() }
                    actionBtn(icon: "square.and.arrow.down", label: "Export", action: onDownload)
                    actionBtn(icon: "arrow.triangle.2.circlepath", label: "Regenerate", action: onRegenerate)
                }
            }
        }
        .padding(12)
        .background(Color(hex: "#252525"))
        .cornerRadius(8)
        .onAppear { setupPlayer() }
        .onDisappear { cleanupPlayer() }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("toggleShotVideoPlayback"))) { _ in
            togglePlayback()
        }
    }

    private func setupPlayer() {
        let avPlayer = AVPlayer(url: videoURL)
        player = avPlayer

        // Observe time updates
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            currentTime = time.seconds
        }

        // Get video duration + the clip's real display aspect ratio
        Task {
            guard let asset = avPlayer.currentItem?.asset else { return }
            if let duration = try? await asset.load(.duration) {
                await MainActor.run {
                    videoDuration = duration.seconds.isFinite ? duration.seconds : self.duration
                }
            }
            if let track = try? await asset.loadTracks(withMediaType: .video).first,
               let (naturalSize, transform) = try? await track.load(.naturalSize, .preferredTransform),
               let aspect = Self.displayAspectRatio(naturalSize: naturalSize, preferredTransform: transform) {
                await MainActor.run { videoAspect = aspect }
            }
        }

        // Observe end of playback to reset
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: avPlayer.currentItem,
            queue: .main
        ) { _ in
            isPlaying = false
            avPlayer.seek(to: .zero)
            currentTime = 0
        }
    }

    private func cleanupPlayer() {
        player?.pause()
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        player = nil
    }

    private func togglePlayback() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }

    private func seekBackward() {
        guard let player = player else { return }
        let newTime = max(0, currentTime - 5)
        player.seek(to: CMTime(seconds: newTime, preferredTimescale: 600))
        currentTime = newTime
    }

    private func seekForward() {
        guard let player = player else { return }
        let newTime = min(videoDuration, currentTime + 5)
        player.seek(to: CMTime(seconds: newTime, preferredTimescale: 600))
        currentTime = newTime
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    @ViewBuilder
    private func actionBtn(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10))
                Text(label).font(.system(size: 10, weight: .medium))
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color(hex: "#3A3A3A")).foregroundColor(.white).cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Video Version Picker

struct VideoVersionPicker: View {
    let versions: [VideoVersion]
    let projectBasePath: URL?
    let onSelect: (VideoVersion) -> Void
    let onDelete: (VideoVersion) -> Void
    let onRename: (VideoVersion, String) -> Void
    let onShowInFinder: (VideoVersion) -> Void

    private var providerGroups: [(provider: VideoProvider?, versions: [VideoVersion])] {
        var grouped: [String: [VideoVersion]] = [:]
        for v in versions {
            let key = v.provider?.folderName ?? "_legacy"
            grouped[key, default: []].append(v)
        }
        // Order: known providers first (in enum order), then legacy
        var result: [(provider: VideoProvider?, versions: [VideoVersion])] = []
        for provider in VideoProvider.allCases {
            if let group = grouped[provider.folderName], !group.isEmpty {
                result.append((provider, group.sorted { $0.takeIndex < $1.takeIndex }))
            }
        }
        if let legacy = grouped["_legacy"], !legacy.isEmpty {
            result.append((nil, legacy.sorted { $0.timestamp > $1.timestamp }))
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "film.stack.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                Text("VIDEO TAKES")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(.gray)
                Spacer()
                Text("\(versions.count) take\(versions.count == 1 ? "" : "s")")
                    .font(.system(size: 9))
                    .foregroundColor(.gray.opacity(0.5))
            }

            // Provider sections
            ForEach(Array(providerGroups.enumerated()), id: \.offset) { _, group in
                VStack(alignment: .leading, spacing: 8) {
                    // Provider header
                    HStack(spacing: 6) {
                        if let provider = group.provider {
                            Image(systemName: provider.icon)
                                .font(.system(size: 10))
                                .foregroundColor(providerColor(provider))
                            Text(provider.displayName.uppercased())
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1.0)
                                .foregroundColor(providerColor(provider))
                        } else {
                            Image(systemName: "film")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                            Text("IMPORTED")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1.0)
                                .foregroundColor(.gray)
                        }
                        Text("\(group.versions.count)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.gray.opacity(0.5))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(4)
                    }

                    // Filmstrip for this provider
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(group.versions) { version in
                                VersionCard(
                                    version: version,
                                    providerColor: group.provider.map { providerColor($0) } ?? .gray,
                                    onSelect: onSelect,
                                    onDelete: onDelete,
                                    onRename: onRename,
                                    onShowInFinder: onShowInFinder
                                )
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(10)
                .background(Color(hex: "#1E1E1E"))
                .cornerRadius(8)
            }
        }
        .padding(14)
        .background(Color(hex: "#252525"))
        .cornerRadius(10)
    }

    private func providerColor(_ provider: VideoProvider) -> Color {
        switch provider {
        case .veo3: return .blue
        case .sora2: return .purple
        case .kling: return .orange
        }
    }
}

// MARK: - Version Card (with inline rename)

struct VersionCard: View {
    let version: VideoVersion
    let providerColor: Color
    let onSelect: (VideoVersion) -> Void
    let onDelete: (VideoVersion) -> Void
    let onRename: (VideoVersion, String) -> Void
    let onShowInFinder: (VideoVersion) -> Void

    @State private var isEditing: Bool = false
    @State private var editText: String = ""

    var body: some View {
        VStack(spacing: 5) {
            // Thumbnail
            Button(action: { onSelect(version) }) {
                ZStack {
                    VideoThumbnailView(videoURL: version.url)
                        .frame(width: 140, height: 85)
                        .clipped()
                        .cornerRadius(6)

                    // Selected badge
                    if version.isSelected {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.accentColor)
                                    .background(Circle().fill(Color.black).frame(width: 12, height: 12))
                            }
                            Spacer()
                        }
                        .padding(4)
                    }

                    // Take badge (bottom left)
                    VStack {
                        Spacer()
                        HStack {
                            Text("take \(version.takeIndex)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(providerColor.opacity(0.8))
                                .cornerRadius(3)
                            Spacer()
                        }
                    }
                    .padding(4)
                }
                .frame(width: 140, height: 85)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(version.isSelected ? Color.accentColor : Color(hex: "#3A3A3A"), lineWidth: version.isSelected ? 2 : 1)
                )
            }
            .buttonStyle(.plain)

            // Editable name
            if isEditing {
                HStack(spacing: 3) {
                    Text("take_\(version.takeIndex)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(providerColor)
                    TextField("name", text: $editText, onCommit: {
                        onRename(version, editText)
                        isEditing = false
                    })
                    .font(.system(size: 9))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color(nsColor: .quaternarySystemFill))
                    .cornerRadius(4)
                    .frame(maxWidth: 80)
                }
                .frame(width: 140)
            } else {
                HStack(spacing: 2) {
                    Text(version.displayName)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(width: 140, alignment: .center)
                .onTapGesture(count: 2) {
                    editText = version.userLabel
                    isEditing = true
                }
            }

            // Date + size
            VStack(spacing: 1) {
                Text(version.dateFormatted)
                    .font(.system(size: 8))
                    .foregroundColor(.gray.opacity(0.6))
                    .lineLimit(1)
                Text(version.fileSizeFormatted)
                    .font(.system(size: 8))
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
        .contextMenu {
            Button(action: { onSelect(version) }) {
                Label("Use This Take", systemImage: "checkmark.circle")
            }
            .disabled(version.isSelected)

            Button(action: {
                editText = version.userLabel
                isEditing = true
            }) {
                Label("Rename", systemImage: "pencil")
            }

            Button(action: { onShowInFinder(version) }) {
                Label("Show in Finder", systemImage: "folder")
            }

            Divider()

            Button(role: .destructive, action: { onDelete(version) }) {
                Label("Delete Take", systemImage: "trash")
            }
            .disabled(version.isSelected)
        }
    }
}

// MARK: - Video Thumbnail View

struct VideoThumbnailView: View {
    let videoURL: URL
    @State private var thumbnail: NSImage?

    var body: some View {
        Group {
            if let thumbnail = thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color(hex: "#1E1E1E"))
                    .overlay(
                        Image(systemName: "film")
                            .font(.system(size: 16))
                            .foregroundColor(.gray.opacity(0.4))
                    )
            }
        }
        .onAppear { generateThumbnail() }
    }

    private func generateThumbnail() {
        let asset = AVAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 260, height: 160)

        let time = CMTime(seconds: 0.1, preferredTimescale: 600)
        generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, cgImage, _, _, _ in
            guard let cgImage = cgImage else { return }
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            DispatchQueue.main.async {
                self.thumbnail = nsImage
            }
        }
    }
}

// MARK: - Prompt Editor Sheet

struct VideoPromptEditorSheet: View {
    @Binding var prompt: String
    @Binding var useCustom: Bool
    let autoPrompt: String
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Video Prompt").font(.headline).foregroundColor(.white)
                Spacer()
                Button("Done") { isPresented = false }
            }
            HStack(spacing: 12) {
                Button(action: { useCustom = false; prompt = autoPrompt }) {
                    Text("Auto-Generated").font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(useCustom ? Color(hex: "#3A3A3A") : Color.accentColor)
                        .foregroundColor(useCustom ? .gray : .white).cornerRadius(6)
                }
                .buttonStyle(.plain)
                Button(action: { useCustom = true }) {
                    Text("Custom").font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(useCustom ? Color.accentColor : Color(hex: "#3A3A3A"))
                        .foregroundColor(useCustom ? .white : .gray).cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            TextEditor(text: $prompt).font(.system(size: 12)).scrollContentBackground(.hidden)
                .padding(10).background(Color(hex: "#1A1A1A")).cornerRadius(8)
                .frame(minHeight: 200).disabled(!useCustom).opacity(useCustom ? 1.0 : 0.7)
            if !useCustom {
                Text("Switch to Custom to edit the prompt directly").font(.system(size: 10)).foregroundColor(.gray)
            }
        }
        .padding(20).frame(width: 500, height: 400).background(Color(hex: "#252525"))
    }
}

// MARK: - Full Screen Video Sheet

struct FullScreenVideoSheet: View {
    let videoURL: URL
    @Binding var isPresented: Bool
    @State private var player: AVPlayer?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 20)).foregroundColor(.gray)
                }
                .buttonStyle(.plain).padding()
            }
            if let player = player {
                NativeVideoPlayerView(player: player).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 800, minHeight: 500).background(Color.black)
        .onAppear { player = AVPlayer(url: videoURL); player?.play() }
        .onDisappear { player?.pause(); player = nil }
    }
}

// MARK: - Native Video Player (bypasses _AVKit_SwiftUI metadata crash on macOS 15)

class NonInteractiveAVPlayerView: AVPlayerView {
    override func scrollWheel(with event: NSEvent) {
        nextResponder?.scrollWheel(with: event)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
}

struct NativeVideoPlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> NonInteractiveAVPlayerView {
        let view = NonInteractiveAVPlayerView()
        view.player = player
        view.controlsStyle = .none
        view.showsFullScreenToggleButton = false
        return view
    }

    func updateNSView(_ nsView: NonInteractiveAVPlayerView, context: Context) {
        nsView.player = player
    }
}

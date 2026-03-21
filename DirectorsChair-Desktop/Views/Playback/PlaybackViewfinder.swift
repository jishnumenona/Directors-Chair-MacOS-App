//
//  PlaybackViewfinder.swift
//  DirectorsChair-Desktop
//
//  16:9 media display area showing shot preview images or videos,
//  with timecode overlay and shot info bar.
//

import SwiftUI
import AVKit
import DirectorsChairCore

struct PlaybackViewfinder: View {
    @ObservedObject var viewModel: PlaybackViewModel

    @State private var avPlayer: AVPlayer?
    @State private var currentVideoPath: String?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black

                if let item = viewModel.currentItem {
                    Group {
                        // Video content
                        if let videoPath = item.videoPath,
                           let videoURL = viewModel.resolvedVideoPath(for: videoPath),
                           FileManager.default.fileExists(atPath: videoURL.path) {
                            PlaybackAVPlayerView(player: avPlayer ?? AVPlayer())
                                .onAppear { setupVideo(url: videoURL, path: videoPath) }
                                .onChange(of: item.id) { _, _ in
                                    if let vp = item.videoPath,
                                       let url = viewModel.resolvedVideoPath(for: vp),
                                       FileManager.default.fileExists(atPath: url.path) {
                                        setupVideo(url: url, path: vp)
                                    } else {
                                        teardownVideo()
                                    }
                                }
                        }
                        // Preview image
                        else if let imgPath = item.previewImagePath,
                                let imgURL = viewModel.resolvedImagePath(for: imgPath),
                                let nsImage = NSImage(contentsOf: imgURL) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        }
                        // Placeholder
                        else {
                            VStack(spacing: 12) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.secondary)
                                Text("Shot \(item.shotId ?? 0)")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                if !item.description.isEmpty {
                                    Text(item.description)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.tertiary)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(3)
                                        .frame(maxWidth: 300)
                                }
                            }
                        }
                    }
                    .id(item.id)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "film")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No shots to play")
                            .font(.system(size: 14))
                            .foregroundStyle(.tertiary)
                    }
                }

                // Timecode overlay (top-left)
                VStack {
                    HStack {
                        Text("\(viewModel.currentTimecode) / \(viewModel.totalTimecode)")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.6))
                            .cornerRadius(4)
                            .padding(12)
                        Spacer()
                    }
                    Spacer()
                }

                // Subtitle overlay (above shot info bar)
                VStack {
                    Spacer()
                    if let subtitle = viewModel.currentSubtitle {
                        VStack(spacing: 2) {
                            Text(subtitle.character.uppercased())
                                .font(.system(size: 9, weight: .bold))
                                .tracking(0.8)
                                .foregroundStyle(.white.opacity(0.7))
                            Text(subtitle.text)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.6))
                        .cornerRadius(6)
                        .padding(.horizontal, 40)
                        .padding(.bottom, 48)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.15), value: subtitle.text)
                    }
                }

                // Shot info bar (bottom)
                VStack {
                    Spacer()
                    if let item = viewModel.currentItem {
                        HStack(spacing: 8) {
                            if let shotId = item.shotId {
                                Text("Shot \(shotId)")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            Text("•")
                                .foregroundStyle(.secondary)
                            Text(item.shotType)
                                .font(.system(size: 11))
                            if !item.cameraAngle.isEmpty {
                                Text("•")
                                    .foregroundStyle(.secondary)
                                Text(item.cameraAngle)
                                    .font(.system(size: 11))
                            }
                            Spacer()
                            Text(viewModel.currentSceneName)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            LinearGradient(
                                colors: [.black.opacity(0.7), .black.opacity(0.3), .clear],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .onChange(of: viewModel.isPlaying) { _, playing in
            if playing {
                avPlayer?.play()
            } else {
                avPlayer?.pause()
            }
        }
    }

    // MARK: - Video Management

    private func setupVideo(url: URL, path: String) {
        guard path != currentVideoPath else { return }
        currentVideoPath = path
        let player = AVPlayer(url: url)
        player.volume = Float(viewModel.effectiveVolume)
        self.avPlayer = player
        if viewModel.isPlaying {
            player.play()
        }
    }

    private func teardownVideo() {
        avPlayer?.pause()
        avPlayer = nil
        currentVideoPath = nil
    }
}

// MARK: - AVPlayer NSViewRepresentable

struct PlaybackAVPlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> PlaybackNonInteractiveAVPlayerView {
        let view = PlaybackNonInteractiveAVPlayerView()
        view.player = player
        view.controlsStyle = .none
        view.showsFullScreenToggleButton = false
        return view
    }

    func updateNSView(_ nsView: PlaybackNonInteractiveAVPlayerView, context: Context) {
        nsView.player = player
    }
}

class PlaybackNonInteractiveAVPlayerView: AVPlayerView {
    override func scrollWheel(with event: NSEvent) {
        nextResponder?.scrollWheel(with: event)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
}

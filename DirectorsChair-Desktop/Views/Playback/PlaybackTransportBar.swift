//
//  PlaybackTransportBar.swift
//  DirectorsChair-Desktop
//
//  Professional transport controls with scrubber, play/pause/stop,
//  skip forward/backward, speed control, and volume.
//

import SwiftUI

struct PlaybackTransportBar: View {
    @ObservedObject var viewModel: PlaybackViewModel

    @State private var isDraggingScrubber = false
    @State private var scrubTime: CGFloat = 0
    @State private var showTrackMixer = false

    var body: some View {
        VStack(spacing: 0) {
            // Scrubber
            scrubber

            // Transport controls
            HStack(spacing: 0) {
                // Left: Timecode
                HStack(spacing: 4) {
                    Text(viewModel.currentTimecode)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)
                    Text("/")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(viewModel.totalTimecode)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 120, alignment: .leading)

                Spacer()

                // Center: Transport buttons
                HStack(spacing: 4) {
                    transportButton("backward.end.fill", size: 12) { viewModel.goToStart() }
                    transportButton("backward.fill", size: 12) { viewModel.skipToPreviousScene() }
                    transportButton("chevron.left", size: 12) { viewModel.skipToPreviousShot() }

                    // Play/Pause — larger
                    Button(action: { viewModel.togglePlayPause() }) {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.accentColor.opacity(0.8))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    transportButton("chevron.right", size: 12) { viewModel.skipToNextShot() }
                    transportButton("forward.fill", size: 12) { viewModel.skipToNextScene() }
                    transportButton("backward.end.fill", size: 12) { viewModel.goToEnd() }
                        .rotationEffect(.degrees(180))

                    Divider()
                        .frame(height: 20)
                        .padding(.horizontal, 4)

                    transportButton("stop.fill", size: 12) { viewModel.stop() }
                }

                Spacer()

                // Right: Speed + Track Mixer + Volume
                HStack(spacing: 12) {
                    // Speed picker
                    Menu {
                        ForEach([0.5, 1.0, 1.5, 2.0], id: \.self) { speed in
                            Button(action: { viewModel.playbackSpeed = speed }) {
                                HStack {
                                    Text(speed == 1.0 ? "1x" : "\(speed, specifier: "%.1f")x")
                                    if viewModel.playbackSpeed == speed {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Text(viewModel.speedLabel)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color(nsColor: .quaternarySystemFill))
                            .cornerRadius(4)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()

                    // Track mixer (per-character mute/unmute)
                    if !viewModel.audioCharacters.isEmpty {
                        Button(action: { showTrackMixer.toggle() }) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "person.wave.2")
                                    .font(.system(size: 11))
                                    .foregroundStyle(viewModel.mutedTracks.isEmpty ? .secondary : Color.accentColor)
                                    .frame(width: 20, height: 20)

                                if !viewModel.mutedTracks.isEmpty {
                                    Circle()
                                        .fill(Color.orange)
                                        .frame(width: 6, height: 6)
                                        .offset(x: 2, y: -2)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showTrackMixer, arrowEdge: .top) {
                            trackMixerPopover
                        }
                    }

                    // Volume
                    HStack(spacing: 4) {
                        Button(action: { viewModel.isMuted.toggle() }) {
                            Image(systemName: viewModel.isMuted ? "speaker.slash.fill" : volumeIcon)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .frame(width: 16)
                        }
                        .buttonStyle(.plain)

                        Slider(value: $viewModel.volume, in: 0...1)
                            .frame(width: 60)
                            .controlSize(.mini)
                    }
                }
                .frame(minWidth: 180, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Scrubber

    private var scrubber: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let displayTime = isDraggingScrubber ? scrubTime : viewModel.currentTime
            let ratio = viewModel.totalDuration > 0 ? displayTime / viewModel.totalDuration : 0
            let x = ratio * width

            ZStack(alignment: .leading) {
                // Track background
                Rectangle()
                    .fill(Color(nsColor: .separatorColor).opacity(0.3))

                // Progress fill
                Rectangle()
                    .fill(Color.accentColor.opacity(0.5))
                    .frame(width: max(0, x))

                // Scene boundary markers
                ForEach(viewModel.sceneBoundaries) { boundary in
                    let bx = viewModel.totalDuration > 0 ? (boundary.time / viewModel.totalDuration) * width : 0
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 1)
                        .offset(x: bx)
                }

                // Playhead
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2)
                    .offset(x: max(0, x - 1))
                    .shadow(color: .black.opacity(0.5), radius: 2)
            }
            .frame(height: 6)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDraggingScrubber = true
                        let ratio = max(0, min(1, value.location.x / width))
                        scrubTime = ratio * viewModel.totalDuration
                    }
                    .onEnded { value in
                        let ratio = max(0, min(1, value.location.x / width))
                        let time = ratio * viewModel.totalDuration
                        viewModel.seekTo(time: time)
                        isDraggingScrubber = false
                    }
            )
        }
        .frame(height: 6)
    }

    // MARK: - Helpers

    private func transportButton(_ systemName: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    // MARK: - Track Mixer Popover

    private var trackMixerPopover: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "person.wave.2")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text("DIALOGUE TRACKS")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                Spacer()
                if !viewModel.mutedTracks.isEmpty {
                    Button("Unmute All") {
                        viewModel.mutedTracks.removeAll()
                    }
                    .font(.system(size: 9, weight: .medium))
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            Divider()

            ForEach(viewModel.audioCharacters, id: \.self) { character in
                let isMuted = viewModel.mutedTracks.contains(character)
                Button(action: { viewModel.toggleTrackMute(character) }) {
                    HStack(spacing: 8) {
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(isMuted ? .secondary : Color.accentColor)
                            .frame(width: 14)

                        Text(character)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(isMuted ? .secondary : .primary)
                            .strikethrough(isMuted, color: .secondary)

                        Spacer()

                        if isMuted {
                            Text("MUTED")
                                .font(.system(size: 8, weight: .bold))
                                .tracking(0.5)
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 6)
        .frame(minWidth: 180)
    }

    private var volumeIcon: String {
        if viewModel.volume == 0 { return "speaker.fill" }
        if viewModel.volume < 0.33 { return "speaker.wave.1.fill" }
        if viewModel.volume < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}

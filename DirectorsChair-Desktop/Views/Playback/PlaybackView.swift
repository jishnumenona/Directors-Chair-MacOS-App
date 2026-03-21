//
//  PlaybackView.swift
//  DirectorsChair-Desktop
//
//  Main playback container: viewfinder (left) + metadata sidebar (right).
//  The playhead moves on the existing Timeline panel (bottom of screen),
//  synced directly by the PlaybackViewModel (no SwiftUI onChange overhead).
//

import SwiftUI
import DirectorsChairCore
import DirectorsChairViews

struct PlaybackView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var timelineViewModel: TimelineViewModel
    @StateObject private var playbackVM = PlaybackViewModel()

    @State private var sidebarWidth: CGFloat = 300
    @State private var keyMonitor: Any?

    private let minSidebarWidth: CGFloat = 200
    private let maxSidebarWidth: CGFloat = 500

    var body: some View {
        HStack(spacing: 0) {
            // Left: Viewfinder + Transport
            VStack(spacing: 0) {
                // Viewfinder (expands to fill)
                PlaybackViewfinder(viewModel: playbackVM)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)

                // Transport Bar
                PlaybackTransportBar(viewModel: playbackVM)
            }

            // Resizable divider
            PlaybackSidebarDivider(sidebarWidth: $sidebarWidth, minWidth: minSidebarWidth, maxWidth: maxSidebarWidth)

            // Right: Metadata Sidebar
            PlaybackMetadataSidebar(viewModel: playbackVM)
                .frame(width: sidebarWidth)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            // Wire up the timeline VM for direct playhead sync
            playbackVM.timelineViewModel = timelineViewModel
            timelineViewModel.playheadActive = true
            timelineViewModel.playheadTime = 0

            // When user clicks/drags the timeline ruler → seek playback to that time
            timelineViewModel.onPlayheadSeeked = { [weak playbackVM] time in
                playbackVM?.seekTo(time: time)
            }

            // When user toggles mute from timeline context menu → sync to playback
            timelineViewModel.onTrackMuteToggled = { [weak playbackVM] character in
                playbackVM?.toggleTrackMute(character)
            }

            buildPlaylist()
            installKeyMonitor()

            // Auto-play if triggered by global space bar shortcut
            if coordinator.shouldAutoPlay {
                coordinator.shouldAutoPlay = false
                // Small delay to let the playlist build complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    playbackVM.play()
                }
            }
        }
        .onChange(of: projectViewModel.project.sequences.count) { _, _ in
            buildPlaylist()
        }
        .onChange(of: playbackVM.mutedTracks) { _, newValue in
            timelineViewModel.mutedTracks = newValue
        }
        .onDisappear {
            playbackVM.stop()
            timelineViewModel.playheadActive = false
            timelineViewModel.playheadTime = nil
            timelineViewModel.onPlayheadSeeked = nil
            timelineViewModel.onTrackMuteToggled = nil
            timelineViewModel.mutedTracks.removeAll()
            removeKeyMonitor()
        }
    }

    private func buildPlaylist() {
        let basePath = projectViewModel.projectPath?.deletingLastPathComponent()
        playbackVM.buildPlaylist(from: projectViewModel.project, basePath: basePath)
    }

    // MARK: - Keyboard Shortcut Monitor

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak playbackVM] event in
            // Don't intercept if a text field is focused
            if let responder = event.window?.firstResponder,
               responder is NSTextView || responder is NSTextField {
                return event
            }

            switch event.keyCode {
            case 49: // Space bar
                playbackVM?.togglePlayPause()
                return nil
            case 123: // Left arrow
                if event.modifierFlags.contains(.command) {
                    playbackVM?.skipToPreviousScene()
                } else {
                    playbackVM?.skipToPreviousShot()
                }
                return nil
            case 124: // Right arrow
                if event.modifierFlags.contains(.command) {
                    playbackVM?.skipToNextScene()
                } else {
                    playbackVM?.skipToNextShot()
                }
                return nil
            default:
                return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
}

// MARK: - Sidebar Resize Divider

private struct PlaybackSidebarDivider: View {
    @Binding var sidebarWidth: CGFloat
    let minWidth: CGFloat
    let maxWidth: CGFloat

    @State private var isDragging = false

    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(width: 5)
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        isDragging = true
                        // Dragging left increases sidebar width, dragging right decreases
                        let delta = -value.translation.width
                        let newWidth = sidebarWidth + delta
                        sidebarWidth = max(minWidth, min(maxWidth, newWidth))
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 1)
                    .fill(isDragging ? Color.accentColor : Color.clear)
                    .frame(width: 3)
            )
    }
}

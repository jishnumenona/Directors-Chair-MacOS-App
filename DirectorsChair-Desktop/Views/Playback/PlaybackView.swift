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
import DirectorsChairServices

struct PlaybackView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var timelineViewModel: TimelineViewModel
    @StateObject private var playbackVM = PlaybackViewModel()
    @StateObject private var storyteller = StorytellerPlaybackController()

    @State private var sidebarWidth: CGFloat = 300
    @State private var keyMonitor: Any?
    @State private var showStorytellerCostSheet = false

    private let minSidebarWidth: CGFloat = 200
    private let maxSidebarWidth: CGFloat = 500

    var body: some View {
        HStack(spacing: 0) {
            // Left: Viewfinder + Transport
            VStack(spacing: 0) {
                // Viewfinder (expands to fill)
                PlaybackViewfinder(viewModel: playbackVM, storyteller: storyteller)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)

                // Transport Bar
                PlaybackTransportBar(viewModel: playbackVM,
                                     storytellerActive: storyteller.isActive,
                                     onStoryteller: { toggleStoryteller() })

                // Storyteller scene strip (visible while the mode is open)
                if storyteller.isActive {
                    StorytellerPanel(
                        engine: storyteller.engine,
                        controller: storyteller,
                        onPlayPause: { storytellerPlayPause() },
                        onClearCache: { clearStorytellerCache() },
                        onClose: { storyteller.deactivate() })
                }
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

            // Assistant deep-link: open Storyteller mode (start_storyteller).
            // The cost sheet still gates any generation.
            if coordinator.shouldOpenStoryteller {
                coordinator.shouldOpenStoryteller = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    toggleStoryteller()
                }
            }
        }
        .onChange(of: projectViewModel.project.sequences.count) { _, _ in
            buildPlaylist()
            // Keep scene spans/slides in sync; chunks already generated
            // from the old text stay playable until the cache is cleared.
            if storyteller.isActive { configureStoryteller() }
        }
        .onChange(of: playbackVM.mutedTracks) { _, newValue in
            timelineViewModel.mutedTracks = newValue
        }
        .sheet(isPresented: $showStorytellerCostSheet) {
            StorytellerCostSheet(
                engine: storyteller.engine,
                onGenerate: {
                    showStorytellerCostSheet = false
                    confirmStorytellerGeneration()
                },
                onCancel: {
                    showStorytellerCostSheet = false
                    // Don't sit on "Preparing scene…" for chunks that were
                    // never approved — park the storyteller transport.
                    storyteller.pause()
                })
        }
        .onDisappear {
            storyteller.deactivate()
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

    // MARK: - Storyteller Mode

    private func configureStoryteller() {
        let basePath = projectViewModel.projectPath?.deletingLastPathComponent()
        storyteller.configure(
            project: projectViewModel.project,
            basePath: basePath,
            playlistItems: playbackVM.playlistItems,
            sceneBoundaries: playbackVM.sceneBoundaries,
            totalDuration: playbackVM.totalDuration,
            timelineViewModel: timelineViewModel)
        storyteller.volumeProvider = { [weak playbackVM] in
            playbackVM?.effectiveVolume ?? 1.0
        }
    }

    private func toggleStoryteller() {
        if storyteller.isActive {
            storyteller.deactivate()
            return
        }
        // The storyteller owns the playhead while active — park normal playback.
        playbackVM.pause()
        configureStoryteller()
        storyteller.engine.prepare(project: projectViewModel.project)
        guard !storyteller.engine.chunks.isEmpty else { return }
        storyteller.beginStory()
        armStorytellerGenerationIfNeeded()
    }

    private func storytellerPlayPause() {
        if storyteller.isPlaying {
            storyteller.pause()
        } else {
            storyteller.resume()
            armStorytellerGenerationIfNeeded()
        }
    }

    /// Ungenerated chunks exist and nothing is running: either confirm via
    /// the cost sheet or start generating, per the analysis-gate precedent.
    private func armStorytellerGenerationIfNeeded() {
        let engine = storyteller.engine
        guard engine.pendingChunkCount > 0, !engine.isGenerating else { return }
        if shouldShowStorytellerCostSheet(estimated: engine.totalEstimatedCost) {
            showStorytellerCostSheet = true
        } else {
            confirmStorytellerGeneration()
        }
    }

    private func storytellerSeenKey() -> String {
        "storyteller.costSheetSeen.\(projectViewModel.project.uuid)"
    }

    private func shouldShowStorytellerCostSheet(estimated: Double) -> Bool {
        // ALWAYS confirm the first generation for a project — a whole
        // screenplay can cost dollars, not cents. Afterwards the global
        // preference + threshold gate applies (ContentView analysis
        // precedent).
        if !UserDefaults.standard.bool(forKey: storytellerSeenKey()) { return true }
        return PreferencesManager.shared.aiShowCostEstimates
            && estimated > AIUsageStats.costWarningThreshold
    }

    private func confirmStorytellerGeneration() {
        UserDefaults.standard.set(true, forKey: storytellerSeenKey())
        storyteller.engine.startGeneration()
    }

    private func clearStorytellerCache() {
        storyteller.pause()
        storyteller.engine.clearCache()
    }

    // MARK: - Keyboard Shortcut Monitor

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak playbackVM, weak storyteller] event in
            // Don't intercept if a text field is focused
            if let responder = event.window?.firstResponder,
               responder is NSTextView || responder is NSTextField {
                return event
            }

            // Storyteller mode owns the transport keys while active.
            let storyMode = storyteller?.isActive == true

            switch event.keyCode {
            case 49: // Space bar
                if storyMode {
                    storytellerPlayPause()
                } else {
                    playbackVM?.togglePlayPause()
                }
                return nil
            case 123: // Left arrow
                if storyMode {
                    storyteller?.seekToPreviousChunk()
                } else if event.modifierFlags.contains(.command) {
                    playbackVM?.skipToPreviousScene()
                } else {
                    playbackVM?.skipToPreviousShot()
                }
                return nil
            case 124: // Right arrow
                if storyMode {
                    storyteller?.seekToNextChunk()
                } else if event.modifierFlags.contains(.command) {
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

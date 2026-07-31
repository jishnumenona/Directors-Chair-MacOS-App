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
                PlaybackViewfinder(viewModel: playbackVM,
                                   narration: playbackVM.narrationPlayer)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)

                // Transport Bar — one transport for BOTH modes; while the
                // storyteller is active every control drives the narration.
                PlaybackTransportBar(viewModel: playbackVM,
                                     storytellerActive: playbackVM.storytellerActive,
                                     onStoryteller: { toggleStoryteller() })

                // Storyteller scene strip (visible while the mode is open)
                if playbackVM.storytellerActive {
                    StorytellerPanel(
                        engine: playbackVM.narrationPlayer.engine,
                        narration: playbackVM.narrationPlayer,
                        onSeekChunk: { playbackVM.seekToStorytellerChunk($0) },
                        onClearCache: { clearStorytellerCache() },
                        onClose: { playbackVM.exitStorytellerMode() })
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

            // When user clicks/drags the timeline ruler → seek playback to
            // that time (the ruler speaks EDIT-timeline/WPM time; in
            // storyteller mode it's mapped onto the story clock).
            timelineViewModel.onPlayheadSeeked = { [weak playbackVM] time in
                playbackVM?.seekFromEditTimeline(time)
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
            // The view model re-derives the storyteller timing internally
            // when the mode is active; chunks already generated from the
            // old text stay playable until the cache is cleared.
            buildPlaylist()
        }
        .onChange(of: playbackVM.mutedTracks) { _, newValue in
            timelineViewModel.mutedTracks = newValue
        }
        .onChange(of: playbackVM.storytellerPlayArmRequests) { _, _ in
            // Play was pressed with ungenerated chunks and no generation
            // running — arm the cost-confirmation gate.
            armStorytellerGenerationIfNeeded()
        }
        .sheet(isPresented: $showStorytellerCostSheet) {
            StorytellerCostSheet(
                engine: playbackVM.narrationPlayer.engine,
                onGenerate: {
                    showStorytellerCostSheet = false
                    confirmStorytellerGeneration()
                },
                onCancel: {
                    showStorytellerCostSheet = false
                    // Don't sit on "Preparing scene…" for chunks that were
                    // never approved — park the transport.
                    playbackVM.pause()
                })
        }
        .onDisappear {
            playbackVM.exitStorytellerMode()
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

    private func toggleStoryteller() {
        if playbackVM.storytellerActive {
            playbackVM.exitStorytellerMode()
            return
        }
        playbackVM.enterStorytellerMode()
        guard playbackVM.storytellerActive else { return }  // nothing to tell
        // Auto-play the story; play() bumps storytellerPlayArmRequests when
        // ungenerated chunks need the cost gate.
        playbackVM.play()
    }

    /// Ungenerated chunks exist and nothing is running: either confirm via
    /// the cost sheet or start generating, per the analysis-gate precedent.
    private func armStorytellerGenerationIfNeeded() {
        let engine = playbackVM.narrationPlayer.engine
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
        playbackVM.narrationPlayer.engine.startGeneration()
    }

    private func clearStorytellerCache() {
        playbackVM.pause()
        playbackVM.narrationPlayer.engine.clearCache()
    }

    // MARK: - Keyboard Shortcut Monitor

    private func installKeyMonitor() {
        // One transport for both modes: in storyteller mode the same
        // bindings drive the narration (space = play/pause, arrows = shot
        // sub-spans, ⌘-arrows = scene/chunk boundaries).
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

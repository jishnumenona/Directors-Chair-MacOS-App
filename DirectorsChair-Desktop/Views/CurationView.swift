// CurationView.swift
// DirectorsChair-Desktop
//
// Post-production footage curation — cinematic review interface
// Scene/shot/take hierarchy with inline rating, video preview, camera mapping

import SwiftUI
import AVKit
import DirectorsChairCore
import DirectorsChairViews

// MARK: - Curation Tab Enum

enum CurationTab: String, CaseIterable {
    case curation
    case mapping

    var displayName: String {
        switch self {
        case .curation: return "Curation"
        case .mapping: return "Mapping"
        }
    }

    var icon: String {
        switch self {
        case .curation: return "film.stack.fill"
        case .mapping: return "externaldrive.connected.to.line.below.fill"
        }
    }
}

struct CurationView: View {
    @Binding var project: Project
    let projectDir: URL?
    @StateObject var viewModel = CurationViewModel()
    @EnvironmentObject var coordinator: AppCoordinator
    @State var isVideoFullScreen: Bool = false
    @State var fullScreenVideoURL: URL?
    @State var selectedTab: CurationTab = .curation

    // Compare mode
    @State var isCompareMode: Bool = false
    @State var isCompareFullScreen: Bool = false
    @State var compareLeftTake: Take?
    @State var compareLeftShot: Shot?
    @State var compareLeftScene: DCScene?
    @State var compareRightTake: Take?
    @State var compareRightShot: Shot?
    @State var compareRightScene: DCScene?
    @State var compareSyncPlayback: Bool = true
    @State var compareLeftPlayer: AVPlayer?
    @State var compareRightPlayer: AVPlayer?

    // Clipboard copy feedback
    @State var copiedMetadataLabel: String?
    @State var hoveredMetadataLabel: String?

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            curationTabBar

            // Tab content
            ZStack {
                switch selectedTab {
                case .curation:
                    curationTabContent
                case .mapping:
                    mappingTabContent
                }

                // Full-screen compare overlay
                if isCompareFullScreen {
                    fullScreenComparePanel
                        .transition(.opacity)
                        .zIndex(100)
                }
            }
        }
        .background(Color(hex: "#1A1A1A"))
        .sheet(isPresented: $isVideoFullScreen) {
            fullScreenVideoPlayer
                .frame(minWidth: 900, minHeight: 600)
        }
        .onAppear {
            // If navigated here with a specific shot selected (e.g. from Shot List → Curate)
            if let targetShot = coordinator.selectedShot {
                // Find the scene containing this shot
                for sequence in project.sequences {
                    for scene in sequence.scenes {
                        if let match = scene.shots.first(where: { $0.id == targetShot.id }) {
                            viewModel.selectedScene = scene
                            viewModel.selectedShot = match
                            if let firstTake = match.takes.sorted(by: { $0.takeNumber < $1.takeNumber }).first {
                                viewModel.selectedTake = firstTake
                            }
                            coordinator.selectedShot = nil
                            return
                        }
                    }
                }
            }
        }
        .onChange(of: isCompareFullScreen) { newValue in
            DispatchQueue.main.async {
                guard let window = NSApp.keyWindow else { return }
                let isFS = window.styleMask.contains(.fullScreen)
                if newValue && !isFS {
                    window.toggleFullScreen(nil)
                } else if !newValue && isFS {
                    window.toggleFullScreen(nil)
                }
            }
        }
        .onChange(of: viewModel.selectedTake?.id) { _ in
            // Auto-extract camera metadata when selecting a take with video but no metadata
            if let take = viewModel.selectedTake,
               take.capturedVideoPath != nil,
               !take.hasCameraMetadata,
               let dir = projectDir {
                Task {
                    if let metadata = await viewModel.extractCameraMetadata(for: take, projectDir: dir),
                       metadata.hasData,
                       let shot = viewModel.selectedShot {
                        updateTake(take, in: shot) { t in
                            metadata.apply(to: &t)
                        }
                    }
                }
            }

            // Auto-detect audio cues when selecting a take with video but no cue detection
            if let take = viewModel.selectedTake {
                print("[CurationView] onChange take: \(take.id), videoPath: \(take.capturedVideoPath ?? "nil"), hasAudioCueDetection: \(take.hasAudioCueDetection), projectDir: \(projectDir?.path ?? "nil")")
                if take.capturedVideoPath != nil,
                   !take.hasAudioCueDetection,
                   let dir = projectDir {
                    print("[CurationView] Triggering auto-detect for take \(take.takeNumber)")
                    Task {
                        if let result = await viewModel.detectAudioCues(for: take, projectDir: dir) {
                            print("[CurationView] Detection result: hasResults=\(result.hasResults), action=\(result.actionTimestamp ?? -1), cut=\(result.cutTimestamp ?? -1)")
                            if result.hasResults, let shot = viewModel.selectedShot {
                                updateTake(take, in: shot) { t in
                                    result.apply(to: &t)
                                }
                            }
                        } else {
                            print("[CurationView] Detection returned nil")
                        }
                    }
                }

                // Auto-detect sync tones when take has video but no sync detection
                if take.capturedVideoPath != nil,
                   !take.hasSyncToneDetection,
                   let dir = projectDir {
                    Task {
                        if let result = await viewModel.detectSyncTones(for: take, projectDir: dir),
                           result.hasResults,
                           let shot = viewModel.selectedShot {
                            updateTake(take, in: shot) { t in
                                result.apply(to: &t)
                            }
                        }
                    }
                }
            }
        }
    }
}

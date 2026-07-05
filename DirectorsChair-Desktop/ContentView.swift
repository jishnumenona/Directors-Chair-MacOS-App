//
//  ContentView.swift
//  DirectorsChair-Desktop
//
//  Phase 8: Main App Integration
//  Main window layout with navigation
//

import SwiftUI
import AppKit
import AVFoundation
import UniformTypeIdentifiers
import DirectorsChairCore
import DirectorsChairViews
import DirectorsChairProduction
import DirectorsChairServices

extension Notification.Name {
    static let toggleShotVideoPlayback = Notification.Name("toggleShotVideoPlayback")
}

struct ContentView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @StateObject private var timelineViewModel = TimelineViewModel()
    @StateObject private var captureService = LiveCaptureService()
    @EnvironmentObject var onboardingState: OnboardingState
    @EnvironmentObject var tourManager: GuidedTourManager
    @EnvironmentObject var authManager: AuthManager

    @State private var showLoginSuccess = false
    @State private var loginSuccessUsername = ""
    @State private var spaceBarMonitor: Any?

    // Timeline analysis state
    @State private var showAnalysisReview = false
    @State private var analysisResult: TimelineAnalysisResult?
    @State private var isAnalyzing = false
    @State private var analysisProgress: Int = 0

    // Cost estimation warning state
    @State private var pendingAnalysisScenes: [(scene: DirectorsChairCore.Scene, sceneName: String, sequenceIndex: Int, sceneIndex: Int)] = []
    @State private var analysisEstimateCost: Double = 0
    @State private var analysisEstimateCalls: Int = 0
    @State private var analysisEstimateSceneCount: Int = 0
    @State private var showAnalysisCostWarning = false

    /// Timeline height as percentage of available space (default 20%)
    @State private var timelineHeightRatio: CGFloat = 0.20

    /// Sidebar width
    @State private var sidebarWidth: CGFloat = 280

    /// Whether we're on the Projects view (hide panels)
    private var isProjectsView: Bool {
        coordinator.selectedView == .projects
    }

    /// Whether to show the navigator (hidden on Projects view)
    private var shouldShowNavigator: Bool {
        coordinator.showingNavigator && !isProjectsView
    }

    /// Whether to show the timeline (hidden on Projects view)
    private var shouldShowTimeline: Bool {
        coordinator.showingTimeline && !isProjectsView
    }

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                let totalHeight = geometry.size.height
                let timelineHeight = shouldShowTimeline ? max(100, totalHeight * timelineHeightRatio) : 0
                let mainContentHeight = totalHeight - timelineHeight - (shouldShowTimeline ? 6 : 0) // 6 for divider

                VStack(spacing: 0) {
                    // Main content area - using simple HStack instead of NavigationSplitView
                    HStack(spacing: 0) {
                        // Left Sidebar - Navigator (conditionally shown, hidden on Projects view)
                        if shouldShowNavigator {
                            NavigatorSidebar()
                                .environmentObject(timelineViewModel)
                                .frame(width: sidebarWidth)
                                .frame(maxHeight: .infinity)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .accessibilityIdentifier("navigator-sidebar")
                                .spotlightTarget(id: "navigator-sidebar")

                            // Sidebar resize handle
                            SidebarDivider(sidebarWidth: $sidebarWidth)
                        }

                        // Main Content Area
                        VStack(spacing: 0) {
                            // Top Toolbar (hidden on Projects view for cleaner look)
                            if !isProjectsView {
                                AppToolbar()
                            }

                            // Central View Stack - isolated to only re-render on selectedView change
                            CentralViewRouter()
                                .environmentObject(timelineViewModel)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(height: mainContentHeight)

                    // Timeline section - spans full width (hidden on Projects view)
                    if shouldShowTimeline {
                        // Resizable divider
                        TimelineDivider(
                            timelineHeightRatio: $timelineHeightRatio,
                            totalHeight: totalHeight
                        )
                        .hintDot(id: "hint-timeline-resize", title: "Resize Timeline", description: "Double-click to expand, drag to resize", alignment: .center)

                        // Bottom Timeline (20% of space, resizable) - full width
                        TimelineContainer()
                            .environmentObject(timelineViewModel)
                            .frame(maxWidth: .infinity)
                            .frame(height: timelineHeight)
                            .accessibilityIdentifier("timeline-panel")
                            .spotlightTarget(id: "timeline-panel")
                    }
                }
            }

            // Loading overlay
            if projectViewModel.isLoading {
                LoadingOverlay()
            }

            // AI Chat overlay
            if coordinator.showingAIChat {
                AIChatOverlayView()
                    .transition(.opacity)
            }

            // Guided tour spotlight overlay
            if tourManager.isSpotlightTourActive {
                SpotlightOverlayView()
                    .transition(.opacity)
                    .zIndex(90)
            }

            // First-launch onboarding overlay (above tour, below login gate)
            if onboardingState.showOnboarding {
                OnboardingView {
                    withAnimation(.easeOut(duration: 0.4)) {
                        onboardingState.complete()
                    }
                }
                .zIndex(150)
            }

            // Login gate — shown when not authenticated (hidden during onboarding)
            if !authManager.isAuthenticated && !authManager.isLoading && !onboardingState.showOnboarding {
                LoginView()
                    .transition(.opacity)
                    .zIndex(200)
            }

            // Login success toast
            if showLoginSuccess {
                VStack {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Welcome back, \(loginSuccessUsername)!")
                                .font(.system(size: 13, weight: .semibold))
                            Text("You're signed in. AI and cloud features are active.")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            withAnimation(.easeOut(duration: 0.3)) {
                                showLoginSuccess = false
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(14)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.3)))
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    .frame(maxWidth: 380)
                    .padding(.top, 52)

                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(250)
            }
        }
        .onChange(of: authManager.currentUser?.username) { _, newUsername in
            if let username = newUsername {
                loginSuccessUsername = username
                withAnimation(.easeInOut(duration: 0.4)) {
                    showLoginSuccess = true
                }
                // Auto-dismiss after 4 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showLoginSuccess = false
                    }
                }
            }
        }
        .onAppear {
            DoubleShiftMonitor.shared.onDoubleShift = {
                coordinator.toggleAIChat()
            }
            DoubleShiftMonitor.shared.install()
            installSpaceBarMonitor()
            RemoteControlService.shared.install()
        }
        .onDisappear {
            if let monitor = spaceBarMonitor {
                NSEvent.removeMonitor(monitor)
                spaceBarMonitor = nil
            }
            RemoteControlService.shared.uninstall()
        }
        .onPreferenceChange(SpotlightTargetKey.self) { targets in
            for target in targets {
                tourManager.targetFrames[target.id] = target.frame
            }
        }
        .environmentObject(captureService)
        .focusedValue(\.projectViewModel, projectViewModel)
        .focusedValue(\.appCoordinator, coordinator)
        .errorAlert($projectViewModel.errorAlert)
        // Timeline analysis review sheet
        .sheet(isPresented: $showAnalysisReview) {
            if let result = analysisResult {
                TimelineAnalysisReviewView(
                    result: result,
                    onApply: {
                        TimelineAnalyzer.applyChanges(to: &projectViewModel.project, from: result)
                        showAnalysisReview = false
                        analysisResult = nil
                        // Refresh timeline and save
                        timelineViewModel.setProject(projectViewModel.project)
                        timelineViewModel.refresh()
                        coordinator.notifyProjectChanged()
                        Task { await projectViewModel.saveSilently() }
                    },
                    onCancel: {
                        showAnalysisReview = false
                        analysisResult = nil
                    }
                )
            }
        }
        // Timeline analysis progress overlay
        .overlay {
            if isAnalyzing {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()

                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Analyzing Timeline...")
                            .font(.system(size: 14, weight: .semibold))
                        Text("\(analysisProgress)%")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        // Cost estimation warning before expensive analysis
        .alert("Timeline Analysis", isPresented: $showAnalysisCostWarning) {
            Button("Cancel", role: .cancel) {
                pendingAnalysisScenes = []
            }
            Button("Analyze") {
                launchTimelineAnalysis(scenes: pendingAnalysisScenes)
                pendingAnalysisScenes = []
            }
        } message: {
            Text("This will analyze \(analysisEstimateSceneCount) scene\(analysisEstimateSceneCount == 1 ? "" : "s") using ~\(analysisEstimateCalls) AI calls.\n\nEstimated cost: $\(String(format: "%.2f", analysisEstimateCost))")
        }
        // Listen for analysis scope changes from coordinator
        .onChange(of: coordinator.timelineAnalysisScope != nil) { _, hasScope in
            if hasScope, let scope = coordinator.timelineAnalysisScope {
                coordinator.timelineAnalysisScope = nil
                prepareTimelineAnalysis(scope: scope)
            }
        }
        .background(
            // Navigation history keyboard shortcuts (Cmd+[ / Cmd+])
            Group {
                Button("") { coordinator.navigateBack() }
                    .keyboardShortcut("[", modifiers: .command)
                    .hidden()

                Button("") { coordinator.navigateForward() }
                    .keyboardShortcut("]", modifiers: .command)
                    .hidden()
            }
            .frame(width: 0, height: 0)
        )
    }

    // MARK: - Timeline Analysis

    private func prepareTimelineAnalysis(scope: TimelineAnalysisScope) {
        let project = projectViewModel.project

        // Build the scene list based on scope
        var scenesToAnalyze: [(scene: DirectorsChairCore.Scene, sceneName: String, sequenceIndex: Int, sceneIndex: Int)] = []

        switch scope {
        case .all:
            for (seqIdx, sequence) in project.sequences.enumerated() {
                for (scnIdx, scene) in sequence.scenes.enumerated() {
                    scenesToAnalyze.append((scene, scene.name, seqIdx, scnIdx))
                }
            }
        case .sequence(let seq):
            if let seqIdx = project.sequences.firstIndex(where: { $0.id == seq.id }) {
                for (scnIdx, scene) in project.sequences[seqIdx].scenes.enumerated() {
                    scenesToAnalyze.append((scene, scene.name, seqIdx, scnIdx))
                }
            }
        case .scene(let scene, let seqIdx, let scnIdx):
            scenesToAnalyze.append((scene, scene.name, seqIdx, scnIdx))
        case .shot(_, let scene, let seqIdx, let scnIdx):
            scenesToAnalyze.append((scene, scene.name, seqIdx, scnIdx))
        }

        guard !scenesToAnalyze.isEmpty else { return }

        // Estimate cost and decide whether to show warning
        let estimate = TimelineAnalyzer.estimateCost(scenes: scenesToAnalyze)

        if PreferencesManager.shared.aiShowCostEstimates && estimate.estimatedCostUSD > AIUsageStats.costWarningThreshold {
            // Show confirmation dialog
            pendingAnalysisScenes = scenesToAnalyze
            analysisEstimateSceneCount = estimate.sceneCount
            analysisEstimateCalls = estimate.estimatedCalls
            analysisEstimateCost = estimate.estimatedCostUSD
            showAnalysisCostWarning = true
        } else {
            // Proceed directly
            launchTimelineAnalysis(scenes: scenesToAnalyze)
        }
    }

    private func launchTimelineAnalysis(scenes: [(scene: DirectorsChairCore.Scene, sceneName: String, sequenceIndex: Int, sceneIndex: Int)]) {
        isAnalyzing = true
        analysisProgress = 0

        Task {
            do {
                let analyzer = TimelineAnalyzer()
                let result = try await analyzer.analyzeScenes(
                    scenes: scenes,
                    progressCallback: { progress in
                        Task { @MainActor in
                            analysisProgress = progress
                        }
                    }
                )
                await MainActor.run {
                    isAnalyzing = false
                    analysisResult = result
                    showAnalysisReview = true
                }
            } catch {
                await MainActor.run {
                    isAnalyzing = false
                    projectViewModel.errorAlert = .init(title: "Timeline Analysis Failed", message: error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Global Space Bar → Toggle Video Playback

    private func installSpaceBarMonitor() {
        spaceBarMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Only handle space bar (keyCode 49), no modifiers
            guard event.keyCode == 49,
                  !event.modifierFlags.contains(.command),
                  !event.modifierFlags.contains(.option),
                  !event.modifierFlags.contains(.control) else {
                return event
            }

            // Don't intercept if a text field/editor is focused
            if let responder = event.window?.firstResponder,
               responder is NSTextView || responder is NSTextField {
                return event
            }

            // Already on playback view — let PlaybackView's own monitor handle it
            if coordinator.selectedView == .playback {
                return event
            }

            // Toggle any video player visible in the current view
            NotificationCenter.default.post(name: .toggleShotVideoPlayback, object: nil)
            return nil  // consume the event
        }
    }
}
// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(AppCoordinator())
        .environmentObject(ProjectViewModel())
        .environmentObject(OnboardingState())
        .environmentObject(GuidedTourManager())
}

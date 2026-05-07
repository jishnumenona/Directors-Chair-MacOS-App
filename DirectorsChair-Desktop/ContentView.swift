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

// MARK: - Sidebar Divider (Resizable)

struct SidebarDivider: View {
    @Binding var sidebarWidth: CGFloat
    @State private var isDragging = false

    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(width: 1)
            .contentShape(Rectangle().inset(by: -3))
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        let newWidth = sidebarWidth + value.translation.width
                        sidebarWidth = min(500, max(200, newWidth))
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
    }
}

// MARK: - Central View Router (Isolated from unnecessary updates)

/// This view ONLY observes selectedView changes, not the entire coordinator
/// This prevents cascading re-renders when other coordinator properties change
struct CentralViewRouter: View {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        // Don't use .id() - it destroys @StateObjects and causes issues during rapid switching
        CentralViewStack()
    }
}

// MARK: - Timeline Divider (Resizable)

struct TimelineDivider: View {
    @Binding var timelineHeightRatio: CGFloat
    let totalHeight: CGFloat

    @State private var isDragging = false
    @State private var previousRatio: CGFloat? = nil

    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(height: 6)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .fill(isDragging ? Color.accentColor : Color.gray.opacity(0.5))
                    .frame(width: 40, height: 4)
            )
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        // Clear saved ratio when user manually drags
                        previousRatio = nil
                        // Calculate new ratio based on drag
                        let dragOffset = value.translation.height
                        let newTimelineHeight = (totalHeight * timelineHeightRatio) - dragOffset
                        let newRatio = newTimelineHeight / totalHeight

                        // Clamp between 10% and 60%
                        timelineHeightRatio = min(0.60, max(0.10, newRatio))
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .help("Drag to resize timeline panel")
            .onTapGesture(count: 2) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    if abs(timelineHeightRatio - 0.50) < 0.01, let saved = previousRatio {
                        // Already at 50% — restore previous size
                        timelineHeightRatio = saved
                        previousRatio = nil
                    } else {
                        // Save current and snap to 50%
                        previousRatio = timelineHeightRatio
                        timelineHeightRatio = 0.50
                    }
                }
            }
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(.circular)

                Text("Loading...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
            .shadow(radius: 20)
        }
    }
}

// MARK: - AI Progress Tracker

/// Tracks AI operation progress across navigation. Class-based so it can be
/// captured in @Sendable closures and updated from async callbacks.
final class AIProgressTracker: ObservableObject, @unchecked Sendable {
    @Published var traitAnalysis: [String: Int] = [:]
    @Published var biography: [String: Int] = [:]
}

// MARK: - Central View Stack

/// Routes to the appropriate view based on coordinator.selectedView
struct CentralViewStack: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var timelineViewModel: TimelineViewModel

    /// Incremented on each projectChanged event to trigger BubbleView cache refresh
    @State private var bubbleRefreshTrigger = 0

    /// Track which views have been visited so we only create them lazily,
    /// but keep them alive (preserving scroll position and all @State) once created.
    @State private var visitedViews: Set<AppView> = []

    /// AI operation progress — survives navigation between tabs
    @StateObject private var aiProgress = AIProgressTracker()

    // Cache view models to prevent recreation on every switch
    @StateObject private var scheduleViewModel = ScheduleViewModel(scheduleItems: [])
    @StateObject private var castCrewViewModel = CastCrewViewModel(castMembers: [], crewMembers: [], teams: [], equipment: [])
    @StateObject private var budgetViewModel = BudgetViewModel(budget: ProjectBudget())
    @StateObject private var equipmentViewModel = EquipmentViewModel()
    @StateObject private var ganttViewModel = GanttViewModel()

    var body: some View {
        let currentView = coordinator.selectedView
        let _ = debugLog("🔄 CentralViewStack body - current: \(currentView.rawValue)")

        ZStack {
            ForEach(AppView.allCases) { view in
                if visitedViews.contains(view) || view == currentView {
                    viewContent(for: view)
                        .opacity(view == currentView ? 1 : 0)
                        .allowsHitTesting(view == currentView)
                        .zIndex(view == currentView ? 1 : 0)
                }
            }
        }
        .onChange(of: currentView) { _, newView in
            visitedViews.insert(newView)
        }
        .onAppear {
            visitedViews.insert(currentView)
        }
        // Removed animation to prevent stacking during rapid view switches
        .onReceive(coordinator.projectChanged) { _ in
            bubbleRefreshTrigger += 1
        }
    }

    @ViewBuilder
    private func viewContent(for view: AppView) -> some View {
        switch view {
        case .overview:
            ProjectOverviewView()
                .onAppear { debugLog("📱 Overview appeared") }
        case .script:
            ScriptView()
                .onAppear { debugLog("📱 ScriptView appeared") }
        case .bubble:
            BubbleView(
                project: $projectViewModel.project,
                projectBasePath: projectViewModel.projectPath?.deletingLastPathComponent(),
                highlightedBubbleItem: coordinator.highlightedBubbleItem,
                onItemsReordered: {
                    projectViewModel.isDirty = true
                    coordinator.notifyProjectChanged()
                },
                onContentChanged: {
                    projectViewModel.isDirty = true
                    coordinator.notifyProjectChanged()
                },
                externalSelectedSceneId: coordinator.selectedScene?.id,
                externalRefreshTrigger: bubbleRefreshTrigger,
                onDialogueSelected: { dialogue in
                    coordinator.chatContextDialogue = dialogue
                },
                onNavigateToCharacter: { character in
                    coordinator.selectCharacter(character)
                }
            )
            .onAppear { debugLog("📱 BubbleView appeared") }
        case .scenes:
            ScenesListView()
                .onAppear { debugLog("📱 ScenesListView appeared") }
        case .assets:
            AssetsView()
                .onAppear { debugLog("📱 AssetsView appeared") }
        case .visionBoard:
            VisionBoardView(
                cards: projectViewModel.project.beats,
                onCardsChanged: { cards in
                    projectViewModel.project.beats = cards
                    projectViewModel.isDirty = true
                }
            )
            .onAppear { debugLog("📱 VisionBoardView appeared") }
        case .shotList:
            ProductionViewWrapper(
                project: projectViewModel.project,
                projectPath: projectViewModel.projectPath,
                subtitle: "Shot List"
            ) {
                CinematographyViewAdapter()
            }
            .onAppear { debugLog("📱 CinematographyView appeared") }
        case .production:
            ProductionContainer(
                scheduleViewModel: scheduleViewModel,
                castCrewViewModel: castCrewViewModel,
                budgetViewModel: budgetViewModel,
                equipmentViewModel: equipmentViewModel,
                ganttViewModel: ganttViewModel
            )
            .onAppear { debugLog("📱 ProductionContainer appeared") }
        case .storyDesign:
            StoryDesignView(
                project: $projectViewModel.project,
                projectBasePath: projectViewModel.projectPath?.deletingLastPathComponent(),
                initialCharacterId: coordinator.selectedCharacter?.id,
                initialLocationId: coordinator.selectedLocation?.id,
                preferredMode: coordinator.preferredStoryDesignMode,
                initialLightCueId: coordinator.selectedLightCueId,
                initialSFXCueId: coordinator.selectedSFXCueId,
                initialSupportCueId: coordinator.selectedSupportCueId,
                markers: timelineViewModel.userMarkers,
                traitAnalysisProgress: aiProgress.traitAnalysis,
                biographyProgress: aiProgress.biography,
                onGenerateImage: { character, angle, prompt, progressHandler in
                    Task {
                        await generateCharacterImage(character: character, angle: angle, prompt: prompt, progressHandler: progressHandler)
                    }
                },
                onAnalyzeTraits: { character in
                    Task {
                        await analyzeCharacterTraits(character: character)
                    }
                },
                onGenerateBiography: { character in
                    Task {
                        await generateCharacterBiography(character: character)
                    }
                },
                onGenerateLocationImage: { location, variation, prompt, progressHandler in
                    Task {
                        await generateLocationImage(location: location, variation: variation, prompt: prompt, progressHandler: progressHandler)
                    }
                },
                onUploadReferenceImage: { character, imageData, progressHandler in
                    Task {
                        await analyzeCharacterReferenceImage(character: character, imageData: imageData, progressHandler: progressHandler)
                    }
                }
            )
            .onAppear { debugLog("📱 StoryDesignView appeared") }
        case .curation:
            ProductionViewWrapper(
                project: projectViewModel.project,
                projectPath: projectViewModel.projectPath,
                subtitle: "Curation"
            ) {
                CurationViewAdapter()
            }
            .onAppear { debugLog("📱 CurationView appeared") }
        case .playback:
            PlaybackView()
                .onAppear { debugLog("📱 PlaybackView appeared") }
        case .settings:
            ProjectSettingsView()
                .onAppear { debugLog("📱 ProjectSettingsView appeared") }
        case .projects:
            ProjectsExplorerView()
                .onAppear { debugLog("📱 ProjectsExplorerView appeared") }
        }
    }

    // MARK: - AI Integration Methods

    private func generateCharacterImage(character: Character, angle: String, prompt: String, progressHandler: @escaping @MainActor (Double) -> Void) async {
        let aiClient = AIServiceClient.shared

        await MainActor.run { progressHandler(0.05) }

        // Check if AI server is available
        guard await aiClient.testConnection() else {
            await MainActor.run {
                progressHandler(1.0) // Clear progress
                projectViewModel.errorAlert = ErrorAlert(
                    title: "AI Service Unavailable",
                    message: "Could not connect to AI server at directorschair.app. Please check your internet connection and try again."
                )
            }
            return
        }

        await MainActor.run { progressHandler(0.1) }

        do {
            // Load base image as reference when generating angle variants
            var referenceBase64: String? = nil
            var referenceMime: String? = nil
            if angle != "base" {
                referenceBase64 = loadBaseImageAsBase64(for: character)
                if referenceBase64 != nil {
                    referenceMime = "image/png"
                }
            }

            await MainActor.run { progressHandler(0.15) }

            let request = ImageGenerationRequest(
                prompt: prompt,
                provider: .googleImagen,
                aspectRatio: "1:1",
                numberOfImages: 1,
                referenceImageBase64: referenceBase64,
                referenceMimeType: referenceMime
            )

            // Simulate gradual progress during the AI call
            let progressSimulator = Task { @MainActor in
                var current = 0.2
                while current < 0.85 {
                    progressHandler(current)
                    try await Task.sleep(nanoseconds: 800_000_000) // 0.8s intervals
                    current += Double.random(in: 0.03...0.08)
                }
            }

            let response = try await aiClient.generateImage(request)
            progressSimulator.cancel()

            await MainActor.run { progressHandler(0.88) }

            guard let imageData = response.images.first else {
                throw AIClientError.invalidResponse("No image generated")
            }

            await MainActor.run { progressHandler(0.92) }

            // Save image to project directory
            if let projectPath = projectViewModel.projectPath {
                let projectDir = projectPath.deletingLastPathComponent()
                let sanitizedName = sanitizeAssetName(character.name)

                // Check if this is a costume image (format: "costume:{costumeName}:{angle}")
                let isCostumeImage = angle.hasPrefix("costume:")
                let costumeComponents = angle.split(separator: ":", maxSplits: 2).map(String.init)

                let subfolder: String
                let filename: String

                if isCostumeImage, costumeComponents.count == 3 {
                    let costumeName = costumeComponents[1]
                    let costumeAngle = costumeComponents[2]
                    let sanitizedCostumeName = sanitizeAssetName(costumeName)
                    subfolder = "costumes/\(sanitizedCostumeName)"
                    filename = costumeAngle
                } else {
                    let assetPath = getAssetPath(for: angle)
                    subfolder = assetPath.subfolder
                    filename = assetPath.filename
                }

                let characterAssetsDir = projectDir
                    .appendingPathComponent("assets")
                    .appendingPathComponent("characters")
                    .appendingPathComponent(sanitizedName)
                    .appendingPathComponent(subfolder)

                let imagePath = characterAssetsDir.appendingPathComponent("\(filename).png")

                let saveSucceeded = await saveImageWithUserPermission(
                    imageData: imageData,
                    imagePath: imagePath,
                    imagesDir: characterAssetsDir,
                    projectDir: projectDir
                )

                if !saveSucceeded {
                    await MainActor.run { progressHandler(1.0) }
                    return
                }

                await MainActor.run { progressHandler(0.96) }

                let relativePath = "assets/characters/\(sanitizedName)/\(subfolder)/\(filename).png"

                if let charIndex = projectViewModel.project.characters.firstIndex(where: { $0.id == character.id }) {
                    await MainActor.run {
                        if isCostumeImage, costumeComponents.count == 3 {
                            // Store on the matching CharacterCostume
                            let costumeName = costumeComponents[1]
                            let costumeAngle = costumeComponents[2]
                            if var costumes = projectViewModel.project.characters[charIndex].costumes,
                               let costumeIdx = costumes.firstIndex(where: { $0.name == costumeName }) {
                                switch costumeAngle {
                                case "front":
                                    costumes[costumeIdx].imageFront = relativePath
                                case "three_quarter_left":
                                    costumes[costumeIdx].imageThreeQuarterLeft = relativePath
                                case "three_quarter_right":
                                    costumes[costumeIdx].imageThreeQuarterRight = relativePath
                                case "profile":
                                    costumes[costumeIdx].imageProfile = relativePath
                                case "back":
                                    costumes[costumeIdx].imageBack = relativePath
                                case "full_body":
                                    costumes[costumeIdx].imageFullBody = relativePath
                                default:
                                    costumes[costumeIdx].imageFront = relativePath
                                }
                                projectViewModel.project.characters[charIndex].costumes = costumes
                            }
                        } else {
                            switch angle {
                            case "base":
                                projectViewModel.project.characters[charIndex].baseImage = relativePath
                            case "front":
                                projectViewModel.project.characters[charIndex].imageFront = relativePath
                            case "three_quarter_left":
                                projectViewModel.project.characters[charIndex].imageThreeQuarterLeft = relativePath
                            case "three_quarter_right":
                                projectViewModel.project.characters[charIndex].imageThreeQuarterRight = relativePath
                            case "profile_left":
                                projectViewModel.project.characters[charIndex].imageProfileLeft = relativePath
                            case "profile_right":
                                projectViewModel.project.characters[charIndex].imageProfileRight = relativePath
                            case "back":
                                projectViewModel.project.characters[charIndex].imageBack = relativePath
                            default:
                                projectViewModel.project.characters[charIndex].baseImage = relativePath
                            }
                        }
                        projectViewModel.isDirty = true
                    }
                }
            }

            // Signal completion
            await MainActor.run { progressHandler(1.0) }

        } catch {
            await MainActor.run {
                progressHandler(1.0) // Clear progress even on failure
                projectViewModel.errorAlert = ErrorAlert(
                    error: error,
                    title: "Image Generation Failed"
                )
            }
        }
    }

    /// Load the base image for a character as base64 string for use as reference
    private func loadBaseImageAsBase64(for character: Character) -> String? {
        guard let projectPath = projectViewModel.projectPath else { return nil }
        let projectDir = projectPath.deletingLastPathComponent()

        // Try character's stored base image path first, then front image
        let candidatePaths = [character.baseImage, character.imageFront].compactMap { $0 }

        for relativePath in candidatePaths {
            let fullPath = projectDir.appendingPathComponent(relativePath)
            if let imageData = try? Data(contentsOf: fullPath) {
                return imageData.base64EncodedString()
            }
        }

        // Also try discovered images from filesystem
        let sanitizedName = sanitizeAssetName(character.name)
        let faceFrontPath = projectDir
            .appendingPathComponent("assets/characters/\(sanitizedName)/face/front.png")
        if let imageData = try? Data(contentsOf: faceFrontPath) {
            return imageData.base64EncodedString()
        }

        return nil
    }

    /// Save image with user permission - prompts for folder access if needed
    private func saveImageWithUserPermission(
        imageData: Data,
        imagePath: URL,
        imagesDir: URL,
        projectDir: URL
    ) async -> Bool {
        // Create directory automatically if it doesn't exist
        if !FileManager.default.fileExists(atPath: imagesDir.path) {
            do {
                _ = projectDir.startAccessingSecurityScopedResource()
                defer { projectDir.stopAccessingSecurityScopedResource() }

                try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                await MainActor.run {
                    self.projectViewModel.errorAlert = ErrorAlert(
                        title: "Failed to Create Folder",
                        message: "Could not create images folder at:\n\(imagesDir.path)\n\nError: \(error.localizedDescription)"
                    )
                }
                return false
            }
        }

        // Try to write the image
        do {
            _ = projectDir.startAccessingSecurityScopedResource()
            defer { projectDir.stopAccessingSecurityScopedResource() }

            try imageData.write(to: imagePath)
            return true
        } catch {
            await MainActor.run {
                self.projectViewModel.errorAlert = ErrorAlert(
                    title: "Failed to Save Image",
                    message: "Could not save image to character_images folder. You may need to manually create the folder at:\n\(projectDir.path)\n\nError: \(error.localizedDescription)"
                )
            }
            return false
        }
    }

    /// Sanitize asset name for filesystem (Python-compatible)
    /// Converts spaces to underscores, removes special characters
    private func sanitizeAssetName(_ name: String) -> String {
        var sanitized = name
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "(", with: "_")
            .replacingOccurrences(of: ")", with: "_")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\"", with: "")

        // Collapse multiple underscores
        while sanitized.contains("__") {
            sanitized = sanitized.replacingOccurrences(of: "__", with: "_")
        }

        // Remove leading/trailing underscores
        sanitized = sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "_"))

        // Limit length
        if sanitized.count > 100 {
            sanitized = String(sanitized.prefix(100))
        }

        return sanitized.isEmpty ? "Unnamed" : sanitized
    }

    /// Get asset subfolder and filename for a given angle
    /// Returns (subfolder, filename) tuple matching Python structure
    private func getAssetPath(for angle: String) -> (subfolder: String, filename: String) {
        switch angle {
        case "base", "front":
            return ("face", "front")
        case "three_quarter_left":
            return ("face", "three_quarter_left")
        case "three_quarter_right":
            return ("face", "three_quarter_right")
        case "profile_left", "profile":
            return ("face", "profile")
        case "profile_right":
            return ("face", "profile_right")
        case "back":
            return ("body", "back")
        case "body_front":
            return ("body", "front")
        case "body_three_quarter_left":
            return ("body", "three_quarter_left")
        case "body_three_quarter_right":
            return ("body", "three_quarter_right")
        case "body_profile":
            return ("body", "profile")
        default:
            return ("face", "front")
        }
    }

    // MARK: - Analyze Character Reference Image

    private func analyzeCharacterReferenceImage(
        character: Character,
        imageData: Data,
        progressHandler: @escaping @MainActor (Double) -> Void
    ) async {
        let aiClient = AIServiceClient.shared

        await MainActor.run { progressHandler(0.1) }

        guard await aiClient.testConnection() else {
            await MainActor.run {
                progressHandler(1.0)
                projectViewModel.errorAlert = ErrorAlert(
                    title: "AI Service Unavailable",
                    message: "Could not connect to AI server. Please check your internet connection and try again."
                )
            }
            return
        }

        await MainActor.run { progressHandler(0.2) }

        let base64 = imageData.base64EncodedString()

        let prompt = """
        Analyze this character reference image and extract physical attributes and costume details.
        Return ONLY valid JSON with no markdown formatting or code fences.

        {
          "gender": "male|female|neutral",
          "age": <estimated age as integer>,
          "build": "Slim|Athletic|Average|Stocky|Heavy",
          "heightCm": <estimated height in cm>,
          "weightKg": <estimated weight in kg>,
          "hairColor": "<hex color string like #8B4513>",
          "hairStyle": "<e.g., Wavy, Straight, Curly, Braided>",
          "hairLength": "Bald|Short|Medium|Long|Very Long",
          "eyeColor": "<hex color string>",
          "eyeColorDescription": "<e.g., Brown, Blue, Hazel>",
          "eyeShape": "Almond|Round|Hooded|Monolid|Deep-set|Upturned|Downturned",
          "skinTone": "<hex color string>",
          "ethnicity": "<estimated ethnicity description>",
          "facialStructure": "Oval|Round|Square|Heart|Oblong|Diamond",
          "distinguishingFeatures": "<scars, tattoos, birthmarks, or 'None'>",
          "costume": {
            "name": "<descriptive costume name>",
            "description": "<brief overall description>",
            "garmentTop": "<top garment description>",
            "garmentBottom": "<bottom garment description>",
            "footwear": "<footwear description or empty string>",
            "outerwear": "<outerwear description or empty string>",
            "headwear": "<headwear description or empty string>",
            "accessories": ["<item1>", "<item2>"],
            "colorPalette": ["#hex1", "#hex2", "#hex3"],
            "era": "<Modern|Period|Fantasy|Sci-Fi|Victorian|Medieval|etc>",
            "styleCategory": "<Casual|Formal|Military|Athletic|etc>"
          }
        }
        """

        do {
            let request = TextGenerationRequest(
                prompt: prompt,
                provider: .google,
                maxTokens: 2000,
                temperature: 0.3,
                imageBase64: base64,
                imageMimeType: "image/png"
            )

            await MainActor.run { progressHandler(0.4) }

            let response = try await aiClient.generateText(request)

            await MainActor.run { progressHandler(0.7) }

            // Strip markdown code fences if present
            var jsonText = response.text
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if jsonText.hasPrefix("```") {
                if let firstNewline = jsonText.firstIndex(of: "\n") {
                    jsonText = String(jsonText[jsonText.index(after: firstNewline)...])
                }
                if jsonText.hasSuffix("```") {
                    jsonText = String(jsonText.dropLast(3))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            guard let jsonData = jsonText.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                await MainActor.run {
                    progressHandler(1.0)
                    projectViewModel.errorAlert = ErrorAlert(
                        title: "Analysis Failed",
                        message: "Could not parse AI response. The image may not contain a clear character."
                    )
                }
                return
            }

            await MainActor.run { progressHandler(0.8) }

            guard let charIndex = projectViewModel.project.characters.firstIndex(where: { $0.id == character.id }) else {
                await MainActor.run { progressHandler(1.0) }
                return
            }

            await MainActor.run {
                var char = projectViewModel.project.characters[charIndex]

                if let gender = json["gender"] as? String, !gender.isEmpty {
                    let g = gender.lowercased()
                    if g == "male" || g == "female" || g == "neutral" {
                        char.gender = g
                    }
                }
                if let age = json["age"] as? Int, age > 0 {
                    char.age = age
                }
                if let build = json["build"] as? String, !build.isEmpty {
                    char.build = build
                }
                if let heightCm = json["heightCm"] as? Double, heightCm > 0 {
                    char.heightCm = heightCm
                }
                if let weightKg = json["weightKg"] as? Double, weightKg > 0 {
                    char.weightKg = weightKg
                }
                if let hairColor = json["hairColor"] as? String, !hairColor.isEmpty {
                    char.hairColor = hairColor
                }
                if let hairStyle = json["hairStyle"] as? String, !hairStyle.isEmpty {
                    char.hairStyle = hairStyle
                }
                if let hairLength = json["hairLength"] as? String, !hairLength.isEmpty {
                    char.hairLength = hairLength
                }
                if let eyeColor = json["eyeColor"] as? String, !eyeColor.isEmpty {
                    char.eyeColor = eyeColor
                }
                if let eyeColorDesc = json["eyeColorDescription"] as? String, !eyeColorDesc.isEmpty {
                    char.eyeColorDescription = eyeColorDesc
                }
                if let eyeShape = json["eyeShape"] as? String, !eyeShape.isEmpty {
                    char.eyeShape = eyeShape
                }
                if let skinTone = json["skinTone"] as? String, !skinTone.isEmpty {
                    char.skinTone = skinTone
                }
                if let ethnicity = json["ethnicity"] as? String, !ethnicity.isEmpty {
                    char.ethnicity = ethnicity
                }
                if let facialStructure = json["facialStructure"] as? String, !facialStructure.isEmpty {
                    char.facialStructure = facialStructure
                }
                if let features = json["distinguishingFeatures"] as? String, !features.isEmpty, features != "None" {
                    char.distinguishingFeatures = features
                }

                // Create costume if present
                if let costumeJson = json["costume"] as? [String: Any],
                   let costumeName = costumeJson["name"] as? String, !costumeName.isEmpty {
                    let costume = CharacterCostume(
                        name: costumeName,
                        description: costumeJson["description"] as? String ?? "",
                        era: costumeJson["era"] as? String,
                        styleCategory: costumeJson["styleCategory"] as? String,
                        colorPalette: costumeJson["colorPalette"] as? [String],
                        garmentTop: costumeJson["garmentTop"] as? String,
                        garmentBottom: costumeJson["garmentBottom"] as? String,
                        footwear: costumeJson["footwear"] as? String,
                        outerwear: costumeJson["outerwear"] as? String,
                        headwear: costumeJson["headwear"] as? String,
                        accessories: costumeJson["accessories"] as? [String]
                    )

                    if char.costumes == nil {
                        char.costumes = [costume]
                    } else {
                        char.costumes?.append(costume)
                    }

                    // Copy uploaded image as costume front image
                    if let projectPath = projectViewModel.projectPath {
                        let projectDir = projectPath.deletingLastPathComponent()
                        let sanitizedCharName = sanitizeAssetName(char.name)
                        let sanitizedCostumeName = sanitizeAssetName(costumeName)
                        let costumeDir = projectDir
                            .appendingPathComponent("assets/characters/\(sanitizedCharName)/costumes/\(sanitizedCostumeName)")
                        let costumeFrontPath = costumeDir.appendingPathComponent("front.png")

                        do {
                            _ = projectDir.startAccessingSecurityScopedResource()
                            defer { projectDir.stopAccessingSecurityScopedResource() }
                            try FileManager.default.createDirectory(at: costumeDir, withIntermediateDirectories: true)
                            try imageData.write(to: costumeFrontPath)

                            let relativePath = "assets/characters/\(sanitizedCharName)/costumes/\(sanitizedCostumeName)/front.png"
                            if let lastIndex = char.costumes?.indices.last {
                                char.costumes?[lastIndex].imageFront = relativePath
                            }
                        } catch {
                            print("Failed to save costume image: \(error)")
                        }
                    }
                }

                projectViewModel.project.characters[charIndex] = char
                projectViewModel.isDirty = true
                progressHandler(1.0)
            }
        } catch {
            await MainActor.run {
                progressHandler(1.0)
                projectViewModel.errorAlert = ErrorAlert(
                    title: "Analysis Failed",
                    message: "Failed to analyze reference image: \(error.localizedDescription)"
                )
            }
        }
    }

    /// Open project folder in Finder
    func openProjectFolder() {
        guard let projectPath = projectViewModel.projectPath else {
            projectViewModel.errorAlert = ErrorAlert(
                title: "No Project Open",
                message: "Please open a project first."
            )
            return
        }
        let projectDir = projectPath.deletingLastPathComponent()
        NSWorkspace.shared.open(projectDir)
    }

    private func analyzeCharacterTraits(character: Character) async {
        let aiClient = AIServiceClient.shared
        let charId = character.id
        let tracker = aiProgress

        await MainActor.run { tracker.traitAnalysis[charId] = 0 }

        // Check if AI server is available
        guard await aiClient.testConnection() else {
            await MainActor.run {
                tracker.traitAnalysis.removeValue(forKey: charId)
                projectViewModel.errorAlert = ErrorAlert(
                    title: "AI Service Unavailable",
                    message: "Could not connect to AI server at directorschair.app. Please check your internet connection and try again."
                )
            }
            return
        }

        do {
            let analyzer = CharacterAnalyzer(project: projectViewModel.project, aiClient: aiClient)

            let result = try await analyzer.analyzeCharacter(character) { progress in
                Task { @MainActor in
                    tracker.traitAnalysis[charId] = progress
                }
            }

            // Update character with analysis results
            if let charIndex = projectViewModel.project.characters.firstIndex(where: { $0.id == character.id }) {
                await MainActor.run {
                    tracker.traitAnalysis[charId] = 95

                    // Update traits
                    for (trait, score) in result.traitScores {
                        projectViewModel.project.characters[charIndex].traits[trait] = score
                    }

                    // Store AI analysis metadata
                    projectViewModel.project.characters[charIndex].traitsConfidenceScore = result.confidenceScore
                    projectViewModel.project.characters[charIndex].traitsAiReasoning = result.reasoning
                    projectViewModel.project.characters[charIndex].traitsLastCalibrated = Date()

                    // Update physical attributes if available
                    if !result.physicalAttributes.isEmpty {
                        if let build = result.physicalAttributes["build"] {
                            projectViewModel.project.characters[charIndex].build = build
                        }
                        if let hairColor = result.physicalAttributes["hair_color"] {
                            projectViewModel.project.characters[charIndex].hairColor = hairColor
                        }
                        if let eyeColor = result.physicalAttributes["eye_color"] {
                            projectViewModel.project.characters[charIndex].eyeColor = eyeColor
                        }
                    }

                    // Update biography attributes if available
                    if !result.biographyAttributes.isEmpty {
                        if let occupation = result.biographyAttributes["occupation"] {
                            projectViewModel.project.characters[charIndex].occupation = occupation
                        }
                        if let primaryGoal = result.biographyAttributes["primary_goal"] {
                            projectViewModel.project.characters[charIndex].primaryGoal = primaryGoal
                        }
                        if let primaryFear = result.biographyAttributes["primary_fear"] {
                            projectViewModel.project.characters[charIndex].primaryFear = primaryFear
                        }
                    }

                    projectViewModel.isDirty = true
                    tracker.traitAnalysis.removeValue(forKey: charId)
                }
            } else {
                await MainActor.run {
                    tracker.traitAnalysis.removeValue(forKey: charId)
                }
            }

        } catch {
            await MainActor.run {
                tracker.traitAnalysis.removeValue(forKey: charId)
                projectViewModel.errorAlert = ErrorAlert(
                    error: error,
                    title: "Character Analysis Failed"
                )
            }
        }
    }

    private func generateCharacterBiography(character: Character) async {
        let aiClient = AIServiceClient.shared
        let charId = character.id
        let tracker = aiProgress

        await MainActor.run { tracker.biography[charId] = 0 }

        // Check if AI server is available
        guard await aiClient.testConnection() else {
            await MainActor.run {
                tracker.biography.removeValue(forKey: charId)
                projectViewModel.errorAlert = ErrorAlert(
                    title: "AI Service Unavailable",
                    message: "Could not connect to AI server at directorschair.app. Please check your internet connection and try again."
                )
            }
            return
        }

        do {
            let keyTraits = character.traits.sorted { $0.value > $1.value }.prefix(5).map { $0.key }

            let backstory = try await aiClient.generateCharacterBackstory(
                characterName: character.name,
                age: "\(character.age)",
                occupation: character.occupation ?? "",
                keyTraits: Array(keyTraits),
                storyContext: projectViewModel.project.overviewSummary
            )

            // Update character with generated backstory
            if let charIndex = projectViewModel.project.characters.firstIndex(where: { $0.id == character.id }) {
                await MainActor.run {
                    projectViewModel.project.characters[charIndex].backgroundStory = backstory
                    projectViewModel.isDirty = true
                    tracker.biography.removeValue(forKey: charId)
                }
            } else {
                await MainActor.run {
                    tracker.biography.removeValue(forKey: charId)
                }
            }

        } catch {
            await MainActor.run {
                tracker.biography.removeValue(forKey: charId)
                projectViewModel.errorAlert = ErrorAlert(
                    error: error,
                    title: "Biography Generation Failed"
                )
            }
        }
    }

    // MARK: - Location Image Generation

    private func generateLocationImage(location: Location, variation: String, prompt: String, progressHandler: @escaping @MainActor (Double) -> Void) async {
        let aiClient = AIServiceClient.shared

        await MainActor.run { progressHandler(0.05) }

        guard await aiClient.testConnection() else {
            await MainActor.run {
                progressHandler(1.0)
                projectViewModel.errorAlert = ErrorAlert(
                    title: "AI Service Unavailable",
                    message: "Could not connect to AI server at directorschair.app. Please check your internet connection and try again."
                )
            }
            return
        }

        await MainActor.run { progressHandler(0.1) }

        do {
            // Load primary image as reference when generating variations
            var referenceBase64: String? = nil
            var referenceMime: String? = nil
            if variation != "primary" {
                referenceBase64 = loadPrimaryLocationImageAsBase64(for: location)
                if referenceBase64 != nil {
                    referenceMime = "image/png"
                }
            }

            await MainActor.run { progressHandler(0.15) }

            let request = ImageGenerationRequest(
                prompt: prompt,
                provider: .googleImagen,
                aspectRatio: "16:9",
                numberOfImages: 1,
                referenceImageBase64: referenceBase64,
                referenceMimeType: referenceMime
            )

            // Simulate gradual progress during the AI call
            let progressSimulator = Task { @MainActor in
                var current = 0.2
                while current < 0.85 {
                    progressHandler(current)
                    try await Task.sleep(nanoseconds: 800_000_000)
                    current += Double.random(in: 0.03...0.08)
                }
            }

            let response = try await aiClient.generateImage(request)
            progressSimulator.cancel()

            await MainActor.run { progressHandler(0.88) }

            guard let imageData = response.images.first else {
                throw AIClientError.invalidResponse("No image generated")
            }

            await MainActor.run { progressHandler(0.92) }

            // Save image to project directory
            if let projectPath = projectViewModel.projectPath {
                let projectDir = projectPath.deletingLastPathComponent()
                let sanitizedName = sanitizeAssetName(location.name)

                let locationAssetsDir = projectDir
                    .appendingPathComponent("assets")
                    .appendingPathComponent("locations")
                    .appendingPathComponent(sanitizedName)

                let imagePath = locationAssetsDir.appendingPathComponent("\(variation).png")

                let saveSucceeded = await saveImageWithUserPermission(
                    imageData: imageData,
                    imagePath: imagePath,
                    imagesDir: locationAssetsDir,
                    projectDir: projectDir
                )

                if !saveSucceeded {
                    await MainActor.run { progressHandler(1.0) }
                    return
                }

                await MainActor.run { progressHandler(0.96) }

                let relativePath = "assets/locations/\(sanitizedName)/\(variation).png"

                if let locIndex = projectViewModel.project.locations.firstIndex(where: { $0.id == location.id }) {
                    await MainActor.run {
                        if variation == "primary" {
                            projectViewModel.project.locations[locIndex].primaryImage = relativePath
                        }
                        if !projectViewModel.project.locations[locIndex].images.contains(relativePath) {
                            projectViewModel.project.locations[locIndex].images.append(relativePath)
                        }
                        projectViewModel.isDirty = true
                    }
                }
            }

            await MainActor.run { progressHandler(1.0) }

        } catch {
            await MainActor.run {
                progressHandler(1.0)
                projectViewModel.errorAlert = ErrorAlert(
                    error: error,
                    title: "Location Image Generation Failed"
                )
            }
        }
    }

    /// Load the primary image for a location as base64 string for use as reference
    private func loadPrimaryLocationImageAsBase64(for location: Location) -> String? {
        guard let projectPath = projectViewModel.projectPath else { return nil }
        let projectDir = projectPath.deletingLastPathComponent()

        // Try location's stored primary image path first
        if let primaryPath = location.primaryImage {
            let fullPath = projectDir.appendingPathComponent(primaryPath)
            if let imageData = try? Data(contentsOf: fullPath) {
                return imageData.base64EncodedString()
            }
        }

        // Try discovered primary image from filesystem
        let sanitizedName = sanitizeAssetName(location.name)
        let primaryPath = projectDir
            .appendingPathComponent("assets/locations/\(sanitizedName)/primary.png")
        if let imageData = try? Data(contentsOf: primaryPath) {
            return imageData.base64EncodedString()
        }

        return nil
    }
}

// MARK: - App Toolbar

struct AppToolbar: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var tourManager: GuidedTourManager
    @EnvironmentObject var captureService: LiveCaptureService
    @EnvironmentObject var cloudSyncManager: CloudSyncManager

    var body: some View {
        HStack(spacing: 0) {
            // View Selection (Radio Button Group) — excludes Projects (moved to right)
            HStack(spacing: 4) {
                ForEach(AppView.allCases.filter { $0 != .projects }) { view in
                    let button = Button(action: {
                        debugLog("🖱️ Button pressed: \(view.rawValue)")
                        coordinator.navigateTo(view)
                        debugLog("🖱️ Button action complete: \(view.rawValue)")
                    }) {
                        Label(view.rawValue, systemImage: view.icon)
                            .labelStyle(.iconOnly)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(ToolbarButtonStyle(isSelected: coordinator.selectedView == view, tooltipText: view.rawValue))
                    .accessibilityIdentifier("nav-\(view.rawValue.lowercased().replacingOccurrences(of: " ", with: "-"))")
                    .spotlightTarget(id: "toolbar-\(view.rawValue)")

                    // Add hint dots on specific toolbar buttons
                    if view == .visionBoard {
                        button.hintDot(id: "hint-vision-board", title: "Vision Board", description: "Create mood boards and visual references")
                    } else {
                        button
                    }
                }
            }
            .padding(.leading, 12)

            Spacer()

            // Toggle Controls
            HStack(spacing: 8) {
                // Projects folder button (moved from left tab group)
                Button(action: {
                    coordinator.navigateTo(.projects)
                }) {
                    Label("Projects", systemImage: "folder")
                        .labelStyle(.iconOnly)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(ToolbarButtonStyle(isSelected: coordinator.selectedView == .projects, tooltipText: "Projects"))
                .accessibilityIdentifier("nav-projects")

                if coordinator.showingUsageWidget {
                    AIUsageWidget(projectStorageSize: projectViewModel.projectStorageSize)
                }

                Divider()
                    .frame(height: 20)

                // Global capture device selector
                CaptureDeviceToolbarItem(captureService: captureService)

                Divider()
                    .frame(height: 20)

                // Cloud sync status
                SyncStatusView(syncManager: cloudSyncManager)

                // Account menu
                AccountMenuView()

                Divider()
                    .frame(height: 20)

                Button(action: {
                    coordinator.toggleNavigator()
                }) {
                    Image(systemName: "sidebar.left")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(ToggleButtonStyle(isActive: coordinator.showingNavigator, tooltipText: "Navigator (⌘⌥1)"))
                .spotlightTarget(id: "toggle-navigator")

                Button(action: {
                    coordinator.toggleTimeline()
                }) {
                    Image(systemName: "waveform")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(ToggleButtonStyle(isActive: coordinator.showingTimeline, tooltipText: "Timeline (⌘⌥2)"))
                .hintDot(id: "hint-ai-chat", title: "AI Chat Assistant", description: "Press Shift twice to open the AI Chat assistant")

                Button(action: {
                    coordinator.toggleRightPanel()
                }) {
                    Image(systemName: "sidebar.right")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(ToggleButtonStyle(isActive: coordinator.showingRightPanel, tooltipText: "Right Panel (⌘⌥3)"))
            }
            .padding(.trailing, 12)
        }
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(nsColor: .separatorColor)),
            alignment: .bottom
        )
    }
}

// MARK: - Capture Device Toolbar Item

/// Compact capture device selector for the app toolbar — sets default video source globally.
/// Does NOT start a capture session. The TakesSectionView auto-connects when it appears.
struct CaptureDeviceToolbarItem: View {
    @ObservedObject var captureService: LiveCaptureService
    @State private var showingHardwarePopover = false

    private var hasDefault: Bool { captureService.defaultDevice != nil }
    private var isLive: Bool { captureService.isSessionRunning }

    var body: some View {
        Button {
            showingHardwarePopover.toggle()
        } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(isLive ? Color.green : hasDefault ? Color.accentColor : Color.gray.opacity(0.35))
                    .frame(width: 7, height: 7)

                Image(systemName: "cable.connector.horizontal")
                    .font(.system(size: 11))
                    .foregroundColor(hasDefault ? .primary : .secondary)

                if let device = captureService.defaultDevice {
                    Text(device.localizedName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .frame(maxWidth: 120)
                } else {
                    Text("No Device")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isLive ? Color.green.opacity(0.08)
                          : hasDefault ? Color.accentColor.opacity(0.06)
                          : Color(nsColor: .quaternarySystemFill))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isLive ? Color.green.opacity(0.2)
                            : hasDefault ? Color.accentColor.opacity(0.15)
                            : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingHardwarePopover, arrowEdge: .bottom) {
            HardwarePopoverView(captureService: captureService)
        }
    }
}

// MARK: - Instant Tooltip using NSWindow

/// A floating tooltip window that appears instantly on hover
class TooltipWindowController {
    static let shared = TooltipWindowController()

    private var window: NSWindow?
    private var textField: NSTextField?

    private init() {}

    func show(text: String, near point: NSPoint) {
        debugLog("🪟 TooltipWindow.show: '\(text)' near \(point)")
        hide()

        let textField = NSTextField(labelWithString: text)
        textField.font = NSFont.systemFont(ofSize: 11)
        textField.textColor = NSColor.labelColor
        textField.backgroundColor = NSColor.windowBackgroundColor
        textField.isBordered = false
        textField.sizeToFit()

        let padding: CGFloat = 8
        let contentSize = NSSize(
            width: textField.frame.width + padding * 2,
            height: textField.frame.height + padding
        )

        textField.frame.origin = NSPoint(x: padding, y: padding / 2)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.backgroundColor = NSColor.windowBackgroundColor
        window.isOpaque = false
        window.hasShadow = true
        window.level = .floating
        window.ignoresMouseEvents = true
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 4
        window.contentView?.addSubview(textField)

        // Position below the mouse cursor
        let screenPoint = NSPoint(
            x: point.x - contentSize.width / 2,
            y: point.y - contentSize.height - 20
        )
        debugLog("🪟 TooltipWindow positioning at: \(screenPoint)")
        window.setFrameOrigin(screenPoint)
        window.orderFront(nil)

        self.window = window
        self.textField = textField
        debugLog("🪟 TooltipWindow shown")
    }

    func hide() {
        window?.orderOut(nil)
        window = nil
        textField = nil
    }
}


// MARK: - Toolbar Button Styles

struct ToolbarButtonStyle: ButtonStyle {
    let isSelected: Bool
    var tooltipText: String = ""
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        isSelected
                            ? Color.accentColor.opacity(0.2)
                            : (isHovered ? Color.gray.opacity(0.1) : Color.clear)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        isSelected ? Color.accentColor : Color.clear,
                        lineWidth: isSelected ? 1.5 : 0
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .onHover { hovering in
                isHovered = hovering
                if !tooltipText.isEmpty {
                    if hovering {
                        let mouseLocation = NSEvent.mouseLocation
                        TooltipWindowController.shared.show(text: tooltipText, near: mouseLocation)
                    } else {
                        TooltipWindowController.shared.hide()
                    }
                }
            }
    }
}

struct ToggleButtonStyle: ButtonStyle {
    let isActive: Bool
    var tooltipText: String = ""
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isActive ? .accentColor : .secondary)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        isActive
                            ? Color.accentColor.opacity(0.15)
                            : (isHovered ? Color.gray.opacity(0.1) : Color.clear)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .onHover { hovering in
                isHovered = hovering
                if !tooltipText.isEmpty {
                    if hovering {
                        let mouseLocation = NSEvent.mouseLocation
                        TooltipWindowController.shared.show(text: tooltipText, near: mouseLocation)
                    } else {
                        TooltipWindowController.shared.hide()
                    }
                }
            }
    }
}

// MARK: - Navigator Sidebar

struct NavigatorSidebar: View {
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @State private var selectedTab: NavigatorTab = .outline

    var body: some View {
        VStack(spacing: 0) {
            // Project Identity Header
            if projectViewModel.hasProject {
                ProjectIdentityView(
                    project: projectViewModel.project,
                    projectPath: projectViewModel.projectPath,
                    size: .standard,
                    showMetadata: false
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

                Divider()
            }

            // Navigator Header
            HStack {
                Text("Navigator")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Tab Selector
            Picker("", selection: $selectedTab) {
                ForEach(NavigatorTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            .help("Switch between Outline, Versions, and Comments views")

            Divider()

            // Tab Content
            Group {
                switch selectedTab {
                case .outline:
                    OutlineTab()
                case .markers:
                    MarkersTab()
                case .versions:
                    VersionsTab()
                case .comments:
                    CommentsTab()
                }
            }
        }
    }
}

enum NavigatorTab: String, CaseIterable, Identifiable {
    case outline = "Outline"
    case markers = "Markers"
    case versions = "Versions"
    case comments = "Comments"

    var id: String { rawValue }
}

// MARK: - Timeline Container

struct TimelineContainer: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var timelineViewModel: TimelineViewModel

    /// Track sequence count to detect actual changes (not just any array mutation)
    @State private var lastSequenceCount: Int = 0

    /// Audio player for timeline TTS playback
    @State private var timelineAudioPlayer: AVAudioPlayer?

    /// Whether the soundtrack file importer is showing
    @State private var showSoundtrackImporter: Bool = false

    /// Project base path as URL for image loading (matches CinematographyView resolution)
    private var projectBaseURL: URL? {
        projectViewModel.projectPath?.deletingLastPathComponent()
    }

    var body: some View {
        TimelineView(
            viewModel: timelineViewModel,
            projectBasePath: projectBaseURL,
            onSegmentClicked: { segment in
                // Handle segment click - navigate to the appropriate scene
                if !segment.sceneName.isEmpty {
                    // Find scene by name and select it
                    if let scene = projectViewModel.allScenes.first(where: { $0.name == segment.sceneName }) {
                        coordinator.selectScene(scene)
                        // Navigate to bubble view
                        coordinator.navigateTo(.bubble)
                    }
                }
            },
            onSegmentDoubleClicked: { segment in
                // Handle double-click - highlight the corresponding bubble
                let itemType: String
                switch segment.contentType {
                case .dialogue:
                    itemType = "dialogue"
                case .action:
                    itemType = "action"
                case .narration:
                    itemType = "narration"
                case .note:
                    itemType = "note"
                case .soundNote:
                    itemType = "soundNote"
                }

                // Use sourceItemId (the original dialogue/action/narration ID) for matching
                let itemId = segment.sourceItemId ?? segment.id.uuidString

                // Trigger highlight in bubble view
                coordinator.highlightBubbleItem(
                    id: itemId,
                    type: itemType,
                    sceneName: segment.sceneName
                )

                // Navigate to bubble view if not already there
                if coordinator.selectedView != .bubble {
                    coordinator.navigateTo(.bubble)
                }
            },
            onOptionClickSegment: { segment in
                // Option+Click: jump to script element
                if let sourceItemId = segment.sourceItemId {
                    let itemType: String
                    switch segment.contentType {
                    case .dialogue: itemType = "dialogue"
                    case .action: itemType = "action"
                    case .narration: itemType = "narration"
                    case .note: itemType = "note"
                    case .soundNote: itemType = "soundNote"
                    }
                    coordinator.jumpToScriptElement(itemId: sourceItemId, itemType: itemType)
                }
            },
            onOptionClickShotLabel: { shotId, sceneName in
                // Option+Click on shot label: resolve the full Shot and jump to script
                if let scene = projectViewModel.allScenes.first(where: { $0.name == sceneName }),
                   let shot = scene.shots.first(where: { $0.shotId == shotId }) {
                    coordinator.jumpToScriptForShot(shot, scene: scene)
                }
            },
            onShotLabelDoubleClicked: { shotId, sceneName in
                // Find the shot by shotId and sceneName to ensure correct match
                if let scene = projectViewModel.allScenes.first(where: { $0.name == sceneName }),
                   let shot = scene.shots.first(where: { $0.shotId == shotId }) {
                    coordinator.selectScene(scene)
                    coordinator.selectShot(shot)
                    coordinator.navigateTo(.shotList)
                }
            },
            onSceneMarkerDoubleClicked: { sceneName in
                // Double-click scene marker → open scene in Scenes view
                if let scene = projectViewModel.allScenes.first(where: { $0.name == sceneName }) {
                    coordinator.selectScene(scene)
                    coordinator.navigateTo(.scenes)
                }
            },
            onLightCueDoubleClicked: { cueId in
                // Double-click light cue → open in Lighting Cue Editor
                coordinator.selectedLightCueId = cueId
                coordinator.preferredStoryDesignMode = "lighting"
                coordinator.navigateTo(.storyDesign)
            },
            onSFXCueDoubleClicked: { cueId in
                // Double-click SFX cue → open in SFX Editor
                coordinator.selectedSFXCueId = cueId
                coordinator.preferredStoryDesignMode = "lighting"
                coordinator.navigateTo(.storyDesign)
            },
            onSupportCueDoubleClicked: { cueId in
                // Double-click support cue → open in choreography editor
                coordinator.selectedSupportCueId = cueId
                coordinator.preferredStoryDesignMode = "lighting"
                coordinator.navigateTo(.storyDesign)
            },
            onShotLabelMoved: { _, _, _ in
                // Sync updated project and save silently (no loading overlay)
                if let updatedProject = timelineViewModel.getProject() {
                    projectViewModel.project = updatedProject
                    Task { await projectViewModel.saveSilently() }
                }
            },
            onSegmentMoved: { _, _ in
                // Sync updated project and save silently (no loading overlay)
                if let updatedProject = timelineViewModel.getProject() {
                    projectViewModel.project = updatedProject
                    Task { await projectViewModel.saveSilently() }
                }
            },
            onSegmentsMoved: { _ in
                // Sync updated project and save silently (no loading overlay)
                if let updatedProject = timelineViewModel.getProject() {
                    projectViewModel.project = updatedProject
                    Task { await projectViewModel.saveSilently() }
                }
            },
            onAnalyzeTimeline: {
                coordinator.requestTimelineAnalysis(scope: .all)
            },
            onGenerateAudio: { segment in
                guard segment.contentType == .dialogue,
                      let sourceId = segment.sourceItemId else { return }

                timelineViewModel.generatingAudioSourceIds.insert(sourceId)

                Task {
                    do {
                        let dialogue = timelineViewModel.findDialogue(sourceItemId: sourceId)
                        let character = timelineViewModel.findCharacter(name: segment.character)
                        let voiceName = character?.voice ?? (character?.gender.lowercased() == "female" ? "Kore" : "Charon")

                        var emotionParts: [String] = []
                        if let style = character?.voiceStyle, !style.isEmpty {
                            emotionParts.append(style)
                        }
                        if let tags = dialogue?.tags, !tags.isEmpty {
                            emotionParts.append(contentsOf: tags)
                        }
                        let emotion = emotionParts.isEmpty ? nil : "Say \(emotionParts.joined(separator: ", "))"

                        // Strip HTML from text
                        var text = dialogue?.text ?? segment.text
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.hasPrefix("<") {
                            let tagPattern = "<[^>]+>"
                            if let regex = try? NSRegularExpression(pattern: tagPattern, options: .caseInsensitive) {
                                let range = NSRange(location: 0, length: text.utf16.count)
                                text = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                        }

                        let request = SpeechGenerationRequest(
                            text: text,
                            provider: .google,
                            voiceName: voiceName,
                            emotion: emotion,
                            characterName: segment.character,
                            voiceTone: character?.voiceTone,
                            voicePersonality: character?.voicePersonality,
                            voicePace: character?.voicePace,
                            voiceAccent: character?.voiceAccent,
                            voiceAge: character?.voiceAge
                        )

                        let response = try await AIServiceClient.shared.generateSpeech(request)

                        // Save audio file
                        if let projectPath = projectViewModel.projectPath {
                            let projectDir = projectPath.deletingLastPathComponent()
                            let audioDir = projectDir.appendingPathComponent("assets/audio/dialogues")
                            try FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)

                            let fileName = "\(sourceId).wav"
                            let filePath = audioDir.appendingPathComponent(fileName)
                            try response.audioData.write(to: filePath)

                            let relativePath = "assets/audio/dialogues/\(fileName)"
                            timelineViewModel.updateDialogueAudioPath(sourceItemId: sourceId, audioFilePath: relativePath)

                            // Sync project back
                            if let updatedProject = timelineViewModel.getProject() {
                                projectViewModel.project = updatedProject
                                Task { await projectViewModel.saveSilently() }
                            }

                            // Refresh timeline to update hasAudio
                            timelineViewModel.setProject(projectViewModel.project)
                        }

                        // Play the generated audio
                        timelineAudioPlayer?.stop()
                        timelineAudioPlayer = try AVAudioPlayer(data: response.audioData)
                        timelineViewModel.playingAudioSourceId = sourceId
                        timelineAudioPlayer?.play()

                        // Monitor playback completion
                        Task {
                            while timelineAudioPlayer?.isPlaying == true {
                                try? await Task.sleep(nanoseconds: 200_000_000)
                            }
                            if timelineViewModel.playingAudioSourceId == sourceId {
                                timelineViewModel.playingAudioSourceId = nil
                            }
                        }

                    } catch {
                        print("Timeline TTS generation error: \(error)")
                    }

                    timelineViewModel.generatingAudioSourceIds.remove(sourceId)
                }
            },
            onPlayAudio: { segment in
                guard let sourceId = segment.sourceItemId,
                      let dialogue = timelineViewModel.findDialogue(sourceItemId: sourceId),
                      let audioPath = dialogue.audioFilePath,
                      let projectPath = projectViewModel.projectPath else { return }

                let projectDir = projectPath.deletingLastPathComponent()
                let fileURL = projectDir.appendingPathComponent(audioPath)
                guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

                do {
                    timelineAudioPlayer?.stop()
                    timelineAudioPlayer = try AVAudioPlayer(contentsOf: fileURL)
                    timelineViewModel.playingAudioSourceId = sourceId
                    timelineAudioPlayer?.play()

                    // Monitor playback completion
                    Task {
                        while timelineAudioPlayer?.isPlaying == true {
                            try? await Task.sleep(nanoseconds: 200_000_000)
                        }
                        if timelineViewModel.playingAudioSourceId == sourceId {
                            timelineViewModel.playingAudioSourceId = nil
                        }
                    }
                } catch {
                    print("Timeline audio playback error: \(error)")
                }
            },
            onStopAudio: {
                timelineAudioPlayer?.stop()
                timelineAudioPlayer = nil
                timelineViewModel.playingAudioSourceId = nil
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
        .onAppear {
            // Set project and show global timeline view
            timelineViewModel.projectFilePath = projectViewModel.projectPath
            timelineViewModel.setProject(projectViewModel.project)
            timelineViewModel.showGlobal()
            lastSequenceCount = projectViewModel.project.sequences.count

            // Load existing soundtracks from project
            timelineViewModel.soundtrackTracks = projectViewModel.project.soundtracks

            // Load existing light cues from project
            timelineViewModel.lightCues = projectViewModel.project.lightCues

            // Load existing SFX cues from project
            timelineViewModel.sfxCues = projectViewModel.project.sfxCues

            // Load existing support cues from project
            timelineViewModel.supportCues = projectViewModel.project.supportCues

            // Wire soundtrack import callback
            timelineViewModel.onImportSoundtrack = {
                showSoundtrackImporter = true
            }

            // Wire soundtrack changed callback to persist
            timelineViewModel.onSoundtracksChanged = { tracks in
                projectViewModel.project.soundtracks = tracks
                Task { await projectViewModel.saveSilently() }
            }

            // Wire light cues changed callback to persist
            timelineViewModel.onLightCuesChanged = { cues in
                projectViewModel.project.lightCues = cues
                Task { await projectViewModel.saveSilently() }
            }

            // Wire SFX cues changed callback to persist
            timelineViewModel.onSFXCuesChanged = { cues in
                projectViewModel.project.sfxCues = cues
                Task { await projectViewModel.saveSilently() }
            }

            // Wire support cues changed callback to persist
            timelineViewModel.onSupportCuesChanged = { cues in
                projectViewModel.project.supportCues = cues
                Task { await projectViewModel.saveSilently() }
            }
        }
        .fileImporter(
            isPresented: $showSoundtrackImporter,
            allowedContentTypes: [.audio, .mp3, .wav, .aiff],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                importSoundtrackFile(url: url)
            case .failure(let error):
                print("Soundtrack import error: \(error)")
            }
        }
        // Refresh when project finishes loading (catches async restoreLastProject)
        .onChange(of: projectViewModel.hasProject) { _, hasProject in
            if hasProject {
                timelineViewModel.projectFilePath = projectViewModel.projectPath
                timelineViewModel.setProject(projectViewModel.project)
                timelineViewModel.showGlobal()
                lastSequenceCount = projectViewModel.project.sequences.count
                timelineViewModel.soundtrackTracks = projectViewModel.project.soundtracks
                timelineViewModel.lightCues = projectViewModel.project.lightCues
                timelineViewModel.sfxCues = projectViewModel.project.sfxCues
                timelineViewModel.supportCues = projectViewModel.project.supportCues

                // Auto-open AI chat on first launch after project loads
                if !UserDefaults.standard.bool(forKey: "hasShownAIChatWelcome") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        if !coordinator.showingAIChat {
                            coordinator.showingAIChat = true
                        }
                    }
                }
            }
        }
        // Only refresh when sequence COUNT changes, not on every array comparison
        .onChange(of: projectViewModel.project.sequences.count) { _, newCount in
            if newCount != lastSequenceCount {
                lastSequenceCount = newCount
                timelineViewModel.setProject(projectViewModel.project)
                timelineViewModel.refresh()
            }
        }
        // Keep timeline cue lanes in sync when editor changes project cues
        .onChange(of: projectViewModel.project.lightCues) { _, newCues in
            if timelineViewModel.lightCues != newCues {
                timelineViewModel.lightCues = newCues
                timelineViewModel.extendDurationIfNeeded()
                Task { await projectViewModel.saveSilently() }
            }
        }
        .onChange(of: projectViewModel.project.sfxCues) { _, newCues in
            if timelineViewModel.sfxCues != newCues {
                timelineViewModel.sfxCues = newCues
                timelineViewModel.extendDurationIfNeeded()
                Task { await projectViewModel.saveSilently() }
            }
        }
        .onChange(of: projectViewModel.project.supportCues) { _, newCues in
            if timelineViewModel.supportCues != newCues {
                timelineViewModel.supportCues = newCues
                timelineViewModel.extendDurationIfNeeded()
                Task { await projectViewModel.saveSilently() }
            }
        }
        // Subscribe to project changed events (e.g., when bubbles are reordered)
        .onReceive(coordinator.projectChanged) { _ in
            debugLog("🎬 TimelineContainer: projectChanged received, refreshing timeline")
            timelineViewModel.setProject(projectViewModel.project)
            timelineViewModel.refresh()
        }
    }

    // MARK: - Soundtrack Import

    private func importSoundtrackFile(url: URL) {
        guard let projectPath = projectViewModel.projectPath else { return }
        let projectDir = projectPath.deletingLastPathComponent()

        // Start security-scoped access
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        Task {
            do {
                // Extract waveform data
                let waveformData = try WaveformExtractor.extract(from: url)

                // Create soundtrack directory
                let soundtrackDir = projectDir.appendingPathComponent("assets/audio/soundtracks")
                try FileManager.default.createDirectory(at: soundtrackDir, withIntermediateDirectories: true)

                // Copy audio file
                let trackId = UUID().uuidString
                let ext = url.pathExtension.isEmpty ? "mp3" : url.pathExtension
                let destFileName = "\(trackId).\(ext)"
                let destURL = soundtrackDir.appendingPathComponent(destFileName)
                try FileManager.default.copyItem(at: url, to: destURL)

                let relativePath = "assets/audio/soundtracks/\(destFileName)"

                // Assign a color based on existing track count
                let colors = ["#00BCD4", "#E91E63", "#4CAF50", "#FF9800", "#9C27B0", "#03A9F4"]
                let colorIndex = timelineViewModel.soundtrackTracks.count % colors.count

                // Create track model
                let track = SoundtrackTrack(
                    id: trackId,
                    name: url.deletingPathExtension().lastPathComponent,
                    audioFilePath: relativePath,
                    startTimeOffset: 0,
                    duration: waveformData.duration,
                    volume: 1.0,
                    color: colors[colorIndex],
                    isMuted: false,
                    waveformSamples: waveformData.samples,
                    sortOrder: timelineViewModel.soundtrackTracks.count
                )

                await MainActor.run {
                    timelineViewModel.addSoundtrack(track)
                }
            } catch {
                print("Failed to import soundtrack: \(error)")
            }
        }
    }
}

// MARK: - Production Container

/// Combines Schedule, Cast & Crew, and Budget into a single tabbed view
struct ProductionContainer: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @ObservedObject var scheduleViewModel: ScheduleViewModel
    @ObservedObject var castCrewViewModel: CastCrewViewModel
    @ObservedObject var budgetViewModel: BudgetViewModel
    @ObservedObject var equipmentViewModel: EquipmentViewModel
    @ObservedObject var ganttViewModel: GanttViewModel

    var body: some View {
        ProductionViewWrapper(
            project: projectViewModel.project,
            projectPath: projectViewModel.projectPath,
            subtitle: "Production"
        ) {
            VStack(spacing: 0) {
                // Custom icon+label tab bar
                HStack(spacing: 0) {
                    ProductionTabButton(
                        icon: "calendar",
                        title: "Schedule",
                        isSelected: coordinator.selectedProductionTab == "Schedule"
                    ) {
                        coordinator.selectedProductionTab = "Schedule"
                    }
                    ProductionTabButton(
                        icon: "chart.bar.xaxis",
                        title: "Gantt",
                        isSelected: coordinator.selectedProductionTab == "Gantt"
                    ) {
                        coordinator.selectedProductionTab = "Gantt"
                    }
                    ProductionTabButton(
                        icon: "person.3",
                        title: "Cast & Crew",
                        isSelected: coordinator.selectedProductionTab == "Cast & Crew"
                    ) {
                        coordinator.selectedProductionTab = "Cast & Crew"
                    }
                    ProductionTabButton(
                        icon: "banknote",
                        title: "Accounting",
                        isSelected: coordinator.selectedProductionTab == "Accounting"
                    ) {
                        coordinator.selectedProductionTab = "Accounting"
                    }
                    ProductionTabButton(
                        icon: "camera.metering.matrix",
                        title: "Equipment",
                        isSelected: coordinator.selectedProductionTab == "Equipment"
                    ) {
                        coordinator.selectedProductionTab = "Equipment"
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

                Divider()

                // Tab content
                switch coordinator.selectedProductionTab {
                case "Schedule":
                    ScheduleView(viewModel: scheduleViewModel, sequences: projectViewModel.project.sequences, onSceneStatusUpdate: updateSceneStatus)
                case "Gantt":
                    GanttChartView(viewModel: ganttViewModel)
                case "Cast & Crew":
                    CastCrewView(viewModel: castCrewViewModel)
                case "Accounting":
                    BudgetView(viewModel: budgetViewModel)
                case "Equipment":
                    EquipmentView(viewModel: equipmentViewModel)
                default:
                    ScheduleView(viewModel: scheduleViewModel, sequences: projectViewModel.project.sequences, onSceneStatusUpdate: updateSceneStatus)
                }
            }
        }
        .onAppear {
            wireUpCallbacks()
            loadProductionData()
        }
        .onChange(of: coordinator.selectedProductionTab) { _, _ in loadProductionData() }
    }

    private func wireUpCallbacks() {
        // Sync schedule changes back to project (triggers auto-save)
        scheduleViewModel.onScheduleChanged = { items in
            projectViewModel.project.scheduleItems = items
        }

        // Sync cast & crew changes back to project
        castCrewViewModel.onCastChanged = { members in
            projectViewModel.project.castMembers = members
        }
        castCrewViewModel.onCrewChanged = { members in
            projectViewModel.project.crewMembers = members
        }
        castCrewViewModel.onTeamsChanged = { teams in
            projectViewModel.project.teams = teams
        }
        castCrewViewModel.onEquipmentChanged = { equipment in
            projectViewModel.project.equipmentLibrary = equipment
        }

        // Sync budget changes back to project
        budgetViewModel.onBudgetChanged = { budget in
            projectViewModel.project.projectBudget = budget
        }

        // AI receipt analysis callback
        // Capture category names upfront (on main actor) to avoid actor-isolation issues in the async closure
        let capturedBudgetVM = budgetViewModel
        budgetViewModel.onAnalyzeReceipt = { imageData, mimeType in
            let logFile = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("receipt_analysis_debug.log")
            func debugLog(_ msg: String) {
                let line = "[\(Date())] \(msg)\n"
                print("[Receipt Analysis] \(msg)")
                if let data = line.data(using: .utf8) {
                    if FileManager.default.fileExists(atPath: logFile.path) {
                        if let handle = try? FileHandle(forWritingTo: logFile) {
                            handle.seekToEndOfFile()
                            handle.write(data)
                            handle.closeFile()
                        }
                    } else {
                        try? data.write(to: logFile)
                    }
                }
            }

            let aiClient = AIServiceClient.shared
            debugLog("Starting analysis, data size: \(imageData.count) bytes, mime: \(mimeType)")

            guard await aiClient.testConnection() else {
                debugLog("AI server connection failed")
                return []
            }
            debugLog("Server connection OK")

            let base64 = imageData.base64EncodedString()
            debugLog("Base64 encoded, length: \(base64.count)")

            // Build category names on main actor
            let categoryNames = capturedBudgetVM.budget.categories.map { $0.name }.joined(separator: ", ")
            debugLog("Categories: \(categoryNames)")

            let prompt = """
            Analyze this receipt image. If the receipt contains multiple distinct line items, return ALL items individually.
            Return ONLY valid JSON with this structure:
            {
              "vendor": "store/vendor name",
              "date": "YYYY-MM-DD format",
              "items": [
                {"description": "item 1 description", "amount": 12.99, "category": "best matching category"},
                {"description": "item 2 description", "amount": 45.00, "category": "best matching category"}
              ]
            }

            Rules:
            - "vendor" and "date" are shared across all items.
            - Each item in "items" should have its own description, amount, and category.
            - If the receipt has only one item or a single total, return a single item in the array.
            - Do NOT include tax/tip as separate items unless they are distinct line items on the receipt.
            - Available budget categories: \(categoryNames)
            - Choose the category that best matches each item. If no category matches well, use the most general one.
            - Return ONLY the JSON object, no other text.
            """

            let request = TextGenerationRequest(
                prompt: prompt,
                provider: .google,
                maxTokens: 4000,
                temperature: 0.1,
                imageBase64: base64,
                imageMimeType: mimeType
            )

            do {
                debugLog("Sending request to AI...")
                let response = try await aiClient.generateText(request)
                let text = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
                debugLog("AI response: \(text)")

                // Strip markdown code fences if present
                var jsonString = text
                if jsonString.hasPrefix("```json") {
                    jsonString = String(jsonString.dropFirst(7))
                } else if jsonString.hasPrefix("```") {
                    jsonString = String(jsonString.dropFirst(3))
                }
                if jsonString.hasSuffix("```") {
                    jsonString = String(jsonString.dropLast(3))
                }
                jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
                debugLog("Cleaned JSON string: \(jsonString)")

                guard let jsonData = jsonString.data(using: .utf8),
                      let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                    debugLog("Failed to parse JSON")
                    return []
                }

                debugLog("Parsed JSON: \(json)")

                let sharedVendor = json["vendor"] as? String ?? ""
                let sharedDate = json["date"] as? String ?? ""

                guard let items = json["items"] as? [[String: Any]], !items.isEmpty else {
                    debugLog("No items array found in response")
                    return []
                }

                var results: [ReceiptAnalysisResult] = []
                for item in items {
                    // Handle amount as either Double or Int from JSON
                    let parsedAmount: Double
                    if let doubleVal = item["amount"] as? Double {
                        parsedAmount = doubleVal
                    } else if let intVal = item["amount"] as? Int {
                        parsedAmount = Double(intVal)
                    } else if let strVal = item["amount"] as? String, let numVal = Double(strVal) {
                        parsedAmount = numVal
                    } else {
                        parsedAmount = 0
                    }

                    let result = ReceiptAnalysisResult(
                        description: item["description"] as? String ?? "",
                        vendor: sharedVendor,
                        date: sharedDate,
                        amount: parsedAmount,
                        category: item["category"] as? String ?? ""
                    )
                    results.append(result)
                }

                debugLog("Returning \(results.count) results")
                return results
            } catch {
                debugLog("Error: \(error)")
                return []
            }
        }

        // Sync equipment changes back to project
        equipmentViewModel.onEquipmentChanged = { equipment in
            projectViewModel.project.equipmentLibrary = equipment
        }
        equipmentViewModel.onAllocationsChanged = { allocations in
            projectViewModel.project.equipmentAllocations = allocations
        }

        // Sync Gantt task changes back to project
        ganttViewModel.onTasksChanged = { tasks in
            projectViewModel.project.ganttTasks = tasks
        }
    }

    private func loadProductionData() {
        switch coordinator.selectedProductionTab {
        case "Schedule":
            // Auto-promote any "Planned" items that have a date to "Scheduled"
            var items = projectViewModel.project.scheduleItems
            var changed = false
            for i in items.indices {
                if items[i].status == "Planned", let date = items[i].shootDate, !date.isEmpty {
                    items[i].status = "Scheduled"
                    changed = true
                    // Also update the scene's productionStatus
                    updateSceneStatus(sequenceName: items[i].sequenceName, sceneName: items[i].sceneName, status: "Scheduled")
                }
            }
            if changed {
                projectViewModel.project.scheduleItems = items
            }
            scheduleViewModel.setScheduleItems(items)
        case "Cast & Crew":
            castCrewViewModel.setCastMembers(projectViewModel.project.castMembers)
            castCrewViewModel.setCrewMembers(projectViewModel.project.crewMembers)
            castCrewViewModel.setTeams(projectViewModel.project.teams)
            castCrewViewModel.setEquipment(projectViewModel.project.equipmentLibrary)
            castCrewViewModel.characterNames = projectViewModel.project.characters.map { $0.name }
            castCrewViewModel.scheduleItems = projectViewModel.project.scheduleItems
            if let projectPath = projectViewModel.projectPath {
                castCrewViewModel.projectBasePath = projectPath.deletingLastPathComponent()
            }
        case "Accounting":
            budgetViewModel.setBudget(projectViewModel.project.projectBudget ?? ProjectBudget())
            budgetViewModel.castMembers = projectViewModel.project.castMembers
            budgetViewModel.crewMembers = projectViewModel.project.crewMembers
            budgetViewModel.equipment = projectViewModel.project.equipmentLibrary
            budgetViewModel.equipmentAllocations = projectViewModel.project.equipmentAllocations
            budgetViewModel.scheduleItems = projectViewModel.project.scheduleItems
            budgetViewModel.props = projectViewModel.project.props
            budgetViewModel.sequences = projectViewModel.project.sequences
            // Pass accounting defaults and project base path
            budgetViewModel.defaultDepartment = projectViewModel.project.defaultExpenseDepartment
            budgetViewModel.defaultAccountCode = projectViewModel.project.defaultExpenseAccountCode
            if let projectPath = projectViewModel.projectPath {
                budgetViewModel.projectBasePath = projectPath.deletingLastPathComponent()
            }
        case "Gantt":
            ganttViewModel.setTasks(projectViewModel.project.ganttTasks)
            ganttViewModel.scheduleItems = projectViewModel.project.scheduleItems
            ganttViewModel.castMembers = projectViewModel.project.castMembers
            ganttViewModel.crewMembers = projectViewModel.project.crewMembers
            ganttViewModel.characters = projectViewModel.project.characters
            ganttViewModel.props = projectViewModel.project.props
            ganttViewModel.equipment = projectViewModel.project.equipmentLibrary
            ganttViewModel.locations = projectViewModel.project.locations
            ganttViewModel.sequences = projectViewModel.project.sequences
        case "Equipment":
            equipmentViewModel.setEquipment(projectViewModel.project.equipmentLibrary)
            equipmentViewModel.setAllocations(projectViewModel.project.equipmentAllocations)
        default: break
        }
    }

    private func updateSceneStatus(sequenceName: String, sceneName: String, status: String) {
        if let seqIdx = projectViewModel.project.sequences.firstIndex(where: { $0.name == sequenceName }),
           let sceneIdx = projectViewModel.project.sequences[seqIdx].scenes.firstIndex(where: { $0.name == sceneName }) {
            projectViewModel.project.sequences[seqIdx].scenes[sceneIdx].productionStatus = status
        }
    }
}

// MARK: - Placeholder Views

struct ProjectOverviewPlaceholder: View {
    var body: some View {
        PlaceholderView(title: "Project Overview", description: "Project pitch and overview information")
    }
}

struct ScenesPlaceholder: View {
    var body: some View {
        PlaceholderView(title: "Scenes", description: "Scene list and management")
    }
}

struct AssetsPlaceholder: View {
    var body: some View {
        PlaceholderView(title: "Assets", description: "Media library and asset management")
    }
}

struct SettingsPlaceholder: View {
    var body: some View {
        PlaceholderView(title: "Project Settings", description: "Project metadata and configuration")
    }
}


// MARK: - Generic Placeholder View

struct PlaceholderView: View {
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(title)
                .font(.title)
                .fontWeight(.semibold)

            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }
}

// MARK: - Production View Wrapper

/// Wraps production views with a project identity header
struct ProductionViewWrapper<Content: View>: View {
    let project: Project
    let projectPath: URL?
    let subtitle: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            ProjectHeaderBanner(
                project: project,
                projectPath: projectPath,
                subtitle: subtitle
            )

            Divider()

            content()
        }
    }
}

// MARK: - Cinematography View Adapter

/// Adapter view that integrates CinematographyView with scene-based shot storage
struct CinematographyViewAdapter: View {
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var shotsAdapter: ShotsAdapter?

    var body: some View {
        Group {
            if let adapter = shotsAdapter {
                CinematographyView(
                    shots: adapter.allShots,
                    scenes: projectViewModel.allScenes,
                    characters: projectViewModel.project.characters,
                    locations: projectViewModel.project.locations,
                    projectBasePath: projectViewModel.projectPath,
                    initialSelectedShotId: coordinator.selectedShot?.shotId,
                    scrollToShotSection: $coordinator.scrollToShotSection,
                    onShotsChanged: { updatedShots in
                        adapter.updateShots(updatedShots)
                    },
                    onJumpToScriptElement: { itemId, itemType in
                        coordinator.jumpToScriptElement(itemId: itemId, itemType: itemType)
                    },
                    onOptionClickShot: { shot in
                        let parentScene = projectViewModel.allScenes.first { scene in
                            scene.shots.contains { $0.id == shot.id }
                        }
                        coordinator.jumpToScriptForShot(shot, scene: parentScene)
                    },
                    onNavigateToCharacter: { character in
                        coordinator.selectCharacter(character)
                    },
                    onNavigateToLocation: { location in
                        coordinator.selectLocation(location)
                    },
                    onNavigateToStoryDesign: {
                        coordinator.navigateTo(.storyDesign)
                    },
                    onNavigateToCuration: { shot in
                        coordinator.selectShotInCuration(shot)
                    },
                    onSceneUpdated: { updatedScene in
                        // Update the scene in the project model — search ALL sequences
                        for seqIdx in projectViewModel.project.sequences.indices {
                            if let sceneIdx = projectViewModel.project.sequences[seqIdx].scenes.firstIndex(where: { $0.id == updatedScene.id }) {
                                projectViewModel.project.sequences[seqIdx].scenes[sceneIdx] = updatedScene
                                projectViewModel.isDirty = true
                                coordinator.projectChanged.send(())
                                break
                            }
                        }
                    }
                )
            } else {
                ProgressView("Loading...")
            }
        }
        .onAppear {
            // Initialize adapter with actual project and callback
            if shotsAdapter == nil {
                shotsAdapter = ShotsAdapter(
                    project: projectViewModel.project,
                    onShotsChanged: { updatedProject in
                        projectViewModel.project = updatedProject
                        projectViewModel.isDirty = true
                        // Notify timeline and other views that shots changed
                        coordinator.projectChanged.send(())
                    }
                )
            }
        }
        // Refresh adapter when project changes externally (e.g. navigator adds/removes shots)
        .onReceive(coordinator.projectChanged) { _ in
            shotsAdapter?.refresh(from: projectViewModel.project)
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

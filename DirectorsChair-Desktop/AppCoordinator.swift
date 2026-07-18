//
//  AppCoordinator.swift
//  DirectorsChair
//
//  Phase 8: Main App Integration
//  Event bus and navigation coordinator
//

import Foundation
import SwiftUI
import Combine
import os
import DirectorsChairCore

// MARK: - Debug Logging

private let appLog = Logger(subsystem: "com.directorschair", category: "app")

/// Lightweight debug logging routed through os.Logger at the .debug level.
/// Unlike the previous implementation, this does NOT write to a world-readable
/// /tmp file and is not persisted in release builds — messages are visible only
/// when actively streaming logs during development.
func debugLog(_ message: String) {
    appLog.debug("\(message, privacy: .public)")
}

/// Main application coordinator - manages navigation state and acts as event bus
/// Replaces Python's _Bus singleton and QStackedWidget navigation
@MainActor
class AppCoordinator: ObservableObject {

    // MARK: - Initialization

    init() {
        debugLog("🚀 AppCoordinator initialized")
    }

    // MARK: - Navigation State

    /// Currently selected view in the central area
    @Published var selectedView: AppView = .projects

    // MARK: - Navigation History (Back/Forward)

    /// Snapshot of navigation state for history
    struct NavigationSnapshot: Equatable {
        let view: AppView
        let sceneTab: String?  // SceneViewTab raw value, if on scenes view
        let scriptScrollY: CGFloat?  // Script scroll position (when on script view)
        let productionTab: String?  // Production sub-tab, if on production view
    }

    /// Stack of previously visited states (for navigate back).
    /// Plain vars: publishing them re-rendered every coordinator observer on
    /// each navigation; selectedView's publish already refreshes button state.
    private var navigationBackStack: [NavigationSnapshot] = []

    /// Stack of states navigated back from (for navigate forward)
    private var navigationForwardStack: [NavigationSnapshot] = []

    /// Whether navigating via history (to avoid pushing to stack during back/forward)
    private var isHistoryNavigation: Bool = false

    /// Can navigate back
    var canNavigateBack: Bool { !navigationBackStack.isEmpty }

    /// Can navigate forward
    var canNavigateForward: Bool { !navigationForwardStack.isEmpty }

    // MARK: - Sub-Tab State

    /// Currently selected tab within the Scenes view
    @Published var selectedSceneTab: String = "Scenes"

    /// Currently selected tab within the Production view
    @Published var selectedProductionTab: String = "Schedule"

    /// Currently selected sequence (if any)
    @Published var selectedSequence: DirectorsChairCore.Sequence?

    /// Currently selected scene (if any)
    @Published var selectedScene: DirectorsChairCore.Scene?

    /// Currently selected shot (for cinematography)
    @Published var selectedShot: Shot?

    /// Currently selected character (for story design)
    @Published var selectedCharacter: Character?

    /// Currently selected location (for story design)
    @Published var selectedLocation: Location?

    /// Preferred Story Design mode when navigating without a specific character/location
    @Published var preferredStoryDesignMode: String?

    /// Light cue ID to select when navigating to lighting design
    @Published var selectedLightCueId: String?
    @Published var selectedSFXCueId: String?
    @Published var selectedSupportCueId: String?

    /// Deep-link targets for the Scene Connections canvas: when set, the
    /// canvas selects + scrolls to this shot/script item on arrival, then
    /// clears them (consumed like scrollToShotSection).
    @Published var connectionsHighlightShotId: String?
    @Published var connectionsHighlightItemId: String?

    /// When true, PlaybackView should auto-play on appear (set by global space bar shortcut)
    @Published var shouldAutoPlay: Bool = false

    // MARK: - UI State

    /// Navigator sidebar visibility
    @Published var showingNavigator = true

    /// Timeline panel visibility
    @Published var showingTimeline = true

    /// Right panel visibility (dialogue details, cinematography, design manager)
    @Published var showingRightPanel = true

    /// Comments overlay visibility
    @Published var showingComments = false

    /// AI usage widget visibility
    @Published var showingUsageWidget = true

    /// AI Chat overlay visibility
    @Published var showingAIChat = false

    /// AI Chat context snapshot (set when overlay opens)
    @Published var aiChatContext: AIChatContext? = nil

    /// Fine-grained selection forwarded from BubbleView for AI context
    @Published var chatContextDialogue: Dialogue? = nil
    @Published var chatContextAction: Action? = nil
    @Published var chatContextNarration: Narration? = nil

    // MARK: - Timeline Analysis

    /// Requested scope for timeline analysis (set by context menu or toolbar button)
    @Published var timelineAnalysisScope: TimelineAnalysisScope?

    /// Request AI timeline analysis for the given scope
    func requestTimelineAnalysis(scope: TimelineAnalysisScope) {
        debugLog("🔬 Timeline analysis requested: \(scope)")
        timelineAnalysisScope = scope
    }

    // MARK: - Cross-View Highlight State

    /// Item to highlight in bubble view (set from timeline double-click)
    /// Contains: (itemId, itemType, sceneName)
    /// itemType: "dialogue", "action", "narration", "note", "soundNote"
    @Published var highlightedBubbleItem: (id: String, type: String, sceneName: String)?

    /// Highlight an item in the bubble view with auto-clear
    func highlightBubbleItem(id: String, type: String, sceneName: String) {
        debugLog("✨ Highlighting bubble item: \(type) \(id) in scene \(sceneName)")

        // Set the highlighted item
        highlightedBubbleItem = (id: id, type: type, sceneName: sceneName)

        // Auto-clear after 1.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            // Only clear if it's still the same item
            if self?.highlightedBubbleItem?.id == id {
                self?.highlightedBubbleItem = nil
                debugLog("✨ Cleared highlight for \(id)")
            }
        }
    }

    /// Current script scroll Y position (continuously updated by ScreenplayTextView)
    var scriptScrollY: CGFloat = 0

    /// Script scroll Y to restore after back/forward navigation
    @Published var restoreScriptScrollY: CGFloat?

    /// Script element to scroll to (set from shot detail "Jump to Script")
    /// Contains: (sourceItemId, itemType) where itemType is "dialogue", "action", "narration"
    @Published var scrollToScriptItemId: String?

    /// Shot detail section to scroll to (e.g. "takes"). Consumed and cleared by CinematographyView.
    @Published var scrollToShotSection: String?

    /// Navigate to script view and scroll to a specific element by its source item ID
    func jumpToScriptElement(itemId: String, itemType: String) {
        debugLog("📜 Jump to script: \(itemType) \(itemId)")
        scrollToScriptItemId = itemId
        if selectedView != .script {
            navigateTo(.script)
        }
    }

    /// Jump to script for a shot: linked script element first, parent scene fallback
    func jumpToScriptForShot(_ shot: Shot, scene: DirectorsChairCore.Scene?) {
        if let dialogueId = shot.linkedDialogueIds.first {
            jumpToScriptElement(itemId: dialogueId, itemType: "dialogue")
        } else if let actionId = shot.linkedActionIds.first {
            jumpToScriptElement(itemId: actionId, itemType: "action")
        } else if let narrationId = shot.linkedNarrationIds.first {
            jumpToScriptElement(itemId: narrationId, itemType: "narration")
        } else if let scene = scene {
            jumpToScriptElement(itemId: scene.id, itemType: "scene")
        }
    }

    // MARK: - Event Publishers (WS5.2 — typed project events)
    //
    // One typed stream replaces the untyped Void "project changed" ping and
    // six never-subscribed subjects (sceneChanged, sequenceChanged,
    // dialogueSelected, actionSelected, narrationSelected, openShotList).
    // Subscribers filter by what they render, so e.g. a schedule/budget edit
    // no longer forces a full timeline rebuild.

    /// What kind of project change occurred.
    enum ProjectEvent {
        /// Sequences/scenes added, removed, renamed or reordered.
        case structure
        /// Script content (dialogue/action/narration text) changed.
        case script
        /// Shot-level changes (add/remove/edit shots, takes, video).
        case shots
        /// Production-side data (schedule, budget, cast) changed.
        case production
        /// Unclassified change — subscribers must treat as "anything".
        case general
    }

    /// Typed project-change stream.
    let projectEvents = PassthroughSubject<ProjectEvent, Never>()

    // MARK: - Navigation Methods

    /// Navigate to a specific view
    func navigateTo(_ view: AppView) {
        // Skip if already on this view
        guard selectedView != view else {
            debugLog("🧭 Already on \(view.rawValue), skipping")
            return
        }

        // Navigator responsiveness fix: navigation used to DROP clicks — a
        // 150ms lock plus a 250ms debounce silently ignored fast clicks,
        // which read as "the sidebar is sluggish". Those guards protected
        // animated transitions that no longer exist (navigation is a plain
        // assignment and hidden tabs unmount via LRU-2) — every click lands.
        debugLog("🧭 Navigating: \(selectedView.rawValue) -> \(view.rawValue)")

        // Push current state to back stack (unless this is a history navigation)
        if !isHistoryNavigation {
            let snapshot = NavigationSnapshot(
                view: selectedView,
                sceneTab: selectedView == .scenes ? selectedSceneTab : nil,
                scriptScrollY: selectedView == .script ? scriptScrollY : nil,
                productionTab: selectedView == .production ? selectedProductionTab : nil
            )
            navigationBackStack.append(snapshot)
            navigationForwardStack.removeAll()
            restoreScriptScrollY = nil  // Clear on fresh navigation
        }

        // Direct assignment without animation to prevent stacking during rapid switches
        selectedView = view
        debugLog("🧭 Navigation complete to \(view.rawValue)")
    }

    /// Navigate to the Scene Connections canvas for a scene, optionally
    /// highlighting a shot and/or a script bubble there. This is the single
    /// linking hub — every view (Shots, Bubble, Scenes) deep-links here.
    /// Cmd+[ returns to wherever the user came from.
    func navigateToConnections(scene: DirectorsChairCore.Scene?,
                               highlightShotId: String? = nil,
                               highlightItemId: String? = nil) {
        if let scene { selectedScene = scene }
        connectionsHighlightShotId = highlightShotId
        connectionsHighlightItemId = highlightItemId
        selectedSceneTab = "Connections"
        navigateTo(.scenes)
    }

    /// Navigate back to the previous view in history
    func navigateBack() {
        guard let previousSnapshot = navigationBackStack.popLast() else { return }
        debugLog("🧭 Navigate back to \(previousSnapshot.view.rawValue)")
        let currentSnapshot = NavigationSnapshot(
            view: selectedView,
            sceneTab: selectedView == .scenes ? selectedSceneTab : nil,
            scriptScrollY: selectedView == .script ? scriptScrollY : nil,
            productionTab: selectedView == .production ? selectedProductionTab : nil
        )
        navigationForwardStack.append(currentSnapshot)
        isHistoryNavigation = true
        // Restore sub-tab state before navigating
        if let sceneTab = previousSnapshot.sceneTab {
            selectedSceneTab = sceneTab
        }
        if let productionTab = previousSnapshot.productionTab {
            selectedProductionTab = productionTab
        }
        // Restore script scroll position if returning to script view
        restoreScriptScrollY = previousSnapshot.view == .script ? previousSnapshot.scriptScrollY : nil
        navigateTo(previousSnapshot.view)
        isHistoryNavigation = false
    }

    /// Navigate forward to the next view in history
    func navigateForward() {
        guard let nextSnapshot = navigationForwardStack.popLast() else { return }
        debugLog("🧭 Navigate forward to \(nextSnapshot.view.rawValue)")
        let currentSnapshot = NavigationSnapshot(
            view: selectedView,
            sceneTab: selectedView == .scenes ? selectedSceneTab : nil,
            scriptScrollY: selectedView == .script ? scriptScrollY : nil,
            productionTab: selectedView == .production ? selectedProductionTab : nil
        )
        navigationBackStack.append(currentSnapshot)
        isHistoryNavigation = true
        // Restore sub-tab state before navigating
        if let sceneTab = nextSnapshot.sceneTab {
            selectedSceneTab = sceneTab
        }
        if let productionTab = nextSnapshot.productionTab {
            selectedProductionTab = productionTab
        }
        // Restore script scroll position if returning to script view
        restoreScriptScrollY = nextSnapshot.view == .script ? nextSnapshot.scriptScrollY : nil
        navigateTo(nextSnapshot.view)
        isHistoryNavigation = false
    }

    /// Select a sequence and notify observers
    func selectSequence(_ sequence: DirectorsChairCore.Sequence) {
        selectedSequence = sequence
    }

    /// Select a scene and notify observers
    func selectScene(_ scene: DirectorsChairCore.Scene) {
        selectedScene = scene
    }

    /// Select a shot and navigate to shot list if needed
    func selectShot(_ shot: Shot) {
        selectedShot = shot
        if selectedView != .shotList {
            navigateTo(.shotList)
        }
    }

    /// Select a shot and navigate to curation view
    func selectShotInCuration(_ shot: Shot) {
        selectedShot = shot
        if selectedView != .curation {
            navigateTo(.curation)
        }
    }

    /// Select a character and navigate to story design if needed
    func selectCharacter(_ character: Character) {
        selectedLocation = nil
        selectedCharacter = character
        if selectedView != .storyDesign {
            navigateTo(.storyDesign)
        }
    }

    /// Select a location and navigate to story design if needed
    func selectLocation(_ location: Location) {
        selectedCharacter = nil
        selectedLocation = location
        if selectedView != .storyDesign {
            navigateTo(.storyDesign)
        }
    }

    // MARK: - UI State Methods

    /// Toggle navigator sidebar
    func toggleNavigator() {
        withAnimation {
            showingNavigator.toggle()
        }
    }

    /// Toggle timeline panel
    func toggleTimeline() {
        withAnimation {
            showingTimeline.toggle()
        }
    }

    /// Toggle right panel
    func toggleRightPanel() {
        withAnimation {
            showingRightPanel.toggle()
        }
    }

    /// Toggle comments overlay
    func toggleComments() {
        withAnimation {
            showingComments.toggle()
        }
    }

    /// Toggle AI usage widget
    func toggleUsageWidget() {
        withAnimation {
            showingUsageWidget.toggle()
        }
    }

    /// Toggle AI Chat overlay
    func toggleAIChat() {
        if showingAIChat {
            showingAIChat = false
        } else {
            aiChatContext = AIChatContext(
                currentView: selectedView,
                selectedScene: selectedScene,
                selectedShot: selectedShot,
                selectedCharacter: selectedCharacter,
                selectedLocation: selectedLocation,
                selectedSequence: selectedSequence,
                selectedDialogue: chatContextDialogue,
                selectedAction: chatContextAction,
                selectedNarration: chatContextNarration,
                productionTab: selectedView == .production ? selectedProductionTab : nil
            )
            showingAIChat = true
        }
    }

    // MARK: - Global Event Methods

    /// Notify that the project has changed. Pass the most specific event you
    /// can — unclassified callers default to `.general` (full refresh).
    func notifyProjectChanged(_ event: ProjectEvent = .general) {
        projectEvents.send(event)
    }

    /// Clear all selections (e.g., when closing a project)
    func clearSelections() {
        selectedSequence = nil
        selectedScene = nil
        selectedShot = nil
        selectedCharacter = nil
    }
}

// MARK: - Timeline Analysis Scope

/// Scope for AI timeline analysis
enum TimelineAnalysisScope {
    case all
    case sequence(DirectorsChairCore.Sequence)
    case scene(DirectorsChairCore.Scene, sequenceIndex: Int, sceneIndex: Int)
    case shot(Shot, scene: DirectorsChairCore.Scene, sequenceIndex: Int, sceneIndex: Int)
}

// MARK: - App View Enumeration

/// All available views in the application
/// Corresponds to Python's QStackedWidget views
enum AppView: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case script = "Script"
    case bubble = "Bubble"
    case shotList = "Shot List"
    case scenes = "Scenes"
    case assets = "Assets"
    case visionBoard = "Vision Board"
    case production = "Production"
    case storyDesign = "Story Design"
    case curation = "Curation"
    case playback = "Playback"
    case settings = "Settings"
    case projects = "Projects"

    var id: String { rawValue }

    /// SF Symbol icon for the view
    var icon: String {
        switch self {
        case .overview: return "doc.text"
        case .script: return "text.alignleft"
        case .bubble: return "bubble.left.and.bubble.right"
        case .scenes: return "film"
        case .assets: return "photo.on.rectangle"
        case .visionBoard: return "square.grid.2x2"
        case .shotList: return "camera"
        case .production: return "theatermasks"
        case .storyDesign: return "book"
        case .curation: return "film.stack"
        case .playback: return "play.rectangle.fill"
        case .settings: return "gear"
        case .projects: return "folder"
        }
    }

    /// Whether this view requires a loaded project
    var requiresProject: Bool {
        switch self {
        case .settings, .overview, .projects:
            return false
        default:
            return true
        }
    }
}

// MARK: - AI Chat Context

struct AIChatContext: Equatable {
    var currentView: AppView
    var selectedScene: DirectorsChairCore.Scene?
    var selectedShot: Shot?
    var selectedCharacter: Character?
    var selectedLocation: Location?
    var selectedSequence: DirectorsChairCore.Sequence?
    var selectedDialogue: Dialogue?
    var selectedAction: Action?
    var selectedNarration: Narration?
    var productionTab: String?
}

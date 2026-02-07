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
import DirectorsChairCore

// MARK: - Debug File Logger
private let debugLogPath = "/tmp/directorschair_debug.log"
private let debugLogQueue = DispatchQueue(label: "com.directorschair.debuglog", qos: .utility)
private let debugDateFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    return formatter
}()

private func initDebugLog() {
    debugLogQueue.async {
        let header = "=== DirectorsChair Debug Log - \(Date()) ===\n"
        try? header.write(toFile: debugLogPath, atomically: true, encoding: .utf8)
    }
}

func debugLog(_ message: String) {
    // Capture timestamp on main thread for accuracy
    let timestamp = debugDateFormatter.string(from: Date())

    // Async write to not block main thread
    debugLogQueue.async {
        let line = "[\(timestamp)] \(message)\n"

        // Append to file
        if let handle = FileHandle(forWritingAtPath: debugLogPath) {
            handle.seekToEndOfFile()
            if let data = line.data(using: .utf8) {
                handle.write(data)
            }
            handle.closeFile()
        } else {
            // File doesn't exist, create it
            try? line.write(toFile: debugLogPath, atomically: true, encoding: .utf8)
        }
    }

    // Print to console synchronously for immediate feedback
    print(message)
}

/// Main application coordinator - manages navigation state and acts as event bus
/// Replaces Python's _Bus singleton and QStackedWidget navigation
@MainActor
class AppCoordinator: ObservableObject {

    // MARK: - Initialization

    init() {
        initDebugLog()
        debugLog("🚀 AppCoordinator initialized")
    }

    // MARK: - Navigation State

    /// Currently selected view in the central area
    @Published var selectedView: AppView = .projects

    /// Navigation debounce - prevents rapid switching (250ms to allow view to settle)
    private var lastNavigationTime: Date = .distantPast
    private let navigationDebounceInterval: TimeInterval = 0.25  // 250ms debounce

    /// Navigation lock - prevents concurrent navigation
    private var isNavigating: Bool = false

    // MARK: - Navigation History (Back/Forward)

    /// Snapshot of navigation state for history
    struct NavigationSnapshot: Equatable {
        let view: AppView
        let sceneTab: String?  // SceneViewTab raw value, if on scenes view
    }

    /// Stack of previously visited states (for navigate back)
    @Published private var navigationBackStack: [NavigationSnapshot] = []

    /// Stack of states navigated back from (for navigate forward)
    @Published private var navigationForwardStack: [NavigationSnapshot] = []

    /// Whether navigating via history (to avoid pushing to stack during back/forward)
    private var isHistoryNavigation: Bool = false

    /// Can navigate back
    var canNavigateBack: Bool { !navigationBackStack.isEmpty }

    /// Can navigate forward
    var canNavigateForward: Bool { !navigationForwardStack.isEmpty }

    // MARK: - Sub-Tab State

    /// Currently selected tab within the Scenes view
    @Published var selectedSceneTab: String = "Scenes"

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

    // MARK: - UI State

    /// Navigator sidebar visibility
    @Published var showingNavigator = true

    /// Timeline panel visibility
    @Published var showingTimeline = true

    /// Right panel visibility (dialogue details, cinematography, design manager)
    @Published var showingRightPanel = true

    /// Comments overlay visibility
    @Published var showingComments = false

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

    // MARK: - Event Publishers (replaces Qt signals)

    /// Fired when project is changed (global refresh)
    let projectChanged = PassthroughSubject<Void, Never>()

    /// Fired when a scene is changed
    let sceneChanged = PassthroughSubject<DirectorsChairCore.Scene, Never>()

    /// Fired when a sequence is changed
    let sequenceChanged = PassthroughSubject<DirectorsChairCore.Sequence, Never>()

    /// Fired when a dialogue is selected
    let dialogueSelected = PassthroughSubject<Dialogue, Never>()

    /// Fired when an action is selected
    let actionSelected = PassthroughSubject<Action, Never>()

    /// Fired when a narration is selected
    let narrationSelected = PassthroughSubject<Narration, Never>()

    /// Fired when shot list should be opened
    let openShotList = PassthroughSubject<Int, Never>()

    // MARK: - Navigation Methods

    /// Navigate to a specific view
    func navigateTo(_ view: AppView) {
        // Skip if already on this view
        guard selectedView != view else {
            debugLog("🧭 Already on \(view.rawValue), skipping")
            return
        }

        // Block if navigation is in progress (skip for explicit history navigation)
        guard !isNavigating || isHistoryNavigation else {
            debugLog("🔒 Navigation locked, skipping \(view.rawValue)")
            return
        }

        // Debounce rapid navigation requests (skip for explicit history navigation)
        let now = Date()
        let timeSinceLastNav = now.timeIntervalSince(lastNavigationTime)
        if !isHistoryNavigation && timeSinceLastNav < navigationDebounceInterval {
            debugLog("⏳ Debounce: Skipping navigation to \(view.rawValue) (too fast: \(String(format: "%.3f", timeSinceLastNav))s)")
            return
        }

        // Lock navigation
        isNavigating = true
        lastNavigationTime = now
        debugLog("🧭 Navigating: \(selectedView.rawValue) -> \(view.rawValue)")

        // Push current state to back stack (unless this is a history navigation)
        if !isHistoryNavigation {
            let snapshot = NavigationSnapshot(
                view: selectedView,
                sceneTab: selectedView == .scenes ? selectedSceneTab : nil
            )
            navigationBackStack.append(snapshot)
            navigationForwardStack.removeAll()
        }

        // Direct assignment without animation to prevent stacking during rapid switches
        selectedView = view
        debugLog("🧭 Navigation complete to \(view.rawValue)")

        // Unlock after a brief settling period to allow view to render
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.isNavigating = false
            debugLog("🔓 Navigation unlocked")
        }
    }

    /// Navigate back to the previous view in history
    func navigateBack() {
        guard let previousSnapshot = navigationBackStack.popLast() else { return }
        debugLog("🧭 Navigate back to \(previousSnapshot.view.rawValue)")
        let currentSnapshot = NavigationSnapshot(
            view: selectedView,
            sceneTab: selectedView == .scenes ? selectedSceneTab : nil
        )
        navigationForwardStack.append(currentSnapshot)
        isHistoryNavigation = true
        // Restore sub-tab state before navigating
        if let sceneTab = previousSnapshot.sceneTab {
            selectedSceneTab = sceneTab
        }
        navigateTo(previousSnapshot.view)
        isHistoryNavigation = false
    }

    /// Navigate forward to the next view in history
    func navigateForward() {
        guard let nextSnapshot = navigationForwardStack.popLast() else { return }
        debugLog("🧭 Navigate forward to \(nextSnapshot.view.rawValue)")
        let currentSnapshot = NavigationSnapshot(
            view: selectedView,
            sceneTab: selectedView == .scenes ? selectedSceneTab : nil
        )
        navigationBackStack.append(currentSnapshot)
        isHistoryNavigation = true
        // Restore sub-tab state before navigating
        if let sceneTab = nextSnapshot.sceneTab {
            selectedSceneTab = sceneTab
        }
        navigateTo(nextSnapshot.view)
        isHistoryNavigation = false
    }

    /// Select a sequence and notify observers
    func selectSequence(_ sequence: DirectorsChairCore.Sequence) {
        selectedSequence = sequence
        sequenceChanged.send(sequence)
    }

    /// Select a scene and notify observers
    func selectScene(_ scene: DirectorsChairCore.Scene) {
        selectedScene = scene
        sceneChanged.send(scene)
    }

    /// Select a shot and navigate to shot list if needed
    func selectShot(_ shot: Shot) {
        selectedShot = shot
        if selectedView != .shotList {
            navigateTo(.shotList)
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

    // MARK: - Global Event Methods

    /// Notify that the project has changed (triggers global refresh)
    func notifyProjectChanged() {
        projectChanged.send()
    }

    /// Clear all selections (e.g., when closing a project)
    func clearSelections() {
        selectedSequence = nil
        selectedScene = nil
        selectedShot = nil
        selectedCharacter = nil
    }
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
    case schedule = "Schedule"
    case castCrew = "Cast & Crew"
    case budget = "Budget"
    case storyDesign = "Story Design"
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
        case .schedule: return "calendar"
        case .castCrew: return "person.3"
        case .budget: return "dollarsign.circle"
        case .storyDesign: return "book"
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

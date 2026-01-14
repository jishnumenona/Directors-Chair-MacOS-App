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

/// Main application coordinator - manages navigation state and acts as event bus
/// Replaces Python's _Bus singleton and QStackedWidget navigation
@MainActor
class AppCoordinator: ObservableObject {
    // MARK: - Navigation State

    /// Currently selected view in the central area
    @Published var selectedView: AppView = .overview

    /// Currently selected sequence (if any)
    @Published var selectedSequence: DirectorsChairCore.Sequence?

    /// Currently selected scene (if any)
    @Published var selectedScene: DirectorsChairCore.Scene?

    /// Currently selected shot (for cinematography)
    @Published var selectedShot: Shot?

    /// Currently selected character (for story design)
    @Published var selectedCharacter: Character?

    // MARK: - UI State

    /// Navigator sidebar visibility
    @Published var showingNavigator = true

    /// Timeline panel visibility
    @Published var showingTimeline = true

    /// Right panel visibility (dialogue details, cinematography, design manager)
    @Published var showingRightPanel = true

    /// Comments overlay visibility
    @Published var showingComments = false

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
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedView = view
        }
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
        selectedCharacter = character
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
}

// MARK: - App View Enumeration

/// All available views in the application
/// Corresponds to Python's QStackedWidget views
enum AppView: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case bubble = "Bubble"
    case scenes = "Scenes"
    case assets = "Assets"
    case visionBoard = "Vision Board"
    case shotList = "Shot List"
    case schedule = "Schedule"
    case castCrew = "Cast & Crew"
    case budget = "Budget"
    case storyDesign = "Story Design"
    case settings = "Settings"

    var id: String { rawValue }

    /// SF Symbol icon for the view
    var icon: String {
        switch self {
        case .overview: return "doc.text"
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
        }
    }

    /// Whether this view requires a loaded project
    var requiresProject: Bool {
        switch self {
        case .settings, .overview:
            return false
        default:
            return true
        }
    }
}

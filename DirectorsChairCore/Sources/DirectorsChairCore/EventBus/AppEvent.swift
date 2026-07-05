// DirectorsChairCore/Sources/DirectorsChairCore/EventBus/AppEvent.swift
//
// Event types for the application event bus

import Foundation

/// All events that can be broadcast through the application event bus
public enum AppEvent: Equatable, Sendable {

    // MARK: - Project Events

    /// Project loaded successfully
    case projectLoaded(projectName: String)

    /// Project saved successfully
    case projectSaved(projectName: String, timestamp: Date)

    /// Project save failed
    case projectSaveFailed(projectName: String, error: String)

    /// Project closed
    case projectClosed(projectName: String)

    /// New project created
    case projectCreated(projectName: String)

    /// Project modified (any change)
    case projectModified(projectName: String)

    // MARK: - Data Model Events

    /// Character added, updated, or deleted
    case characterAdded(characterId: String, name: String)
    case characterUpdated(characterId: String, name: String)
    case characterDeleted(characterId: String, name: String)

    /// Scene added, updated, or deleted
    case sceneAdded(sceneId: String, name: String, sequenceName: String)
    case sceneUpdated(sceneId: String, name: String)
    case sceneDeleted(sceneId: String, name: String)

    /// Sequence added, updated, or deleted
    case sequenceAdded(sequenceId: String, name: String)
    case sequenceUpdated(sequenceId: String, name: String)
    case sequenceDeleted(sequenceId: String, name: String)

    /// Prop added, updated, or deleted
    case propAdded(propId: String, name: String)
    case propUpdated(propId: String, name: String)
    case propDeleted(propId: String, name: String)

    /// Location added, updated, or deleted
    case locationAdded(locationId: String, name: String)
    case locationUpdated(locationId: String, name: String)
    case locationDeleted(locationId: String, name: String)

    /// Cast/Crew member added, updated, or deleted
    case castMemberAdded(memberId: String, name: String)
    case castMemberUpdated(memberId: String, name: String)
    case castMemberDeleted(memberId: String, name: String)

    case crewMemberAdded(memberId: String, name: String)
    case crewMemberUpdated(memberId: String, name: String)
    case crewMemberDeleted(memberId: String, name: String)

    // MARK: - AI Service Events

    /// AI generation started
    case aiGenerationStarted(taskId: String, type: AIGenerationType)

    /// AI generation completed
    case aiGenerationCompleted(taskId: String, type: AIGenerationType)

    /// AI generation failed
    case aiGenerationFailed(taskId: String, type: AIGenerationType, error: String)

    /// AI generation progress update
    case aiGenerationProgress(taskId: String, progress: Double, message: String)

    // MARK: - Export Events

    /// Export started
    case exportStarted(format: String, destination: String)

    /// Export completed
    case exportCompleted(format: String, destination: String)

    /// Export failed
    case exportFailed(format: String, error: String)

    /// Export progress update
    case exportProgress(format: String, progress: Double)

    // MARK: - Git Service Events

    /// Git operation started
    case gitOperationStarted(operation: String)

    /// Git operation completed
    case gitOperationCompleted(operation: String, message: String)

    /// Git operation failed
    case gitOperationFailed(operation: String, error: String)

    /// Git status changed
    case gitStatusChanged(hasChanges: Bool, branch: String)

    // MARK: - UI Events

    /// Navigation request
    case navigateToScene(sceneId: String)
    case navigateToCharacter(characterId: String)
    case navigateToSequence(sequenceName: String)

    /// Selection changed
    case selectionChanged(itemType: String, itemId: String)

    /// View mode changed
    case viewModeChanged(mode: String)

    // MARK: - System Events

    /// Application started
    case applicationStarted

    /// Application will terminate
    case applicationWillTerminate

    /// Error occurred
    case errorOccurred(message: String, details: String?)

    /// Warning issued
    case warningIssued(message: String)

    /// Info message
    case infoMessage(message: String)

    // MARK: - Computed Properties

    /// Event category for filtering
    public var category: EventCategory {
        switch self {
        case .projectLoaded, .projectSaved, .projectSaveFailed, .projectClosed, .projectCreated, .projectModified:
            return .project
        case .characterAdded, .characterUpdated, .characterDeleted,
             .sceneAdded, .sceneUpdated, .sceneDeleted,
             .sequenceAdded, .sequenceUpdated, .sequenceDeleted,
             .propAdded, .propUpdated, .propDeleted,
             .locationAdded, .locationUpdated, .locationDeleted,
             .castMemberAdded, .castMemberUpdated, .castMemberDeleted,
             .crewMemberAdded, .crewMemberUpdated, .crewMemberDeleted:
            return .dataModel
        case .aiGenerationStarted, .aiGenerationCompleted, .aiGenerationFailed, .aiGenerationProgress:
            return .aiService
        case .exportStarted, .exportCompleted, .exportFailed, .exportProgress:
            return .export
        case .gitOperationStarted, .gitOperationCompleted, .gitOperationFailed, .gitStatusChanged:
            return .git
        case .navigateToScene, .navigateToCharacter, .navigateToSequence,
             .selectionChanged, .viewModeChanged:
            return .ui
        case .applicationStarted, .applicationWillTerminate, .errorOccurred, .warningIssued, .infoMessage:
            return .system
        }
    }

    /// Event priority for ordering
    public var priority: EventPriority {
        switch self {
        case .errorOccurred, .applicationWillTerminate:
            return .critical
        case .projectSaveFailed, .aiGenerationFailed, .exportFailed, .gitOperationFailed:
            return .high
        case .projectLoaded, .projectSaved, .projectCreated:
            return .normal
        case .aiGenerationProgress, .exportProgress:
            return .low
        default:
            return .normal
        }
    }
}

// MARK: - Event Category

/// Categories for filtering events
public enum EventCategory: String, Sendable {
    case project
    case dataModel
    case aiService
    case export
    case git
    case ui
    case system
}

// MARK: - Event Priority

/// Priority levels for events
public enum EventPriority: Int, Comparable, Sendable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3

    public static func < (lhs: EventPriority, rhs: EventPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - AI Generation Type

/// Types of AI generation operations
public enum AIGenerationType: String, Equatable, Sendable {
    case characterImage = "character_image"
    case sceneImage = "scene_image"
    case dialogue = "dialogue"
    case voiceover = "voiceover"
    case video = "video"
    case script = "script"
    case storyboard = "storyboard"
    case other
}

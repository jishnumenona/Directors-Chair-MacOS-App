// DirectorsChairCore/Sources/DirectorsChairCore/Protocols/ViewModelProtocol.swift
//
// Protocol interfaces for ViewModels (Module 5)

import Foundation
import Combine

// MARK: - BaseViewModelProtocol

/// Base protocol for all ViewModels
/// Provides common functionality for SwiftUI integration
@MainActor
public protocol BaseViewModelProtocol: ObservableObject {
    /// Whether the view model is currently loading data
    var isLoading: Bool { get set }

    /// Current error state
    var error: Error? { get set }

    /// Initialize the view model with required dependencies
    func initialize() async

    /// Clean up resources when view model is deallocated
    func cleanup() async
}

// MARK: - ProjectViewModelProtocol

/// Protocol for project-level view model
@MainActor
public protocol ProjectViewModelProtocol: BaseViewModelProtocol {
    /// Current project
    var project: Project? { get set }

    /// Whether project has unsaved changes
    var hasUnsavedChanges: Bool { get }

    /// Load project from disk
    /// - Parameter url: URL to project file
    func loadProject(from url: URL) async throws

    /// Save current project
    func saveProject() async throws

    /// Create new project
    /// - Parameter name: Project name
    func createNewProject(name: String) async throws

    /// Close current project
    func closeProject() async throws

    /// Export project
    /// - Parameters:
    ///   - format: Export format
    ///   - destination: Destination URL
    func exportProject(format: ExportFormat, to destination: URL) async throws
}

// MARK: - SceneEditorViewModelProtocol

/// Protocol for scene editor view model
@MainActor
public protocol SceneEditorViewModelProtocol: BaseViewModelProtocol {
    /// Current scene being edited
    var currentScene: Scene? { get set }

    /// All available characters
    var characters: [Character] { get }

    /// Add dialogue to scene
    /// - Parameter dialogue: Dialogue to add
    func addDialogue(_ dialogue: Dialogue) async

    /// Update dialogue
    /// - Parameters:
    ///   - dialogue: Dialogue to update
    ///   - text: New text
    func updateDialogue(_ dialogue: Dialogue, text: String) async

    /// Delete dialogue
    /// - Parameter dialogue: Dialogue to delete
    func deleteDialogue(_ dialogue: Dialogue) async

    /// Generate AI dialogue
    /// - Parameters:
    ///   - character: Character speaking
    ///   - context: Scene context
    func generateAIDialogue(for character: Character, context: String) async throws

    /// Add action to scene
    /// - Parameter action: Action to add
    func addAction(_ action: Action) async

    /// Update scene metadata
    /// - Parameters:
    ///   - name: Scene name
    ///   - description: Scene description
    func updateSceneMetadata(name: String, description: String) async
}

// MARK: - CharacterManagerViewModelProtocol

/// Protocol for character management view model
@MainActor
public protocol CharacterManagerViewModelProtocol: BaseViewModelProtocol {
    /// All characters in project
    var characters: [Character] { get set }

    /// Currently selected character
    var selectedCharacter: Character? { get set }

    /// Add new character
    /// - Parameter character: Character to add
    func addCharacter(_ character: Character) async

    /// Update character
    /// - Parameter character: Updated character
    func updateCharacter(_ character: Character) async

    /// Delete character
    /// - Parameter character: Character to delete
    func deleteCharacter(_ character: Character) async

    /// Generate character image
    /// - Parameter character: Character to generate image for
    func generateCharacterImage(for character: Character) async throws

    /// Import character from template
    /// - Parameter templateId: Template identifier
    func importCharacterTemplate(templateId: String) async throws
}

// MARK: - ScheduleViewModelProtocol

/// Protocol for production schedule view model
@MainActor
public protocol ScheduleViewModelProtocol: BaseViewModelProtocol {
    /// All schedule items
    var scheduleItems: [ScheduleItem] { get set }

    /// Currently selected schedule item
    var selectedItem: ScheduleItem? { get set }

    /// Calendar view mode
    var viewMode: ScheduleViewMode { get set }

    /// Add schedule item
    /// - Parameter item: Schedule item to add
    func addScheduleItem(_ item: ScheduleItem) async

    /// Update schedule item
    /// - Parameter item: Updated schedule item
    func updateScheduleItem(_ item: ScheduleItem) async

    /// Delete schedule item
    /// - Parameter item: Schedule item to delete
    func deleteScheduleItem(_ item: ScheduleItem) async

    /// Generate optimized schedule
    func generateOptimizedSchedule() async throws

    /// Check for scheduling conflicts
    /// - Returns: Array of conflicts
    func checkConflicts() async throws -> [SchedulingConflict]

    /// Export schedule
    /// - Parameters:
    ///   - format: Export format
    ///   - destination: Destination URL
    func exportSchedule(format: ExportFormat, to destination: URL) async throws
}

// MARK: - BudgetViewModelProtocol

/// Protocol for budget management view model
@MainActor
public protocol BudgetViewModelProtocol: BaseViewModelProtocol {
    /// Current project budget
    var budget: ProjectBudget? { get set }

    /// Budget categories
    var categories: [BudgetCategory] { get }

    /// Recent expenses
    var recentExpenses: [Expense] { get }

    /// Total budget remaining
    var totalRemaining: Decimal { get }

    /// Add expense
    /// - Parameter expense: Expense to add
    func addExpense(_ expense: Expense) async

    /// Update budget category
    /// - Parameter category: Category to update
    func updateCategory(_ category: BudgetCategory) async

    /// Generate budget forecast
    /// - Returns: Budget forecast
    func generateForecast() async throws -> BudgetForecast

    /// Export budget report
    /// - Parameters:
    ///   - format: Export format
    ///   - destination: Destination URL
    func exportBudgetReport(format: ExportFormat, to destination: URL) async throws
}

// MARK: - AIGenerationViewModelProtocol

/// Protocol for AI generation view model
@MainActor
public protocol AIGenerationViewModelProtocol: BaseViewModelProtocol {
    /// Current generation task
    var currentTask: AIGenerationTask? { get set }

    /// Generation progress (0.0 - 1.0)
    var progress: Double { get set }

    /// Generation status message
    var statusMessage: String { get set }

    /// Generation history
    var generationHistory: [AIGenerationResult] { get }

    /// Start image generation
    /// - Parameters:
    ///   - prompt: Generation prompt
    ///   - options: Generation options
    func generateImage(prompt: String, options: ImageGenerationOptions) async throws

    /// Start character image generation
    /// - Parameter character: Character to generate image for
    func generateCharacterImage(character: Character) async throws

    /// Start video generation
    /// - Parameters:
    ///   - scene: Scene to generate video for
    ///   - duration: Video duration
    func generateVideo(scene: Scene, duration: TimeInterval) async throws

    /// Cancel current generation
    func cancelGeneration() async

    /// Estimate generation cost
    /// - Parameters:
    ///   - type: Generation type
    ///   - parameters: Generation parameters
    /// - Returns: Estimated cost
    func estimateCost(type: AIGenerationType, parameters: [String: Any]) async throws -> Decimal
}

// MARK: - Supporting Types

/// Schedule view mode
public enum ScheduleViewMode: String, Sendable {
    case calendar = "Calendar"
    case list = "List"
    case gantt = "Gantt"
}

/// AI generation task
public struct AIGenerationTask: Sendable, Identifiable {
    public let id: String
    public let type: AIGenerationType
    public let startTime: Date
    public var status: TaskStatus

    public init(
        id: String = UUID().uuidString,
        type: AIGenerationType,
        startTime: Date = Date(),
        status: TaskStatus = .running
    ) {
        self.id = id
        self.type = type
        self.startTime = startTime
        self.status = status
    }
}

/// Task status
public enum TaskStatus: String, Sendable {
    case pending = "Pending"
    case running = "Running"
    case completed = "Completed"
    case failed = "Failed"
    case cancelled = "Cancelled"
}

/// AI generation result
public struct AIGenerationResult: Sendable, Identifiable {
    public let id: String
    public let type: AIGenerationType
    public let resultURL: URL?
    public let timestamp: Date
    public let cost: Decimal?

    public init(
        id: String = UUID().uuidString,
        type: AIGenerationType,
        resultURL: URL? = nil,
        timestamp: Date = Date(),
        cost: Decimal? = nil
    ) {
        self.id = id
        self.type = type
        self.resultURL = resultURL
        self.timestamp = timestamp
        self.cost = cost
    }
}

// MARK: - ViewModel Coordinator Protocol

/// Protocol for coordinating between multiple view models
@MainActor
public protocol ViewModelCoordinatorProtocol {
    /// Event bus for cross-view communication
    var eventBus: EventBus { get }

    /// Navigate to scene editor
    /// - Parameter scene: Scene to edit
    func navigateToScene(_ scene: Scene) async

    /// Navigate to character editor
    /// - Parameter character: Character to edit
    func navigateToCharacter(_ character: Character) async

    /// Show error alert
    /// - Parameter error: Error to display
    func showError(_ error: Error) async

    /// Show success message
    /// - Parameter message: Success message
    func showSuccess(message: String) async
}

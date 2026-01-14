// DirectorsChairServices/Sources/DirectorsChairServices/Tasks/BackgroundTaskManager.swift
//
// Background Task Manager for async operations
// Handles AI requests, exports, and other long-running tasks

import Foundation
import Combine

// MARK: - Task Status

/// Status of a background task
public enum TaskStatus: Sendable, Equatable {
    case pending
    case running
    case completed
    case failed(String)
    case cancelled
    
    public var isFinished: Bool {
        switch self {
        case .completed, .failed, .cancelled:
            return true
        case .pending, .running:
            return false
        }
    }
}

// MARK: - Task Priority

/// Priority level for background tasks
public enum TaskPriority: Int, Sendable, Comparable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3
    
    public static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Background Task

/// A background task with progress tracking
public struct BackgroundTask: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let description: String
    public let priority: TaskPriority
    public let createdAt: Date
    public var status: TaskStatus
    public var progress: Double
    public var progressMessage: String
    public var result: (any Sendable)?
    
    public init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        priority: TaskPriority = .normal
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.priority = priority
        self.createdAt = Date()
        self.status = .pending
        self.progress = 0
        self.progressMessage = ""
        self.result = nil
    }
}

// MARK: - Task Update

/// Update for a background task
public struct TaskUpdate: Sendable {
    public let taskId: UUID
    public let status: TaskStatus?
    public let progress: Double?
    public let progressMessage: String?
    
    public init(taskId: UUID, status: TaskStatus? = nil, progress: Double? = nil, progressMessage: String? = nil) {
        self.taskId = taskId
        self.status = status
        self.progress = progress
        self.progressMessage = progressMessage
    }
}

// MARK: - Background Task Manager

/// Manages background tasks with progress tracking and cancellation
public actor BackgroundTaskManager {
    
    // MARK: - Properties

    private var tasks: [UUID: BackgroundTask] = [:]
    private var runningTasks: [UUID: Task<Void, Never>] = [:]

    // Using nonisolated(unsafe) because PassthroughSubject is designed for thread-safe publishing
    private nonisolated(unsafe) let updateSubject = PassthroughSubject<TaskUpdate, Never>()

    /// Maximum concurrent tasks
    public var maxConcurrentTasks: Int = 4

    /// Shared instance
    public static let shared = BackgroundTaskManager()

    /// Publisher for task updates
    public nonisolated var updates: AnyPublisher<TaskUpdate, Never> {
        updateSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Task Management
    
    /// Get all tasks
    public func getAllTasks() -> [BackgroundTask] {
        Array(tasks.values).sorted { $0.createdAt > $1.createdAt }
    }
    
    /// Get a specific task
    public func getTask(_ id: UUID) -> BackgroundTask? {
        tasks[id]
    }
    
    /// Get running tasks count
    public func runningTasksCount() -> Int {
        runningTasks.count
    }
    
    /// Submit a new task
    @discardableResult
    public func submit<T: Sendable>(
        name: String,
        description: String = "",
        priority: TaskPriority = .normal,
        operation: @escaping @Sendable () async throws -> T
    ) -> UUID {
        let task = BackgroundTask(
            name: name,
            description: description,
            priority: priority
        )
        
        tasks[task.id] = task
        
        // Create Swift Task to run the operation
        let swiftTask = Task {
            await self.runTask(task.id, operation: operation)
        }
        
        runningTasks[task.id] = swiftTask
        
        return task.id
    }
    
    /// Submit a task with progress callback
    @discardableResult
    public func submitWithProgress<T: Sendable>(
        name: String,
        description: String = "",
        priority: TaskPriority = .normal,
        operation: @escaping @Sendable (@Sendable (Double, String) -> Void) async throws -> T
    ) -> UUID {
        let task = BackgroundTask(
            name: name,
            description: description,
            priority: priority
        )
        
        tasks[task.id] = task
        
        // Create progress callback
        let taskId = task.id
        let progressCallback: @Sendable (Double, String) -> Void = { [weak self] progress, message in
            Task {
                await self?.updateProgress(taskId, progress: progress, message: message)
            }
        }
        
        // Create Swift Task to run the operation
        let swiftTask = Task {
            await self.runTaskWithProgress(task.id, operation: { try await operation(progressCallback) })
        }
        
        runningTasks[task.id] = swiftTask
        
        return task.id
    }
    
    // MARK: - Task Execution
    
    private func runTask<T: Sendable>(_ id: UUID, operation: @escaping @Sendable () async throws -> T) async {
        // Update status to running
        updateTaskStatus(id, status: .running)
        
        do {
            let result = try await operation()
            
            // Update with result
            if var task = tasks[id] {
                task.status = .completed
                task.progress = 1.0
                task.result = result
                tasks[id] = task
            }
            
            sendUpdate(TaskUpdate(taskId: id, status: .completed, progress: 1.0))
            
        } catch is CancellationError {
            updateTaskStatus(id, status: .cancelled)
        } catch {
            updateTaskStatus(id, status: .failed(error.localizedDescription))
        }
        
        // Clean up
        runningTasks.removeValue(forKey: id)
    }
    
    private func runTaskWithProgress<T: Sendable>(_ id: UUID, operation: @escaping @Sendable () async throws -> T) async {
        // Update status to running
        updateTaskStatus(id, status: .running)
        
        do {
            let result = try await operation()
            
            // Update with result
            if var task = tasks[id] {
                task.status = .completed
                task.progress = 1.0
                task.result = result
                tasks[id] = task
            }
            
            sendUpdate(TaskUpdate(taskId: id, status: .completed, progress: 1.0))
            
        } catch is CancellationError {
            updateTaskStatus(id, status: .cancelled)
        } catch {
            updateTaskStatus(id, status: .failed(error.localizedDescription))
        }
        
        // Clean up
        runningTasks.removeValue(forKey: id)
    }
    
    // MARK: - Progress Updates
    
    private func updateProgress(_ id: UUID, progress: Double, message: String) {
        guard var task = tasks[id] else { return }
        
        task.progress = min(1.0, max(0.0, progress))
        task.progressMessage = message
        tasks[id] = task
        
        sendUpdate(TaskUpdate(taskId: id, progress: progress, progressMessage: message))
    }
    
    private func updateTaskStatus(_ id: UUID, status: TaskStatus) {
        guard var task = tasks[id] else { return }
        
        task.status = status
        if case .completed = status {
            task.progress = 1.0
        }
        tasks[id] = task
        
        sendUpdate(TaskUpdate(taskId: id, status: status))
    }
    
    private func sendUpdate(_ update: TaskUpdate) {
        updateSubject.send(update)
    }
    
    // MARK: - Task Control
    
    /// Cancel a task
    public func cancel(_ id: UUID) {
        if let swiftTask = runningTasks[id] {
            swiftTask.cancel()
            runningTasks.removeValue(forKey: id)
        }
        updateTaskStatus(id, status: .cancelled)
    }
    
    /// Cancel all tasks
    public func cancelAll() {
        for (id, swiftTask) in runningTasks {
            swiftTask.cancel()
            updateTaskStatus(id, status: .cancelled)
        }
        runningTasks.removeAll()
    }
    
    /// Remove completed/cancelled/failed tasks
    public func cleanup() {
        let finishedIds = tasks.filter { $0.value.status.isFinished }.map { $0.key }
        for id in finishedIds {
            tasks.removeValue(forKey: id)
        }
    }
    
    /// Remove a specific task (if finished)
    public func remove(_ id: UUID) {
        guard let task = tasks[id], task.status.isFinished else { return }
        tasks.removeValue(forKey: id)
    }
    
    /// Wait for a task to complete
    public func waitForTask(_ id: UUID) async -> BackgroundTask? {
        // If task is already finished, return immediately
        if let task = tasks[id], task.status.isFinished {
            return task
        }
        
        // Wait for the Swift task to complete
        if let swiftTask = runningTasks[id] {
            await swiftTask.value
        }
        
        return tasks[id]
    }
}

// MARK: - Convenience Extensions

extension BackgroundTaskManager {
    
    /// Submit an AI generation task
    @discardableResult
    public func submitAITask<T: Sendable>(
        name: String,
        operation: @escaping @Sendable (@Sendable (Double, String) -> Void) async throws -> T
    ) -> UUID {
        submitWithProgress(
            name: name,
            description: "AI generation task",
            priority: .normal,
            operation: operation
        )
    }
    
    /// Submit an export task
    @discardableResult
    public func submitExportTask<T: Sendable>(
        name: String,
        operation: @escaping @Sendable (@Sendable (Double, String) -> Void) async throws -> T
    ) -> UUID {
        submitWithProgress(
            name: name,
            description: "Export task",
            priority: .high,
            operation: operation
        )
    }
}

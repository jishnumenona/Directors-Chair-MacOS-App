// DirectorsChairCore/Sources/DirectorsChairCore/Persistence/DebouncedSaveManager.swift
//
// Auto-save manager with debouncing to prevent excessive disk writes

import Foundation
import Combine

/// Manages automatic saving of project with debouncing to prevent excessive writes
/// Implements a 500ms debounce window - saves only occur after changes stop for 500ms
@MainActor
public class DebouncedSaveManager: ObservableObject {

    // MARK: - Published Properties

    /// Whether a save operation is currently in progress
    @Published public private(set) var isSaving: Bool = false

    /// Whether there are pending unsaved changes
    @Published public private(set) var hasUnsavedChanges: Bool = false

    /// Last save timestamp
    @Published public private(set) var lastSaveDate: Date?

    /// Last error that occurred during save
    @Published public private(set) var lastError: ProjectError?

    // MARK: - Configuration

    /// Debounce interval in seconds (default 500ms)
    public let debounceInterval: TimeInterval

    /// Whether auto-save is enabled
    @Published public var isAutoSaveEnabled: Bool = true

    // MARK: - Dependencies

    private let persistence: ProjectPersistence

    // MARK: - State

    private var saveTask: Task<Void, Never>?
    private var pendingSave: (project: Project, url: URL)?
    private var debounceTimer: Timer?

    // MARK: - Initialization

    public init(
        persistence: ProjectPersistence = ProjectPersistence(),
        debounceInterval: TimeInterval = 0.5
    ) {
        self.persistence = persistence
        self.debounceInterval = debounceInterval
    }

    // MARK: - Public API

    /// Request a save operation (will be debounced)
    /// - Parameters:
    ///   - project: The project to save
    ///   - url: The URL to save to
    public func requestSave(project: Project, to url: URL) {
        guard isAutoSaveEnabled else {
            pendingSave = nil
            return
        }

        // Store pending save
        pendingSave = (project, url)
        hasUnsavedChanges = true

        // Cancel existing timer
        debounceTimer?.invalidate()

        // Start new debounce timer
        debounceTimer = Timer.scheduledTimer(
            withTimeInterval: debounceInterval,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.executeSave()
            }
        }
    }

    /// Force immediate save without debouncing
    /// - Parameters:
    ///   - project: The project to save
    ///   - url: The URL to save to
    public func saveImmediately(project: Project, to url: URL) async throws {
        // Cancel any pending debounced save
        debounceTimer?.invalidate()
        debounceTimer = nil

        // Store as pending
        pendingSave = (project, url)

        // Execute immediately
        try await performSave()
    }

    /// Cancel any pending save operations
    public func cancelPendingSave() {
        debounceTimer?.invalidate()
        debounceTimer = nil
        pendingSave = nil
        hasUnsavedChanges = false
        saveTask?.cancel()
        saveTask = nil
    }

    // MARK: - Private Methods

    /// Execute the debounced save
    private func executeSave() async {
        guard let (_, url) = pendingSave else {
            return
        }

        do {
            try await performSave()
        } catch let error as ProjectError {
            lastError = error
            print("Save failed: \(error.localizedDescription)")
        } catch {
            lastError = ProjectError.fileWriteFailed(url, error)
            print("Save failed: \(error.localizedDescription)")
        }
    }

    /// Perform the actual save operation
    private func performSave() async throws {
        guard let (project, url) = pendingSave else {
            return
        }

        // Prevent concurrent saves
        if isSaving {
            return
        }

        isSaving = true
        defer {
            isSaving = false
        }

        do {
            // Execute save through persistence layer
            try await persistence.save(project, to: url)

            // Update state on success
            lastSaveDate = Date()
            hasUnsavedChanges = false
            lastError = nil
            pendingSave = nil
        } catch {
            throw error
        }
    }

    // MARK: - Utility

    /// Check if there's a pending save operation
    public var hasPendingSave: Bool {
        pendingSave != nil
    }

    /// Get time since last save
    public var timeSinceLastSave: TimeInterval? {
        guard let lastSaveDate = lastSaveDate else {
            return nil
        }
        return Date().timeIntervalSince(lastSaveDate)
    }

    deinit {
        debounceTimer?.invalidate()
        saveTask?.cancel()
    }
}

// MARK: - Save Status

/// Status of a save operation
public enum SaveStatus {
    case idle
    case pending
    case saving
    case success(Date)
    case failed(ProjectError)

    public var isActive: Bool {
        switch self {
        case .pending, .saving:
            return true
        default:
            return false
        }
    }

    public var isFailed: Bool {
        if case .failed = self {
            return true
        }
        return false
    }
}

// MARK: - Convenience Extensions

extension DebouncedSaveManager {
    /// Get current save status
    public var saveStatus: SaveStatus {
        if isSaving {
            return .saving
        }
        if hasUnsavedChanges {
            return .pending
        }
        if let error = lastError {
            return .failed(error)
        }
        if let lastSave = lastSaveDate {
            return .success(lastSave)
        }
        return .idle
    }
}

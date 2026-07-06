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

    private let persistence: any ProjectPersisting

    // MARK: - State

    /// The most recent snapshot awaiting persistence. `nil` once fully flushed.
    private var pendingSave: (project: Project, url: URL)?
    /// Monotonic counter bumped every time a new snapshot is queued. Used to
    /// detect that a newer edit arrived while an older one was being written,
    /// so the newer one is never discarded.
    private var saveGeneration: UInt64 = 0
    /// The in-flight save chain. New saves await this before running, so writes
    /// are serialized rather than dropped when one is already in progress.
    private var inFlight: Task<Void, Never>?
    private var debounceTimer: Timer?

    // MARK: - Initialization

    public init(
        persistence: any ProjectPersisting = ProjectPersistence(),
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

        // Store the latest snapshot and mark it as a new generation.
        pendingSave = (project, url)
        saveGeneration &+= 1
        hasUnsavedChanges = true

        // Restart the debounce timer.
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(
            withTimeInterval: debounceInterval,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor in
                self?.scheduleDrain()
            }
        }
    }

    /// Force immediate save without debouncing. Awaits any in-flight save first,
    /// then persists the latest snapshot, and rethrows any failure to the caller.
    /// - Parameters:
    ///   - project: The project to save
    ///   - url: The URL to save to
    public func saveImmediately(project: Project, to url: URL) async throws {
        debounceTimer?.invalidate()
        debounceTimer = nil

        pendingSave = (project, url)
        saveGeneration &+= 1
        hasUnsavedChanges = true
        lastError = nil

        await scheduleDrain().value

        // The drain leaves pendingSave set and lastError populated on failure.
        if let error = lastError {
            throw error
        }
    }

    /// Cancel any pending save operations
    public func cancelPendingSave() {
        debounceTimer?.invalidate()
        debounceTimer = nil
        pendingSave = nil
        hasUnsavedChanges = false
        inFlight?.cancel()
        inFlight = nil
    }

    // MARK: - Private Methods

    /// Enqueue a drain that runs after any in-flight save completes, so writes
    /// never overlap or get silently dropped. Returns the task for callers that
    /// need to await completion (e.g. `saveImmediately`).
    @discardableResult
    private func scheduleDrain() -> Task<Void, Never> {
        let previous = inFlight
        let task = Task { @MainActor [weak self] in
            await previous?.value
            await self?.drainSaves()
        }
        inFlight = task
        return task
    }

    /// Persist the latest pending snapshot, looping if a newer snapshot arrives
    /// mid-write so the freshest state always reaches disk. On failure the
    /// pending snapshot is retained (for retry) and surfaced via `lastError`.
    private func drainSaves() async {
        while let (project, url) = pendingSave {
            let generation = saveGeneration
            isSaving = true
            do {
                try await persistence.save(project, to: url)
            } catch let error as ProjectError {
                isSaving = false
                lastError = error
                return
            } catch {
                isSaving = false
                lastError = ProjectError.fileWriteFailed(url, error)
                return
            }
            isSaving = false
            lastSaveDate = Date()
            lastError = nil

            if saveGeneration == generation {
                // Nothing newer queued while we were writing — fully flushed.
                pendingSave = nil
                hasUnsavedChanges = false
                return
            }
            // A newer snapshot arrived during the await; loop and write it too.
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
        // The debounce timer is a one-shot `[weak self]` timer, invalidated on
        // every active code path; if it survives to fire after deinit it simply
        // no-ops. Touching the main-actor, non-Sendable `Timer?` from this
        // nonisolated deinit is unsafe under Swift 6, so we only cancel the
        // in-flight save (a Sendable Task, safe to cancel from anywhere).
        inFlight?.cancel()
    }
}

// MARK: - Persistence Seam

/// Abstraction over the on-disk project store so the save manager can be tested
/// against a controllable double. `ProjectPersistence` is the production actor.
public protocol ProjectPersisting: Sendable {
    func save(_ project: Project, to url: URL) async throws
    func load(from url: URL) async throws -> Project
}

extension ProjectPersistence: ProjectPersisting {}

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

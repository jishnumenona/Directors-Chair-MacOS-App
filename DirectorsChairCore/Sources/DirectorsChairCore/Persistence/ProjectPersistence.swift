// DirectorsChairCore/Sources/DirectorsChairCore/Persistence/ProjectPersistence.swift
//
// Thread-safe actor for project JSON persistence operations

import Foundation

/// Actor responsible for loading and saving Project data to/from JSON files
/// Provides thread-safe access to file I/O operations with atomic saves and backup management
public actor ProjectPersistence {

    // MARK: - Configuration

    /// JSON encoder configured for pretty-printed output compatible with Python
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    /// JSON decoder configured to handle both snake_case and camelCase
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    /// Maximum number of backup files to keep
    private let maxBackups: Int

    /// Whether to create backups before saving
    private let enableBackups: Bool

    // MARK: - Initialization

    public init(maxBackups: Int = 5, enableBackups: Bool = true) {
        self.maxBackups = maxBackups
        self.enableBackups = enableBackups
    }

    // MARK: - Load Operations

    /// Load a project from a JSON file
    /// - Parameter url: The URL of the project.json file
    /// - Returns: The decoded Project instance
    /// - Throws: ProjectError if loading or decoding fails
    public func load(from url: URL) async throws -> Project {
        // Verify file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ProjectError.fileNotFound(url)
        }

        // Check read permissions
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            throw ProjectError.permissionDenied(url)
        }

        do {
            // Read file data
            let data = try Data(contentsOf: url)

            // Decode project
            let project = try decoder.decode(Project.self, from: data)

            return project
        } catch let error as DecodingError {
            throw ProjectError.decodingFailed(error)
        } catch {
            throw ProjectError.invalidJSON(url, error)
        }
    }

    // MARK: - Save Operations

    /// Save a project to a JSON file using atomic write operation
    /// - Parameters:
    ///   - project: The Project instance to save
    ///   - url: The URL where the project.json file should be saved
    /// - Throws: ProjectError if encoding or writing fails
    public func save(_ project: Project, to url: URL) async throws {
        // Create backup if enabled and file exists
        if enableBackups && FileManager.default.fileExists(atPath: url.path) {
            try await createBackup(of: url)
        }

        do {
            // Encode project to JSON
            let data = try encoder.encode(project)

            // Perform atomic write using temporary file
            try await atomicWrite(data: data, to: url)

            // Rotate backups if needed
            if enableBackups {
                try await rotateBackups(for: url)
            }
        } catch let error as EncodingError {
            throw ProjectError.encodingFailed(error)
        } catch let error as ProjectError {
            throw error
        } catch {
            throw ProjectError.fileWriteFailed(url, error)
        }
    }

    // MARK: - Atomic Write

    /// Perform atomic write by writing to temp file then moving
    private func atomicWrite(data: Data, to url: URL) async throws {
        // Create parent directory if needed
        let parentDir = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parentDir.path) {
            try FileManager.default.createDirectory(
                at: parentDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        // Create temporary file URL
        let tempURL = url.deletingLastPathComponent()
            .appendingPathComponent(".\(url.lastPathComponent).tmp")

        // Write to temporary file
        try data.write(to: tempURL, options: .atomic)

        // Validate written data by attempting to decode it
        let writtenData = try Data(contentsOf: tempURL)
        _ = try decoder.decode(Project.self, from: writtenData)

        // Move temp file to final location (atomic operation)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.moveItem(at: tempURL, to: url)
    }

    // MARK: - Backup Management

    /// Create a backup of the existing project file
    private func createBackup(of url: URL) async throws {
        let backupURL = backupURL(for: url, timestamp: Date())

        do {
            // Create backups directory if needed
            let backupsDir = url.deletingLastPathComponent().appendingPathComponent(".backups")
            if !FileManager.default.fileExists(atPath: backupsDir.path) {
                try FileManager.default.createDirectory(
                    at: backupsDir,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            }

            // Copy file to backup location
            try FileManager.default.copyItem(at: url, to: backupURL)
        } catch {
            throw ProjectError.backupFailed(backupURL, error)
        }
    }

    /// Rotate backups, keeping only the most recent ones
    private func rotateBackups(for url: URL) async throws {
        let backupsDir = url.deletingLastPathComponent().appendingPathComponent(".backups")

        guard FileManager.default.fileExists(atPath: backupsDir.path) else {
            return
        }

        do {
            // Get all backup files
            let contents = try FileManager.default.contentsOfDirectory(
                at: backupsDir,
                includingPropertiesForKeys: [.creationDateKey],
                options: .skipsHiddenFiles
            )

            // Filter to only project.json backups
            let backupFiles = contents.filter { $0.lastPathComponent.hasPrefix("project_") }

            // Sort by creation date (newest first)
            let sortedBackups = try backupFiles.sorted { url1, url2 in
                let date1 = try url1.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                let date2 = try url2.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                return date1 > date2
            }

            // Delete oldest backups beyond maxBackups
            if sortedBackups.count > maxBackups {
                for backup in sortedBackups.dropFirst(maxBackups) {
                    try FileManager.default.removeItem(at: backup)
                }
            }
        } catch {
            // Non-fatal: log but don't throw
            print("Warning: Failed to rotate backups: \(error.localizedDescription)")
        }
    }

    /// Generate backup URL with timestamp
    private func backupURL(for url: URL, timestamp: Date) -> URL {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        let timestampString = formatter.string(from: timestamp)
            .replacingOccurrences(of: ":", with: "-")

        let backupsDir = url.deletingLastPathComponent().appendingPathComponent(".backups")
        let filename = "project_\(timestampString).json"

        return backupsDir.appendingPathComponent(filename)
    }

    // MARK: - Validation

    /// Validate that a project file can be loaded
    /// - Parameter url: The URL of the project file
    /// - Returns: true if the file is valid and can be loaded
    public func validate(url: URL) async -> Bool {
        do {
            _ = try await load(from: url)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Utility

    /// Get list of available backups for a project
    /// - Parameter url: The URL of the project file
    /// - Returns: Array of backup file URLs sorted by date (newest first)
    public func listBackups(for url: URL) async throws -> [URL] {
        let backupsDir = url.deletingLastPathComponent().appendingPathComponent(".backups")

        guard FileManager.default.fileExists(atPath: backupsDir.path) else {
            return []
        }

        let contents = try FileManager.default.contentsOfDirectory(
            at: backupsDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        )

        let backupFiles = contents.filter { $0.lastPathComponent.hasPrefix("project_") }

        return try backupFiles.sorted { url1, url2 in
            let date1 = try url1.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
            let date2 = try url2.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
            return date1 > date2
        }
    }

    /// Restore project from a specific backup
    /// - Parameters:
    ///   - backupURL: The URL of the backup file
    ///   - targetURL: The URL where the project should be restored
    /// - Throws: ProjectError if restoration fails
    public func restore(from backupURL: URL, to targetURL: URL) async throws {
        // Validate backup can be loaded
        let project = try await load(from: backupURL)

        // Save to target location
        try await save(project, to: targetURL)
    }
}

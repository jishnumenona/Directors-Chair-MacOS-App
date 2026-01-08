// DirectorsChairCore/Sources/DirectorsChairCore/Protocols/ExportServiceProtocol.swift
//
// Protocol interfaces for export and collaboration services (Module 4)

import Foundation

// MARK: - ExportServiceProtocol

/// Protocol for exporting project data to various formats
public protocol ExportServiceProtocol: Sendable {
    /// Export project to PDF
    /// - Parameters:
    ///   - project: Project to export
    ///   - options: PDF export options
    ///   - progress: Progress callback
    /// - Returns: URL to generated PDF file
    func exportToPDF(
        project: Project,
        options: PDFExportOptions,
        progress: (@Sendable (Double, String) -> Void)?
    ) async throws -> URL

    /// Export script to Final Draft format
    /// - Parameters:
    ///   - project: Project to export
    ///   - destination: Destination file URL
    /// - Returns: URL to exported file
    func exportToFinalDraft(
        project: Project,
        destination: URL
    ) async throws -> URL

    /// Export to Fountain script format
    /// - Parameters:
    ///   - project: Project to export
    ///   - destination: Destination file URL
    /// - Returns: URL to exported file
    func exportToFountain(
        project: Project,
        destination: URL
    ) async throws -> URL

    /// Export breakdown sheet
    /// - Parameters:
    ///   - project: Project to export
    ///   - format: Export format (PDF, Excel, CSV)
    ///   - destination: Destination file URL
    /// - Returns: URL to exported file
    func exportBreakdown(
        project: Project,
        format: ExportFormat,
        destination: URL
    ) async throws -> URL

    /// Export schedule/call sheet
    /// - Parameters:
    ///   - schedule: Schedule items to export
    ///   - project: Project context
    ///   - format: Export format
    ///   - destination: Destination file URL
    /// - Returns: URL to exported file
    func exportSchedule(
        schedule: [ScheduleItem],
        project: Project,
        format: ExportFormat,
        destination: URL
    ) async throws -> URL

    /// Export storyboard
    /// - Parameters:
    ///   - project: Project to export
    ///   - options: Storyboard export options
    ///   - destination: Destination file URL
    ///   - progress: Progress callback
    /// - Returns: URL to exported file
    func exportStoryboard(
        project: Project,
        options: StoryboardExportOptions,
        destination: URL,
        progress: (@Sendable (Double, String) -> Void)?
    ) async throws -> URL

    /// Export video sequence
    /// - Parameters:
    ///   - sequence: Sequence to export
    ///   - project: Project context
    ///   - options: Video export options
    ///   - progress: Progress callback
    /// - Returns: URL to exported video
    func exportVideo(
        sequence: Sequence,
        project: Project,
        options: VideoExportOptions,
        progress: (@Sendable (Double, String) -> Void)?
    ) async throws -> URL
}

// MARK: - GitServiceProtocol

/// Protocol for Git version control operations
public protocol GitServiceProtocol: Sendable {
    /// Initialize Git repository in project directory
    /// - Parameter projectPath: Path to project directory
    /// - Returns: Success status
    func initializeRepository(projectPath: URL) async throws -> Bool

    /// Commit changes to repository
    /// - Parameters:
    ///   - message: Commit message
    ///   - projectPath: Project directory
    /// - Returns: Commit hash
    func commit(message: String, projectPath: URL) async throws -> String

    /// Push changes to remote
    /// - Parameters:
    ///   - projectPath: Project directory
    ///   - remote: Remote name (default: "origin")
    ///   - branch: Branch name
    /// - Returns: Success status
    func push(
        projectPath: URL,
        remote: String,
        branch: String
    ) async throws -> Bool

    /// Pull changes from remote
    /// - Parameters:
    ///   - projectPath: Project directory
    ///   - remote: Remote name
    ///   - branch: Branch name
    /// - Returns: Success status
    func pull(
        projectPath: URL,
        remote: String,
        branch: String
    ) async throws -> Bool

    /// Get repository status
    /// - Parameter projectPath: Project directory
    /// - Returns: Git status information
    func getStatus(projectPath: URL) async throws -> GitStatus

    /// Get commit history
    /// - Parameters:
    ///   - projectPath: Project directory
    ///   - limit: Maximum commits to retrieve
    /// - Returns: Array of commit information
    func getHistory(
        projectPath: URL,
        limit: Int
    ) async throws -> [GitCommit]

    /// Create a new branch
    /// - Parameters:
    ///   - branchName: Name for new branch
    ///   - projectPath: Project directory
    /// - Returns: Success status
    func createBranch(
        branchName: String,
        projectPath: URL
    ) async throws -> Bool

    /// Switch to a branch
    /// - Parameters:
    ///   - branchName: Branch to switch to
    ///   - projectPath: Project directory
    /// - Returns: Success status
    func checkoutBranch(
        branchName: String,
        projectPath: URL
    ) async throws -> Bool

    /// Merge branches
    /// - Parameters:
    ///   - sourceBranch: Branch to merge from
    ///   - targetBranch: Branch to merge into
    ///   - projectPath: Project directory
    /// - Returns: Merge result
    func mergeBranch(
        sourceBranch: String,
        targetBranch: String,
        projectPath: URL
    ) async throws -> GitMergeResult
}

// MARK: - Supporting Types

/// PDF export options
public struct PDFExportOptions: Sendable {
    public var includeScript: Bool
    public var includeBreakdown: Bool
    public var includeSchedule: Bool
    public var includeStoryboard: Bool
    public var includeBudget: Bool
    public var pageSize: PDFPageSize
    public var includeImages: Bool

    public init(
        includeScript: Bool = true,
        includeBreakdown: Bool = false,
        includeSchedule: Bool = false,
        includeStoryboard: Bool = false,
        includeBudget: Bool = false,
        pageSize: PDFPageSize = .letter,
        includeImages: Bool = true
    ) {
        self.includeScript = includeScript
        self.includeBreakdown = includeBreakdown
        self.includeSchedule = includeSchedule
        self.includeStoryboard = includeStoryboard
        self.includeBudget = includeBudget
        self.pageSize = pageSize
        self.includeImages = includeImages
    }
}

/// PDF page size
public enum PDFPageSize: String, Sendable {
    case letter = "Letter"
    case a4 = "A4"
    case legal = "Legal"
}

/// Export format options
public enum ExportFormat: String, Sendable {
    case pdf = "PDF"
    case excel = "Excel"
    case csv = "CSV"
    case json = "JSON"
    case html = "HTML"
}

/// Storyboard export options
public struct StoryboardExportOptions: Sendable {
    public var layout: StoryboardLayout
    public var includeDialogue: Bool
    public var includeNotes: Bool
    public var framesPerPage: Int

    public init(
        layout: StoryboardLayout = .grid,
        includeDialogue: Bool = true,
        includeNotes: Bool = true,
        framesPerPage: Int = 6
    ) {
        self.layout = layout
        self.includeDialogue = includeDialogue
        self.includeNotes = includeNotes
        self.framesPerPage = framesPerPage
    }
}

/// Storyboard layout
public enum StoryboardLayout: String, Sendable {
    case grid = "Grid"
    case list = "List"
    case comic = "Comic"
}

/// Video export options
public struct VideoExportOptions: Sendable {
    public var resolution: String
    public var frameRate: Int
    public var codec: String
    public var includeAudio: Bool
    public var includeSubtitles: Bool

    public init(
        resolution: String = "1920x1080",
        frameRate: Int = 30,
        codec: String = "H.264",
        includeAudio: Bool = true,
        includeSubtitles: Bool = false
    ) {
        self.resolution = resolution
        self.frameRate = frameRate
        self.codec = codec
        self.includeAudio = includeAudio
        self.includeSubtitles = includeSubtitles
    }
}

/// Git repository status
public struct GitStatus: Sendable {
    public var branch: String
    public var hasUncommittedChanges: Bool
    public var modifiedFiles: [String]
    public var untrackedFiles: [String]
    public var aheadBy: Int
    public var behindBy: Int

    public init(
        branch: String = "main",
        hasUncommittedChanges: Bool = false,
        modifiedFiles: [String] = [],
        untrackedFiles: [String] = [],
        aheadBy: Int = 0,
        behindBy: Int = 0
    ) {
        self.branch = branch
        self.hasUncommittedChanges = hasUncommittedChanges
        self.modifiedFiles = modifiedFiles
        self.untrackedFiles = untrackedFiles
        self.aheadBy = aheadBy
        self.behindBy = behindBy
    }
}

/// Git commit information
public struct GitCommit: Sendable {
    public var hash: String
    public var message: String
    public var author: String
    public var date: Date
    public var filesChanged: Int

    public init(
        hash: String,
        message: String,
        author: String,
        date: Date,
        filesChanged: Int = 0
    ) {
        self.hash = hash
        self.message = message
        self.author = author
        self.date = date
        self.filesChanged = filesChanged
    }
}

/// Git merge result
public struct GitMergeResult: Sendable {
    public var success: Bool
    public var conflicts: [String]
    public var message: String

    public init(
        success: Bool,
        conflicts: [String] = [],
        message: String = ""
    ) {
        self.success = success
        self.conflicts = conflicts
        self.message = message
    }
}

// MARK: - Export Errors

/// Errors that can occur during export operations
public enum ExportError: LocalizedError, Sendable {
    case invalidFormat
    case exportFailed(String)
    case fileWriteError(URL, Error)
    case unsupportedOperation
    case missingData(String)

    public var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid export format"
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        case .fileWriteError(let url, let error):
            return "Failed to write file at \(url.path): \(error.localizedDescription)"
        case .unsupportedOperation:
            return "Operation not supported"
        case .missingData(let description):
            return "Missing required data: \(description)"
        }
    }
}

/// Errors that can occur during Git operations
public enum GitError: LocalizedError, Sendable {
    case notARepository
    case commitFailed(String)
    case pushFailed(String)
    case pullFailed(String)
    case mergeFailed(String)
    case branchExists
    case branchNotFound
    case networkError(Error)

    public var errorDescription: String? {
        switch self {
        case .notARepository:
            return "Not a Git repository"
        case .commitFailed(let reason):
            return "Commit failed: \(reason)"
        case .pushFailed(let reason):
            return "Push failed: \(reason)"
        case .pullFailed(let reason):
            return "Pull failed: \(reason)"
        case .mergeFailed(let reason):
            return "Merge failed: \(reason)"
        case .branchExists:
            return "Branch already exists"
        case .branchNotFound:
            return "Branch not found"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

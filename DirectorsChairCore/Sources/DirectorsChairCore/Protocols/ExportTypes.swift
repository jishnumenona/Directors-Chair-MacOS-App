// DirectorsChairCore — export + git-commit value types
//
// Extracted from the deleted ExportServiceProtocol.swift during WS2.1 dead-code removal:
// these types are live (referenced by shipped code); the rest of that file was dead.

import Foundation

/// Export format options
public enum ExportFormat: String, Sendable {
    case pdf = "PDF"
    case excel = "Excel"
    case csv = "CSV"
    case json = "JSON"
    case html = "HTML"
}

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

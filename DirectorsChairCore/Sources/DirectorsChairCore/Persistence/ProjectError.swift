// DirectorsChairCore/Sources/DirectorsChairCore/Persistence/ProjectError.swift
//
// Error types for project persistence operations

import Foundation

/// Errors that can occur during project persistence operations
public enum ProjectError: LocalizedError {
    case fileNotFound(URL)
    case invalidJSON(URL, Error)
    case encodingFailed(Error)
    case decodingFailed(Error)
    case fileWriteFailed(URL, Error)
    case backupFailed(URL, Error)
    case invalidProjectData(String)
    case permissionDenied(URL)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "Project file not found at: \(url.path)"
        case .invalidJSON(let url, let error):
            return "Invalid JSON in project file at \(url.path): \(error.localizedDescription)"
        case .encodingFailed(let error):
            return "Failed to encode project data: \(error.localizedDescription)"
        case .decodingFailed(let error):
            if let decodingError = error as? DecodingError {
                return "Failed to decode project data: \(Self.formatDecodingError(decodingError))"
            }
            return "Failed to decode project data: \(error.localizedDescription)"
        case .fileWriteFailed(let url, let error):
            return "Failed to write project file to \(url.path): \(error.localizedDescription)"
        case .backupFailed(let url, let error):
            return "Failed to create backup at \(url.path): \(error.localizedDescription)"
        case .invalidProjectData(let reason):
            return "Invalid project data: \(reason)"
        case .permissionDenied(let url):
            return "Permission denied accessing: \(url.path)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .fileNotFound:
            return "Verify the project file exists and the path is correct."
        case .invalidJSON:
            return "The project file may be corrupted. Try restoring from a backup."
        case .encodingFailed, .decodingFailed:
            return "Check that the project data structure is valid."
        case .fileWriteFailed:
            return "Verify you have write permissions and sufficient disk space."
        case .backupFailed:
            return "Check disk space and permissions for the backup location."
        case .invalidProjectData:
            return "Verify the project data meets all requirements."
        case .permissionDenied:
            return "Check file permissions and access rights."
        }
    }

    /// Helper to format DecodingError with detailed information
    private static func formatDecodingError(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, let context):
            let path = context.codingPath.map { $0.stringValue }.joined(separator: " -> ")
            return "Missing key '\(key.stringValue)' at \(path.isEmpty ? "root" : path)"
        case .typeMismatch(let type, let context):
            let path = context.codingPath.map { $0.stringValue }.joined(separator: " -> ")
            return "Type mismatch for '\(type)' at \(path.isEmpty ? "root" : path): \(context.debugDescription)"
        case .valueNotFound(let type, let context):
            let path = context.codingPath.map { $0.stringValue }.joined(separator: " -> ")
            return "Value not found for '\(type)' at \(path.isEmpty ? "root" : path): \(context.debugDescription)"
        case .dataCorrupted(let context):
            let path = context.codingPath.map { $0.stringValue }.joined(separator: " -> ")
            return "Data corrupted at \(path.isEmpty ? "root" : path): \(context.debugDescription)"
        @unknown default:
            return error.localizedDescription
        }
    }
}

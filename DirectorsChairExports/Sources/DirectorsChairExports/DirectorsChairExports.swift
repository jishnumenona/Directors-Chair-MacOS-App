// DirectorsChairExports
// Export services for DirectorsChair application
// Supports PDF, HTML, Fountain, and Final Draft XML formats
//
// Phase 2: Services Layer
// Owner: Agent 3 (Characters & AI)

import Foundation
@_exported import DirectorsChairCore

/// Version information for DirectorsChairExports module
public struct DirectorsChairExportsVersion {
    public static let version = "1.0.0"
    public static let build = "2026.01.13"
    public static let phase = "Phase 2 - Services Layer"
}

/// Export format types
public enum ExportFormat: String, CaseIterable, Sendable {
    case fountain = "fountain"
    case fdx = "fdx"
    case pdf = "pdf"
    case html = "html"
    
    public var fileExtension: String {
        switch self {
        case .fountain: return "fountain"
        case .fdx: return "fdx"
        case .pdf: return "pdf"
        case .html: return "html"
        }
    }
    
    public var displayName: String {
        switch self {
        case .fountain: return "Fountain"
        case .fdx: return "Final Draft"
        case .pdf: return "PDF"
        case .html: return "HTML"
        }
    }
}

/// Export error types
public enum ExportError: LocalizedError, Sendable {
    case invalidProject(String)
    case fileWriteError(String)
    case generationFailed(String)
    case unsupportedFormat(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidProject(let reason):
            return "Invalid project: \(reason)"
        case .fileWriteError(let reason):
            return "Failed to write file: \(reason)"
        case .generationFailed(let reason):
            return "Export generation failed: \(reason)"
        case .unsupportedFormat(let format):
            return "Unsupported export format: \(format)"
        }
    }
}

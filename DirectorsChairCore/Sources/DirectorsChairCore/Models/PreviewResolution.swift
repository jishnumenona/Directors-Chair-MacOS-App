// DirectorsChairCore/Models/PreviewResolution.swift
//
// The one size every generated shot, scene and location preview comes out
// at (DC-0090, owner request 2026-08-29: previews arrived at whatever size
// the provider felt like — 1024×1024 squares cropped into the wide shot
// frame). Project-wide, HD by default, changed in Project Settings. Raw
// values are stored in project files — stable, never rename.

import Foundation

public enum PreviewResolution: String, Codable, CaseIterable, Sendable {
    case hd720 = "720p"
    case hd1080 = "1080p"
    case uhd4k = "4k"

    /// Full HD — the owner's default for every project.
    public static let `default`: PreviewResolution = .hd1080

    public var width: Int {
        switch self {
        case .hd720: return 1280
        case .hd1080: return 1920
        case .uhd4k: return 3840
        }
    }

    public var height: Int {
        switch self {
        case .hd720: return 720
        case .hd1080: return 1080
        case .uhd4k: return 2160
        }
    }

    public var displayName: String {
        switch self {
        case .hd720: return "HD 720p"
        case .hd1080: return "Full HD 1080p"
        case .uhd4k: return "4K UHD"
        }
    }

    /// "1920 × 1080" — the label under every option.
    public var dimensionsLabel: String { "\(width) × \(height)" }

    /// Every option is a 16:9 film frame — previews are frames, not squares.
    public var aspectRatio: String { "16:9" }

    /// Tolerant reader for project files: a token this build doesn't know
    /// (a future option) falls back to the default instead of failing the
    /// whole project decode.
    public static func stored(_ raw: String?) -> PreviewResolution {
        raw.flatMap(PreviewResolution.init(rawValue:)) ?? .default
    }
}

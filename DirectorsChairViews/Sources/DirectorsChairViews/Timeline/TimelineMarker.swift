// DirectorsChairViews/Sources/DirectorsChairViews/Timeline/TimelineMarker.swift
//
// Timeline marker representing scene boundaries, sequence boundaries, and user markers

import Foundation
import SwiftUI

/// Represents a marker on the timeline (scene/sequence boundary, user marker, or note)
public struct TimelineMarker: Identifiable, Equatable {
    public let id: UUID

    /// Time position in seconds
    public var time: CGFloat

    /// Label text for the marker
    public var label: String

    /// Kind of marker
    public var kind: MarkerKind

    /// Color for the marker (hex string)
    public var color: String

    /// Type of user marker (for user markers only)
    public var markerType: MarkerType

    /// Additional notes
    public var notes: String

    /// Kind of marker on the timeline
    public enum MarkerKind: String, Sendable {
        case user       // User-placed marker
        case scene      // Scene boundary
        case sequence   // Sequence boundary
        case note       // Production note
        case shot       // Shot marker (camera setup)
    }

    /// Type of user marker (subcategory)
    public enum MarkerType: String, Sendable {
        case general    // General purpose marker
        case lighting   // Lighting cue
        case effect     // Special effect cue
    }

    public init(
        id: UUID = UUID(),
        time: CGFloat,
        label: String,
        kind: MarkerKind = .user,
        color: String = "#FF5F5F",
        markerType: MarkerType = .general,
        notes: String = ""
    ) {
        self.id = id
        self.time = time
        self.label = label
        self.kind = kind
        self.color = color
        self.markerType = markerType
        self.notes = notes
    }

    /// SwiftUI Color from hex string
    public var markerColor: Color {
        Color(hex: color)
    }
}

// MARK: - Scene/Sequence Boundary

/// Represents a scene or sequence boundary time and name
public struct TimelineBoundary: Identifiable, Equatable {
    public let id: UUID
    public var time: CGFloat
    public var name: String

    public init(id: UUID = UUID(), time: CGFloat, name: String) {
        self.id = id
        self.time = time
        self.name = name
    }
}

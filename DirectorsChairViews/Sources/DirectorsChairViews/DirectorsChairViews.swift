// DirectorsChairViews
// SwiftUI views and UI components for DirectorsChair application
//
// Module 3: Views (Agent 4 - Timeline & Canvas)
// This module contains all SwiftUI views for DirectorsChair

import Foundation
import SwiftUI

/// Version information for DirectorsChairViews module
public struct DirectorsChairViewsVersion {
    public static let version = "1.0.0"
    public static let build = "2026.01.11"
    public static let modules = ["Timeline"]
}

// MARK: - Public API

// All Timeline types are defined in the Timeline/ subdirectory
// Import this module to access:
// - TimelineView: Main timeline view with controls
// - TimelineCanvas: GPU-accelerated canvas with viewport culling
// - TimelineViewModel: View model for building segments
// - TimelineSegment: Segment data structure
// - TimelineMarker: Marker data structure
// - TimelineBoundary: Scene/sequence boundary
// - TimelineMode: View mode enum (scene/sequence/global)
// - TimelineLayoutConstants: Layout configuration
// - DurationEstimator: WPM-based duration calculation

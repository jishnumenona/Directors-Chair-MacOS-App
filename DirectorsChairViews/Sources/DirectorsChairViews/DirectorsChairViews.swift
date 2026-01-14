// DirectorsChairViews
// SwiftUI views and UI components for DirectorsChair application
//
// Module 3: Views (Agent 2 - Core Editing, Agent 4 - Timeline & Canvas)
// This module contains all SwiftUI views for DirectorsChair

import Foundation
import SwiftUI

/// Version information for DirectorsChairViews module
public struct DirectorsChairViewsVersion {
    public static let version = "1.2.0"
    public static let build = "2026.01.14"
    public static let modules = [
        "Timeline",
        "Bubble",
        "StoryDesign",
        "VisionBoard",
        "Cinematography"
    ]
}

// MARK: - Public API

// Timeline Module (Timeline/ subdirectory)
// - TimelineView: Main timeline view with controls
// - TimelineCanvas: GPU-accelerated canvas with viewport culling
// - TimelineViewModel: View model for building segments
// - TimelineSegment: Segment data structure
// - TimelineMarker: Marker data structure
// - TimelineBoundary: Scene/sequence boundary
// - TimelineMode: View mode enum (scene/sequence/global)
// - TimelineLayoutConstants: Layout configuration
// - DurationEstimator: WPM-based duration calculation

// Bubble Module (Bubble/ subdirectory)
// - BubbleView: Main dialogue editing interface
// - DialogueBubbleCard: Dialogue bubble component
// - ActionBubbleCard: Action/stage direction component
// - NarrationBubbleCard: Narration/voiceover component
// - NoteBubbleCard: Production note component
// - SoundNoteBubbleCard: Sound/music note component
// - DialogueEditorPanel: Right panel editor
// - SceneListSidebar: Scene navigation

// StoryDesign Module (StoryDesign/ subdirectory)
// - StoryDesignView: Main character design view
// - CharacterListSidebar: Character list with search
// - PhysicalAppearanceTab: Character customizer
// - PersonalityTraitsTab: 25 traits with radar chart
// - BiographyTab: Goals, fears, backstory
// - RelationshipsTab: Character relationships

// VisionBoard Module (VisionBoard/ subdirectory) - Phase 5
// - VisionBoardView: Main vision board interface with toolbar
// - VisionBoardCanvas: Infinite freeform canvas with pan/zoom
// - VisionCardItem: Draggable/resizable vision card component
// - VisionCardEditor: Dialog for creating/editing cards
// - VisionBoardViewModel: State management for vision board
// - VisionCardType: Enum for card types (image, text, color palette, etc.)
// - VisionDepartment: Enum for department categorization

// Cinematography Module (Cinematography/ subdirectory) - Phase 5
// - CinematographyView: Shot planning interface
// - CinematographyViewModel: Shot state management
// - ShotStatus: Enum for shot status tracking
// - CinematographyViewMode: View mode enum (shot list, storyboard, etc.)
// - CameraPreset: Camera configuration presets
// - CameraAngleOptions: Static options for camera settings

// Shared Module (Shared/ subdirectory)
// - CharacterAvatarView: Circular avatar display
// - TagPillView: Tag display component
// - ColorExtensions: Hex color support

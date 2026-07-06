// DirectorsChairCore — AI generation kind vocabulary
//
// Extracted from the deleted EventBus/AppEvent.swift during WS2.1 dead-code removal:
// these types are live (referenced by shipped code); the rest of that file was dead.

import Foundation

/// Types of AI generation operations
public enum AIGenerationType: String, Equatable, Sendable {
    case characterImage = "character_image"
    case sceneImage = "scene_image"
    case dialogue = "dialogue"
    case voiceover = "voiceover"
    case video = "video"
    case script = "script"
    case storyboard = "storyboard"
    case other
}

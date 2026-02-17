//
//  ScriptElement.swift
//  DirectorsChair-Desktop
//
//  Script View: Data model for screenplay elements
//

import Foundation

/// Types of screenplay elements following industry-standard formatting
enum ScriptElementType: String, CaseIterable {
    case sceneHeading       // INT. LOCATION - TIME (ALL CAPS, bold)
    case action             // Stage directions / description
    case character          // Character name line (ALL CAPS, centered)
    case parenthetical      // (emotion/direction)
    case dialogue           // Spoken text
    case transition         // CUT TO:, FADE IN: (right-aligned, ALL CAPS)
    case dualDialogue       // Two characters speaking simultaneously
    case scriptNote         // Hidden note/comment (editor-only)
    case soundCue           // Sound/music cue (maps to SoundNote)
    case sectionHeading     // Sequence/Act heading
    case blankLine          // Separator
}

/// A single element in the linear screenplay representation
struct ScriptElement: Identifiable, Equatable {
    let id: UUID
    var type: ScriptElementType
    var text: String

    // Source tracking for bi-directional sync with Project model
    var sourceSequenceIndex: Int?
    var sourceSceneIndex: Int?
    var sourceItemId: String?
    var sourceItemType: String?  // "dialogue", "action", "narration", "note", "soundNote"

    // Scene metadata
    var sceneNumber: String?
    var isContinued: Bool = false
    var isDualDialogueLeft: Bool = false
    var isDualDialogueRight: Bool = false

    // Placeholder state (gray italic hint text that clears on edit)
    var isPlaceholder: Bool = false

    /// Display text with auto-capitalization for character names, scene headings, transitions
    var displayText: String {
        switch type {
        case .sceneHeading, .character, .transition:
            return text.uppercased()
        default:
            return text
        }
    }

    init(
        id: UUID = UUID(),
        type: ScriptElementType,
        text: String,
        sourceSequenceIndex: Int? = nil,
        sourceSceneIndex: Int? = nil,
        sourceItemId: String? = nil,
        sourceItemType: String? = nil,
        sceneNumber: String? = nil,
        isContinued: Bool = false,
        isPlaceholder: Bool = false
    ) {
        self.id = id
        self.type = type
        self.text = text
        self.sourceSequenceIndex = sourceSequenceIndex
        self.sourceSceneIndex = sourceSceneIndex
        self.sourceItemId = sourceItemId
        self.sourceItemType = sourceItemType
        self.sceneNumber = sceneNumber
        self.isContinued = isContinued
        self.isPlaceholder = isPlaceholder
    }

    static func == (lhs: ScriptElement, rhs: ScriptElement) -> Bool {
        lhs.id == rhs.id &&
        lhs.type == rhs.type &&
        lhs.text == rhs.text &&
        lhs.sourceSequenceIndex == rhs.sourceSequenceIndex &&
        lhs.sourceSceneIndex == rhs.sourceSceneIndex &&
        lhs.sourceItemId == rhs.sourceItemId &&
        lhs.isPlaceholder == rhs.isPlaceholder
    }
}

/// Scene outline item for the navigator sidebar
struct SceneOutlineItem: Identifiable {
    let id: UUID
    let sceneNumber: String
    let heading: String
    let elementId: UUID  // ID of the corresponding ScriptElement for scroll-to
}

/// An item in the autocomplete dropdown
struct AutocompleteItem: Identifiable {
    let id = UUID()
    let text: String
    var imagePath: String?   // Relative path for avatar (characters)
    var color: String?       // Fallback color for initials badge
}

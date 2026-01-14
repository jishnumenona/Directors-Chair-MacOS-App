// DirectorsChairExports/Sources/DirectorsChairExports/Fountain/FountainExportService.swift
//
// Fountain Screenplay Export Service
// Exports project to industry-standard Fountain screenplay format

import Foundation
import DirectorsChairCore

/// Service for exporting screenplays to Fountain format
/// Fountain is a plain text markup language for screenwriting
/// Reference: https://fountain.io/syntax
public struct FountainExportService: Sendable {
    
    // MARK: - Export Methods
    
    /// Export entire project to Fountain format
    public static func exportProject(_ project: Project) -> String {
        var output = ""
        
        // Title page
        output += buildTitlePage(project)
        output += "\n\n"
        
        // Sequences and scenes
        for sequence in project.sequences {
            output += buildSequence(sequence)
        }
        
        return output
    }
    
    /// Export a single scene to Fountain format
    public static func exportScene(_ scene: Scene, location: String? = nil) -> String {
        return buildScene(scene, sequenceLocation: location)
    }
    
    /// Export to file
    public static func exportToFile(_ project: Project, url: URL) throws {
        let content = exportProject(project)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
    
    // MARK: - Title Page
    
    private static func buildTitlePage(_ project: Project) -> String {
        var titlePage = ""
        
        // Title
        titlePage += "Title: \(project.name)\n"
        
        // Director/Author
        if !project.director.isEmpty {
            titlePage += "Author: \(project.director)\n"
        }
        
        // Genre
        if !project.genre.isEmpty {
            titlePage += "Genre: \(project.genre)\n"
        }
        
        // Draft date
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        titlePage += "Draft date: \(formatter.string(from: Date()))\n"
        
        // Contact (from user manager if available)
        if let userManager = project.userManager, !userManager.users.isEmpty {
            // Just add a placeholder contact
            titlePage += "Contact: [Author Contact]\n"
        }
        
        return titlePage
    }
    
    // MARK: - Sequence Building
    
    private static func buildSequence(_ sequence: Sequence) -> String {
        var output = ""
        
        // Sequence header as action/description
        if !sequence.name.isEmpty {
            output += "= \(sequence.name.uppercased()) =\n\n"
        }
        
        // All scenes in sequence
        for scene in sequence.scenes {
            output += buildScene(scene, sequenceLocation: sequence.location)
            output += "\n\n"
        }
        
        return output
    }
    
    // MARK: - Scene Building
    
    private static func buildScene(_ scene: Scene, sequenceLocation: String? = nil) -> String {
        var output = ""
        
        // Scene heading (slug line)
        let heading = buildSceneHeading(scene, sequenceLocation: sequenceLocation)
        output += heading + "\n\n"
        
        // Scene description
        if !scene.description.isEmpty {
            output += scene.description + "\n\n"
        }
        
        // Build scene content in chronological order
        let elements = collectSceneElements(scene)
        
        for element in elements {
            output += formatElement(element) + "\n\n"
        }
        
        return output
    }
    
    private static func buildSceneHeading(_ scene: Scene, sequenceLocation: String?) -> String {
        // Format: INT./EXT. LOCATION - TIME OF DAY
        var heading = ""
        
        // Determine INT/EXT from location or scene name
        let location = scene.location ?? sequenceLocation ?? scene.name
        let locationUpper = location.uppercased()
        
        if locationUpper.hasPrefix("INT") || locationUpper.hasPrefix("EXT") {
            heading = locationUpper
        } else {
            // Default to INT if not specified
            heading = "INT. \(locationUpper)"
        }
        
        // Add time of day if we can extract it
        // Common patterns: "- DAY", "- NIGHT", "- DAWN", etc.
        if !heading.contains(" - ") {
            heading += " - DAY"
        }
        
        return heading
    }
    
    // MARK: - Scene Elements
    
    private enum SceneElement {
        case dialogue(Dialogue)
        case action(Action)
        case narration(Narration)
        case note(Note)
        case soundNote(SoundNote)
        
        var chronologyNumber: Int {
            switch self {
            case .dialogue(let d): return d.chronologyNumber
            case .action(let a): return a.chronologyNumber
            case .narration(let n): return n.chronologyNumber
            case .note(let n): return n.chronologyNumber
            case .soundNote(let s): return s.chronologyNumber
            }
        }
    }
    
    private static func collectSceneElements(_ scene: Scene) -> [SceneElement] {
        var elements: [SceneElement] = []
        
        for dialogue in scene.dialogues {
            elements.append(.dialogue(dialogue))
        }
        for action in scene.actions {
            elements.append(.action(action))
        }
        for narration in scene.narrations {
            elements.append(.narration(narration))
        }
        for note in scene.sceneNotes {
            elements.append(.note(note))
        }
        for soundNote in scene.soundNotes {
            elements.append(.soundNote(soundNote))
        }
        
        // Sort by chronology number
        return elements.sorted { $0.chronologyNumber < $1.chronologyNumber }
    }
    
    private static func formatElement(_ element: SceneElement) -> String {
        switch element {
        case .dialogue(let dialogue):
            return formatDialogue(dialogue)
        case .action(let action):
            return formatAction(action)
        case .narration(let narration):
            return formatNarration(narration)
        case .note(let note):
            return formatNote(note)
        case .soundNote(let soundNote):
            return formatSoundNote(soundNote)
        }
    }
    
    // MARK: - Element Formatting
    
    private static func formatDialogue(_ dialogue: Dialogue) -> String {
        var output = ""
        
        // Character name (uppercase)
        output += dialogue.character.uppercased()
        
        // Parenthetical for tags/tone
        if !dialogue.tags.isEmpty {
            let parenthetical = dialogue.tags.joined(separator: ", ")
            output += "\n(\(parenthetical))"
        }
        
        // Dialogue text
        output += "\n\(dialogue.text)"
        
        return output
    }
    
    private static func formatAction(_ action: Action) -> String {
        // Action/description is just plain text in Fountain
        return action.description
    }
    
    private static func formatNarration(_ narration: Narration) -> String {
        // Narration as action with emphasis
        return ">\(narration.text)"
    }
    
    private static func formatNote(_ note: Note) -> String {
        // Notes as Fountain notes (double brackets)
        return "[[\(note.content)]]"
    }
    
    private static func formatSoundNote(_ soundNote: SoundNote) -> String {
        // Sound notes as transition or note
        var output = "[[SFX: \(soundNote.soundType)"
        if !soundNote.description.isEmpty {
            output += " - \(soundNote.description)"
        }
        output += "]]"
        return output
    }
}

// MARK: - Fountain Format Constants

extension FountainExportService {
    /// Fountain formatting reference
    public struct FountainFormat {
        /// Force scene heading with period prefix
        public static let forceSceneHeading = "."
        
        /// Force action with exclamation prefix
        public static let forceAction = "!"
        
        /// Force character with @ prefix
        public static let forceCharacter = "@"
        
        /// Transition suffix
        public static let transitionSuffix = "TO:"
        
        /// Centered text markers
        public static let centeredStart = ">"
        public static let centeredEnd = "<"
        
        /// Note markers
        public static let noteStart = "[["
        public static let noteEnd = "]]"
        
        /// Boneyard (commented out) markers
        public static let boneyardStart = "/*"
        public static let boneyardEnd = "*/"
        
        /// Section marker
        public static let section = "#"
        
        /// Synopsis marker
        public static let synopsis = "="
        
        /// Page break
        public static let pageBreak = "==="
    }
}

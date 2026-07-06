// DirectorsChairExports/Sources/DirectorsChairExports/HTML/HTMLExportService.swift
//
// HTML Export Service
// Generates professional HTML documents for characters, projects, and scenes

import Foundation
import DirectorsChairCore

/// Service for exporting project data to HTML format
public struct HTMLExportService: Sendable {
    
    // MARK: - Export Types
    
    public enum HTMLExportType: String, Sendable {
        case characterOverview
        case projectOverview
        case sceneOverview
        case screenplay
        case callSheet
    }
    
    // MARK: - Character Overview Export
    
    /// Generate HTML for character overview infographic
    public static func exportCharacterOverview(_ character: Character, project: Project? = nil) -> String {
        let generator = CharacterOverviewGenerator(character: character, project: project)
        return generator.generate()
    }
    
    /// Generate HTML for project overview
    public static func exportProjectOverview(_ project: Project) -> String {
        let generator = ProjectOverviewGenerator(project: project)
        return generator.generate()
    }
    
    /// Generate HTML screenplay
    public static func exportScreenplay(_ project: Project) -> String {
        let generator = ScreenplayHTMLGenerator(project: project)
        return generator.generate()
    }
    
    /// Export to file
    public static func exportToFile(html: String, url: URL) throws {
        try html.write(to: url, atomically: true, encoding: .utf8)
    }
}

// MARK: - Character Overview Generator

private struct CharacterOverviewGenerator {
    let character: Character
    let project: Project?
    
    func generate() -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>Character Overview - \(escapeHTML(character.name))</title>
            <style>\(getCSS())</style>
        </head>
        <body>
            <div class="container">
                \(buildHeader())
                \(buildHeroSection())
                \(buildPhysicalSection())
                \(buildPersonalitySection())
                \(buildBiographySection())
            </div>
        </body>
        </html>
        """
    }
    
    private func buildHeader() -> String {
        return """
        <div class="header">
            <h1>\(escapeHTML(character.name))</h1>
            <p class="role">\(escapeHTML(character.role))</p>
        </div>
        """
    }
    
    private func buildHeroSection() -> String {
        var imageHTML = ""
        if let baseImage = character.baseImage, !baseImage.isEmpty {
            imageHTML = "<img src=\"\(escapeHTML(baseImage))\" alt=\"\(escapeHTML(character.name))\" class=\"hero-image\">"
        } else {
            // Placeholder with initials
            let initials = String(character.name.prefix(2)).uppercased()
            imageHTML = "<div class=\"hero-placeholder\" style=\"background-color: \(character.color);\">\(initials)</div>"
        }
        
        return """
        <div class="hero-section">
            \(imageHTML)
            <div class="hero-info">
                <p class="about">\(escapeHTML(character.about))</p>
                <div class="quick-facts">
                    <span class="fact"><strong>Age:</strong> \(character.age)</span>
                    <span class="fact"><strong>Gender:</strong> \(escapeHTML(character.gender))</span>
                    <span class="fact"><strong>Build:</strong> \(escapeHTML(character.build))</span>
                </div>
            </div>
        </div>
        """
    }
    
    private func buildPhysicalSection() -> String {
        return """
        <div class="section physical-section">
            <h2>Physical Appearance</h2>
            <div class="attributes-grid">
                <div class="attribute">
                    <label>Height</label>
                    <span>\(character.heightCm.map { "\(Int($0)) cm" } ?? "Not specified")</span>
                </div>
                <div class="attribute">
                    <label>Weight</label>
                    <span>\(character.weightKg.map { "\(Int($0)) kg" } ?? "Not specified")</span>
                </div>
                <div class="attribute">
                    <label>Hair</label>
                    <span>\(escapeHTML(character.hairStyle)), \(escapeHTML(character.hairColor))</span>
                </div>
                <div class="attribute">
                    <label>Eyes</label>
                    <span>\(escapeHTML(character.eyeShape)), \(escapeHTML(character.eyeColorDescription.isEmpty ? character.eyeColor : character.eyeColorDescription))</span>
                </div>
                <div class="attribute">
                    <label>Skin Tone</label>
                    <span>\(escapeHTML(character.skinTone))</span>
                </div>
                <div class="attribute">
                    <label>Distinguishing Features</label>
                    <span>\(escapeHTML(character.distinguishingFeatures.isEmpty ? "None noted" : character.distinguishingFeatures))</span>
                </div>
            </div>
        </div>
        """
    }
    
    private func buildPersonalitySection() -> String {
        let traits = character.traits
        var traitBars = ""
        
        for (trait, score) in traits.sorted(by: { $0.key < $1.key }) {
            let percentage = min(100, max(0, score))
            traitBars += """
            <div class="trait-bar">
                <span class="trait-name">\(escapeHTML(trait.replacingOccurrences(of: "_", with: " ").capitalized))</span>
                <div class="bar-container">
                    <div class="bar-fill" style="width: \(percentage)%;"></div>
                </div>
                <span class="trait-score">\(Int(percentage))</span>
            </div>
            """
        }
        
        return """
        <div class="section personality-section">
            <h2>Personality Traits</h2>
            <div class="traits-container">
                \(traitBars)
            </div>
        </div>
        """
    }
    
    private func buildBiographySection() -> String {
        return """
        <div class="section biography-section">
            <h2>Biography</h2>
            <div class="bio-grid">
                \(buildBioField("Full Name", character.fullName))
                \(buildBioField("Nickname", character.nickname))
                \(buildBioField("Occupation", character.occupation))
                \(buildBioField("Affiliation", character.affiliation))
                \(buildBioField("Primary Goal", character.primaryGoal))
                \(buildBioField("Primary Fear", character.primaryFear))
                \(buildBioField("Weakness", character.weakness))
                \(buildBioField("Flaw", character.flaw))
            </div>
            \(buildBioLongField("Background Story", character.backgroundStory))
            \(buildBioLongField("Character Arc Notes", character.characterArcNotes))
        </div>
        """
    }
    
    private func buildBioField(_ label: String, _ value: String?) -> String {
        guard let value = value, !value.isEmpty else { return "" }
        return """
        <div class="bio-field">
            <label>\(escapeHTML(label))</label>
            <span>\(escapeHTML(value))</span>
        </div>
        """
    }
    
    private func buildBioLongField(_ label: String, _ value: String?) -> String {
        guard let value = value, !value.isEmpty else { return "" }
        return """
        <div class="bio-field-long">
            <label>\(escapeHTML(label))</label>
            <p>\(escapeHTML(value))</p>
        </div>
        """
    }
    
    private func getCSS() -> String {
        return """
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
            color: #f0f0f0;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            padding: 40px;
        }
        .container { max-width: 1200px; margin: 0 auto; }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 30px;
            border-radius: 16px;
            margin-bottom: 30px;
            text-align: center;
        }
        .header h1 { font-size: 2.5rem; margin-bottom: 8px; }
        .header .role { font-size: 1.2rem; opacity: 0.9; }
        .hero-section {
            display: flex;
            gap: 30px;
            margin-bottom: 30px;
            background: rgba(255,255,255,0.05);
            border-radius: 16px;
            padding: 30px;
        }
        .hero-image, .hero-placeholder {
            width: 300px;
            height: 400px;
            border-radius: 12px;
            object-fit: cover;
        }
        .hero-placeholder {
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 4rem;
            font-weight: bold;
            color: white;
        }
        .hero-info { flex: 1; }
        .hero-info .about { font-size: 1.1rem; margin-bottom: 20px; }
        .quick-facts { display: flex; gap: 20px; flex-wrap: wrap; }
        .fact { background: rgba(255,255,255,0.1); padding: 8px 16px; border-radius: 8px; }
        .section {
            background: rgba(255,255,255,0.05);
            border-radius: 16px;
            padding: 30px;
            margin-bottom: 30px;
        }
        .section h2 { margin-bottom: 20px; color: #667eea; }
        .attributes-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 20px; }
        .attribute label { display: block; font-size: 0.85rem; color: #888; margin-bottom: 4px; }
        .attribute span { font-size: 1.1rem; }
        .traits-container { display: flex; flex-direction: column; gap: 12px; }
        .trait-bar { display: flex; align-items: center; gap: 12px; }
        .trait-name { width: 150px; font-size: 0.9rem; }
        .bar-container { flex: 1; height: 20px; background: rgba(255,255,255,0.1); border-radius: 10px; overflow: hidden; }
        .bar-fill { height: 100%; background: linear-gradient(90deg, #667eea, #764ba2); border-radius: 10px; }
        .trait-score { width: 40px; text-align: right; font-weight: bold; }
        .bio-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 20px; margin-bottom: 20px; }
        .bio-field label { display: block; font-size: 0.85rem; color: #888; margin-bottom: 4px; }
        .bio-field-long { margin-top: 20px; }
        .bio-field-long label { display: block; font-size: 0.85rem; color: #888; margin-bottom: 8px; }
        .bio-field-long p { background: rgba(0,0,0,0.2); padding: 15px; border-radius: 8px; }
        @media (max-width: 768px) {
            .hero-section { flex-direction: column; }
            .hero-image, .hero-placeholder { width: 100%; height: 300px; }
            .attributes-grid { grid-template-columns: repeat(2, 1fr); }
            .bio-grid { grid-template-columns: 1fr; }
        }
        """
    }
}

// MARK: - Project Overview Generator

private struct ProjectOverviewGenerator {
    let project: Project
    
    func generate() -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>\(escapeHTML(project.name)) - Project Overview</title>
            <style>\(getCSS())</style>
        </head>
        <body>
            <div class="container">
                \(buildHeader())
                \(buildSummarySection())
                \(buildCharactersSection())
                \(buildSequencesSection())
            </div>
        </body>
        </html>
        """
    }
    
    private func buildHeader() -> String {
        return """
        <div class="header">
            <h1>\(escapeHTML(project.name))</h1>
            <p class="meta">\(escapeHTML(project.genre)) | \(escapeHTML(project.director))</p>
        </div>
        """
    }
    
    private func buildSummarySection() -> String {
        let stats = """
        <div class="stats-grid">
            <div class="stat"><span class="stat-value">\(project.characters.count)</span><span class="stat-label">Characters</span></div>
            <div class="stat"><span class="stat-value">\(project.sequences.count)</span><span class="stat-label">Sequences</span></div>
            <div class="stat"><span class="stat-value">\(project.sequences.reduce(0) { $0 + $1.scenes.count })</span><span class="stat-label">Scenes</span></div>
        </div>
        """
        
        return """
        <div class="section">
            <h2>Project Summary</h2>
            <p class="logline">\(escapeHTML(project.overviewLogline))</p>
            \(stats)
        </div>
        """
    }
    
    private func buildCharactersSection() -> String {
        var cards = ""
        for character in project.characters.prefix(8) {
            let initials = String(character.name.prefix(2)).uppercased()
            cards += """
            <div class="character-card">
                <div class="avatar" style="background-color: \(character.color);">\(initials)</div>
                <div class="info">
                    <h3>\(escapeHTML(character.name))</h3>
                    <p>\(escapeHTML(character.role))</p>
                </div>
            </div>
            """
        }
        
        return """
        <div class="section">
            <h2>Characters</h2>
            <div class="characters-grid">\(cards)</div>
        </div>
        """
    }
    
    private func buildSequencesSection() -> String {
        var items = ""
        for sequence in project.sequences {
            items += """
            <div class="sequence-item">
                <h3>\(escapeHTML(sequence.name))</h3>
                <p>\(sequence.scenes.count) scenes</p>
            </div>
            """
        }
        
        return """
        <div class="section">
            <h2>Story Structure</h2>
            <div class="sequences-list">\(items)</div>
        </div>
        """
    }
    
    private func getCSS() -> String {
        return """
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            background: #0a0a0f;
            color: #f0f0f0;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            padding: 40px;
        }
        .container { max-width: 1200px; margin: 0 auto; }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 60px 40px;
            border-radius: 16px;
            text-align: center;
            margin-bottom: 30px;
        }
        .header h1 { font-size: 3rem; margin-bottom: 10px; }
        .header .meta { font-size: 1.2rem; opacity: 0.9; }
        .section {
            background: rgba(255,255,255,0.05);
            border-radius: 16px;
            padding: 30px;
            margin-bottom: 30px;
        }
        .section h2 { color: #667eea; margin-bottom: 20px; }
        .logline { font-size: 1.2rem; font-style: italic; margin-bottom: 20px; }
        .stats-grid { display: flex; gap: 30px; }
        .stat { text-align: center; }
        .stat-value { display: block; font-size: 2.5rem; font-weight: bold; color: #667eea; }
        .stat-label { font-size: 0.9rem; color: #888; }
        .characters-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 20px; }
        .character-card { display: flex; align-items: center; gap: 12px; background: rgba(0,0,0,0.3); padding: 15px; border-radius: 12px; }
        .avatar { width: 50px; height: 50px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-weight: bold; color: white; }
        .character-card h3 { font-size: 1rem; }
        .character-card p { font-size: 0.85rem; color: #888; }
        .sequences-list { display: flex; flex-direction: column; gap: 12px; }
        .sequence-item { background: rgba(0,0,0,0.3); padding: 20px; border-radius: 12px; border-left: 4px solid #667eea; }
        .sequence-item h3 { margin-bottom: 4px; }
        .sequence-item p { color: #888; font-size: 0.9rem; }
        @media (max-width: 768px) {
            .characters-grid { grid-template-columns: repeat(2, 1fr); }
            .stats-grid { flex-direction: column; gap: 15px; }
        }
        """
    }
}

// MARK: - Screenplay HTML Generator

private struct ScreenplayHTMLGenerator {
    let project: Project
    
    func generate() -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>\(escapeHTML(project.name)) - Screenplay</title>
            <style>\(getCSS())</style>
        </head>
        <body>
            <div class="screenplay">
                \(buildTitlePage())
                \(buildContent())
            </div>
        </body>
        </html>
        """
    }
    
    private func buildTitlePage() -> String {
        return """
        <div class="title-page">
            <h1>\(escapeHTML(project.name))</h1>
            <p class="author">by \(escapeHTML(project.director))</p>
        </div>
        <div class="page-break"></div>
        """
    }
    
    private func buildContent() -> String {
        var content = ""
        for sequence in project.sequences {
            for scene in sequence.scenes {
                content += buildScene(scene, sequenceLocation: sequence.location)
            }
        }
        return content
    }
    
    private func buildScene(_ scene: Scene, sequenceLocation: String?) -> String {
        let location = scene.location ?? sequenceLocation ?? scene.name
        var sceneHTML = """
        <div class="scene">
            <p class="scene-heading">\(escapeHTML(SceneHeadingFormatter.heading(for: scene, sequenceLocation: sequenceLocation)))</p>
        """
        
        if !scene.description.isEmpty {
            sceneHTML += "<p class=\"action\">\(escapeHTML(scene.description))</p>"
        }
        
        // Collect and sort elements
        var elements: [(Int, String)] = []
        
        for dialogue in scene.dialogues {
            let html = """
            <div class="dialogue-block">
                <p class="character">\(escapeHTML(dialogue.character.uppercased()))</p>
                <p class="dialogue">\(escapeHTML(dialogue.text))</p>
            </div>
            """
            elements.append((dialogue.chronologyNumber, html))
        }
        
        for action in scene.actions {
            let html = "<p class=\"action\">\(escapeHTML(action.description))</p>"
            elements.append((action.chronologyNumber, html))
        }
        
        elements.sort { $0.0 < $1.0 }
        
        for (_, html) in elements {
            sceneHTML += html
        }
        
        sceneHTML += "</div>"
        return sceneHTML
    }
    
    private func getCSS() -> String {
        return """
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            background: white;
            color: black;
            font-family: 'Courier New', Courier, monospace;
            font-size: 12pt;
            line-height: 1.0;
        }
        .screenplay { max-width: 8.5in; margin: 0 auto; padding: 1in; }
        .title-page { height: 9in; display: flex; flex-direction: column; justify-content: center; align-items: center; text-align: center; }
        .title-page h1 { font-size: 24pt; margin-bottom: 24pt; }
        .title-page .author { font-size: 12pt; }
        .page-break { page-break-after: always; }
        .scene { margin-bottom: 24pt; }
        .scene-heading { margin-bottom: 12pt; font-weight: bold; }
        .action { margin-bottom: 12pt; margin-left: 0; margin-right: 0; }
        .dialogue-block { margin-bottom: 12pt; }
        .character { margin-left: 2.5in; margin-bottom: 0; font-weight: bold; }
        .dialogue { margin-left: 1.5in; margin-right: 1.5in; }
        @media print {
            .screenplay { padding: 0; }
            .page-break { page-break-after: always; }
        }
        """
    }
}

// MARK: - Helper Functions

private func escapeHTML(_ string: String) -> String {
    var escaped = string
    escaped = escaped.replacingOccurrences(of: "&", with: "&amp;")
    escaped = escaped.replacingOccurrences(of: "<", with: "&lt;")
    escaped = escaped.replacingOccurrences(of: ">", with: "&gt;")
    escaped = escaped.replacingOccurrences(of: "\"", with: "&quot;")
    escaped = escaped.replacingOccurrences(of: "'", with: "&#39;")
    return escaped
}

// DirectorsChairExports/Sources/DirectorsChairExports/FDX/FDXExportService.swift
//
// Final Draft XML (FDX) Export Service
// Exports project to Final Draft's native XML format

import Foundation
import DirectorsChairCore

/// Service for exporting screenplays to Final Draft XML format
/// FDX is the native format for Final Draft screenwriting software
public struct FDXExportService: Sendable {
    
    // MARK: - Export Methods
    
    /// Export entire project to FDX format
    public static func exportProject(_ project: Project) -> String {
        let generator = FDXGenerator(project: project)
        return generator.generate()
    }
    
    /// Export to file
    public static func exportToFile(_ project: Project, url: URL) throws {
        let content = exportProject(project)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
}

// MARK: - FDX Generator

private struct FDXGenerator {
    let project: Project
    
    func generate() -> String {
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <FinalDraft DocumentType="Script" Template="No" Version="5">
            \(buildHeaderInfo())
            \(buildTitlePage())
            <Content>
                \(buildContent())
            </Content>
            \(buildCastList())
        </FinalDraft>
        """
    }
    
    // MARK: - Header Info
    
    private func buildHeaderInfo() -> String {
        return """
        <HeaderAndFooter>
            <Header/>
            <Footer/>
        </HeaderAndFooter>
        """
    }
    
    // MARK: - Title Page
    
    private func buildTitlePage() -> String {
        return """
        <TitlePage>
            <Content>
                <Paragraph Type="Title Page" Alignment="Center">
                    <Text>\(escapeXML(project.name))</Text>
                </Paragraph>
                <Paragraph Type="Title Page" Alignment="Center">
                    <Text>by</Text>
                </Paragraph>
                <Paragraph Type="Title Page" Alignment="Center">
                    <Text>\(escapeXML(project.director))</Text>
                </Paragraph>
            </Content>
        </TitlePage>
        """
    }
    
    // MARK: - Content
    
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
        var sceneXML = ""
        
        // Scene heading
        let location = scene.location ?? sequenceLocation ?? scene.name
        let heading = "INT. \(location.uppercased()) - DAY"
        sceneXML += buildParagraph(type: "Scene Heading", text: heading)
        
        // Scene description as action
        if !scene.description.isEmpty {
            sceneXML += buildParagraph(type: "Action", text: scene.description)
        }
        
        // Collect and sort all elements by chronology
        var elements: [(Int, String)] = []
        
        for dialogue in scene.dialogues {
            let xml = buildDialogue(dialogue)
            elements.append((dialogue.chronologyNumber, xml))
        }
        
        for action in scene.actions {
            let xml = buildParagraph(type: "Action", text: action.description)
            elements.append((action.chronologyNumber, xml))
        }
        
        for narration in scene.narrations {
            let xml = buildParagraph(type: "Action", text: narration.text)
            elements.append((narration.chronologyNumber, xml))
        }
        
        // Sort by chronology number
        elements.sort { $0.0 < $1.0 }
        
        for (_, xml) in elements {
            sceneXML += xml
        }
        
        return sceneXML
    }
    
    private func buildDialogue(_ dialogue: Dialogue) -> String {
        var xml = ""
        
        // Character name
        xml += buildParagraph(type: "Character", text: dialogue.character.uppercased())
        
        // Parenthetical (if tags exist)
        if !dialogue.tags.isEmpty {
            let parenthetical = dialogue.tags.joined(separator: ", ")
            xml += buildParagraph(type: "Parenthetical", text: "(\(parenthetical))")
        }
        
        // Dialogue text
        xml += buildParagraph(type: "Dialogue", text: dialogue.text)
        
        return xml
    }
    
    private func buildParagraph(type: String, text: String) -> String {
        return """
        <Paragraph Type="\(type)">
            <Text>\(escapeXML(text))</Text>
        </Paragraph>
        """
    }
    
    // MARK: - Cast List
    
    private func buildCastList() -> String {
        var castXML = "<Cast>"
        
        for character in project.characters {
            castXML += """
            <Member>
                <Name>\(escapeXML(character.name))</Name>
            </Member>
            """
        }
        
        castXML += "</Cast>"
        return castXML
    }
}

// MARK: - FDX Element Types

extension FDXExportService {
    /// Standard FDX paragraph types
    public struct FDXElementTypes {
        public static let sceneHeading = "Scene Heading"
        public static let action = "Action"
        public static let character = "Character"
        public static let dialogue = "Dialogue"
        public static let parenthetical = "Parenthetical"
        public static let transition = "Transition"
        public static let shot = "Shot"
        public static let generalText = "General"
    }
}

// MARK: - XML Escaping

private func escapeXML(_ string: String) -> String {
    var escaped = string
    escaped = escaped.replacingOccurrences(of: "&", with: "&amp;")
    escaped = escaped.replacingOccurrences(of: "<", with: "&lt;")
    escaped = escaped.replacingOccurrences(of: ">", with: "&gt;")
    escaped = escaped.replacingOccurrences(of: "\"", with: "&quot;")
    escaped = escaped.replacingOccurrences(of: "'", with: "&apos;")
    return escaped
}

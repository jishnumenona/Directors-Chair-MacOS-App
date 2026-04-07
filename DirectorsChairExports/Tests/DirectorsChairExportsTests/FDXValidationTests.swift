// DirectorsChairExports/Tests/DirectorsChairExportsTests/FDXValidationTests.swift
//
// Tests for Final Draft XML (FDX) export format.
// Validates: well-formed XML, correct root element, paragraph structure,
// character encoding, XML escaping of special characters, and cast list.

import XCTest
@testable import DirectorsChairExports
@testable import DirectorsChairCore

final class FDXValidationTests: XCTestCase {

    // MARK: - Test Data Factory

    /// Creates a project with diverse screenplay content for FDX testing.
    private func makeTestProject() -> Project {
        var project = Project(name: "Midnight Express")
        project.director = "Alex Turner"

        // Characters
        let detective = Character(characterId: "char-det", name: "Detective Mills")
        let suspect = Character(characterId: "char-sus", name: "Sarah Connor")
        project.characters = [detective, suspect]

        // Scene with all element types
        var scene = Scene(name: "Scene 1")
        scene.description = "A stark interrogation room. Fluorescent lights hum overhead."
        scene.location = "INT. INTERROGATION ROOM - NIGHT"

        let action1 = Action(
            uuid: "a1",
            description: "Mills slaps a folder down on the table.",
            chronologyNumber: 0,
            characters: ["Detective Mills"]
        )
        let dialogue1 = Dialogue(
            uuid: "d1",
            character: "Detective Mills",
            text: "Where were you last Tuesday?",
            tags: ["stern"],
            chronologyNumber: 1
        )
        let dialogue2 = Dialogue(
            uuid: "d2",
            character: "Sarah Connor",
            text: "I already told you. I was at home.",
            chronologyNumber: 2
        )
        let narration1 = Narration(
            uuid: "n1",
            text: "The silence stretched between them like a wire about to snap.",
            chronologyNumber: 3
        )
        let action2 = Action(
            uuid: "a2",
            description: "Mills leans forward, his eyes narrowing.",
            chronologyNumber: 4,
            characters: ["Detective Mills"]
        )

        scene.actions = [action1, action2]
        scene.dialogues = [dialogue1, dialogue2]
        scene.narrations = [narration1]

        let sequence = Sequence(uuid: "seq1", name: "Act 1", scenes: [scene])
        project.sequences = [sequence]

        return project
    }

    // MARK: - Well-Formed XML Tests

    func testFDXOutputIsWellFormedXML() {
        let project = makeTestProject()
        let fdx = FDXExportService.exportProject(project)

        // Parse the FDX output with XMLParser to verify well-formedness
        let xmlData = fdx.data(using: .utf8)!
        let parser = XMLParser(data: xmlData)
        let delegate = XMLWellFormednessDelegate()
        parser.delegate = delegate

        let success = parser.parse()

        XCTAssertTrue(success, "FDX output should be well-formed XML. Error: \(delegate.lastError ?? "unknown")")
    }

    func testFDXOutputStartsWithXMLDeclaration() {
        let project = makeTestProject()
        let fdx = FDXExportService.exportProject(project)

        let trimmed = fdx.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(
            trimmed.hasPrefix("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"),
            "FDX should start with XML declaration"
        )
    }

    // MARK: - Root Element Tests

    func testFDXRootElementIsFinalDraft() {
        let project = makeTestProject()
        let fdx = FDXExportService.exportProject(project)

        XCTAssertTrue(fdx.contains("<FinalDraft"), "Root element should be FinalDraft")
        XCTAssertTrue(fdx.contains("</FinalDraft>"), "Should have closing FinalDraft tag")
    }

    func testFDXRootElementHasDocumentTypeAttribute() {
        let project = makeTestProject()
        let fdx = FDXExportService.exportProject(project)

        XCTAssertTrue(
            fdx.contains("DocumentType=\"Script\""),
            "FinalDraft element should have DocumentType=\"Script\""
        )
    }

    func testFDXRootElementHasVersionAttribute() {
        let project = makeTestProject()
        let fdx = FDXExportService.exportProject(project)

        XCTAssertTrue(
            fdx.contains("Version=\"5\""),
            "FinalDraft element should have Version attribute"
        )
    }

    // MARK: - Content Structure Tests

    func testFDXContainsContentElement() {
        let project = makeTestProject()
        let fdx = FDXExportService.exportProject(project)

        XCTAssertTrue(fdx.contains("<Content>"), "Should contain Content element")
        XCTAssertTrue(fdx.contains("</Content>"), "Should have closing Content tag")
    }

    func testFDXContainsHeaderAndFooter() {
        let project = makeTestProject()
        let fdx = FDXExportService.exportProject(project)

        XCTAssertTrue(fdx.contains("<HeaderAndFooter>"), "Should contain HeaderAndFooter element")
        XCTAssertTrue(fdx.contains("<Header/>"), "Should contain Header element")
        XCTAssertTrue(fdx.contains("<Footer/>"), "Should contain Footer element")
    }

    // MARK: - Title Page Tests

    func testFDXContainsTitlePage() {
        let project = makeTestProject()
        let fdx = FDXExportService.exportProject(project)

        XCTAssertTrue(fdx.contains("<TitlePage>"), "Should contain TitlePage element")
        XCTAssertTrue(fdx.contains("</TitlePage>"), "Should have closing TitlePage tag")
    }

    func testFDXTitlePageContainsProjectName() {
        let project = makeTestProject()
        let fdx = FDXExportService.exportProject(project)

        XCTAssertTrue(
            fdx.contains("Midnight Express"),
            "Title page should contain project name"
        )
    }

    func testFDXTitlePageContainsDirector() {
        let project = makeTestProject()
        let fdx = FDXExportService.exportProject(project)

        XCTAssertTrue(
            fdx.contains("Alex Turner"),
            "Title page should contain director name"
        )
    }

    // MARK: - Paragraph Type Tests

    func testFDXContainsSceneHeadingParagraph() {
        let project = makeTestProject()
        let fdx = FDXExportService.exportProject(project)

        XCTAssertTrue(
            fdx.contains("Type=\"Scene Heading\""),
            "Should contain Scene Heading paragraph type"
        )
    }

    func testFDXContainsActionParagraph() {
        let project = makeTestProject()
        let fdx = FDXExportService.exportProject(project)

        XCTAssertTrue(
            fdx.contains("Type=\"Action\""),
            "Should contain Action paragraph type"
        )
    }

    func testFDXContainsCharacterParagraph() {
        let project = makeTestProject()
        let fdx = FDXExportService.exportProject(project)

        XCTAssertTrue(
            fdx.contains("Type=\"Character\""),
            "Should contain Character paragraph type"
        )
    }

    func testFDXContainsDialogueParagraph() {
        let project = makeTestProject()
        let fdx = FDXExportService.exportProject(project)

        XCTAssertTrue(
            fdx.contains("Type=\"Dialogue\""),
            "Should contain Dialogue paragraph type"
        )
    }

    func testFDXContainsParentheticalForTaggedDialogue() {
        let project = makeTestProject()
        let fdx = FDXExportService.exportProject(project)

        // The first dialogue has tag "stern"
        XCTAssertTrue(
            fdx.contains("Type=\"Parenthetical\""),
            "Should contain Parenthetical paragraph for tagged dialogue"
        )
        XCTAssertTrue(
            fdx.contains("(stern)"),
            "Parenthetical should contain the tag text"
        )
    }

    // MARK: - Text Content Tests

    func testFDXContainsSceneHeadingText() {
        let project = makeTestProject()
        let fdx = FDXExportService.exportProject(project)

        // Scene heading should contain the location in uppercase
        XCTAssertTrue(
            fdx.contains("INTERROGATION ROOM"),
            "Scene heading should contain location name uppercase"
        )
    }

    func testFDXContainsCharacterNamesUppercase() {
        let project = makeTestProject()
        let fdx = FDXExportService.exportProject(project)

        XCTAssertTrue(
            fdx.contains("DETECTIVE MILLS"),
            "Character name should be uppercase"
        )
        XCTAssertTrue(
            fdx.contains("SARAH CONNOR"),
            "Character name should be uppercase"
        )
    }

    func testFDXContainsDialogueText() {
        let project = makeTestProject()
        let fdx = FDXExportService.exportProject(project)

        XCTAssertTrue(
            fdx.contains("Where were you last Tuesday?"),
            "Should contain dialogue text"
        )
        XCTAssertTrue(
            fdx.contains("I already told you. I was at home."),
            "Should contain dialogue text"
        )
    }

    func testFDXContainsActionText() {
        let project = makeTestProject()
        let fdx = FDXExportService.exportProject(project)

        XCTAssertTrue(
            fdx.contains("Mills slaps a folder down on the table."),
            "Should contain action text"
        )
    }

    func testFDXContainsNarrationAsAction() {
        let project = makeTestProject()
        let fdx = FDXExportService.exportProject(project)

        // Narration is exported as Action type in FDX
        XCTAssertTrue(
            fdx.contains("The silence stretched between them"),
            "Should contain narration text (exported as Action)"
        )
    }

    func testFDXContainsSceneDescription() {
        let project = makeTestProject()
        let fdx = FDXExportService.exportProject(project)

        XCTAssertTrue(
            fdx.contains("A stark interrogation room. Fluorescent lights hum overhead."),
            "Should contain scene description as action"
        )
    }

    // MARK: - Cast List Tests

    func testFDXContainsCastList() {
        let project = makeTestProject()
        let fdx = FDXExportService.exportProject(project)

        XCTAssertTrue(fdx.contains("<Cast>"), "Should contain Cast element")
        XCTAssertTrue(fdx.contains("</Cast>"), "Should have closing Cast tag")
    }

    func testFDXCastListContainsAllCharacters() {
        let project = makeTestProject()
        let fdx = FDXExportService.exportProject(project)

        XCTAssertTrue(fdx.contains("<Member>"), "Should contain Member elements")
        XCTAssertTrue(fdx.contains("<Name>Detective Mills</Name>"), "Should contain character name")
        XCTAssertTrue(fdx.contains("<Name>Sarah Connor</Name>"), "Should contain character name")
    }

    func testFDXEmptyProjectHasEmptyCastList() {
        let project = Project(name: "No Characters")
        let fdx = FDXExportService.exportProject(project)

        XCTAssertTrue(fdx.contains("<Cast>"), "Should contain Cast element")
        XCTAssertTrue(fdx.contains("</Cast>"), "Should have closing Cast tag")
        XCTAssertFalse(fdx.contains("<Member>"), "Should not contain any Member elements")
    }

    // MARK: - XML Escaping Tests

    func testFDXEscapesAmpersand() {
        var project = Project(name: "Tom & Jerry")
        project.director = "Director & Co"
        let sequence = Sequence(name: "Act 1", scenes: [Scene(name: "Scene 1")])
        project.sequences = [sequence]

        let fdx = FDXExportService.exportProject(project)

        XCTAssertTrue(
            fdx.contains("Tom &amp; Jerry"),
            "Ampersand should be escaped to &amp;"
        )
        XCTAssertTrue(
            fdx.contains("Director &amp; Co"),
            "Ampersand in director should be escaped"
        )
    }

    func testFDXEscapesAngleBrackets() {
        var project = Project(name: "Test")
        project.director = "Test"
        var scene = Scene(name: "Scene 1")
        scene.location = "Room"
        let action = Action(
            description: "He reads the sign: <DANGER> Keep Out",
            chronologyNumber: 0
        )
        scene.actions = [action]
        let sequence = Sequence(name: "Act 1", scenes: [scene])
        project.sequences = [sequence]

        let fdx = FDXExportService.exportProject(project)

        XCTAssertTrue(
            fdx.contains("&lt;DANGER&gt;"),
            "Angle brackets should be escaped to &lt; and &gt;"
        )
    }

    func testFDXEscapesQuotes() {
        var project = Project(name: "Test")
        project.director = "Test"
        var scene = Scene(name: "Scene 1")
        scene.location = "Room"
        let dialogue = Dialogue(
            character: "Bob",
            text: "She said \"hello\" to me.",
            chronologyNumber: 0
        )
        scene.dialogues = [dialogue]
        let sequence = Sequence(name: "Act 1", scenes: [scene])
        project.sequences = [sequence]

        let fdx = FDXExportService.exportProject(project)

        XCTAssertTrue(
            fdx.contains("&quot;hello&quot;"),
            "Quotes should be escaped to &quot;"
        )
    }

    func testFDXEscapesApostrophe() {
        var project = Project(name: "Test")
        project.director = "Test"
        var scene = Scene(name: "Scene 1")
        scene.location = "Room"
        let dialogue = Dialogue(
            character: "Bob",
            text: "It's a beautiful day.",
            chronologyNumber: 0
        )
        scene.dialogues = [dialogue]
        let sequence = Sequence(name: "Act 1", scenes: [scene])
        project.sequences = [sequence]

        let fdx = FDXExportService.exportProject(project)

        XCTAssertTrue(
            fdx.contains("It&apos;s a beautiful day."),
            "Apostrophe should be escaped to &apos;"
        )
    }

    func testFDXEscapesCharacterNameInCastList() {
        var project = Project(name: "Test")
        let character = Character(name: "O'Malley & Sons")
        project.characters = [character]

        let fdx = FDXExportService.exportProject(project)

        XCTAssertTrue(
            fdx.contains("O&apos;Malley &amp; Sons"),
            "Character name in cast list should have escaped special characters"
        )
    }

    // MARK: - Paragraph Structure Tests

    func testFDXParagraphHasTextChild() {
        let project = makeTestProject()
        let fdx = FDXExportService.exportProject(project)

        // Every Paragraph should have a Text child
        XCTAssertTrue(fdx.contains("<Text>"), "Paragraphs should contain Text elements")
        XCTAssertTrue(fdx.contains("</Text>"), "Text elements should have closing tags")
    }

    func testFDXElementsInChronologicalOrder() {
        let project = makeTestProject()
        let fdx = FDXExportService.exportProject(project)

        // In scene 1, order should be:
        // Scene Heading
        // Action (scene description)
        // Action (Mills slaps)
        // Character + Dialogue (detective's line)
        // Character + Dialogue (Sarah's line)
        // Action (narration)
        // Action (Mills leans forward)

        let sceneHeadingPos = fdx.range(of: "INTERROGATION ROOM")!.lowerBound
        let action1Pos = fdx.range(of: "Mills slaps a folder")!.lowerBound
        let dialogue1Pos = fdx.range(of: "Where were you last Tuesday?")!.lowerBound
        let dialogue2Pos = fdx.range(of: "I already told you")!.lowerBound

        XCTAssertTrue(sceneHeadingPos < action1Pos)
        XCTAssertTrue(action1Pos < dialogue1Pos)
        XCTAssertTrue(dialogue1Pos < dialogue2Pos)
    }

    // MARK: - Empty / Edge Case Tests

    func testFDXEmptyProjectProducesValidXML() {
        let project = Project(name: "Empty")
        let fdx = FDXExportService.exportProject(project)

        let xmlData = fdx.data(using: .utf8)!
        let parser = XMLParser(data: xmlData)
        let delegate = XMLWellFormednessDelegate()
        parser.delegate = delegate

        let success = parser.parse()
        XCTAssertTrue(success, "Empty project FDX should still be well-formed XML")
    }

    func testFDXProjectWithEmptyScenesProducesValidXML() {
        var project = Project(name: "Minimal")
        let scene = Scene(name: "Empty Scene")
        let sequence = Sequence(name: "Act 1", scenes: [scene])
        project.sequences = [sequence]

        let fdx = FDXExportService.exportProject(project)

        let xmlData = fdx.data(using: .utf8)!
        let parser = XMLParser(data: xmlData)
        let delegate = XMLWellFormednessDelegate()
        parser.delegate = delegate

        let success = parser.parse()
        XCTAssertTrue(success, "Minimal project FDX should be well-formed XML")
    }

    func testFDXProjectWithOnlyDialogueProducesValidXML() {
        var project = Project(name: "Dialogue Only")
        var scene = Scene(name: "Scene 1")
        scene.location = "INT. ROOM - DAY"
        scene.dialogues = [
            Dialogue(character: "Alice", text: "Line one.", chronologyNumber: 0),
            Dialogue(character: "Bob", text: "Line two.", chronologyNumber: 1)
        ]
        let sequence = Sequence(name: "Act 1", scenes: [scene])
        project.sequences = [sequence]

        let fdx = FDXExportService.exportProject(project)

        let xmlData = fdx.data(using: .utf8)!
        let parser = XMLParser(data: xmlData)
        let delegate = XMLWellFormednessDelegate()
        parser.delegate = delegate

        let success = parser.parse()
        XCTAssertTrue(success, "Dialogue-only project FDX should be well-formed XML")
    }

    // MARK: - Multiple Scenes/Sequences

    func testFDXMultipleScenesAllIncluded() {
        var project = Project(name: "Multi Scene")
        let scene1 = Scene(name: "Scene 1", location: "INT. OFFICE - DAY")
        let scene2 = Scene(name: "Scene 2", location: "EXT. PARK - NIGHT")
        let sequence = Sequence(name: "Act 1", scenes: [scene1, scene2])
        project.sequences = [sequence]

        let fdx = FDXExportService.exportProject(project)

        // Both scene locations should appear as scene headings
        XCTAssertTrue(fdx.contains("OFFICE"))
        XCTAssertTrue(fdx.contains("PARK"))
    }

    func testFDXMultipleSequencesAllIncluded() {
        var project = Project(name: "Multi Seq")
        let scene1 = Scene(name: "S1", location: "INT. ROOM A - DAY")
        let scene2 = Scene(name: "S2", location: "INT. ROOM B - NIGHT")
        let seq1 = Sequence(name: "Act 1", scenes: [scene1])
        let seq2 = Sequence(name: "Act 2", scenes: [scene2])
        project.sequences = [seq1, seq2]

        let fdx = FDXExportService.exportProject(project)

        XCTAssertTrue(fdx.contains("ROOM A"))
        XCTAssertTrue(fdx.contains("ROOM B"))
    }

    // MARK: - FDX Element Types Constants

    func testFDXElementTypeConstants() {
        XCTAssertEqual(FDXExportService.FDXElementTypes.sceneHeading, "Scene Heading")
        XCTAssertEqual(FDXExportService.FDXElementTypes.action, "Action")
        XCTAssertEqual(FDXExportService.FDXElementTypes.character, "Character")
        XCTAssertEqual(FDXExportService.FDXElementTypes.dialogue, "Dialogue")
        XCTAssertEqual(FDXExportService.FDXElementTypes.parenthetical, "Parenthetical")
        XCTAssertEqual(FDXExportService.FDXElementTypes.transition, "Transition")
        XCTAssertEqual(FDXExportService.FDXElementTypes.shot, "Shot")
        XCTAssertEqual(FDXExportService.FDXElementTypes.generalText, "General")
    }

    // MARK: - UTF-8 Encoding

    func testFDXOutputIsValidUTF8() {
        let project = makeTestProject()
        let fdx = FDXExportService.exportProject(project)

        XCTAssertNotNil(fdx.data(using: .utf8), "FDX output should be valid UTF-8")
    }

    func testFDXDeclaresUTF8Encoding() {
        let project = makeTestProject()
        let fdx = FDXExportService.exportProject(project)

        XCTAssertTrue(
            fdx.contains("encoding=\"UTF-8\""),
            "XML declaration should specify UTF-8 encoding"
        )
    }

    // MARK: - XML Parsing With Content Extraction

    func testFDXParsedContentMatchesExpected() {
        let project = makeTestProject()
        let fdx = FDXExportService.exportProject(project)

        let xmlData = fdx.data(using: .utf8)!
        let parser = XMLParser(data: xmlData)
        let delegate = FDXContentExtractionDelegate()
        parser.delegate = delegate

        _ = parser.parse()

        // Verify paragraphs were found with expected types
        XCTAssertTrue(
            delegate.paragraphTypes.contains("Scene Heading"),
            "Parsed XML should contain Scene Heading paragraphs"
        )
        XCTAssertTrue(
            delegate.paragraphTypes.contains("Action"),
            "Parsed XML should contain Action paragraphs"
        )
        XCTAssertTrue(
            delegate.paragraphTypes.contains("Character"),
            "Parsed XML should contain Character paragraphs"
        )
        XCTAssertTrue(
            delegate.paragraphTypes.contains("Dialogue"),
            "Parsed XML should contain Dialogue paragraphs"
        )

        // Verify text content was extracted
        XCTAssertTrue(delegate.textContents.count > 0, "Should have extracted text content")
    }
}

// MARK: - XML Parser Delegates

/// Delegate that simply tracks whether XML parsing succeeds (well-formedness check).
private class XMLWellFormednessDelegate: NSObject, XMLParserDelegate {
    var lastError: String?

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        lastError = parseError.localizedDescription
    }

    func parser(_ parser: XMLParser, validationErrorOccurred validationError: Error) {
        lastError = validationError.localizedDescription
    }
}

/// Delegate that extracts paragraph types and text contents from FDX XML.
private class FDXContentExtractionDelegate: NSObject, XMLParserDelegate {
    var paragraphTypes: [String] = []
    var textContents: [String] = []
    private var currentElement: String = ""
    private var currentText: String = ""
    private var isInText: Bool = false

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName

        if elementName == "Paragraph", let type = attributeDict["Type"] {
            paragraphTypes.append(type)
        }

        if elementName == "Text" {
            isInText = true
            currentText = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isInText {
            currentText += string
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if elementName == "Text" {
            isInText = false
            let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                textContents.append(trimmed)
            }
        }
    }
}

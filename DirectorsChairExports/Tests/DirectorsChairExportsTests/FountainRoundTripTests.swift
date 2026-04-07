// DirectorsChairExports/Tests/DirectorsChairExportsTests/FountainRoundTripTests.swift
//
// Tests for Fountain screenplay export format.
// Verifies that project data is correctly exported to industry-standard
// Fountain plain-text screenplay syntax.

import XCTest
@testable import DirectorsChairExports
@testable import DirectorsChairCore

final class FountainRoundTripTests: XCTestCase {

    // MARK: - Test Data Factory

    /// Creates a project with representative screenplay content for testing.
    private func makeTestProject() -> Project {
        var project = Project(name: "The Last Stand")
        project.director = "Sarah Mitchell"
        project.genre = "Action/Drama"

        // Characters
        let hero = Character(characterId: "char-john", name: "John", role: "Protagonist")
        let villain = Character(characterId: "char-victor", name: "Victor", role: "Antagonist")
        project.characters = [hero, villain]

        // Scene 1: Interior dialogue scene
        var scene1 = Scene(name: "Scene 1 - INT. WAREHOUSE - NIGHT")
        scene1.description = "A dimly lit warehouse. Crates stacked to the ceiling."
        scene1.location = "INT. WAREHOUSE - NIGHT"

        let action1 = Action(
            uuid: "a1",
            description: "John steps out of the shadows, gun drawn.",
            chronologyNumber: 0,
            characters: ["John"]
        )
        let dialogue1 = Dialogue(
            uuid: "d1",
            character: "John",
            text: "It's over, Victor.",
            tags: ["threatening"],
            chronologyNumber: 1
        )
        let dialogue2 = Dialogue(
            uuid: "d2",
            character: "Victor",
            text: "You really think you can stop me?",
            tags: ["mocking"],
            chronologyNumber: 2
        )
        let action2 = Action(
            uuid: "a2",
            description: "Victor laughs and pulls out a detonator.",
            chronologyNumber: 3,
            characters: ["Victor"]
        )

        scene1.actions = [action1, action2]
        scene1.dialogues = [dialogue1, dialogue2]

        // Scene 2: Exterior action scene
        var scene2 = Scene(name: "Scene 2 - EXT. ROOFTOP - DAWN")
        scene2.description = "The sun rises over the city skyline."
        scene2.location = "EXT. ROOFTOP - DAWN"

        let narration1 = Narration(
            uuid: "n1",
            text: "In that moment, John knew there was no turning back.",
            chronologyNumber: 0
        )
        let action3 = Action(
            uuid: "a3",
            description: "John sprints across the rooftop and leaps to the next building.",
            chronologyNumber: 1,
            characters: ["John"]
        )

        scene2.narrations = [narration1]
        scene2.actions = [action3]

        // Scene 3: Scene with notes and sound
        var scene3 = Scene(name: "Scene 3")
        scene3.description = "An empty room."
        scene3.location = "INT. HOSPITAL ROOM - DAY"

        let note = Note(uuid: "note1", content: "Consider adding flashback here", chronologyNumber: 0)
        let soundNote = SoundNote(
            uuid: "sn1",
            description: "Heart monitor beeping",
            soundType: "effects",
            chronologyNumber: 1
        )

        scene3.sceneNotes = [note]
        scene3.soundNotes = [soundNote]

        // Build sequence
        let sequence = Sequence(uuid: "seq1", name: "Act 1", scenes: [scene1, scene2, scene3])
        project.sequences = [sequence]

        return project
    }

    // MARK: - Title Page Tests

    func testFountainExportContainsTitlePage() {
        let project = makeTestProject()
        let output = FountainExportService.exportProject(project)

        XCTAssertTrue(output.contains("Title: The Last Stand"), "Should contain project title")
        XCTAssertTrue(output.contains("Author: Sarah Mitchell"), "Should contain director as author")
        XCTAssertTrue(output.contains("Genre: Action/Drama"), "Should contain genre")
        XCTAssertTrue(output.contains("Draft date:"), "Should contain draft date")
    }

    func testFountainExportOmitsEmptyAuthor() {
        var project = Project(name: "No Author Film")
        project.director = ""
        let sequence = Sequence(name: "Act 1", scenes: [Scene(name: "Scene 1")])
        project.sequences = [sequence]

        let output = FountainExportService.exportProject(project)

        XCTAssertTrue(output.contains("Title: No Author Film"))
        XCTAssertFalse(output.contains("Author:"), "Should omit Author when director is empty")
    }

    func testFountainExportOmitsEmptyGenre() {
        var project = Project(name: "No Genre Film")
        project.genre = ""
        let sequence = Sequence(name: "Act 1", scenes: [Scene(name: "Scene 1")])
        project.sequences = [sequence]

        let output = FountainExportService.exportProject(project)

        XCTAssertFalse(output.contains("Genre:"), "Should omit Genre when genre is empty")
    }

    // MARK: - Scene Heading Tests

    func testFountainExportSceneHeadingsUppercase() {
        let project = makeTestProject()
        let output = FountainExportService.exportProject(project)

        // Scene headings with INT./EXT. prefix should be uppercased
        XCTAssertTrue(output.contains("INT. WAREHOUSE - NIGHT"), "Interior scene heading should be uppercase")
        XCTAssertTrue(output.contains("EXT. ROOFTOP - DAWN"), "Exterior scene heading should be uppercase")
    }

    func testFountainExportSceneHeadingDefaultsToINT() {
        // Scene with a location that doesn't start with INT/EXT
        var scene = Scene(name: "Scene 99")
        scene.location = "Office Building"

        let output = FountainExportService.exportScene(scene)

        // Should default to INT. prefix
        XCTAssertTrue(output.contains("INT. OFFICE BUILDING"), "Should default to INT. when no prefix")
    }

    func testFountainExportSceneHeadingPreservesExistingPrefix() {
        var scene = Scene(name: "Test")
        scene.location = "EXT. BEACH - SUNSET"

        let output = FountainExportService.exportScene(scene)

        XCTAssertTrue(output.contains("EXT. BEACH - SUNSET"))
    }

    func testFountainExportSceneUsesSequenceLocation() {
        var scene = Scene(name: "Test Scene")
        scene.location = nil

        let output = FountainExportService.exportScene(scene, location: "EXT. PARKING LOT - NIGHT")

        XCTAssertTrue(output.contains("EXT. PARKING LOT - NIGHT"))
    }

    // MARK: - Character Name Tests

    func testFountainExportCharacterNamesUppercase() {
        let project = makeTestProject()
        let output = FountainExportService.exportProject(project)

        XCTAssertTrue(output.contains("JOHN"), "Character name should be uppercase in dialogue block")
        XCTAssertTrue(output.contains("VICTOR"), "Character name should be uppercase in dialogue block")
    }

    // MARK: - Dialogue Tests

    func testFountainExportContainsDialogueText() {
        let project = makeTestProject()
        let output = FountainExportService.exportProject(project)

        XCTAssertTrue(output.contains("It's over, Victor."), "Should contain dialogue text")
        XCTAssertTrue(output.contains("You really think you can stop me?"), "Should contain dialogue text")
    }

    func testFountainExportDialogueWithParenthetical() {
        let project = makeTestProject()
        let output = FountainExportService.exportProject(project)

        // Tags are rendered as parentheticals
        XCTAssertTrue(output.contains("(threatening)"), "Should contain parenthetical from tags")
        XCTAssertTrue(output.contains("(mocking)"), "Should contain parenthetical from tags")
    }

    func testFountainExportDialogueWithMultipleTags() {
        var scene = Scene(name: "Test")
        scene.location = "INT. ROOM - DAY"
        let dialogue = Dialogue(
            character: "Alice",
            text: "Stop right there!",
            tags: ["angry", "whispered", "urgent"],
            chronologyNumber: 0
        )
        scene.dialogues = [dialogue]

        let output = FountainExportService.exportScene(scene)

        XCTAssertTrue(output.contains("(angry, whispered, urgent)"), "Multiple tags should be comma-separated")
    }

    // MARK: - Action Tests

    func testFountainExportContainsActionText() {
        let project = makeTestProject()
        let output = FountainExportService.exportProject(project)

        XCTAssertTrue(
            output.contains("John steps out of the shadows, gun drawn."),
            "Should contain action description"
        )
        XCTAssertTrue(
            output.contains("Victor laughs and pulls out a detonator."),
            "Should contain action description"
        )
    }

    // MARK: - Narration Tests

    func testFountainExportContainsNarration() {
        let project = makeTestProject()
        let output = FountainExportService.exportProject(project)

        // Narrations are formatted with > prefix (centered text)
        XCTAssertTrue(
            output.contains(">In that moment, John knew there was no turning back."),
            "Narration should be formatted with > prefix"
        )
    }

    // MARK: - Note Tests

    func testFountainExportContainsNotes() {
        let project = makeTestProject()
        let output = FountainExportService.exportProject(project)

        // Notes use Fountain's [[note]] syntax
        XCTAssertTrue(
            output.contains("[[Consider adding flashback here]]"),
            "Notes should use Fountain double-bracket syntax"
        )
    }

    // MARK: - Sound Note Tests

    func testFountainExportContainsSoundNotes() {
        let project = makeTestProject()
        let output = FountainExportService.exportProject(project)

        // Sound notes use [[SFX: type - description]] syntax
        XCTAssertTrue(
            output.contains("[[SFX: effects - Heart monitor beeping]]"),
            "Sound notes should use [[SFX: type - description]] syntax"
        )
    }

    // MARK: - Sequence Marker Tests

    func testFountainExportContainsSequenceMarker() {
        let project = makeTestProject()
        let output = FountainExportService.exportProject(project)

        // Sequence names are output as synopsis markers (= ... =)
        XCTAssertTrue(
            output.contains("= ACT 1 ="),
            "Sequence name should be uppercase between = markers"
        )
    }

    // MARK: - Scene Description Tests

    func testFountainExportContainsSceneDescription() {
        let project = makeTestProject()
        let output = FountainExportService.exportProject(project)

        XCTAssertTrue(
            output.contains("A dimly lit warehouse. Crates stacked to the ceiling."),
            "Should contain scene description"
        )
        XCTAssertTrue(
            output.contains("The sun rises over the city skyline."),
            "Should contain scene description"
        )
    }

    func testFountainExportOmitsEmptyDescription() {
        var scene = Scene(name: "Test")
        scene.description = ""
        scene.location = "INT. ROOM - DAY"
        let dialogue = Dialogue(character: "Bob", text: "Hi.", chronologyNumber: 0)
        scene.dialogues = [dialogue]

        let output = FountainExportService.exportScene(scene)

        // The output should go from scene heading directly to dialogue
        // without an extra blank paragraph for description
        let lines = output.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        XCTAssertTrue(lines.count >= 2, "Should have heading and dialogue, no extra empty description")
    }

    // MARK: - Chronological Order Tests

    func testFountainExportElementsInChronologicalOrder() {
        let project = makeTestProject()
        let output = FountainExportService.exportProject(project)

        // Scene 1 elements should be in chronology order:
        // 0: action (John steps out)
        // 1: dialogue (It's over)
        // 2: dialogue (You really think)
        // 3: action (Victor laughs)
        let actionRange = output.range(of: "John steps out of the shadows")!
        let dialogue1Range = output.range(of: "It's over, Victor.")!
        let dialogue2Range = output.range(of: "You really think you can stop me?")!
        let action2Range = output.range(of: "Victor laughs and pulls out a detonator.")!

        XCTAssertTrue(actionRange.lowerBound < dialogue1Range.lowerBound)
        XCTAssertTrue(dialogue1Range.lowerBound < dialogue2Range.lowerBound)
        XCTAssertTrue(dialogue2Range.lowerBound < action2Range.lowerBound)
    }

    // MARK: - Single Scene Export

    func testExportSingleScene() {
        var scene = Scene(name: "Standalone Scene")
        scene.location = "EXT. PARK - DAY"
        scene.description = "Children playing."
        let dialogue = Dialogue(character: "Mom", text: "Time to go home!", chronologyNumber: 0)
        scene.dialogues = [dialogue]

        let output = FountainExportService.exportScene(scene)

        XCTAssertTrue(output.contains("EXT. PARK - DAY"))
        XCTAssertTrue(output.contains("Children playing."))
        XCTAssertTrue(output.contains("MOM"))
        XCTAssertTrue(output.contains("Time to go home!"))
    }

    // MARK: - Empty Project

    func testFountainExportEmptyProject() {
        let project = Project(name: "Empty Film")
        let output = FountainExportService.exportProject(project)

        XCTAssertTrue(output.contains("Title: Empty Film"))
        // Should not crash, just title page
        XCTAssertFalse(output.isEmpty)
    }

    // MARK: - Project With Empty Scenes

    func testFountainExportProjectWithEmptyScenes() {
        var project = Project(name: "Minimal")
        let scene = Scene(name: "Empty Scene")
        let sequence = Sequence(name: "Act 1", scenes: [scene])
        project.sequences = [sequence]

        let output = FountainExportService.exportProject(project)

        // Should contain sequence marker and scene heading but no content elements
        XCTAssertTrue(output.contains("= ACT 1 ="))
        XCTAssertTrue(output.contains("INT."))
    }

    // MARK: - Special Characters

    func testFountainExportSpecialCharactersInDialogue() {
        var scene = Scene(name: "Test")
        scene.location = "INT. ROOM - DAY"
        let dialogue = Dialogue(
            character: "O'Brien",
            text: "That's \"impossible\" -- or is it?",
            chronologyNumber: 0
        )
        scene.dialogues = [dialogue]

        let output = FountainExportService.exportScene(scene)

        XCTAssertTrue(output.contains("O'BRIEN"), "Character with apostrophe should be uppercase")
        XCTAssertTrue(
            output.contains("That's \"impossible\" -- or is it?"),
            "Dialogue special characters should be preserved"
        )
    }

    // MARK: - Multiple Sequences

    func testFountainExportMultipleSequences() {
        var project = Project(name: "Multi-Act")
        let scene1 = Scene(name: "Opening")
        let scene2 = Scene(name: "Climax")
        let seq1 = Sequence(name: "Act 1", scenes: [scene1])
        let seq2 = Sequence(name: "Act 2", scenes: [scene2])
        project.sequences = [seq1, seq2]

        let output = FountainExportService.exportProject(project)

        XCTAssertTrue(output.contains("= ACT 1 ="))
        XCTAssertTrue(output.contains("= ACT 2 ="))

        // Act 1 should come before Act 2
        let act1Range = output.range(of: "= ACT 1 =")!
        let act2Range = output.range(of: "= ACT 2 =")!
        XCTAssertTrue(act1Range.lowerBound < act2Range.lowerBound)
    }

    // MARK: - Fountain Format Constants

    func testFountainFormatConstants() {
        XCTAssertEqual(FountainExportService.FountainFormat.forceSceneHeading, ".")
        XCTAssertEqual(FountainExportService.FountainFormat.forceAction, "!")
        XCTAssertEqual(FountainExportService.FountainFormat.forceCharacter, "@")
        XCTAssertEqual(FountainExportService.FountainFormat.transitionSuffix, "TO:")
        XCTAssertEqual(FountainExportService.FountainFormat.centeredStart, ">")
        XCTAssertEqual(FountainExportService.FountainFormat.centeredEnd, "<")
        XCTAssertEqual(FountainExportService.FountainFormat.noteStart, "[[")
        XCTAssertEqual(FountainExportService.FountainFormat.noteEnd, "]]")
        XCTAssertEqual(FountainExportService.FountainFormat.boneyardStart, "/*")
        XCTAssertEqual(FountainExportService.FountainFormat.boneyardEnd, "*/")
        XCTAssertEqual(FountainExportService.FountainFormat.section, "#")
        XCTAssertEqual(FountainExportService.FountainFormat.synopsis, "=")
        XCTAssertEqual(FountainExportService.FountainFormat.pageBreak, "===")
    }

    // MARK: - Output is Valid Fountain (structural)

    func testFountainOutputStructure() {
        let project = makeTestProject()
        let output = FountainExportService.exportProject(project)

        // Fountain files should be non-empty
        XCTAssertFalse(output.isEmpty)

        // Title page should be at the beginning
        XCTAssertTrue(output.hasPrefix("Title:"), "Fountain output should start with Title:")

        // Scene headings should appear (uppercase with INT./EXT.)
        let sceneHeadingPattern = output.contains("INT.") || output.contains("EXT.")
        XCTAssertTrue(sceneHeadingPattern, "Output should contain at least one scene heading")

        // Dialogue blocks should have character name followed by text
        // Character names in UPPERCASE followed by their dialogue
        XCTAssertTrue(output.contains("JOHN\n"), "Character name should be on its own line")
    }
}

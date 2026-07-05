// DirectorsChairExports/Tests/DirectorsChairExportsTests/VectorPDFTests.swift
//
// WS8.6: verifies the PDF export produces real vector text (selectable /
// searchable), not rasterised page images. A bitmap-backed PDF returns no
// extractable text; a vector PDF returns the strings we drew.

import XCTest
import PDFKit
@testable import DirectorsChairExports
@testable import DirectorsChairCore

@MainActor
final class VectorPDFTests: XCTestCase {

    private func makeProject() -> Project {
        var project = Project(name: "Test Movie")
        project.director = "Test Author"

        var character = Character(name: "John Doe")
        character.role = "Protagonist"
        character.age = 35
        project.characters.append(character)

        var sequence = Sequence(name: "Act 1")
        var scene = Scene(name: "Opening")
        scene.description = "The story begins."
        scene.location = "Coffee Shop"
        scene.dialogues.append(Dialogue(character: "John Doe", text: "Hello, world!", chronologyNumber: 1))
        scene.actions.append(Action(description: "John walks through the door.", chronologyNumber: 0))
        sequence.scenes.append(scene)
        project.sequences.append(sequence)
        return project
    }

    // MARK: - Screenplay

    func testScreenplayPDFHasSelectableVectorText() throws {
        let project = makeProject()
        let pdf = try XCTUnwrap(PDFExportService.exportScreenplay(project), "screenplay PDF should generate")

        XCTAssertGreaterThanOrEqual(pdf.pageCount, 2, "title page + at least one content page")

        let text = pdf.string ?? ""
        // The decisive check: a rasterised (image) PDF yields no extractable
        // text at all. Vector text yields the drawn strings.
        XCTAssertFalse(text.isEmpty, "PDF must contain extractable vector text, not a bitmap")
        XCTAssertTrue(text.contains("Test Movie"), "title should be selectable text; got: \(text.prefix(200))")
        XCTAssertTrue(text.contains("JOHN DOE"), "character cue should be selectable text")
        XCTAssertTrue(text.contains("Hello, world!"), "dialogue should be selectable text")
    }

    func testScreenplayPDFIsSearchable() throws {
        let pdf = try XCTUnwrap(PDFExportService.exportScreenplay(makeProject()))
        // PDFKit search only works on real text — proves it's not an image.
        let matches = pdf.findString("Hello, world!", withOptions: [])
        XCTAssertFalse(matches.isEmpty, "dialogue must be findable via PDF text search")
    }

    // MARK: - Character sheet

    func testCharacterSheetPDFHasSelectableVectorText() throws {
        let project = makeProject()
        let character = try XCTUnwrap(project.characters.first)
        let pdf = try XCTUnwrap(PDFExportService.exportCharacterSheet(character, project: project))

        let text = pdf.string ?? ""
        XCTAssertFalse(text.isEmpty, "character sheet must contain vector text")
        XCTAssertTrue(text.contains("John Doe"), "name should be selectable text")
        XCTAssertTrue(text.contains("Quick Facts"), "section headers should be selectable text")
    }

    // MARK: - Round-trip through file

    func testSavedPDFRetainsVectorText() throws {
        let pdf = try XCTUnwrap(PDFExportService.exportScreenplay(makeProject()))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("dc-vec-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertTrue(PDFExportService.saveToFile(pdf, url: url), "PDF should save")
        let reloaded = try XCTUnwrap(PDFDocument(url: url), "saved PDF should reload")
        XCTAssertTrue((reloaded.string ?? "").contains("Test Movie"),
                      "text must survive a save/reload round-trip")
    }
}

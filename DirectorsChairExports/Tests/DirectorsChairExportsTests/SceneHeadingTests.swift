// DirectorsChairExports/Tests/DirectorsChairExportsTests/SceneHeadingTests.swift
//
// WS8.5: scene headings must reflect the scene's real INT/EXT + time-of-day
// across all four exporters (previously PDF/HTML/FDX hardcoded "INT. … - DAY",
// so night/exterior scenes exported wrong).

import XCTest
@testable import DirectorsChairExports
@testable import DirectorsChairCore

@MainActor
final class SceneHeadingTests: XCTestCase {

    private func project(location: String) -> Project {
        var project = Project(name: "Heading Test")
        project.director = "Author"
        var scene = Scene(name: "S1")
        scene.location = location
        scene.dialogues.append(Dialogue(character: "A", text: "Hi.", chronologyNumber: 1))
        var seq = Sequence(name: "Act 1")
        seq.scenes.append(scene)
        project.sequences.append(seq)
        return project
    }

    // MARK: - Formatter unit behaviour

    func testFormatterHonoursExteriorAndNight() {
        var scene = Scene(name: "S")
        scene.location = "EXT. BEACH - NIGHT"
        XCTAssertEqual(SceneHeadingFormatter.heading(for: scene), "EXT. BEACH - NIGHT")
    }

    func testFormatterDefaultsIntDayWhenAbsent() {
        var scene = Scene(name: "S")
        scene.location = "Coffee Shop"
        XCTAssertEqual(SceneHeadingFormatter.heading(for: scene), "INT. COFFEE SHOP - DAY")
    }

    func testFormatterKeepsIntPrefixAddsDay() {
        var scene = Scene(name: "S")
        scene.location = "INT. OFFICE"
        XCTAssertEqual(SceneHeadingFormatter.heading(for: scene), "INT. OFFICE - DAY")
    }

    func testFormatterKeepsTimeOfDayAddsInt() {
        var scene = Scene(name: "S")
        scene.location = "WAREHOUSE - DUSK"
        XCTAssertEqual(SceneHeadingFormatter.heading(for: scene), "INT. WAREHOUSE - DUSK")
    }

    // MARK: - All four exporters honour EXT / NIGHT

    func testExportersHonourExteriorNight() throws {
        let p = project(location: "EXT. ROOFTOP - NIGHT")

        let fountain = FountainExportService.exportProject(p)
        XCTAssertTrue(fountain.contains("EXT. ROOFTOP - NIGHT"), "Fountain")
        XCTAssertFalse(fountain.contains("EXT. ROOFTOP - NIGHT - DAY"), "Fountain must not double-append DAY")

        let fdx = FDXExportService.exportProject(p)
        XCTAssertTrue(fdx.contains("EXT. ROOFTOP - NIGHT"), "FDX")
        XCTAssertFalse(fdx.contains("INT. EXT. ROOFTOP"), "FDX must not double-prefix INT")

        let html = HTMLExportService.exportScreenplay(p)
        XCTAssertTrue(html.contains("EXT. ROOFTOP - NIGHT"), "HTML")

        let pdf = try XCTUnwrap(PDFExportService.exportScreenplay(p))
        let pdfText = pdf.string ?? ""
        XCTAssertTrue(pdfText.contains("EXT. ROOFTOP - NIGHT"), "PDF text: \(pdfText.prefix(200))")
    }

    func testExportersDefaultBareLocation() throws {
        let p = project(location: "Coffee Shop")
        XCTAssertTrue(FountainExportService.exportProject(p).contains("INT. COFFEE SHOP - DAY"))
        XCTAssertTrue(FDXExportService.exportProject(p).contains("INT. COFFEE SHOP - DAY"))
        XCTAssertTrue(HTMLExportService.exportScreenplay(p).contains("INT. COFFEE SHOP - DAY"))
    }
}

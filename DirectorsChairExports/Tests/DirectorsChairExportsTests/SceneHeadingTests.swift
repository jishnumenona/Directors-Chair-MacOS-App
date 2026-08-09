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

// MARK: - Script revisions on the slug line (§2.18)

final class RevisionHeadingTests: XCTestCase {

    private func lockedProject() -> Project {
        var scene = Scene(name: "Night Market")
        scene.location = "EXT. NIGHT MARKET - NIGHT"
        scene.lockedNumber = "22A"
        scene.revisionColor = "Blue"
        var project = Project(name: "Rev")
        project.sequences = [Sequence(name: "Act 1", scenes: [scene])]
        project.scriptRevisionColor = "Blue"
        return project
    }

    func testFountainCarriesTheSceneNumberInSpecSyntax() {
        let fountain = FountainExportService.exportProject(lockedProject())
        XCTAssertTrue(fountain.contains("EXT. NIGHT MARKET - NIGHT #22A#"),
                      "Fountain's scene-number syntax is #N# after the slug")
    }

    func testProductionStyleShowsNumberAndCurrentRevisionAsterisk() {
        let project = lockedProject()
        let scene = project.sequences[0].scenes[0]

        let current = SceneHeadingFormatter.decoratedHeading(
            for: scene, style: .production, currentColor: "Blue")
        XCTAssertEqual(current, "22A  EXT. NIGHT MARKET - NIGHT *",
                       "a scene changed in the CURRENT round wears the mark")

        let older = SceneHeadingFormatter.decoratedHeading(
            for: scene, style: .production, currentColor: "Pink")
        XCTAssertEqual(older, "22A  EXT. NIGHT MARKET - NIGHT",
                       "a Blue change on Pink pages keeps its number, "
                       + "loses the asterisk — that is how reprints read")
    }

    func testUnlockedScenesExportExactlyAsBefore() {
        var scene = Scene(name: "Free Scene")
        scene.location = "INT. KITCHEN - DAY"
        let plain = SceneHeadingFormatter.decoratedHeading(
            for: scene, style: .production, currentColor: nil)
        XCTAssertEqual(plain, "INT. KITCHEN - DAY",
                       "no lock, no numbers — a working draft is untouched")
        let fountain = SceneHeadingFormatter.decoratedHeading(
            for: scene, style: .fountain, currentColor: nil)
        XCTAssertEqual(fountain, "INT. KITCHEN - DAY")
    }

    func testWhiteIsTheLockedBaseNotARevision() {
        var scene = Scene(name: "S")
        scene.location = "INT. A - DAY"
        scene.lockedNumber = "3"
        scene.revisionColor = "White"
        let heading = SceneHeadingFormatter.decoratedHeading(
            for: scene, style: .production, currentColor: "White")
        XCTAssertEqual(heading, "3  INT. A - DAY",
                       "White pages carry numbers but never asterisks")
    }
}

//
//  EditorialInterchangeTests.swift
//
//  Interchange files are read by OTHER software: character-exact
//  formats, tested to the character. The FCPXML additionally has to
//  survive a real XML parser, because "looks like XML" and "parses" are
//  different claims.
//

import XCTest
import DirectorsChairCore
@testable import DirectorsChairExports

final class EditorialInterchangeTests: XCTestCase {

    private func sampleProject() -> Project {
        var shot1 = Shot(shotId: 1)
        shot1.shotType = "WIDE"
        shot1.duration = 6.5
        shot1.description = "Harbor at dawn, boats leaving"
        var shot2 = Shot(shotId: 2)
        shot2.shotType = "CU"
        shot2.duration = 0          // unusable — falls through the chain
        var scene1 = DirectorsChairCore.Scene(name: "Scene 1")
        scene1.location = "EXT. FISHING HARBOR - DAWN"
        scene1.description = "Boats leave, and Meera decides"
        scene1.shots = [shot1, shot2]
        var scene2 = DirectorsChairCore.Scene(name: "Scene 2")
        scene2.location = "INT. TEA SHOP - DAY"
        scene2.shots = []
        var sequence = Sequence(name: "Act One")
        sequence.scenes = [scene1, scene2]
        var project = Project(name: "Backwater & Tide")
        project.sequences = [sequence]
        return project
    }

    // MARK: - Timing

    func testTimecodeIsFrameExact() {
        XCTAssertEqual(EditorialInterchange.timecode(seconds: 0, fps: 24),
                       "00:00:00:00")
        XCTAssertEqual(EditorialInterchange.timecode(seconds: 3600, fps: 24),
                       "01:00:00:00")
        XCTAssertEqual(
            EditorialInterchange.timecode(seconds: 6.5, fps: 24),
            "00:00:06:12", "half a second at 24fps is exactly 12 frames")
    }

    func testDurationResolutionFallsThroughTheChain() {
        var shot = Shot(shotId: 9)
        XCTAssertEqual(EditorialInterchange.resolvedSeconds(for: shot), 4,
                       "a skeleton cut needs SOME length")
        var take = Take(takeNumber: 1)
        take.startTimestamp = Date(timeIntervalSince1970: 100)
        take.endTimestamp = Date(timeIntervalSince1970: 108)
        shot.takes = [take]
        XCTAssertEqual(EditorialInterchange.resolvedSeconds(for: shot), 8,
                       "a measured take beats the slug default")
        shot.duration = 5
        XCTAssertEqual(EditorialInterchange.resolvedSeconds(for: shot), 5,
                       "the shot's own estimate beats everything")
    }

    // MARK: - EDL

    func testEDLIsACutSkeletonWithContinuousRecordTimes() {
        let edl = EditorialInterchange.edl(project: sampleProject())
        let lines = edl.components(separatedBy: "\n")

        XCTAssertEqual(lines[0], "TITLE: BACKWATER & TIDE")
        XCTAssertEqual(lines[1], "FCM: NON-DROP FRAME")

        let events = lines.filter {
            $0.range(of: #"^\d{3}  "#, options: .regularExpression) != nil
        }
        XCTAssertEqual(events.count, 2)
        XCTAssertTrue(events[0].hasPrefix("001  SH1"))
        // First record-in is the habitual first hour; the second event
        // starts exactly where the first ended: 6.5s = 6:12 at 24fps.
        XCTAssertTrue(events[0].contains("01:00:00:00 01:00:06:12"),
                      "record range wrong in: \(events[0])")
        XCTAssertTrue(events[1].contains("01:00:06:12 01:00:10:12"),
                      "the cut must be continuous: \(events[1])")

        XCTAssertTrue(edl.contains(
            "* FROM CLIP NAME: Scene 1 - SHOT 1 (WIDE)"))
        XCTAssertTrue(edl.contains(
            "* COMMENT: HARBOR AT DAWN, BOATS LEAVING"))
    }

    // MARK: - FCPXML

    func testFCPXMLSurvivesARealXMLParserAndCarriesTheCut() throws {
        let xml = EditorialInterchange.fcpxml(project: sampleProject())
        let document = try XMLDocument(data: Data(xml.utf8))

        let titles = try document.nodes(forXPath: "//title")
        XCTAssertEqual(titles.count, 2)

        let names = try document.nodes(forXPath: "//title/@name")
            .compactMap(\.stringValue)
        XCTAssertEqual(names.first, "Scene 1 - SHOT 1 (WIDE)")

        // The ampersand in the project name must arrive escaped-then-
        // unescaped, not explode the parser.
        let event = try document.nodes(forXPath: "//event/@name")
            .first?.stringValue
        XCTAssertEqual(event, "Backwater & Tide")

        // Offsets tile the spine with no gaps: 6.5s @ 24fps = 156
        // frames = 15600 on the ×100 clock.
        let offsets = try document.nodes(forXPath: "//title/@offset")
            .compactMap(\.stringValue)
        XCTAssertEqual(offsets, ["0/2400s", "15600/2400s"])
    }

    // MARK: - Stripboard

    func testStripboardReadsLikeAnADsBoard() {
        let csv = EditorialInterchange.stripboardCSV(project: sampleProject())
        let rows = csv.components(separatedBy: "\r\n")

        XCTAssertTrue(rows[0].hasPrefix("Strip,Sequence,Scene,"))
        XCTAssertTrue(rows[1].contains("EXT"))
        XCTAssertTrue(rows[1].contains("FISHING HARBOR"))
        XCTAssertTrue(rows[1].contains("DAWN"))
        XCTAssertTrue(rows[1].contains("\"Boats leave, and Meera decides\""),
                      "a synopsis with a comma must be quoted: \(rows[1])")
        // 6.5s + 4s fallback = 10.5s = 0.2 minutes.
        XCTAssertTrue(rows[1].contains(",2,0.2,"),
                      "shot count and estimated minutes: \(rows[1])")
    }

    func testHeadingParserToleratesRealWorldSlugs() {
        let parsed = EditorialInterchange.parseHeading("INT./EXT. CAR - NIGHT")
        XCTAssertEqual(parsed.intExt, "INT/EXT")
        XCTAssertEqual(parsed.set, "CAR")
        XCTAssertEqual(parsed.time, "NIGHT")

        let bare = EditorialInterchange.parseHeading("ROOFTOP")
        XCTAssertEqual(bare.set, "ROOFTOP")
        XCTAssertEqual(bare.intExt, "")
        XCTAssertEqual(bare.time, "", "unknowns stay empty, never invented")

        XCTAssertEqual(EditorialInterchange.parseHeading(nil).set, "")
    }

    func testCSVEscapingIsRFC4180() {
        XCTAssertEqual(EditorialInterchange.csvField("plain"), "plain")
        XCTAssertEqual(EditorialInterchange.csvField("a,b"), "\"a,b\"")
        XCTAssertEqual(EditorialInterchange.csvField("say \"cut\""),
                       "\"say \"\"cut\"\"\"")
    }

    func testAnEmptyProjectProducesValidEmptyDocuments() throws {
        let empty = Project(name: "Empty")
        let edl = EditorialInterchange.edl(project: empty)
        XCTAssertTrue(edl.hasPrefix("TITLE: EMPTY"))
        _ = try XMLDocument(data: Data(
            EditorialInterchange.fcpxml(project: empty).utf8))
        let csv = EditorialInterchange.stripboardCSV(project: empty)
        XCTAssertEqual(csv.components(separatedBy: "\r\n").count, 2,
                       "header plus trailing newline, nothing invented")
    }
}

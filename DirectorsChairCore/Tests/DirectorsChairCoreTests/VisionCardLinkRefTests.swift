// Tests/DirectorsChairCoreTests/VisionCardLinkRefTests.swift
//
// What travels from the outline to the wall. The whole point of using a
// URI rather than bare text is that the board can tell a dragged SHOT
// from the dragged word "shot" — so most of what matters here is what
// must NOT parse.

import XCTest
@testable import DirectorsChairCore

final class VisionCardLinkRefTests: XCTestCase {

    func testASceneSurvivesTheTrip() throws {
        let sent = VisionCardLinkRef(kind: .scene, id: "scene-7",
                                     label: "Scene 3")
        let received = try XCTUnwrap(VisionCardLinkRef.parse(sent.dragText))
        XCTAssertEqual(received, sent)
    }

    func testAShotCarriesItsSceneWithIt() throws {
        let sent = VisionCardLinkRef(kind: .shot, id: "shot-2",
                                     label: "SHOT 4B", sceneId: "scene-7")
        let received = try XCTUnwrap(VisionCardLinkRef.parse(sent.dragText))
        XCTAssertEqual(received.sceneId, "scene-7",
                       "linking a shot must also say which scene it is in")
        XCTAssertEqual(received, sent)
    }

    func testLabelsWithSpacesAndPunctuationComeBackIntact() throws {
        let sent = VisionCardLinkRef(kind: .scene, id: "s1",
                                     label: "Scene 12 — INT. KITCHEN / DAY")
        let received = try XCTUnwrap(VisionCardLinkRef.parse(sent.dragText))
        XCTAssertEqual(received.label, "Scene 12 — INT. KITCHEN / DAY")
    }

    // MARK: - Everything that must stay text

    func testOrdinaryWordsAreNotALink() {
        // Dropping a line of writing on the wall must keep making a word
        // clipping, not silently link something.
        XCTAssertNil(VisionCardLinkRef.parse("shot"))
        XCTAssertNil(VisionCardLinkRef.parse("scene 4 is the one"))
        XCTAssertNil(VisionCardLinkRef.parse(""))
    }

    func testOtherURLsAreNotALink() {
        XCTAssertNil(VisionCardLinkRef.parse("https://example.com/scene/7"))
        XCTAssertNil(VisionCardLinkRef.parse("file:///tmp/shot.png"))
    }

    func testOurSchemeWithAnUnknownKindIsNotALink() {
        XCTAssertNil(VisionCardLinkRef.parse("dcref://character/7?label=Ana"),
                     "only scenes and shots pin to elements today")
    }

    func testOurSchemeWithNoIdIsNotALink() {
        XCTAssertNil(VisionCardLinkRef.parse("dcref://scene/?label=x"))
        XCTAssertNil(VisionCardLinkRef.parse("dcref://scene"))
    }

    func testSurroundingWhitespaceIsForgiven() throws {
        let text = "  " + VisionCardLinkRef(kind: .scene, id: "s1",
                                            label: "Scene 1").dragText + "\n"
        XCTAssertNotNil(VisionCardLinkRef.parse(text))
    }

    func testALinkWithoutALabelFallsBackToItsId() throws {
        let received = try XCTUnwrap(VisionCardLinkRef.parse("dcref://scene/s9"))
        XCTAssertEqual(received.label, "s9", "better than an unlabelled tab")
    }

    // MARK: - The card that holds it

    func testABoardSavedBeforeLinksStillOpens() throws {
        let legacy = """
        {"id":"c1","title":"","description":"","text":"","tags":[],
         "props":[],"costumes":[],"effects":[],"position":0,
         "cardType":"image","boardId":"master","colorPalette":[],
         "pinned":false,"size":"medium","zOrder":0,"textColor":"#FFFFFF",
         "imagePaths":[]}
        """.data(using: .utf8)!
        let card = try JSONDecoder().decode(VisionCard.self, from: legacy)
        XCTAssertNil(card.linkedSceneId)
        XCTAssertNil(card.linkedShotId)
        XCTAssertNil(card.linkedLabel)
    }

    func testALinkSurvivesSaveAndReload() throws {
        var card = VisionCard()
        card.linkedShotId = "shot-2"
        card.linkedSceneId = "scene-7"
        card.linkedLabel = "SHOT 4B"

        let data = try JSONEncoder().encode(card)
        let reloaded = try JSONDecoder().decode(VisionCard.self, from: data)

        XCTAssertEqual(reloaded.linkedShotId, "shot-2")
        XCTAssertEqual(reloaded.linkedSceneId, "scene-7")
        XCTAssertEqual(reloaded.linkedLabel, "SHOT 4B")
    }
}

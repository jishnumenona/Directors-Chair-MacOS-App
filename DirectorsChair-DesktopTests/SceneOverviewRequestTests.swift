// DirectorsChair-DesktopTests/SceneOverviewRequestTests.swift
//
// DC-0082: the scene preview's request carries the scene's full likeness
// the way shot previews do — and a scene with no references sends exactly
// the plain request it always sent.

import XCTest
@testable import DirectorsChair_Desktop
@testable import DirectorsChairCore
@testable import DirectorsChairServices
@testable import DirectorsChairViews

final class SceneOverviewRequestTests: XCTestCase {

    private let brief = VisualBrief(purpose: .scene, subject: "A cottage kitchen at dawn")

    func testWithoutReferencesTheRequestIsThePlainOne() {
        let request = SceneCardHelpers.overviewRequest(
            prompt: "Cinematic film still, kitchen", references: [], provider: .googleImagen, brief: brief)
        XCTAssertEqual(request.prompt, "Cinematic film still, kitchen", "no prefix without pictures")
        XCTAssertNil(request.referenceImages)
        XCTAssertNil(request.referenceImageBase64)
        XCTAssertEqual(request.aspectRatio, "16:9")
        XCTAssertEqual(request.numberOfImages, 1)
        XCTAssertEqual(request.provider, .googleImagen)
        XCTAssertEqual(request.brief, brief)
    }

    func testWithReferencesThePromptExplainsEachPictureAndTheSetRidesAlong() {
        let references = [
            ReferenceImage(base64: "AAA", mimeType: "image/png", label: "location:Cottage kitchen"),
            ReferenceImage(base64: "BBB", mimeType: "image/png", label: "character:Mara"),
            ReferenceImage(base64: "CCC", mimeType: "image/png", label: "prop:Storm Lantern"),
        ]
        let request = SceneCardHelpers.overviewRequest(
            prompt: "Cinematic film still, kitchen", references: references, provider: .googleImagen, brief: brief)
        XCTAssertTrue(request.prompt.hasSuffix("Cinematic film still, kitchen"), "the scene prompt stays last")
        XCTAssertTrue(request.prompt.contains("Image 1 is the LOCATION (Cottage kitchen)"), request.prompt)
        XCTAssertTrue(request.prompt.contains("Image 2 is character Mara"), request.prompt)
        XCTAssertTrue(request.prompt.contains("Image 3 is the prop \"Storm Lantern\""), request.prompt)
        XCTAssertEqual(request.referenceImages?.map(\.label),
                       ["location:Cottage kitchen", "character:Mara", "prop:Storm Lantern"], "order kept")
        XCTAssertNil(request.referenceImageBase64, "the labelled set replaces the single legacy picture")
        XCTAssertEqual(request.brief?.purpose, .scene)
    }
}

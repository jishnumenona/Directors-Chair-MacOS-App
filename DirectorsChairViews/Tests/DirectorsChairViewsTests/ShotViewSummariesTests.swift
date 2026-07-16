// ShotViewSummariesTests.swift
//
// Collapsed cards in the Shots view stay glanceable through live one-line
// summaries — the summary text is pure and tested here.

import XCTest
@testable import DirectorsChairViews
@testable import DirectorsChairCore

final class ShotViewSummariesTests: XCTestCase {

    func testCameraSummaryFull() {
        var shot = Shot(shotId: 1)
        shot.shotType = "MS"
        shot.cameraAngle = "Eye Level"
        shot.lensMm = 50
        shot.aperture = "f/2.8"
        shot.movement = "Dolly In"
        shot.duration = 5.0
        XCTAssertEqual(ShotViewSummaries.camera(for: shot), "MS · Eye Level · 50mm f/2.8 · Dolly In · 5.0s")
    }

    func testCameraSummaryOmitsStaticMovementAndMissingOptionals() {
        var shot = Shot(shotId: 1)
        shot.shotType = "CU"
        shot.cameraAngle = "Low"
        shot.lensMm = nil
        shot.aperture = "f/4"
        shot.movement = "Static"
        shot.duration = nil
        XCTAssertEqual(ShotViewSummaries.camera(for: shot), "CU · Low · f/4")
    }

    func testContextSummary() {
        XCTAssertEqual(ShotViewSummaries.context(characterCount: 2, location: "Warehouse",
                                                 propCount: 1, soundCount: 0),
                       "2 characters · Warehouse · 1 prop")
        XCTAssertEqual(ShotViewSummaries.context(characterCount: 1, location: nil,
                                                 propCount: 0, soundCount: 2),
                       "1 character · no location · 2 sounds")
    }

    func testKeyframeAndReferenceSummaries() {
        XCTAssertEqual(ShotViewSummaries.keyframes(withImages: 2, total: 3), "2 of 3 frames set")
        XCTAssertEqual(ShotViewSummaries.references(selected: 0), "none selected")
        XCTAssertEqual(ShotViewSummaries.references(selected: 2), "2 of 3 selected")
    }

    func testLookLightingSummary() {
        XCTAssertEqual(ShotViewSummaries.lookLighting(styleName: "Film Noir", timeOfDay: "Night",
                                                      weather: nil, keyMood: "Low-key"),
                       "Film Noir · Night · Low-key")
        XCTAssertEqual(ShotViewSummaries.lookLighting(styleName: nil, timeOfDay: nil,
                                                      weather: nil, keyMood: nil),
                       "defaults")
    }

    func testMotionSummary() {
        XCTAssertEqual(ShotViewSummaries.motion(cameraMotion: "Dolly In", speed: "Slow"), "Slow Dolly In")
        XCTAssertEqual(ShotViewSummaries.motion(cameraMotion: "Pan Left", speed: "Normal"), "Pan Left")
    }

    func testAdvancedSummary() {
        XCTAssertEqual(ShotViewSummaries.advanced(quality: "High", aspectRatio: "16:9",
                                                  subjectMotion: "Static", hasNegativePrompt: false),
                       "High · 16:9")
        XCTAssertEqual(ShotViewSummaries.advanced(quality: "Ultra", aspectRatio: "9:16",
                                                  subjectMotion: "Walking", hasNegativePrompt: true),
                       "Ultra · 9:16 · subject: walking · negative prompt set")
    }
}

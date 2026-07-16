// VideoReferenceSelectionTests.swift
//
// The consistency-reference tray connects Story Design assets to video
// generation: default pick priority and the time-of-day-aware location
// image preference are pure logic, tested here.

import XCTest
@testable import DirectorsChairViews
@testable import DirectorsChairServices

final class VideoReferenceSelectionTests: XCTestCase {

    private func candidate(_ id: String, _ source: VideoReferenceCandidate.Source) -> VideoReferenceCandidate {
        VideoReferenceCandidate(id: id, source: source, displayName: id,
                                reference: ReferenceImage(base64: "QQ==", label: id))
    }

    // MARK: - Default selection priority

    func testDefaultSelectionPrioritizesKeyframesThenCharactersThenCostumesThenLocation() {
        let candidates = [
            candidate("loc", .location),
            candidate("char1", .character),
            candidate("cost1", .costume),
            candidate("kf1", .keyframe),
            candidate("char2", .character),
        ]
        XCTAssertEqual(VideoReferenceCandidate.defaultSelection(from: candidates),
                       ["kf1", "char1", "char2"])
    }

    func testDefaultSelectionFillsUpWithLowerPrioritySources() {
        let candidates = [candidate("loc", .location), candidate("kf1", .keyframe)]
        XCTAssertEqual(VideoReferenceCandidate.defaultSelection(from: candidates),
                       ["kf1", "loc"])
    }

    func testDefaultSelectionRespectsLimit() {
        let candidates = (1...5).map { candidate("kf\($0)", .keyframe) }
        XCTAssertEqual(VideoReferenceCandidate.defaultSelection(from: candidates, limit: 2),
                       ["kf1", "kf2"])
    }

    func testDefaultSelectionEmptyForNoCandidates() {
        XCTAssertTrue(VideoReferenceCandidate.defaultSelection(from: []).isEmpty)
    }

    // MARK: - Time-of-day-aware location image preference

    func testLocationPatternsPreferSceneTimeOfDay() {
        let patterns = CharacterReferenceHelper.locationImagePatterns(timeOfDay: "Golden Hour")
        XCTAssertEqual(patterns.first, "golden_hour")
        XCTAssertTrue(patterns.contains("primary"), "generic fallbacks remain")
    }

    func testLocationPatternsDedupeWhenTimeOfDayMatchesDefault() {
        let patterns = CharacterReferenceHelper.locationImagePatterns(timeOfDay: "Day")
        XCTAssertEqual(patterns.first, "day")
        XCTAssertEqual(patterns.filter { $0 == "day" }.count, 1)
    }

    func testLocationPatternsDefaultWithoutTimeOfDay() {
        XCTAssertEqual(CharacterReferenceHelper.locationImagePatterns(timeOfDay: nil).first, "primary")
        XCTAssertEqual(CharacterReferenceHelper.locationImagePatterns(timeOfDay: "  ").first, "primary")
    }
}

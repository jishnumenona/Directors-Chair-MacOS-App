// VideoReferenceSelectionTests.swift
//
// The consistency-reference tray connects Story Design assets to video
// generation: default pick priority and the time-of-day-aware location
// image preference are pure logic, tested here.

import XCTest
import AppKit
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

    // MARK: - Veo slot discipline (collages first, third slot free)

    func testDefaultSelectionPrefersCollagesLeavingThirdSlotFree() {
        let candidates = [
            candidate("kf1", .keyframe),
            candidate("chars", .characterCollage),
            candidate("loc", .locationCollage),
            candidate("media", .custom),
        ]
        XCTAssertEqual(VideoReferenceCandidate.defaultSelection(from: candidates),
                       ["chars", "loc"],
                       "collages fill slots 1–2; slot 3 stays free for the director")
    }

    // MARK: - Reference preamble

    func testPromptPreambleDescribesEachReferenceInOrder() {
        let selected = [
            VideoReferenceCandidate(id: "c", source: .characterCollage, displayName: "Alex, Maya",
                                    reference: ReferenceImage(base64: "QQ==", label: "characters")),
            VideoReferenceCandidate(id: "l", source: .locationCollage, displayName: "Warehouse + crowbar",
                                    reference: ReferenceImage(base64: "QQ==", label: "location")),
            candidate("kf", .keyframe),
        ]
        let preamble = VideoReferenceCandidate.promptPreamble(for: selected)
        XCTAssertTrue(preamble.contains("3 reference image(s)"))
        XCTAssertTrue(preamble.contains("Image 1 is a collage of the characters in this shot (Alex, Maya)"))
        XCTAssertTrue(preamble.contains("Image 2 is a collage of the location and its props (Warehouse + crowbar)"))
        XCTAssertTrue(preamble.contains("Image 3 is a mid-shot keyframe"))
    }

    func testPromptPreambleEmptyWithoutReferences() {
        XCTAssertTrue(VideoReferenceCandidate.promptPreamble(for: []).isEmpty)
    }

    // MARK: - Collage composition

    func testCollageGridDimensions() {
        XCTAssertEqual(ReferenceCollageBuilder.gridDimensions(for: 1).columns, 1)
        XCTAssertEqual(ReferenceCollageBuilder.gridDimensions(for: 2).columns, 2)
        XCTAssertEqual(ReferenceCollageBuilder.gridDimensions(for: 2).rows, 1)
        XCTAssertEqual(ReferenceCollageBuilder.gridDimensions(for: 3).columns, 2)
        XCTAssertEqual(ReferenceCollageBuilder.gridDimensions(for: 3).rows, 2)
        XCTAssertEqual(ReferenceCollageBuilder.gridDimensions(for: 5).columns, 3)
        XCTAssertEqual(ReferenceCollageBuilder.gridDimensions(for: 5).rows, 2)
        XCTAssertEqual(ReferenceCollageBuilder.gridDimensions(for: 9).columns, 3)
        XCTAssertEqual(ReferenceCollageBuilder.gridDimensions(for: 9).rows, 3)
    }

    private func solidImage(width: CGFloat, height: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        image.unlockFocus()
        return image
    }

    func testCollageComposition() {
        XCTAssertNil(ReferenceCollageBuilder.collage([]))

        let single = solidImage(width: 100, height: 60)
        XCTAssertIdentical(ReferenceCollageBuilder.collage([single]), single,
                           "a single image needs no collaging")

        let two = ReferenceCollageBuilder.collage(
            [solidImage(width: 100, height: 60), solidImage(width: 50, height: 80)],
            maxDimension: 200)
        XCTAssertEqual(two?.size.width, 200, "two images → 2 columns of 100pt cells")
        XCTAssertEqual(two?.size.height, 100, "two images → 1 row")
        XCTAssertNotNil(two.flatMap { ReferenceCollageBuilder.encodePNG($0) },
                        "collage must be wire-encodable")
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

// VideoPlayerCardTests.swift
//
// The preview player sizes itself to the clip's real display aspect ratio
// (natural size × preferred transform) instead of a fixed letterboxed frame.

import XCTest
import CoreGraphics
@testable import DirectorsChairViews

final class VideoPlayerCardTests: XCTestCase {

    func testLandscapeAspectRatio() {
        let aspect = VideoPlayerCard.displayAspectRatio(
            naturalSize: CGSize(width: 1920, height: 1080),
            preferredTransform: .identity)
        XCTAssertEqual(aspect ?? 0, 16.0 / 9.0, accuracy: 0.001)
    }

    func testPortraitAspectRatio() {
        let aspect = VideoPlayerCard.displayAspectRatio(
            naturalSize: CGSize(width: 1080, height: 1920),
            preferredTransform: .identity)
        XCTAssertEqual(aspect ?? 0, 9.0 / 16.0, accuracy: 0.001)
    }

    func testRotationTransformSwapsAxes() {
        // Portrait clips are often stored landscape with a 90° rotation in
        // metadata; the display aspect must honor the transform.
        let rotated = CGAffineTransform(rotationAngle: .pi / 2)
        let aspect = VideoPlayerCard.displayAspectRatio(
            naturalSize: CGSize(width: 1920, height: 1080),
            preferredTransform: rotated)
        XCTAssertEqual(aspect ?? 0, 9.0 / 16.0, accuracy: 0.001)
    }

    func testDegenerateSizeReturnsNil() {
        XCTAssertNil(VideoPlayerCard.displayAspectRatio(
            naturalSize: .zero, preferredTransform: .identity))
        XCTAssertNil(VideoPlayerCard.displayAspectRatio(
            naturalSize: CGSize(width: 1920, height: 0), preferredTransform: .identity))
    }
}

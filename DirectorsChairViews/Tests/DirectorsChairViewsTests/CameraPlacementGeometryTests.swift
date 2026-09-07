// CameraPlacementGeometryTests.swift
//
// DC-0129: the one mapping between a fitted picture and the camera's
// fractions — identical on the desktop and the iPad.

import XCTest
import DirectorsChairCore
@testable import DirectorsChairViews

final class CameraPlacementGeometryTests: XCTestCase {

    func testFittedRectCentresTheLetterboxedPicture() {
        let rect = CameraPlacementGeometry.fittedRect(imageSize: CGSize(width: 1920, height: 1080),
                                                      in: CGSize(width: 800, height: 800))
        XCTAssertEqual(rect.width, 800, accuracy: 0.001)
        XCTAssertEqual(rect.height, 450, accuracy: 0.001)
        XCTAssertEqual(rect.minY, 175, accuracy: 0.001, "centred vertically")
        XCTAssertEqual(CameraPlacementGeometry.fittedRect(imageSize: .zero, in: CGSize(width: 10, height: 10)), .zero)
    }

    func testFractionsRoundTripThroughViewPointsAndClamp() {
        let rect = CGRect(x: 100, y: 50, width: 400, height: 225)
        let placement = CameraPlacement(basePicture: "p.png", x: 0.25, y: 0.8, targetX: 0.9, targetY: 0.1)
        let c = CameraPlacementGeometry.camera(placement, in: rect)
        XCTAssertEqual(c.x, 200, accuracy: 0.001); XCTAssertEqual(c.y, 230, accuracy: 0.001)
        let back = CameraPlacementGeometry.fraction(of: c, in: rect)
        XCTAssertEqual(back.x, 0.25, accuracy: 1e-9); XCTAssertEqual(back.y, 0.8, accuracy: 1e-9)
        let outside = CameraPlacementGeometry.fraction(of: CGPoint(x: -50, y: 900), in: rect)
        XCTAssertEqual(outside.x, 0); XCTAssertEqual(outside.y, 1, "a point off the picture clamps to its edge")
    }

    func testHandleHitTestingPrefersTheCamera() {
        let rect = CGRect(x: 0, y: 0, width: 1000, height: 500)
        let placement = CameraPlacement(basePicture: "p.png", x: 0.5, y: 0.5, targetX: 0.9, targetY: 0.5)
        XCTAssertEqual(CameraPlacementGeometry.handle(at: CGPoint(x: 505, y: 255), placement: placement, in: rect), .camera)
        XCTAssertEqual(CameraPlacementGeometry.handle(at: CGPoint(x: 890, y: 250), placement: placement, in: rect), .target)
        XCTAssertNil(CameraPlacementGeometry.handle(at: CGPoint(x: 100, y: 100), placement: placement, in: rect))
        XCTAssertNil(CameraPlacementGeometry.handle(at: CGPoint(x: 500, y: 250), placement: nil, in: rect))
    }
}

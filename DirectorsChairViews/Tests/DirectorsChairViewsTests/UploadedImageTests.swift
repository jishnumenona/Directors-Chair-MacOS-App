//
//  UploadedImageTests.swift
//  Custom-image upload pipeline: normalization rejects non-images, converts
//  everything decodable to PNG; writePNG creates the assets tree and returns
//  the model-storable relative path.
//

import AppKit
import XCTest
@testable import DirectorsChairViews

final class UploadedImageTests: XCTestCase {

    private func makeImageData(type: NSBitmapImageRep.FileType) -> Data {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 8, pixelsHigh: 6,
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                   isPlanar: false, colorSpaceName: .deviceRGB,
                                   bytesPerRow: 0, bitsPerPixel: 0)!
        return rep.representation(using: type, properties: [:])!
    }

    func testNormalizesJPEGToPNG() {
        let jpeg = makeImageData(type: .jpeg)
        let png = UploadedImage.normalizedPNG(from: jpeg)
        XCTAssertNotNil(png)
        // PNG magic bytes
        XCTAssertEqual(png!.prefix(4), Data([0x89, 0x50, 0x4E, 0x47]))
        XCTAssertNotNil(NSImage(data: png!))
    }

    func testPassesThroughPNGAsValidPNG() {
        let input = makeImageData(type: .png)
        let png = UploadedImage.normalizedPNG(from: input)
        XCTAssertNotNil(png)
        XCTAssertEqual(png!.prefix(4), Data([0x89, 0x50, 0x4E, 0x47]))
    }

    func testRejectsNonImageData() {
        XCTAssertNil(UploadedImage.normalizedPNG(from: Data("not an image".utf8)))
        XCTAssertNil(UploadedImage.normalizedPNG(from: Data()))
    }

    func testWritePNGCreatesTreeAndReturnsRelativePath() throws {
        let projectDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("uploaded-image-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: projectDir) }

        let png = UploadedImage.normalizedPNG(from: makeImageData(type: .png))!
        let relative = try UploadedImage.writePNG(
            png, projectBasePath: projectDir,
            relativeDirectory: "assets/scenes/test_scene",
            filename: "overview_latest.png")

        XCTAssertEqual(relative, "assets/scenes/test_scene/overview_latest.png")
        let written = projectDir.appendingPathComponent(relative)
        XCTAssertTrue(FileManager.default.fileExists(atPath: written.path))
        XCTAssertEqual(try Data(contentsOf: written), png)

        // Overwrite is allowed (replacing a previous upload/generation)
        XCTAssertNoThrow(try UploadedImage.writePNG(
            png, projectBasePath: projectDir,
            relativeDirectory: "assets/scenes/test_scene",
            filename: "overview_latest.png"))
    }

    func testHistoryTimestampMatchesConvention() {
        let ts = UploadedImage.historyTimestamp(now: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(ts.count, 15)          // yyyyMMdd_HHmmss
        XCTAssertTrue(ts.contains("_"))
    }
}

// DirectorsChair-DesktopTests/ChatVisionContextTests.swift
//
// AI Assistant program, Phase A0.3: the chat vision-context helpers —
// selected-entity image resolution (priority order) and the bounded
// JPEG re-encode that rides the chat request.

import XCTest
import AppKit
@testable import DirectorsChair_Desktop
@testable import DirectorsChairCore

final class ChatVisionContextTests: XCTestCase {

    // MARK: - imagePath priority

    func testNoContextOrNoImagesYieldsNil() {
        XCTAssertNil(ChatVisionContext.imagePath(for: nil))
        let empty = AIChatContext(currentView: .overview)
        XCTAssertNil(ChatVisionContext.imagePath(for: empty))
    }

    func testShotPreviewWinsOverSceneAndCharacter() {
        var shot = Shot(shotId: 1)
        shot.previewImage = "assets/shots/shot_1/latest.png"
        var scene = Scene(name: "Opening")
        scene.sceneOverviewImage = "assets/scenes/opening/overview.png"
        let context = AIChatContext(currentView: .shotList,
                                    selectedScene: scene,
                                    selectedShot: shot)
        XCTAssertEqual(ChatVisionContext.imagePath(for: context),
                       "assets/shots/shot_1/latest.png")
    }

    func testSceneImageUsedWhenShotHasNone() {
        var scene = Scene(name: "Opening")
        scene.sceneOverviewImage = "assets/scenes/opening/overview.png"
        let context = AIChatContext(currentView: .scenes,
                                    selectedScene: scene,
                                    selectedShot: Shot(shotId: 2))
        XCTAssertEqual(ChatVisionContext.imagePath(for: context),
                       "assets/scenes/opening/overview.png")
    }

    func testCharacterFallsBackFromBaseImageToFront() {
        var character = Character(name: "Mara")
        character.imageFront = "assets/characters/Mara/face/front.png"
        let context = AIChatContext(currentView: .storyDesign,
                                    selectedCharacter: character)
        XCTAssertEqual(ChatVisionContext.imagePath(for: context),
                       "assets/characters/Mara/face/front.png")
    }

    func testEmptyPathTreatedAsAbsent() {
        var shot = Shot(shotId: 3)
        shot.previewImage = ""
        let context = AIChatContext(currentView: .shotList, selectedShot: shot)
        XCTAssertNil(ChatVisionContext.imagePath(for: context))
    }

    // MARK: - downscaledJPEGBase64

    private func writeTemporaryPNG(width: Int, height: Int) throws -> URL {
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSColor.systemTeal.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        NSGraphicsContext.restoreGraphicsState()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("chat-vision-\(UUID().uuidString).png")
        try bitmap.representation(using: .png, properties: [:])!.write(to: url)
        return url
    }

    func testDownscaleBoundsLongestSideAndProducesDecodableJPEG() throws {
        let url = try writeTemporaryPNG(width: 1600, height: 900)
        defer { try? FileManager.default.removeItem(at: url) }

        let base64 = ChatVisionContext.downscaledJPEGBase64(at: url, maxDimension: 512)
        let data = try XCTUnwrap(Data(base64Encoded: try XCTUnwrap(base64)))
        let decoded = try XCTUnwrap(NSBitmapImageRep(data: data))
        XCTAssertLessThanOrEqual(max(decoded.pixelsWide, decoded.pixelsHigh), 512)
        XCTAssertEqual(decoded.pixelsWide, 512, "16:9 source downscales to 512 wide")
    }

    func testSmallImagesAreNotUpscaled() throws {
        let url = try writeTemporaryPNG(width: 100, height: 80)
        defer { try? FileManager.default.removeItem(at: url) }

        let base64 = ChatVisionContext.downscaledJPEGBase64(at: url, maxDimension: 512)
        let data = try XCTUnwrap(Data(base64Encoded: try XCTUnwrap(base64)))
        let decoded = try XCTUnwrap(NSBitmapImageRep(data: data))
        XCTAssertEqual(decoded.pixelsWide, 100)
        XCTAssertEqual(decoded.pixelsHigh, 80)
    }

    func testMissingFileYieldsNil() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("does-not-exist-\(UUID().uuidString).png")
        XCTAssertNil(ChatVisionContext.downscaledJPEGBase64(at: missing))
    }
}

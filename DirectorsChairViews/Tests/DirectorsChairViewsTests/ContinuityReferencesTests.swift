// DC-0091: continuity references between shots.
import XCTest
import DirectorsChairCore
import DirectorsChairServices
@testable import DirectorsChairViews

final class ContinuityReferencesTests: XCTestCase {
    private func shot(_ n: Int, preview: String? = nil) -> Shot {
        var s = Shot(shotId: n, description: "Shot \(n)")
        s.previewImage = preview
        return s
    }

    func testCandidatesAreOtherShotsWithPreviewsSameSceneFirst() {
        let me = shot(3, preview: "assets/shots/3.png")
        let a = shot(1, preview: "assets/shots/1.png")
        let b = shot(2)                                  // no preview → not offered
        let c = shot(9, preview: "assets/shots/9.png")   // another scene
        let d = shot(4, preview: "assets/shots/4.png")
        let picks = ContinuityReferences.candidates(for: me, sceneShotIds: [a.id, b.id, me.id, d.id],
                                                    allShots: [c, d, me, b, a])
        XCTAssertEqual(picks.map(\.shotId), [1, 4, 9])
    }

    func testReferenceImagesFollowTheChosenOrderAndSkipMissingFiles() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("continuity-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: dir.appendingPathComponent("one.png"))
        let one = shot(1, preview: "one.png")
        let gone = shot(2, preview: "missing.png")
        var me = shot(3)
        me.referenceShotIds = [gone.id, one.id]
        let refs = ContinuityReferences.referenceImages(for: me, allShots: [one, gone], projectDirectory: dir)
        XCTAssertEqual(refs.map(\.label), ["shot:Shot #1"])
        XCTAssertEqual(refs.first?.mimeType, "image/png")
    }

    func testMergedPutsContinuityFirstWithinTheProviderBudget() {
        let cont = (1...3).map { ReferenceImage(base64: "c\($0)", mimeType: "image/png", label: "shot:Shot #\($0)") }
        let others = (1...4).map { ReferenceImage(base64: "o\($0)", mimeType: "image/png", label: "character:C\($0)") }
        let onDevice = ContinuityReferences.merged(continuity: cont, others: others, onDevice: true)
        XCTAssertEqual(onDevice.count, ContinuityReferences.onDeviceBudget)
        XCTAssertEqual(onDevice.prefix(3).map(\.label), cont.map(\.label))
        let cloud = ContinuityReferences.merged(continuity: cont, others: others, onDevice: false)
        XCTAssertEqual(cloud.count, 7)
    }

    func testPromptPrefixExplainsAContinuityPicture() {
        let ref = ReferenceImage(base64: "x", mimeType: "image/png", label: "shot:Shot #2")
        let prefix = CharacterReferenceHelper.buildReferenceImagePromptPrefix(for: [ref])
        XCTAssertTrue(prefix.contains("finished preview of Shot #2"), prefix)
        XCTAssertTrue(prefix.contains("not a copy"), prefix)
    }

    // MARK: - DC-0109: the hand-drawn sketch reference

    func testSketchRenderProducesAWhitePNGWithBlackWhereDrawn() throws {
        let stroke = SketchStroke(points: [CGPoint(x: 0.1, y: 0.5), CGPoint(x: 0.9, y: 0.5)], width: 0.02)
        let png = try XCTUnwrap(SketchRender.png(strokes: [stroke], size: CGSize(width: 320, height: 180)))
        let source = try XCTUnwrap(CGImageSourceCreateWithData(png as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        XCTAssertEqual(image.width, 320); XCTAssertEqual(image.height, 180)
        // Sample the corner (must be white) and the stroke's midline (must be dark).
        let context = CGContext(data: nil, width: image.width, height: image.height,
                                bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let pixels = context.data!.bindMemory(to: UInt8.self, capacity: image.width * image.height * 4)
        func red(_ x: Int, _ y: Int) -> UInt8 { pixels[(y * image.width + x) * 4] }
        XCTAssertGreaterThan(red(4, 4), 240, "corner stays paper-white")
        XCTAssertLessThan(red(160, 90), 60, "the stroke midline is ink")
        XCTAssertNil(SketchRender.png(strokes: [], size: .zero))
    }

    func testSketchPromptClauseIsThePlanNotThePixels() {
        let refs = [ReferenceImage(base64: "eA==", mimeType: "image/png", label: SketchRender.referenceLabel),
                    ReferenceImage(base64: "eQ==", mimeType: "image/png", label: "shot:Shot #2")]
        let prefix = CharacterReferenceHelper.buildReferenceImagePromptPrefix(for: refs)
        XCTAssertTrue(prefix.contains("Image 1 is a rough hand-drawn PLANNING sketch"), prefix)
        XCTAssertTrue(prefix.contains("none of its ink may appear"), prefix)
        XCTAssertTrue(prefix.contains("Image 2 is the finished preview of Shot #2"), prefix)
    }

    func testComposedPNGBakesARedBadgeAtTheTagWithItsImageNumber() throws {
        let png = try XCTUnwrap(SketchRender.composedPNG(
            strokes: [], tags: [(x: 0.5, y: 0.5)],
            size: CGSize(width: 320, height: 180), base: nil, firstTagNumber: 2))
        let source = try XCTUnwrap(CGImageSourceCreateWithData(png as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let context = CGContext(data: nil, width: image.width, height: image.height,
                                bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let pixels = context.data!.bindMemory(to: UInt8.self, capacity: image.width * image.height * 4)
        func channel(_ x: Int, _ y: Int, _ o: Int) -> UInt8 { pixels[(y * image.width + x) * 4 + o] }
        // Badge centre: strongly red (allow the white numeral by sampling the rim).
        XCTAssertGreaterThan(channel(160 + 8, 90, 0), 200, "badge is red")
        XCTAssertLessThan(channel(160 + 8, 90, 1), 90, "badge is red, not white paper")
        XCTAssertGreaterThan(channel(6, 6, 1), 240, "corner stays paper")
    }
}


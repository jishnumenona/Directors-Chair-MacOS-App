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
}

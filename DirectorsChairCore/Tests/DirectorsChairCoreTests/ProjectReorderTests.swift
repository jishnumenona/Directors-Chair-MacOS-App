// ProjectReorderTests.swift
//
// Covers the navigator reorder model layer (Project+Reorder): moving
// sequences, scenes (within + across sequences), and shots (within + across
// scenes), plus shot display-number renumbering and index clamping. Ordering
// is array position, so these assertions are the source of truth every view
// (screenplay/timeline/bubble) derives from.

import XCTest
@testable import DirectorsChairCore

final class ProjectReorderTests: XCTestCase {

    /// seqA[s1(sh1,sh2,sh3), s2, s3], seqB[s4, s5]
    private func makeProject() -> Project {
        var s1 = Scene(uuid: "s1", name: "S1")
        s1.shots = [Shot(uuid: "sh1", shotId: 1), Shot(uuid: "sh2", shotId: 2), Shot(uuid: "sh3", shotId: 3)]
        let seqA = Sequence(uuid: "A", name: "Act 1",
                            scenes: [s1, Scene(uuid: "s2", name: "S2"), Scene(uuid: "s3", name: "S3")])
        let seqB = Sequence(uuid: "B", name: "Act 2",
                            scenes: [Scene(uuid: "s4", name: "S4"), Scene(uuid: "s5", name: "S5")])
        return Project(name: "P", sequences: [seqA, seqB])
    }

    private func sceneOrder(_ p: Project, _ seq: String) -> [String] {
        p.sequences.first { $0.id == seq }?.scenes.map(\.id) ?? []
    }
    private func shots(_ p: Project, _ scene: String) -> [(id: String, num: Int)] {
        for seq in p.sequences {
            if let s = seq.scenes.first(where: { $0.id == scene }) { return s.shots.map { ($0.id, $0.shotId) } }
        }
        return []
    }

    // MARK: - Sequences

    func testMoveSequenceToIndex() {
        var p = makeProject()
        XCTAssertTrue(p.moveSequence(id: "B", toIndex: 0))
        XCTAssertEqual(p.sequences.map(\.id), ["B", "A"])
    }

    func testMoveSequencesByOffsets() {
        var p = makeProject()
        p.moveSequences(fromOffsets: IndexSet(integer: 0), toOffset: 2)  // A after B
        XCTAssertEqual(p.sequences.map(\.id), ["B", "A"])
    }

    // MARK: - Scenes (within sequence)

    func testMoveSceneToFrontWithinSequence() {
        var p = makeProject()
        XCTAssertTrue(p.moveScene(id: "s3", toIndex: 0))
        XCTAssertEqual(sceneOrder(p, "A"), ["s3", "s1", "s2"])
    }

    func testMoveSceneClampsOutOfRangeIndex() {
        var p = makeProject()
        XCTAssertTrue(p.moveScene(id: "s1", toIndex: 999))   // clamps to last
        XCTAssertEqual(sceneOrder(p, "A"), ["s2", "s3", "s1"])
    }

    // MARK: - Scenes (cross-sequence)

    func testMoveSceneAcrossSequences() {
        var p = makeProject()
        XCTAssertTrue(p.moveScene(id: "s1", toSequenceId: "B", atIndex: 0))
        XCTAssertEqual(sceneOrder(p, "A"), ["s2", "s3"], "scene leaves the source sequence")
        XCTAssertEqual(sceneOrder(p, "B"), ["s1", "s4", "s5"], "and lands in the destination at the given index")
    }

    func testMoveSceneToSameSequenceIsAReorder() {
        var p = makeProject()
        XCTAssertTrue(p.moveScene(id: "s1", toSequenceId: "A", atIndex: 2))
        XCTAssertEqual(sceneOrder(p, "A"), ["s2", "s3", "s1"])
    }

    // MARK: - Shots (within scene, with renumber)

    func testMoveShotRenumbersDisplayIds() {
        var p = makeProject()
        XCTAssertTrue(p.moveShot(id: "sh3", toIndex: 0))
        // Order sh3, sh1, sh2 → display numbers resequenced 1,2,3.
        XCTAssertEqual(shots(p, "s1").map(\.id), ["sh3", "sh1", "sh2"])
        XCTAssertEqual(shots(p, "s1").map(\.num), [1, 2, 3])
    }

    func testMoveShotsByOffsetsRenumbers() {
        var p = makeProject()
        p.moveShots(inSceneId: "s1", fromOffsets: IndexSet(integer: 0), toOffset: 3)  // sh1 to end
        XCTAssertEqual(shots(p, "s1").map(\.id), ["sh2", "sh3", "sh1"])
        XCTAssertEqual(shots(p, "s1").map(\.num), [1, 2, 3])
    }

    // MARK: - Shots (cross-scene)

    func testMoveShotAcrossScenesRenumbersBoth() {
        var p = makeProject()
        XCTAssertTrue(p.moveShot(id: "sh1", toSceneId: "s2", atIndex: 0))
        XCTAssertEqual(shots(p, "s1").map(\.id), ["sh2", "sh3"])
        XCTAssertEqual(shots(p, "s1").map(\.num), [1, 2], "source scene renumbers")
        XCTAssertEqual(shots(p, "s2").map(\.id), ["sh1"])
        XCTAssertEqual(shots(p, "s2").map(\.num), [1], "destination scene renumbers")
    }

    func testRenumberShotsStandalone() {
        var p = makeProject()
        // Scramble display numbers, then renumber back to 1…n by order.
        p.sequences[0].scenes[0].shots[0].shotId = 99
        XCTAssertTrue(p.renumberShots(inSceneId: "s1"))
        XCTAssertEqual(shots(p, "s1").map(\.num), [1, 2, 3])
    }

    // MARK: - Guards

    func testMovesWithUnknownIdsAreNoOps() {
        var p = makeProject()
        XCTAssertFalse(p.moveScene(id: "nope", toIndex: 0))
        XCTAssertFalse(p.moveShot(id: "nope", toIndex: 0))
        XCTAssertFalse(p.moveSequence(id: "nope", toIndex: 0))
        XCTAssertEqual(sceneOrder(p, "A"), ["s1", "s2", "s3"], "nothing changed")
    }
}

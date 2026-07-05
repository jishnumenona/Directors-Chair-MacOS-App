// ShotsAdapterTests.swift
//
// WS5.1 — the ShotsAdapter bridges the flat CinematographyView with the
// scene-based model. Regression tests for the zombie-shot bug: a shot deleted
// in the flat view must actually be removed from the project (previously it was
// "kept as-is" and resurrected on reload).

import XCTest
@testable import DirectorsChair_Desktop
@testable import DirectorsChairCore

@MainActor
final class ShotsAdapterTests: XCTestCase {

    private func scene(_ name: String, shots: [Shot]) -> DirectorsChairCore.Scene {
        DirectorsChairCore.Scene(
            name: name, description: "",
            dialogues: [], actions: [], soundNotes: [],
            shots: shots, locationImages: []
        )
    }

    private func project(scenes: [DirectorsChairCore.Scene]) -> Project {
        Project(name: "P", sequences: [
            DirectorsChairCore.Sequence(name: "Seq 1", description: "", scenes: scenes)
        ])
    }

    private func flatIds(_ p: Project) -> [String] {
        p.sequences.flatMap { $0.scenes.flatMap { $0.shots.map(\.id) } }
    }

    func testDeletingAShotPersistsToTheProject() {
        let a = Shot(shotId: 1), b = Shot(shotId: 2), c = Shot(shotId: 3)
        var saved: Project?
        let adapter = ShotsAdapter(project: project(scenes: [scene("S1", shots: [a, b, c])])) {
            saved = $0
        }

        // Delete shot b: the view passes the full set minus b.
        adapter.updateShots([a, c])

        let result = try! XCTUnwrap(saved)
        XCTAssertEqual(flatIds(result).sorted(), [a.id, c.id].sorted(),
                       "Deleted shot must be gone, not resurrected")
        XCTAssertFalse(flatIds(result).contains(b.id))
        XCTAssertEqual(adapter.allShots.count, 2)
    }

    func testUpdatingAShotPersistsFieldChange() {
        var a = Shot(shotId: 1)
        var saved: Project?
        let adapter = ShotsAdapter(project: project(scenes: [scene("S1", shots: [a])])) {
            saved = $0
        }

        a.description = "Close-up on the letter"
        adapter.updateShots([a])

        let result = try! XCTUnwrap(saved)
        XCTAssertEqual(result.sequences.first?.scenes.first?.shots.first?.description,
                       "Close-up on the letter")
    }

    func testDeletionOnlyAffectsTheDeletedShotAcrossScenes() {
        let a = Shot(shotId: 1), b = Shot(shotId: 2), c = Shot(shotId: 3)
        var saved: Project?
        let adapter = ShotsAdapter(project: project(scenes: [
            scene("S1", shots: [a, b]),
            scene("S2", shots: [c]),
        ])) { saved = $0 }

        // Delete a (from scene 1); b and c must remain in their own scenes.
        adapter.updateShots([b, c])

        let result = try! XCTUnwrap(saved)
        XCTAssertEqual(result.sequences[0].scenes[0].shots.map(\.id), [b.id])
        XCTAssertEqual(result.sequences[0].scenes[1].shots.map(\.id), [c.id])
    }
}

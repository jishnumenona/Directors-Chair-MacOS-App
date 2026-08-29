// Owner 2026-08-29: shot numbers follow story order; folders follow shots.
import XCTest
@testable import DirectorsChairCore

final class ShotRenumberingTests: XCTestCase {
    private func project(order: [Int]) -> Project {
        var scene = Scene(name: "Van")
        scene.shots = order.map { n in
            var shot = Shot(shotId: n, description: "Shot \(n)")
            shot.previewImage = "assets/shots/shot_\(n)/latest.png"
            return shot
        }
        var sequence = Sequence(name: "Act 1"); sequence.scenes = [scene]
        var p = Project(name: "P"); p.sequences = [sequence]
        return p
    }

    func testRenumbersInStoryOrderAndRewritesPaths() {
        let (renumbered, moves) = project(order: [2, 1, 3]).renumberingShots()
        let shots = renumbered.sequences[0].scenes[0].shots
        XCTAssertEqual(shots.map(\.shotId), [1, 2, 3])
        XCTAssertEqual(shots.map(\.description), ["Shot 2", "Shot 1", "Shot 3"], "identity stays with the shot")
        XCTAssertEqual(shots[0].previewImage, "assets/shots/shot_1/latest.png")
        XCTAssertEqual(shots[1].previewImage, "assets/shots/shot_2/latest.png")
        XCTAssertEqual(moves.map { ($0.from, $0.to) }.map { "\($0.0)->\($0.1)" }, ["2->1", "1->2"])
        XCTAssertTrue(project(order: [1, 2, 3]).renumberingShots().moves.isEmpty)
    }

    func testFolderMigrationSwapsWithoutCollision() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("renumber-\(UUID().uuidString)")
        let shots = dir.appendingPathComponent("assets/shots")
        try FileManager.default.createDirectory(at: shots.appendingPathComponent("shot_1"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: shots.appendingPathComponent("shot_2"), withIntermediateDirectories: true)
        try "one".write(to: shots.appendingPathComponent("shot_1/latest.png"), atomically: true, encoding: .utf8)
        try "two".write(to: shots.appendingPathComponent("shot_2/latest.png"), atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: dir) }
        try ShotFolderMigration.apply([ShotNumberMove(shotUUID: "a", from: 2, to: 1), ShotNumberMove(shotUUID: "b", from: 1, to: 2)],
                                      projectDirectory: dir)
        XCTAssertEqual(try String(contentsOf: shots.appendingPathComponent("shot_1/latest.png")), "two")
        XCTAssertEqual(try String(contentsOf: shots.appendingPathComponent("shot_2/latest.png")), "one")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: shots.path).sorted(), ["shot_1", "shot_2"])
    }
}

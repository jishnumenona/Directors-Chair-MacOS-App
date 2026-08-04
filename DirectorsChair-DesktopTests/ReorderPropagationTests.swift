// ReorderPropagationTests.swift
//
// Proves the navigator reorder feature's core promise: reordering scenes in the
// model (Project+Reorder) is reflected in the SCREENPLAY, because
// ProjectToScriptConverter reads scene order from the array. The same array
// order also drives the timeline and bubble view.

import XCTest
@testable import DirectorsChair_Desktop
@testable import DirectorsChairCore

final class ReorderPropagationTests: XCTestCase {

    private func makeProject() -> Project {
        let seq = Sequence(uuid: "A", name: "Act 1", scenes: [
            Scene(uuid: "s1", name: "S1"),
            Scene(uuid: "s2", name: "S2"),
            Scene(uuid: "s3", name: "S3"),
        ])
        return Project(name: "P", sequences: [seq])
    }

    /// Scene ids in the order they appear as headings in the generated script.
    private func screenplaySceneOrder(_ project: Project) -> [String] {
        ProjectToScriptConverter.convert(from: project)
            .filter { $0.type == .sceneHeading }
            .compactMap { $0.sourceItemId }
    }

    func testReorderingScenesReordersTheScreenplay() {
        var project = makeProject()
        XCTAssertEqual(screenplaySceneOrder(project), ["s1", "s2", "s3"])

        // Move the last scene to the front (as the navigator would).
        XCTAssertTrue(project.moveScene(id: "s3", toIndex: 0))

        XCTAssertEqual(screenplaySceneOrder(project), ["s3", "s1", "s2"],
                       "reordering scenes in the model reorders the generated screenplay")
    }

    func testSceneNumbersStaySequentialAfterReorder() {
        var project = makeProject()
        project.moveScene(id: "s3", toIndex: 0)
        let numbers = ProjectToScriptConverter.convert(from: project)
            .filter { $0.type == .sceneHeading }
            .map { $0.sceneNumber }
        XCTAssertEqual(numbers, ["1", "2", "3"],
                       "scene numbers regenerate sequentially in the new order")
    }
}

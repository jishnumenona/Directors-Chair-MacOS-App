// SceneNavigationLinkTests.swift
//
// The script view's scene navigator links each scene to its heading in the
// screenplay. These tests lock that linkage: clicking scene N must resolve to
// the heading of the scene actually at position N — and stay correct after a
// reorder (the bug: clicking scene 7 jumped to scene 5). Assertions use the
// scene's stable `sourceItemId`, so they don't depend on heading formatting.

import XCTest
@testable import DirectorsChair_Desktop
@testable import DirectorsChairCore

@MainActor
final class SceneNavigationLinkTests: XCTestCase {

    private func makeProjectViewModel(sceneIds: [String]) -> ProjectViewModel {
        let scenes = sceneIds.map { id -> Scene in
            var s = Scene(uuid: id, name: id.uppercased())
            s.location = "INT. \(id.uppercased()) - DAY"
            return s
        }
        let pvm = ProjectViewModel()
        pvm.project = Project(name: "P", sequences: [Sequence(uuid: "A", name: "Act 1", scenes: scenes)])
        return pvm
    }

    private func loaded(_ pvm: ProjectViewModel) -> ScriptViewModel {
        let vm = ScriptViewModel()
        vm.loadFromProject(pvm.project, projectViewModel: pvm)
        return vm
    }

    /// The scene id the navigator link resolves to for a given 1-based number.
    private func linkedSceneId(_ vm: ScriptViewModel, _ sceneNumber: String) -> String? {
        vm.scrollToScene(sceneNumber)
        return vm.elements.first { $0.id == vm.scrollToElementId }?.sourceItemId
    }

    // MARK: - Linkage integrity

    func testEveryOutlineItemLinksToItsOwnHeading() {
        let vm = loaded(makeProjectViewModel(sceneIds: ["s1", "s2", "s3"]))
        XCTAssertEqual(vm.sceneOutline.count, 3)
        for item in vm.sceneOutline {
            let element = vm.elements.first { $0.id == item.elementId }
            XCTAssertEqual(element?.type, .sceneHeading, "outline item must point at a scene heading")
            XCTAssertEqual(element?.sceneNumber, item.sceneNumber, "and at the heading with the same number")
        }
    }

    func testClickingSceneTargetsThatScene() {
        let vm = loaded(makeProjectViewModel(sceneIds: ["s1", "s2", "s3"]))
        XCTAssertEqual(linkedSceneId(vm, "1"), "s1")
        XCTAssertEqual(linkedSceneId(vm, "2"), "s2")
        XCTAssertEqual(linkedSceneId(vm, "3"), "s3")
    }

    // MARK: - Stays correct after reorder (the reported bug)

    func testNavigationCorrectAfterLiveReorder() {
        let pvm = makeProjectViewModel(sceneIds: ["s1", "s2", "s3"])
        let vm = loaded(pvm)

        // Reorder as the navigator does: move s3 to the front (→ s3, s1, s2),
        // then refresh the editor the way the .structure event would.
        pvm.moveScene(id: "s3", toIndex: 0)
        vm.refresh(from: pvm.project)

        XCTAssertEqual(linkedSceneId(vm, "1"), "s3", "scene 1 link must follow s3 to the front")
        XCTAssertEqual(linkedSceneId(vm, "2"), "s1")
        XCTAssertEqual(linkedSceneId(vm, "3"), "s2", "scene 3 link must resolve to s2, not a stale scene")
    }

    func testNavigationCorrectAfterCrossSequenceMove() {
        let scenesA = ["s1", "s2"].map { id -> Scene in
            var s = Scene(uuid: id, name: id); s.location = "INT. \(id) - DAY"; return s
        }
        let scenesB = ["s3", "s4"].map { id -> Scene in
            var s = Scene(uuid: id, name: id); s.location = "INT. \(id) - DAY"; return s
        }
        let pvm = ProjectViewModel()
        pvm.project = Project(name: "P", sequences: [
            Sequence(uuid: "A", name: "Act 1", scenes: scenesA),
            Sequence(uuid: "B", name: "Act 2", scenes: scenesB),
        ])
        let vm = loaded(pvm)

        // Move s4 from Act 2 to the front of Act 1 → screenplay order s4,s1,s2,s3.
        pvm.moveScene(id: "s4", toSequenceId: "A", atIndex: 0)
        vm.refresh(from: pvm.project)

        XCTAssertEqual(linkedSceneId(vm, "1"), "s4")
        XCTAssertEqual(linkedSceneId(vm, "2"), "s1")
        XCTAssertEqual(linkedSceneId(vm, "4"), "s3")
    }
}

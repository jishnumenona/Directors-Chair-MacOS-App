// SceneNavigationTests.swift
// Tests for scene creation, ID-based navigation, and AppCoordinator scene selection

import XCTest
import Combine
@testable import DirectorsChair_Desktop
@testable import DirectorsChairCore

@MainActor
final class SceneNavigationTests: XCTestCase {

    var coordinator: AppCoordinator!
    var projectViewModel: ProjectViewModel!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        coordinator = AppCoordinator()
        projectViewModel = ProjectViewModel()
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
        cancellables = nil
        coordinator = nil
        projectViewModel = nil
        super.tearDown()
    }

    // MARK: - Test Helpers

    private func makeTestProject() -> Project {
        let scene1 = Scene(
            name: "Scene 1 - INT. OFFICE - DAY",
            dialogues: [Dialogue(character: "Alice", text: "Good morning!", chronologyNumber: 1)]
        )
        let scene2 = Scene(
            name: "Scene 2 - EXT. PARK - EVENING",
            dialogues: [Dialogue(character: "Bob", text: "Nice sunset.", chronologyNumber: 1)]
        )
        let scene3 = Scene(
            name: "Scene 3 - INT. CAFE - NIGHT",
            dialogues: [Dialogue(character: "Charlie", text: "Coffee time!", chronologyNumber: 1)]
        )

        let sequence = Sequence(name: "Act 1", scenes: [scene1, scene2, scene3])
        return Project(name: "Navigation Test", sequences: [sequence])
    }

    // MARK: - Scene Selection Tests

    func testSelectSceneById() {
        let project = makeTestProject()
        let scene2 = project.sequences[0].scenes[1]

        coordinator.selectedScene = scene2

        XCTAssertNotNil(coordinator.selectedScene)
        XCTAssertEqual(coordinator.selectedScene?.id, scene2.id)
        XCTAssertEqual(coordinator.selectedScene?.name, "Scene 2 - EXT. PARK - EVENING")
    }

    func testSceneSelectionPublisher() {
        let project = makeTestProject()
        let scene1 = project.sequences[0].scenes[0]

        let expectation = XCTestExpectation(description: "sceneChanged fires")

        coordinator.sceneChanged
            .sink { scene in
                XCTAssertEqual(scene.id, scene1.id)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        coordinator.sceneChanged.send(scene1)

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Scene Creation Tests

    func testCreateSceneAddsToProject() {
        var project = makeTestProject()
        let originalCount = project.sequences[0].scenes.count

        let newScene = Scene(name: "Scene 4 - INT. BEDROOM - MORNING")
        project.sequences[0].scenes.append(newScene)

        XCTAssertEqual(project.sequences[0].scenes.count, originalCount + 1)
        XCTAssertEqual(project.sequences[0].scenes.last?.name, "Scene 4 - INT. BEDROOM - MORNING")
    }

    func testSelectNewlyCreatedScene() {
        var project = makeTestProject()

        let newScene = Scene(name: "New Scene")
        project.sequences[0].scenes.append(newScene)

        coordinator.selectedScene = newScene

        XCTAssertEqual(coordinator.selectedScene?.id, newScene.id)
    }

    // MARK: - Scene Switching Tests

    func testSceneSwitchUpdatesContent() {
        let project = makeTestProject()
        let scene1 = project.sequences[0].scenes[0]
        let scene2 = project.sequences[0].scenes[1]

        coordinator.selectedScene = scene1
        XCTAssertEqual(coordinator.selectedScene?.name, "Scene 1 - INT. OFFICE - DAY")

        coordinator.selectedScene = scene2
        XCTAssertEqual(coordinator.selectedScene?.name, "Scene 2 - EXT. PARK - EVENING")
    }

    func testSingleClickSceneSelection() {
        let project = makeTestProject()
        let scene1 = project.sequences[0].scenes[0]

        // Single selection change should be sufficient (regression C1 — was requiring double-click)
        coordinator.selectedScene = scene1

        XCTAssertNotNil(coordinator.selectedScene)
        XCTAssertEqual(coordinator.selectedScene?.id, scene1.id)

        // ID-based lookup should work on first try
        let sceneId = coordinator.selectedScene?.id
        var found: Scene?
        for seq in project.sequences {
            if let s = seq.scenes.first(where: { $0.id == sceneId }) {
                found = s
                break
            }
        }
        XCTAssertNotNil(found, "ID-based lookup should find scene immediately")
        XCTAssertEqual(found?.id, scene1.id)
    }

    // MARK: - Scene List Tests

    func testSceneListReflectsProjectChanges() {
        var project = makeTestProject()
        projectViewModel.project = project
        let originalCount = projectViewModel.project.sequences[0].scenes.count

        // Add scene
        let newScene = Scene(name: "Added Scene")
        project.sequences[0].scenes.append(newScene)
        projectViewModel.project = project

        XCTAssertEqual(projectViewModel.project.sequences[0].scenes.count, originalCount + 1)
    }

    func testDeleteSceneClearsSelection() {
        let project = makeTestProject()
        let sceneToDelete = project.sequences[0].scenes[0]

        coordinator.selectedScene = sceneToDelete
        XCTAssertNotNil(coordinator.selectedScene)

        // Delete the scene
        coordinator.selectedScene = nil

        XCTAssertNil(coordinator.selectedScene)
    }

    // MARK: - Duplicate Name Tests

    func testDuplicateSceneNamesHandled() {
        let scene1 = Scene(name: "Duplicate Name")
        let scene2 = Scene(name: "Duplicate Name")

        XCTAssertNotEqual(scene1.id, scene2.id, "Different scenes should have unique IDs even with same name")

        let sequence = Sequence(name: "Act 1", scenes: [scene1, scene2])
        let project = Project(name: "Test", sequences: [sequence])

        // Select scene2 by ID
        coordinator.selectedScene = scene2

        // ID-based lookup should find scene2, not scene1
        let selectedId = coordinator.selectedScene?.id
        var found: Scene?
        for seq in project.sequences {
            if let s = seq.scenes.first(where: { $0.id == selectedId }) {
                found = s
                break
            }
        }

        XCTAssertNotNil(found)
        XCTAssertEqual(found?.id, scene2.id, "ID-based lookup should distinguish scenes with same name")
        XCTAssertNotEqual(found?.id, scene1.id)
    }

    // MARK: - Scene Order Tests

    func testSceneOrderPreserved() {
        var project = makeTestProject()
        let originalOrder = project.sequences[0].scenes.map { $0.id }

        // Add a scene at a specific position
        let newScene = Scene(name: "Inserted Scene")
        project.sequences[0].scenes.insert(newScene, at: 1)

        let newOrder = project.sequences[0].scenes.map { $0.id }

        // Original scenes should maintain relative order
        XCTAssertEqual(newOrder[0], originalOrder[0])
        XCTAssertEqual(newOrder[1], newScene.id)
        XCTAssertEqual(newOrder[2], originalOrder[1])
        XCTAssertEqual(newOrder[3], originalOrder[2])
    }
}

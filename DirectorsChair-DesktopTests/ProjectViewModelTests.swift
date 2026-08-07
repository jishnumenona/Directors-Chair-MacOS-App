// DirectorsChair-DesktopTests/ProjectViewModelTests.swift
//
// Tests for ProjectViewModel logic: creation, dirty tracking, modifications.

import XCTest
import Combine
@testable import DirectorsChair_Desktop
@testable import DirectorsChairCore

@MainActor
final class ProjectViewModelTests: XCTestCase {

    var viewModel: ProjectViewModel!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        viewModel = ProjectViewModel()
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
        cancellables = nil
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialState() {
        XCTAssertFalse(viewModel.hasProject, "Should have no project initially when created without one")
        XCTAssertFalse(viewModel.isDirty, "Should not be dirty initially")
        XCTAssertNil(viewModel.projectPath, "Project path should be nil initially")
        XCTAssertNil(viewModel.lastSaved, "lastSaved should be nil initially")
        XCTAssertFalse(viewModel.isLoading, "Should not be loading initially")
        XCTAssertNil(viewModel.errorAlert, "Should have no error alert initially")
    }

    func testInitialProjectIsEmpty() {
        // When no project is passed, a default empty project should be created
        XCTAssertEqual(viewModel.project.name, "Untitled Project")
        XCTAssertEqual(viewModel.project.status, "Pre-production")
    }

    // MARK: - Create Project

    func testCreateProjectSetsCorrectState() {
        // Project.empty() includes a sample sequence, scene, dialogue, character, and shot
        let emptyProject = Project.empty()

        XCTAssertEqual(emptyProject.name, "Untitled Project")
        XCTAssertEqual(emptyProject.status, "Pre-production")
        XCTAssertEqual(emptyProject.projectType, "Skit")
        XCTAssertFalse(emptyProject.sequences.isEmpty, "Should have a sample sequence")
        XCTAssertFalse(emptyProject.characters.isEmpty, "Should have a sample character")
    }

    func testCreateProjectPopulatesSampleData() {
        let project = Project.empty()

        // Check sample sequence
        XCTAssertEqual(project.sequences.count, 1)
        XCTAssertEqual(project.sequences.first?.name, "Act 1 - Opening")

        // Check sample scene
        let scenes = project.sequences.first?.scenes ?? []
        XCTAssertEqual(scenes.count, 1)
        XCTAssertEqual(scenes.first?.name, "Scene 1 - Introduction")

        // Check sample dialogue
        let dialogues = scenes.first?.dialogues ?? []
        XCTAssertEqual(dialogues.count, 1)
        XCTAssertEqual(dialogues.first?.character, "Alex")

        // Check sample shot
        let shots = scenes.first?.shots ?? []
        XCTAssertEqual(shots.count, 1)
        XCTAssertEqual(shots.first?.status, "Planning")

        // Check sample character
        XCTAssertEqual(project.characters.count, 1)
        XCTAssertEqual(project.characters.first?.name, "Alex")
    }

    // MARK: - Dirty Tracking

    func testProjectDirtyTracking() {
        // Initially not dirty
        XCTAssertFalse(viewModel.isDirty)

        // Modify metadata
        viewModel.updateMetadata(name: "New Name")

        XCTAssertTrue(viewModel.isDirty, "Should be dirty after metadata change")
        XCTAssertEqual(viewModel.project.name, "New Name")
    }

    func testAddSequenceMarksDirty() {
        XCTAssertFalse(viewModel.isDirty)

        let newSequence = Sequence(name: "Act 2")
        viewModel.addSequence(newSequence)

        XCTAssertTrue(viewModel.isDirty)
        XCTAssertTrue(viewModel.project.sequences.contains(where: { $0.name == "Act 2" }))
    }

    func testRemoveSequenceMarksDirty() {
        // Start with a sequence from empty project
        let seq = viewModel.project.sequences.first!
        viewModel.isDirty = false  // Reset

        viewModel.removeSequence(seq)

        XCTAssertTrue(viewModel.isDirty)
        XCTAssertFalse(viewModel.project.sequences.contains(where: { $0.id == seq.id }))
    }

    func testAddCharacterMarksDirty() {
        viewModel.isDirty = false

        let character = Character(name: "Villain", role: "Antagonist")
        viewModel.addCharacter(character)

        XCTAssertTrue(viewModel.isDirty)
        XCTAssertTrue(viewModel.project.characters.contains(where: { $0.name == "Villain" }))
    }

    func testRemoveCharacterMarksDirty() {
        let char = viewModel.project.characters.first!
        viewModel.isDirty = false

        viewModel.removeCharacter(char)

        XCTAssertTrue(viewModel.isDirty)
        XCTAssertFalse(viewModel.project.characters.contains(where: { $0.id == char.id }))
    }

    // MARK: - Auto-Save Trigger

    func testAutoSaveTriggersOnChange() {
        // The auto-save mechanism watches $project changes.
        // We verify that modifying the project triggers isDirty = true,
        // which is the prerequisite for auto-save.
        let expectation = XCTestExpectation(description: "isDirty set to true")

        viewModel.$isDirty
            .dropFirst()  // Skip initial value
            .filter { $0 == true }
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // Trigger a project change
        viewModel.project.name = "Modified Project"

        wait(for: [expectation], timeout: 2.0)
        XCTAssertTrue(viewModel.isDirty)
    }

    // MARK: - Delete / Close Project

    func testDeleteProject() {
        // Simulate having a project
        viewModel.hasProject = true
        viewModel.project.name = "To Be Deleted"

        // Remove a sequence to simulate deletion of project content
        let originalCount = viewModel.project.sequences.count
        if let firstSeq = viewModel.project.sequences.first {
            viewModel.removeSequence(firstSeq)
        }

        XCTAssertEqual(viewModel.project.sequences.count, originalCount - 1)
        XCTAssertTrue(viewModel.isDirty)
    }

    func testCloseProjectResetsState() async {
        viewModel.hasProject = true
        viewModel.project.name = "Active Project"
        viewModel.isDirty = false

        await viewModel.close()

        XCTAssertFalse(viewModel.hasProject, "Should have no project after close")
        XCTAssertNil(viewModel.projectPath, "Project path should be nil after close")
        XCTAssertFalse(viewModel.isDirty, "Should not be dirty after close")
        XCTAssertNil(viewModel.lastSaved, "lastSaved should be nil after close")
        XCTAssertEqual(viewModel.projectStorageSize, 0)
    }

    // MARK: - Metadata Updates

    func testUpdateMetadataName() {
        viewModel.updateMetadata(name: "My Film")
        XCTAssertEqual(viewModel.project.name, "My Film")
        XCTAssertTrue(viewModel.isDirty)
    }

    func testUpdateMetadataDirector() {
        viewModel.updateMetadata(director: "John Doe")
        XCTAssertEqual(viewModel.project.director, "John Doe")
        XCTAssertTrue(viewModel.isDirty)
    }

    func testUpdateMetadataMultipleFields() {
        viewModel.updateMetadata(
            name: "Epic Film",
            director: "Jane Smith",
            productionCompany: "Studio X",
            genre: "Drama"
        )

        XCTAssertEqual(viewModel.project.name, "Epic Film")
        XCTAssertEqual(viewModel.project.director, "Jane Smith")
        XCTAssertEqual(viewModel.project.productionCompany, "Studio X")
        XCTAssertEqual(viewModel.project.genre, "Drama")
    }

    func testUpdateMetadataPartialUpdate() {
        viewModel.project.name = "Original"
        viewModel.project.director = "Original Director"
        viewModel.isDirty = false

        // Only update name
        viewModel.updateMetadata(name: "Updated")

        XCTAssertEqual(viewModel.project.name, "Updated")
        XCTAssertEqual(viewModel.project.director, "Original Director",
                       "Director should be unchanged when not provided")
    }

    // MARK: - Convenience Accessors

    func testAllScenesAccessor() {
        let project = Project.empty()
        viewModel.project = project

        let allScenes = viewModel.allScenes
        XCTAssertEqual(allScenes.count, 1, "Empty project has one sample scene")
        XCTAssertEqual(allScenes.first?.name, "Scene 1 - Introduction")
    }

    func testAllShotsAccessor() {
        let project = Project.empty()
        viewModel.project = project

        let allShots = viewModel.allShots
        XCTAssertEqual(allShots.count, 1, "Empty project has one sample shot")
    }

    func testCharactersAccessor() {
        let project = Project.empty()
        viewModel.project = project

        XCTAssertEqual(viewModel.characters.count, 1)
        XCTAssertEqual(viewModel.characters.first?.name, "Alex")
    }

    func testSequencesAccessor() {
        let project = Project.empty()
        viewModel.project = project

        XCTAssertEqual(viewModel.sequences.count, 1)
        XCTAssertEqual(viewModel.sequences.first?.name, "Act 1 - Opening")
    }

    // MARK: - Add Scene/Shot Operations

    func testAddSceneToSequence() {
        let project = Project.empty()
        viewModel.project = project
        viewModel.isDirty = false

        let sequenceId = project.sequences.first!.id
        let newScene = Scene(name: "Scene 2 - Confrontation")

        viewModel.addScene(newScene, toSequenceId: sequenceId)

        let scenes = viewModel.project.sequences.first!.scenes
        XCTAssertEqual(scenes.count, 2)
        XCTAssertTrue(scenes.contains(where: { $0.name == "Scene 2 - Confrontation" }))
        XCTAssertTrue(viewModel.isDirty)
    }

    func testRemoveSceneFromSequence() {
        let project = Project.empty()
        viewModel.project = project
        viewModel.isDirty = false

        let sequenceId = project.sequences.first!.id
        let scene = project.sequences.first!.scenes.first!

        viewModel.removeScene(scene, fromSequenceId: sequenceId)

        XCTAssertTrue(viewModel.project.sequences.first!.scenes.isEmpty)
        XCTAssertTrue(viewModel.isDirty)
    }

    func testAddShotToScene() {
        let project = Project.empty()
        viewModel.project = project
        viewModel.isDirty = false

        let sequenceId = project.sequences.first!.id
        let sceneId = project.sequences.first!.scenes.first!.id
        let newShot = Shot(shotId: 2, description: "Close-up")

        viewModel.addShot(newShot, toSceneId: sceneId, inSequenceId: sequenceId)

        let shots = viewModel.project.sequences.first!.scenes.first!.shots
        XCTAssertEqual(shots.count, 2)
        XCTAssertTrue(shots.contains(where: { $0.description == "Close-up" }))
        XCTAssertTrue(viewModel.isDirty)
    }

    func testRemoveShotFromScene() {
        let project = Project.empty()
        viewModel.project = project
        viewModel.isDirty = false

        let sequenceId = project.sequences.first!.id
        let sceneId = project.sequences.first!.scenes.first!.id
        let shot = project.sequences.first!.scenes.first!.shots.first!

        viewModel.removeShot(shot, fromSceneId: sceneId, inSequenceId: sequenceId)

        XCTAssertTrue(viewModel.project.sequences.first!.scenes.first!.shots.isEmpty)
        XCTAssertTrue(viewModel.isDirty)
    }

    // MARK: - Project Next Shot Display Number

    func testNextShotDisplayNumber() {
        let project = Project.empty()
        // Empty project has shot with shotId=1
        XCTAssertEqual(project.nextShotDisplayNumber, 2)
    }

    func testNextShotDisplayNumberWithMultipleShots() {
        var project = Project.empty()
        let shot2 = Shot(shotId: 5, description: "Another shot")
        project.sequences[0].scenes[0].shots.append(shot2)

        XCTAssertEqual(project.nextShotDisplayNumber, 6)
    }

    // MARK: - Save Without Path

    func testSaveWithoutPathShowsError() async {
        viewModel.projectPath = nil

        await viewModel.save()

        XCTAssertNotNil(viewModel.errorAlert, "Should show error when saving without a path")
        XCTAssertEqual(viewModel.errorAlert?.title, "Cannot Save")
    }

    // MARK: - Project Codable

    func testProjectCodableRoundTrip() throws {
        let project = Project.empty()

        let encoder = JSONEncoder()
        let data = try encoder.encode(project)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Project.self, from: data)

        XCTAssertEqual(decoded.name, project.name)
        XCTAssertEqual(decoded.status, project.status)
        XCTAssertEqual(decoded.projectType, project.projectType)
        XCTAssertEqual(decoded.sequences.count, project.sequences.count)
        XCTAssertEqual(decoded.characters.count, project.characters.count)
    }
}

// MARK: - No lost work (P0, 2026-08-06 audit)
//
// The debounced autosave existed before this program; what it lacked was
// honesty and exits. These pin: an autosave that LANDS clears the dirty
// flag; an autosave that keeps FAILING says so exactly once per streak;
// and the lifecycle flush actually reaches disk.

@MainActor
final class NoLostWorkTests: XCTestCase {

    private func temporaryProjectURL() throws -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("nolostwork-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir,
                                                withIntermediateDirectories: true)
        return dir.appendingPathComponent("project.json")
    }

    private func pump(seconds: TimeInterval) {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            RunLoop.main.run(mode: .default,
                             before: Date().addingTimeInterval(0.05))
        }
    }

    func testAnAutosaveThatLandsClearsTheDirtyFlag() throws {
        let url = try temporaryProjectURL()
        let viewModel = ProjectViewModel()
        viewModel.projectPath = url
        viewModel.hasProject = true

        viewModel.project.name = "edited"
        // The dirty flag is set by a deferred main-actor task — poll for
        // it rather than assuming a scheduling deadline.
        let dirtyDeadline = Date().addingTimeInterval(1.0)
        while !viewModel.isDirty && Date() < dirtyDeadline {
            pump(seconds: 0.05)
        }
        XCTAssertTrue(viewModel.isDirty, "an edit marks the project dirty")

        // 500ms debounce + write + main-loop delivery.
        pump(seconds: 2.0)
        XCTAssertFalse(viewModel.isDirty,
            "the edit is on disk — claiming unsaved changes forever was "
            + "the audit's truthful-state finding")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertNotNil(viewModel.lastSaved)
    }

    func testLifecycleFlushWritesWithoutWaitingForTheDebounce() throws {
        let url = try temporaryProjectURL()
        let viewModel = ProjectViewModel()
        viewModel.projectPath = url
        viewModel.hasProject = true

        viewModel.project.name = "quit right now"
        // Let the deferred dirty-marking task land, but stay well inside
        // the 500ms debounce window.
        pump(seconds: 0.25)

        let flushed = expectation(description: "flush")
        Task { @MainActor in
            await viewModel.flushPendingSaves()
            flushed.fulfill()
        }
        wait(for: [flushed], timeout: 5)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                      "⌘Q inside the debounce window must not lose the edit")
        XCTAssertFalse(viewModel.isDirty)
    }

    func testAFailingAutosaveSpeaksUpOnThirdFailureOnceAndResetsOnSuccess() {
        // Driven directly: a genuinely dying disk can't be simulated from
        // a test (the writability precheck filters permission problems,
        // and APFS happily replaces directories), but the CONTRACT —
        // three strikes, one alert, success resets — is pure logic.
        let viewModel = ProjectViewModel()
        struct Boom: Error, LocalizedError {
            var errorDescription: String? { "disk full" }
        }

        var alerts = 0
        let observation = viewModel.$errorAlert.dropFirst().sink { alert in
            if alert != nil { alerts += 1 }
        }
        defer { observation.cancel() }

        viewModel.registerAutosaveFailure(Boom())
        viewModel.registerAutosaveFailure(Boom())
        XCTAssertEqual(alerts, 0, "two failures could be transient")
        viewModel.registerAutosaveFailure(Boom())
        viewModel.registerAutosaveFailure(Boom())
        viewModel.registerAutosaveFailure(Boom())
        pump(seconds: 0.1)
        XCTAssertEqual(alerts, 1, "the streak alerts once, not per tick")
        XCTAssertEqual(viewModel.autosaveFailureStreak, 5)
    }
}

// MARK: - App-wide undo (P0 §2.16c)
//
// One choke point: every durable edit — shots, production tables,
// curation picks, boards — commits through projectViewModel.project, so
// snapshot undo there is undo for the whole app. These pin the contract
// against a real UndoManager.

@MainActor
final class AppWideUndoTests: XCTestCase {

    private func pump(_ seconds: TimeInterval = 0.05) {
        RunLoop.main.run(mode: .default,
                         before: Date().addingTimeInterval(seconds))
    }

    /// Closes the per-event undo group the way the live app's event loop
    /// does at the end of each event — a bare runloop pump in a test
    /// process doesn't count as an event boundary.
    private func endEvent(_ manager: UndoManager) {
        while manager.groupingLevel > 0 { manager.endUndoGrouping() }
        // Let the runloop tick so the manager will lazily open a fresh
        // group for the next registration.
        pump(0.02)
    }

    private func makeViewModel(_ manager: UndoManager)
        -> ProjectViewModel {
        let viewModel = ProjectViewModel()
        viewModel.hasProject = true
        viewModel.windowUndoManager = manager
        viewModel.project.name = "origin"
        endEvent(manager)         // close the seeding event group
        return viewModel
    }

    func testUndoRestoresAndRedoReapplies() {
        let manager = UndoManager()
        let viewModel = makeViewModel(manager)

        viewModel.project.name = "edited"
        endEvent(manager)
        XCTAssertTrue(manager.canUndo, "a committed edit is undoable")

        manager.undo()
        XCTAssertEqual(viewModel.project.name, "origin")
        XCTAssertTrue(manager.canRedo)

        manager.redo()
        XCTAssertEqual(viewModel.project.name, "edited")
    }

    func testABurstInOneEventIsOneUndoStep() {
        // A gesture that commits several fields must not take several ⌘Z
        // to take back — NSUndoManager's per-event grouping, kept intact
        // by registering synchronously with the mutation.
        let manager = UndoManager()
        let viewModel = makeViewModel(manager)

        viewModel.project.name = "step-a"
        viewModel.project.budget = "999"
        endEvent(manager)

        manager.undo()
        XCTAssertEqual(viewModel.project.name, "origin")
        XCTAssertNotEqual(viewModel.project.budget, "999",
                          "one gesture, one undo")
    }

    func testSeparateEventsAreSeparateSteps() {
        let manager = UndoManager()
        let viewModel = makeViewModel(manager)

        viewModel.project.name = "first"
        endEvent(manager)
        viewModel.project.name = "second"
        endEvent(manager)

        manager.undo()
        XCTAssertEqual(viewModel.project.name, "first")
        manager.undo()
        XCTAssertEqual(viewModel.project.name, "origin")
    }

    func testUndoIsAnEditItMarksDirtyAndAutosaves() {
        let manager = UndoManager()
        let viewModel = makeViewModel(manager)
        viewModel.project.name = "edited"
        endEvent(manager)
        pump(0.3)
        viewModel.isDirty = false     // pretend everything was saved

        manager.undo()
        pump(0.3)
        XCTAssertTrue(viewModel.isDirty,
            "a restore changes the document — it saves like any edit")
    }

    func testScriptModeStandsDown() {
        // The script editor owns typing-grained history; while it is
        // frontmost, project snapshots must not double-book ⌘Z.
        let manager = UndoManager()
        let viewModel = makeViewModel(manager)
        viewModel.shouldRecordUndo = { false }

        viewModel.project.name = "typed in script"
        endEvent(manager)
        XCTAssertFalse(manager.canUndo)
    }

    func testDocumentBoundariesEndTheHistory() {
        let manager = UndoManager()
        let viewModel = makeViewModel(manager)
        viewModel.project.name = "edited"
        endEvent(manager)
        XCTAssertTrue(manager.canUndo)

        viewModel.resetUndoHistory()
        XCTAssertFalse(manager.canUndo,
            "undo never carries one document into another's history")
    }

    func testUndoNamesTheSurface() {
        let manager = UndoManager()
        let viewModel = makeViewModel(manager)
        viewModel.undoActionNameProvider = { "Shot List Edit" }

        viewModel.project.name = "edited"
        endEvent(manager)
        XCTAssertEqual(manager.undoMenuItemTitle, "Undo Shot List Edit")
    }
}

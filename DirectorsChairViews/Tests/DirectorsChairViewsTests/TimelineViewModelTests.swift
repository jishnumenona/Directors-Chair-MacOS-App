// TimelineViewModelTests.swift
// Tests for TimelineViewModel: segment building, scene refresh, ID-based lookup

import XCTest
@testable import DirectorsChairViews
@testable import DirectorsChairCore

@MainActor
final class TimelineViewModelTests: XCTestCase {

    var viewModel: TimelineViewModel!

    override func setUp() {
        super.setUp()
        viewModel = TimelineViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Test Helpers

    private func makeTestProject() -> Project {
        let dialogue1 = Dialogue(character: "Alice", text: "Hello there!", chronologyNumber: 1)
        let dialogue2 = Dialogue(character: "Bob", text: "How are you today?", chronologyNumber: 2)
        let action1 = Action(description: "Alice smiles warmly", chronologyNumber: 3)
        let narration1 = Narration(text: "The sun sets behind them.", chronologyNumber: 4)

        let scene1 = Scene(
            name: "Scene 1 - EXT. PARK - DAY",
            dialogues: [dialogue1, dialogue2],
            actions: [action1],
            narrations: [narration1]
        )
        let scene2 = Scene(
            name: "Scene 2 - INT. CAFE - NIGHT",
            dialogues: [Dialogue(character: "Alice", text: "Coffee please.", chronologyNumber: 1)]
        )

        let sequence = Sequence(name: "Act 1", scenes: [scene1, scene2])
        return Project(
            name: "Test Project",
            characters: [Character(name: "Alice"), Character(name: "Bob")],
            sequences: [sequence]
        )
    }

    // MARK: - Segment Building Tests

    func testBuildSegmentsFromScene() {
        let project = makeTestProject()
        viewModel.setProject(project)
        viewModel.showScene(project.sequences[0].scenes[0])

        // Scene 1 has 4 items: 2 dialogues + 1 action + 1 narration
        XCTAssertFalse(viewModel.segments.isEmpty, "Should have segments after showScene")
        XCTAssertEqual(viewModel.segments.count, 4, "Should have one segment per timeline item")
    }

    func testSegmentsUpdateOnSceneSwitch() {
        let project = makeTestProject()
        viewModel.setProject(project)

        viewModel.showScene(project.sequences[0].scenes[0])
        let scene1SegmentCount = viewModel.segments.count

        viewModel.showScene(project.sequences[0].scenes[1])
        let scene2SegmentCount = viewModel.segments.count

        XCTAssertEqual(scene1SegmentCount, 4)
        XCTAssertEqual(scene2SegmentCount, 1, "Scene 2 has only 1 dialogue")
    }

    func testSegmentsUpdateOnContentChange() {
        var project = makeTestProject()
        viewModel.setProject(project)
        viewModel.showScene(project.sequences[0].scenes[0])

        let originalCount = viewModel.segments.count

        // Add a dialogue to the scene in the project
        let newDialogue = Dialogue(character: "Charlie", text: "May I join?", chronologyNumber: 5)
        project.sequences[0].scenes[0].dialogues.append(newDialogue)

        // Update project and refresh (simulating projectChanged event)
        viewModel.setProject(project)
        viewModel.refresh()

        XCTAssertEqual(viewModel.segments.count, originalCount + 1)
    }

    // MARK: - ID-Based Scene Lookup Tests

    func testCurrentSceneById() {
        let project = makeTestProject()
        viewModel.setProject(project)
        viewModel.showScene(project.sequences[0].scenes[0])

        // Modify the scene in the project (simulating external edit)
        var updatedProject = project
        updatedProject.sequences[0].scenes[0].dialogues[0].text = "Modified text!"
        viewModel.setProject(updatedProject)
        viewModel.refresh()

        // The rebuilt segments should reflect the updated text
        let aliceSegment = viewModel.segments.first { $0.character == "Alice" }
        XCTAssertNotNil(aliceSegment)
        XCTAssertEqual(aliceSegment?.text, "Modified text!")
    }

    func testStaleReferenceDoesNotBreak() {
        var project = makeTestProject()
        viewModel.setProject(project)
        viewModel.showScene(project.sequences[0].scenes[0])

        XCTAssertFalse(viewModel.segments.isEmpty)

        // Remove the scene from the project
        project.sequences[0].scenes.removeFirst()
        viewModel.setProject(project)
        viewModel.refresh()

        // Should gracefully handle missing scene
        XCTAssertTrue(viewModel.segments.isEmpty, "Should have no segments when scene is removed")
    }

    // MARK: - Duration Tests

    func testDurationEstimationPositive() {
        let project = makeTestProject()
        viewModel.setProject(project)
        viewModel.showScene(project.sequences[0].scenes[0])

        for segment in viewModel.segments {
            XCTAssertGreaterThan(segment.duration, 0, "All segments should have positive duration")
        }
    }

    func testEmptySceneNoSegments() {
        let emptyScene = Scene(name: "Empty Scene")
        let sequence = Sequence(name: "Act 1", scenes: [emptyScene])
        let project = Project(name: "Test", sequences: [sequence])

        viewModel.setProject(project)
        viewModel.showScene(emptyScene)

        XCTAssertTrue(viewModel.segments.isEmpty)
    }

    func testDialogueSegmentProperties() {
        let project = makeTestProject()
        viewModel.setProject(project)
        viewModel.showScene(project.sequences[0].scenes[0])

        let dialogueSegments = viewModel.segments.filter { $0.contentType == .dialogue }
        XCTAssertEqual(dialogueSegments.count, 2)

        // First dialogue should start at time 0
        let firstSegment = dialogueSegments.sorted(by: { $0.start < $1.start }).first!
        XCTAssertEqual(firstSegment.start, 0)
        XCTAssertEqual(firstSegment.character, "Alice")
    }

    func testActionSegmentProperties() {
        let project = makeTestProject()
        viewModel.setProject(project)
        viewModel.showScene(project.sequences[0].scenes[0])

        let actionSegments = viewModel.segments.filter { $0.contentType == .action }
        XCTAssertEqual(actionSegments.count, 1)
        XCTAssertEqual(actionSegments[0].character, "Action")
    }

    // MARK: - Zoom Tests

    func testZoomRecalculatesPositions() {
        let project = makeTestProject()
        viewModel.setProject(project)
        viewModel.showScene(project.sequences[0].scenes[0])

        let originalPxPerSec = viewModel.pxPerSec
        viewModel.setZoom(originalPxPerSec * 2)

        XCTAssertEqual(viewModel.pxPerSec, originalPxPerSec * 2)
    }

    // MARK: - Track Visibility Tests

    func testTrackVisibilityFiltering() {
        let project = makeTestProject()
        viewModel.setProject(project)
        viewModel.showScene(project.sequences[0].scenes[0])

        // Enable action track first (it defaults to false)
        viewModel.showAction = true
        let allCount = viewModel.visibleSegments.count

        // Now hide action track
        viewModel.showAction = false
        let withoutAction = viewModel.visibleSegments.count

        // Action segments should be filtered out
        let actionCount = viewModel.segments.filter { $0.contentType == .action }.count
        XCTAssertGreaterThan(actionCount, 0, "Should have at least one action segment")
        XCTAssertEqual(withoutAction, allCount - actionCount)
    }

    // MARK: - Refresh Tests

    func testRefreshAfterExternalChange() {
        var project = makeTestProject()
        viewModel.setProject(project)
        viewModel.showScene(project.sequences[0].scenes[0])

        let segmentsBefore = viewModel.segments.count

        // External change: add narration
        let newNarration = Narration(text: "A bird chirps overhead.", chronologyNumber: 5)
        project.sequences[0].scenes[0].narrations.append(newNarration)

        viewModel.setProject(project)
        viewModel.refresh()

        XCTAssertEqual(viewModel.segments.count, segmentsBefore + 1)
    }

    func testGlobalModeAggregatesSequences() {
        let project = makeTestProject()
        viewModel.setProject(project)
        viewModel.showGlobal()

        // Global mode should have segments from both scenes
        let scene1Dialogues = 2 // Alice + Bob
        let scene1Actions = 1
        let scene1Narrations = 1
        let scene2Dialogues = 1 // Alice coffee
        let expectedTotal = scene1Dialogues + scene1Actions + scene1Narrations + scene2Dialogues
        XCTAssertEqual(viewModel.segments.count, expectedTotal)
    }

    func testSequenceModeSegments() {
        let project = makeTestProject()
        viewModel.setProject(project)
        viewModel.showSequence(project.sequences[0])

        // Sequence mode aggregates all scenes in the sequence
        XCTAssertFalse(viewModel.segments.isEmpty)
        XCTAssertGreaterThanOrEqual(viewModel.segments.count, 5)
    }
    // MARK: - Cross-scope parity (WS5.6 — one shared appendScene behind all three rebuilds)

    /// The same scene must produce identical segments whether built in scene,
    /// sequence, or global scope (modulo the time offset of preceding scenes).
    func testSceneSegmentsIdenticalAcrossScopes() {
        let project = makeTestProject()
        let scene1 = project.sequences[0].scenes[0]

        viewModel.setProject(project)
        viewModel.showScene(scene1)
        let sceneSegs = viewModel.segments

        viewModel.showSequence(project.sequences[0])
        let seqSegs = viewModel.segments

        viewModel.showGlobal()
        let globalSegs = viewModel.segments

        // Scene 1 is first in both wider scopes, so its segments lead the list
        // with the same timings.
        XCTAssertGreaterThan(sceneSegs.count, 0)
        for (i, seg) in sceneSegs.enumerated() {
            XCTAssertEqual(seqSegs[i].sourceItemId, seg.sourceItemId, "seq order parity @\(i)")
            XCTAssertEqual(seqSegs[i].start, seg.start, accuracy: 0.001, "seq start parity @\(i)")
            XCTAssertEqual(seqSegs[i].duration, seg.duration, accuracy: 0.001, "seq duration parity @\(i)")
            XCTAssertEqual(globalSegs[i].sourceItemId, seg.sourceItemId, "global order parity @\(i)")
            XCTAssertEqual(globalSegs[i].start, seg.start, accuracy: 0.001, "global start parity @\(i)")
        }
    }

    /// Sequence scope must lay scenes back to back: scene 2's first segment
    /// starts after all of scene 1's content.
    func testSequenceScopeAccumulatesTime() {
        let project = makeTestProject()
        viewModel.setProject(project)

        viewModel.showScene(project.sequences[0].scenes[0])
        let scene1End = viewModel.segments.map { $0.start + $0.duration }.max() ?? 0
        let scene1Count = viewModel.segments.count

        viewModel.showSequence(project.sequences[0])
        XCTAssertGreaterThan(viewModel.segments.count, scene1Count, "sequence adds scene 2's segments")
        let scene2First = viewModel.segments[scene1Count].start
        XCTAssertGreaterThanOrEqual(scene2First, scene1End - 0.001, "scene 2 starts after scene 1 ends")
        XCTAssertEqual(viewModel.sceneBoundaries.count, 2, "one boundary per scene")
    }
}


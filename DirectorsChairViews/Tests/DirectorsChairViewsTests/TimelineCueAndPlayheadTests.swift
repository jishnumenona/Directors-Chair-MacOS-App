// TimelineCueAndPlayheadTests.swift
//
// Covers two timeline workflows at the view-model level:
//   E2E-STORY-003 — adding a lighting / SFX cue puts it on the timeline lane
//                   (cue appended to the published array the lane draws from).
//   E2E-TIMELINE-002 — "Move Playhead Here" seeks to a scene boundary
//                   (the scene → time mapping the context-menu action uses).

import XCTest
@testable import DirectorsChairViews
@testable import DirectorsChairCore

@MainActor
final class TimelineCueAndPlayheadTests: XCTestCase {

    var viewModel: TimelineViewModel!

    override func setUp() {
        super.setUp()
        viewModel = TimelineViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    private func makeProject() -> Project {
        let scene1 = Scene(
            name: "Scene 1 - EXT. PARK - DAY",
            dialogues: [Dialogue(character: "Alice", text: "Hello there!", chronologyNumber: 1),
                        Dialogue(character: "Bob", text: "How are you?", chronologyNumber: 2)],
            actions: [Action(description: "Alice smiles", chronologyNumber: 3)]
        )
        let scene2 = Scene(
            name: "Scene 2 - INT. CAFE - NIGHT",
            dialogues: [Dialogue(character: "Alice", text: "Coffee please.", chronologyNumber: 1)]
        )
        let sequence = Sequence(name: "Act 1", scenes: [scene1, scene2])
        return Project(name: "Test", characters: [Character(name: "Alice"), Character(name: "Bob")],
                       sequences: [sequence])
    }

    // MARK: - E2E-STORY-003: add a lighting / SFX cue

    func testAddLightCueAppendsToLaneWithAutoNumber() {
        var firedWith: [LightCue]?
        viewModel.onLightCuesChanged = { firedWith = $0 }

        XCTAssertTrue(viewModel.lightCues.isEmpty)
        viewModel.addLightCue(at: 12.0, name: "Warm wash")

        XCTAssertEqual(viewModel.lightCues.count, 1, "cue is on the lane's data source")
        XCTAssertEqual(viewModel.lightCues[0].cueNumber, "Q1", "auto-numbered")
        XCTAssertEqual(viewModel.lightCues[0].startTime, 12.0, accuracy: 0.001, "placed at the drag time")
        XCTAssertEqual(firedWith?.count, 1, "change callback fires so the lane redraws")

        viewModel.addLightCue(at: 30.0)
        XCTAssertEqual(viewModel.lightCues[1].cueNumber, "Q2", "second cue increments the number")
    }

    func testAddSFXCueAppendsToLaneWithAutoNumber() {
        var fired = false
        viewModel.onSFXCuesChanged = { _ in fired = true }

        viewModel.addSFXCue(at: 8.0, name: "Thunder", effectType: .smoke)

        XCTAssertEqual(viewModel.sfxCues.count, 1)
        XCTAssertEqual(viewModel.sfxCues[0].cueNumber, "FX1")
        XCTAssertEqual(viewModel.sfxCues[0].startTime, 8.0, accuracy: 0.001)
        XCTAssertTrue(fired, "SFX lane is notified")
    }

    // MARK: - E2E-TIMELINE-002: playhead seek to a scene boundary

    func testSceneBoundariesMapEachSceneToATime() {
        let project = makeProject()
        viewModel.setProject(project)
        viewModel.showSequence(project.sequences[0])

        XCTAssertEqual(viewModel.sceneBoundaries.count, 2, "one boundary per scene")

        // "Move Playhead Here" looks the target up by scene name — the mapping
        // must resolve for every scene.
        let b1 = viewModel.sceneBoundaries.first { $0.name == "Scene 1 - EXT. PARK - DAY" }
        let b2 = viewModel.sceneBoundaries.first { $0.name == "Scene 2 - INT. CAFE - NIGHT" }
        XCTAssertNotNil(b1, "scene 1 boundary resolvable by name")
        XCTAssertNotNil(b2, "scene 2 boundary resolvable by name")
    }

    func testSeekingToLaterSceneMovesPlayheadForward() {
        let project = makeProject()
        viewModel.setProject(project)
        viewModel.showSequence(project.sequences[0])

        let t1 = viewModel.sceneBoundaries.first { $0.name.contains("Scene 1") }?.time ?? -1
        let t2 = viewModel.sceneBoundaries.first { $0.name.contains("Scene 2") }?.time ?? -1

        XCTAssertGreaterThanOrEqual(t1, 0, "scene 1 boundary at or after the start")
        XCTAssertGreaterThan(t2, t1, "seeking to scene 2 moves the playhead to a later time than scene 1")
    }
}

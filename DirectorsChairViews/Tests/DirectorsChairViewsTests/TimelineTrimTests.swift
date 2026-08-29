// TimelineTrimTests.swift
//
// Trim-by-edge (owner request 2026-08-29): the pure snapping/clamping math,
// and that a trim is persisted per element type the way durations are stored
// today — a manual duration (+ manual start for a leading-edge drag) on the
// source row, and timelinePosition + duration on a shot.

import XCTest
@testable import DirectorsChairViews
@testable import DirectorsChairCore

final class TimelineTrimMathTests: XCTestCase {

    func testSnapRoundsToTenths() {
        XCTAssertEqual(TimelineTrim.snap(3.24), 3.2, accuracy: 1e-9)
        XCTAssertEqual(TimelineTrim.snap(3.25), 3.3, accuracy: 1e-9)
        XCTAssertEqual(TimelineTrim.snap(0.04), 0.0, accuracy: 1e-9)
        XCTAssertEqual(TimelineTrim.snap(12), 12, accuracy: 1e-9)
    }

    func testClampDurationNeverBelowHalfSecondAndSnapped() {
        XCTAssertEqual(TimelineTrim.clampDuration(0.2), 0.5, accuracy: 1e-9)
        XCTAssertEqual(TimelineTrim.clampDuration(-3), 0.5, accuracy: 1e-9)
        XCTAssertEqual(TimelineTrim.clampDuration(0.55), 0.6, accuracy: 1e-9)
        XCTAssertEqual(TimelineTrim.clampDuration(2.0), 2.0, accuracy: 1e-9)
        XCTAssertEqual(TimelineTrim.minimumDuration, 0.5)
        XCTAssertEqual(TimelineTrim.snapIncrement, 0.1, accuracy: 1e-9)
    }

    func testTrailingEdgeDragChangesOnlyTheDuration() {
        let r = TimelineTrim.resolve(edge: .trailing, start: 2, duration: 3, deltaSeconds: 1.26)
        XCTAssertEqual(r.start, 2, accuracy: 1e-9)
        XCTAssertEqual(r.duration, 4.3, accuracy: 1e-9)
    }

    func testTrailingEdgeCannotShrinkBelowMinimum() {
        let r = TimelineTrim.resolve(edge: .trailing, start: 2, duration: 3, deltaSeconds: -5)
        XCTAssertEqual(r.start, 2, accuracy: 1e-9)
        XCTAssertEqual(r.duration, 0.5, accuracy: 1e-9)
    }

    func testLeadingEdgeDragKeepsTheEndFixed() {
        let r = TimelineTrim.resolve(edge: .leading, start: 2, duration: 3, deltaSeconds: 1.0)
        XCTAssertEqual(r.start, 3, accuracy: 1e-9)
        XCTAssertEqual(r.duration, 2, accuracy: 1e-9)
        XCTAssertEqual(r.end, 5, accuracy: 1e-9)

        let grown = TimelineTrim.resolve(edge: .leading, start: 2, duration: 3, deltaSeconds: -0.74)
        XCTAssertEqual(grown.duration, 3.7, accuracy: 1e-9)
        XCTAssertEqual(grown.end, 5, accuracy: 1e-9)
    }

    func testLeadingEdgeStopsAtMinimumDuration() {
        let r = TimelineTrim.resolve(edge: .leading, start: 2, duration: 3, deltaSeconds: 10)
        XCTAssertEqual(r.duration, 0.5, accuracy: 1e-9)
        XCTAssertEqual(r.start, 4.5, accuracy: 1e-9)
    }

    func testLeadingEdgeStopsAtTheTimelineOrigin() {
        let r = TimelineTrim.resolve(edge: .leading, start: 1, duration: 2, deltaSeconds: -3)
        XCTAssertEqual(r.start, 0, accuracy: 1e-9)
        XCTAssertEqual(r.duration, 3, accuracy: 1e-9, "the end stays where it was")
    }

    func testDurationLabelShowsTenths() {
        XCTAssertEqual(TimelineTrim.label(for: 3.2), "3.2 s")
        XCTAssertEqual(TimelineTrim.label(for: 12), "12.0 s")
    }

    func testShotsTrackHeightIsClampedToItsRange() {
        XCTAssertEqual(TimelineLayoutConstants.clampedShotLaneHeight(10), TimelineLayoutConstants.minShotLaneHeight)
        XCTAssertEqual(TimelineLayoutConstants.clampedShotLaneHeight(10_000), TimelineLayoutConstants.maxShotLaneHeight)
        XCTAssertEqual(TimelineLayoutConstants.clampedShotLaneHeight(120), 120)
        XCTAssertEqual(TimelineLayoutConstants.clampedShotLaneHeight(.nan), TimelineLayoutConstants.shotLaneHeight)
        XCTAssertGreaterThanOrEqual(TimelineLayoutConstants.shotLaneHeight, TimelineLayoutConstants.minShotLaneHeight)
    }

    func testManualDurationWinsOverFallbackOnlyWhenPositive() {
        XCTAssertEqual(DurationEstimator.effectiveDuration(manualDuration: 4.5, fallback: 2), 4.5)
        XCTAssertEqual(DurationEstimator.effectiveDuration(manualDuration: nil, fallback: 2), 2)
        XCTAssertEqual(DurationEstimator.effectiveDuration(manualDuration: 0, fallback: 2), 2)
        XCTAssertEqual(DurationEstimator.effectiveDuration(manualDuration: -1, fallback: 2), 2)
    }
}

@MainActor
final class TimelineTrimPersistenceTests: XCTestCase {

    private var viewModel: TimelineViewModel!

    override func setUp() {
        super.setUp()
        viewModel = TimelineViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    private func makeProject() -> Project {
        let scene = Scene(
            uuid: "scene-1",
            name: "Scene 1 - EXT. PARK - DAY",
            dialogues: [Dialogue(uuid: "d-1", character: "Alice", text: "Hello there, how are you today?", chronologyNumber: 1)],
            actions: [Action(uuid: "a-1", description: "Alice smiles warmly", chronologyNumber: 2),
                      Action(uuid: "a-linked", description: "(beat)", chronologyNumber: 5, parentDialogueId: "d-1")],
            narrations: [Narration(uuid: "n-1", text: "The sun sets behind them.", chronologyNumber: 3)],
            soundNotes: [SoundNote(uuid: "s-1", description: "Wind", chronologyNumber: 4)],
            shots: [Shot(uuid: "shot-1", shotId: 1, description: "Wide on the park", duration: 3)]
        )
        return Project(name: "Trim", characters: [Character(name: "Alice")],
                       sequences: [Sequence(name: "Act 1", scenes: [scene])])
    }

    private func segment(_ sourceId: String) -> TimelineSegment {
        guard let seg = viewModel.segments.first(where: { $0.sourceItemId == sourceId }) else {
            XCTFail("no segment for \(sourceId)")
            return TimelineSegment(start: 0, duration: 0, character: "", color: "", text: "", sceneName: "", contentType: .note)
        }
        return seg
    }

    private func scene() -> Scene { viewModel.getProject()!.sequences[0].scenes[0] }

    // MARK: Rebuild honours the manual durations

    func testRebuildHonoursManualDurationOnActionNarrationAndSoundNote() {
        var project = makeProject()
        project.sequences[0].scenes[0].actions[0].manualDuration = 4.5
        project.sequences[0].scenes[0].narrations[0].manualDuration = 6.0
        project.sequences[0].scenes[0].soundNotes[0].manualDuration = 1.5
        viewModel.setProject(project)
        viewModel.showScene(project.sequences[0].scenes[0])

        XCTAssertEqual(segment("a-1").duration, 4.5, accuracy: 1e-6)
        XCTAssertEqual(segment("n-1").duration, 6.0, accuracy: 1e-6)
        XCTAssertEqual(segment("s-1").duration, 1.5, accuracy: 1e-6)
        // The trimmed action pushes the narration after it, exactly like a dialogue's manual duration does
        XCTAssertEqual(segment("n-1").start, segment("a-1").start + 4.5, accuracy: 1e-6)
    }

    func testRebuildHonoursManualDurationOnAConnectedAction() {
        var project = makeProject()
        project.sequences[0].scenes[0].actions[1].manualDuration = 1.2
        viewModel.setProject(project)
        viewModel.showScene(project.sequences[0].scenes[0])

        let linked = segment("a-linked")
        XCTAssertEqual(linked.duration, 1.2, accuracy: 1e-6, "not the parent dialogue's duration")
        XCTAssertEqual(linked.start, segment("d-1").start, accuracy: 1e-6, "still anchored to its parent")
    }

    func testWithoutManualDurationActionsKeepTheFixedDefault() {
        let project = makeProject()
        viewModel.setProject(project)
        viewModel.showScene(project.sequences[0].scenes[0])
        XCTAssertEqual(segment("a-1").duration, TimelineWPMConstants.actionDuration, accuracy: 1e-6)
    }

    // MARK: Trimming persists per element type

    func testTrailingTrimOfADialoguePersistsAManualDurationOnly() {
        let project = makeProject()
        viewModel.setProject(project)
        viewModel.showScene(project.sequences[0].scenes[0])
        let seg = segment("d-1")

        viewModel.trimSegment(id: seg.id, newStart: seg.start, newDuration: 4.2)

        XCTAssertEqual(scene().dialogues[0].manualDuration, 4.2)
        XCTAssertNil(scene().dialogues[0].manualStartTime, "the start did not move")
        XCTAssertEqual(segment("d-1").duration, 4.2, accuracy: 1e-6)

        // The block keeps the dragged size across a rebuild
        viewModel.setProject(viewModel.getProject()!)
        viewModel.refresh()
        XCTAssertEqual(segment("d-1").duration, 4.2, accuracy: 1e-6)
    }

    func testLeadingTrimOfAnActionPersistsStartAndDuration() {
        let project = makeProject()
        viewModel.setProject(project)
        viewModel.showScene(project.sequences[0].scenes[0])
        let seg = segment("a-1")
        let end = seg.end

        viewModel.trimSegment(id: seg.id, newStart: end - 1.5, newDuration: 1.5)

        XCTAssertEqual(scene().actions[0].manualDuration, 1.5)
        XCTAssertEqual(scene().actions[0].manualStartTime ?? -1, Double(end - 1.5), accuracy: 1e-6)

        viewModel.setProject(viewModel.getProject()!)
        viewModel.refresh()
        XCTAssertEqual(segment("a-1").start, end - 1.5, accuracy: 1e-6)
        XCTAssertEqual(segment("a-1").duration, 1.5, accuracy: 1e-6)
        XCTAssertEqual(segment("a-1").end, end, accuracy: 1e-6, "the end stayed put")
    }

    func testTrimOfNarrationAndSoundNotePersistManualDurations() {
        let project = makeProject()
        viewModel.setProject(project)
        viewModel.showScene(project.sequences[0].scenes[0])

        let narration = segment("n-1")
        viewModel.trimSegment(id: narration.id, newStart: narration.start, newDuration: 7.3)
        let sound = segment("s-1")
        viewModel.trimSegment(id: sound.id, newStart: sound.start, newDuration: 2.4)

        XCTAssertEqual(scene().narrations[0].manualDuration, 7.3)
        XCTAssertEqual(scene().soundNotes[0].manualDuration, 2.4)

        viewModel.setProject(viewModel.getProject()!)
        viewModel.refresh()
        XCTAssertEqual(segment("n-1").duration, 7.3, accuracy: 1e-6)
        XCTAssertEqual(segment("s-1").duration, 2.4, accuracy: 1e-6)
    }

    func testTrimNeverPersistsLessThanTheMinimumDuration() {
        let project = makeProject()
        viewModel.setProject(project)
        viewModel.showScene(project.sequences[0].scenes[0])
        let seg = segment("d-1")

        viewModel.trimSegment(id: seg.id, newStart: seg.start, newDuration: 0.1)

        XCTAssertEqual(scene().dialogues[0].manualDuration, Double(TimelineTrim.minimumDuration))
        XCTAssertEqual(segment("d-1").duration, TimelineTrim.minimumDuration, accuracy: 1e-6)
    }

    func testTrimExtendsTheTimelineWhenDraggedPastItsEnd() {
        let project = makeProject()
        viewModel.setProject(project)
        viewModel.showScene(project.sequences[0].scenes[0])
        let seg = segment("s-1")   // an unplaced sound note floats at the end of the scene

        viewModel.trimSegment(id: seg.id, newStart: seg.start, newDuration: 60)

        XCTAssertGreaterThanOrEqual(viewModel.totalDuration, seg.start + 60 - 1e-6)
    }

    func testTrimShotLabelPersistsPositionAndDuration() {
        let project = makeProject()
        viewModel.setProject(project)
        viewModel.showScene(project.sequences[0].scenes[0])
        let sceneName = project.sequences[0].scenes[0].name

        viewModel.trimShotLabel(shotId: 1, sceneName: sceneName, newTime: 2.5, newDuration: 4.0)

        XCTAssertEqual(scene().shots[0].timelinePosition, 2.5)
        XCTAssertEqual(scene().shots[0].duration, 4.0)
        let label = viewModel.shotLabels.first { $0.shotId == 1 }
        XCTAssertEqual(label?.time ?? -1, 2.5, accuracy: 1e-6)
        XCTAssertEqual(label?.duration ?? -1, 4.0, accuracy: 1e-6)

        // Survives a rebuild (position override + stored duration)
        viewModel.setProject(viewModel.getProject()!)
        viewModel.refresh()
        let rebuilt = viewModel.shotLabels.first { $0.shotId == 1 }
        XCTAssertEqual(rebuilt?.time ?? -1, 2.5, accuracy: 1e-6)
        XCTAssertEqual(rebuilt?.duration ?? -1, 4.0, accuracy: 1e-6)
    }
}

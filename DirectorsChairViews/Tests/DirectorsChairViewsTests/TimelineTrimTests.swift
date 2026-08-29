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

    // MARK: Per-type minimums (owner 2026-08-29)

    private func segment(_ type: TimelineSegment.ContentType, text: String) -> TimelineSegment {
        TimelineSegment(start: 0, duration: 3, character: type == .dialogue ? "Alice" : "Action",
                        color: "#FFFFFF", text: text, sceneName: "S", contentType: type)
    }

    func testActionNarrationAndSoundBlocksTrimDownToTheFloorWhateverTheirText() {
        let essay = String(repeating: "A long description that would need a very wide block. ", count: 4)
        for type in [TimelineSegment.ContentType.action, .narration, .soundNote] {
            XCTAssertEqual(TimelineTrim.minimumSeconds(for: segment(type, text: essay), pxPerSec: 60, showThumbs: true),
                           TimelineTrim.minimumDuration, "\(type)")
        }
    }

    func testDialogueMinimumIsItsLabelWidthAtTheCurrentZoom() {
        let seg = segment(.dialogue, text: "Hello there, how are you today?")
        let labelWidth = DurationEstimator.dialogueLabelWidth(for: seg.text, showThumbs: false)
        let minimum = TimelineTrim.minimumSeconds(for: seg, pxPerSec: 60, showThumbs: false)

        XCTAssertGreaterThanOrEqual(minimum * 60, labelWidth - 1e-6, "the block at its minimum still shows the whole label")
        XCTAssertLessThan(minimum * 60 - labelWidth, 6 + 1e-6, "…rounded up to the next 0.1 s, no further")
        XCTAssertEqual(minimum, TimelineTrim.snap(minimum), accuracy: 1e-9, "on the trim grid")

        // Zoomed in, the same label needs fewer seconds; with avatars it needs more; a longer line needs more
        XCTAssertLessThan(TimelineTrim.minimumSeconds(for: seg, pxPerSec: 120, showThumbs: false), minimum)
        XCTAssertGreaterThan(TimelineTrim.minimumSeconds(for: seg, pxPerSec: 60, showThumbs: true), minimum)
        let longer = segment(.dialogue, text: seg.text + " I was hoping we could talk about the plan for tonight.")
        XCTAssertGreaterThan(TimelineTrim.minimumSeconds(for: longer, pxPerSec: 60, showThumbs: false), minimum)
    }

    func testDialogueMinimumNeverDropsBelowTheFloorNorAboveTheWidestBubble() {
        XCTAssertEqual(TimelineTrim.minimumSeconds(for: segment(.dialogue, text: ""), pxPerSec: 240, showThumbs: false),
                       TimelineTrim.minimumDuration)
        let novel = String(repeating: "word ", count: 300)
        let capped = TimelineTrim.minimumSeconds(for: segment(.dialogue, text: novel), pxPerSec: 60, showThumbs: false)
        XCTAssertEqual(capped, TimelineTrim.snapUp(TimelineLayoutConstants.maxTextBasedBubbleWidth / 60), accuracy: 1e-9,
                       "a very long line is capped like the bubble itself")
        XCTAssertEqual(TimelineTrim.minimumSeconds(for: segment(.dialogue, text: novel), pxPerSec: 0, showThumbs: false),
                       TimelineTrim.minimumDuration, "no zoom, no label-based floor")
    }

    func testLabelWidthNeverUnderTheCanvasEstimateAndGrowsWithTheText() {
        let short = "Hello there, how are you today?"
        XCTAssertGreaterThanOrEqual(DurationEstimator.labelWidth(for: short),
                                    CGFloat(short.count) * TimelineLayoutConstants.minWidthPerCharacter,
                                    "the canvas truncates by this estimate, so the label is never narrower than it")
        XCTAssertGreaterThan(DurationEstimator.labelWidth(for: "WWWWWWWWWW"), DurationEstimator.labelWidth(for: "iiiiiiiiii") - 1e-6,
                             "wide glyphs measure at least as wide as narrow ones")
        XCTAssertEqual(DurationEstimator.labelWidth(for: ""), 0)
        XCTAssertEqual(DurationEstimator.labelWidth(for: "<p>Hi</p>"), DurationEstimator.labelWidth(for: "Hi"), "HTML is stripped")
        XCTAssertEqual(DurationEstimator.displayLabel(for: "  Line one\nline two  "), "Line one line two")
        XCTAssertEqual(DurationEstimator.displayLabel(for: String(repeating: "x", count: 250)).count,
                       TimelineLayoutConstants.maxTextDisplayLength + 3)
    }

    func testClampAndResolveHonourAPerBlockMinimum() {
        XCTAssertEqual(TimelineTrim.clampDuration(1.0, minimumSeconds: 2.3), 2.3, accuracy: 1e-9)
        XCTAssertEqual(TimelineTrim.clampDuration(4.26, minimumSeconds: 2.3), 4.3, accuracy: 1e-9)
        XCTAssertEqual(TimelineTrim.clampDuration(0.1, minimumSeconds: 0.2), 0.5, accuracy: 1e-9, "the 0.5 s floor always holds")
        XCTAssertEqual(TimelineTrim.snapUp(4.4583), 4.5, accuracy: 1e-9)
        XCTAssertEqual(TimelineTrim.snapUp(4.5), 4.5, accuracy: 1e-9, "an exact tenth stays put")

        let trailing = TimelineTrim.resolve(edge: .trailing, start: 2, duration: 5, deltaSeconds: -4, minimumSeconds: 2.3)
        XCTAssertEqual(trailing.start, 2, accuracy: 1e-9)
        XCTAssertEqual(trailing.duration, 2.3, accuracy: 1e-9)

        let leading = TimelineTrim.resolve(edge: .leading, start: 2, duration: 5, deltaSeconds: 4, minimumSeconds: 2.3)
        XCTAssertEqual(leading.duration, 2.3, accuracy: 1e-9)
        XCTAssertEqual(leading.end, 7, accuracy: 1e-9, "the end stays put")

        let pinned = TimelineTrim.resolve(edge: .leading, start: 0.5, duration: 1, deltaSeconds: -3, minimumSeconds: 2.3)
        XCTAssertEqual(pinned.start, 0, accuracy: 1e-9)
        XCTAssertEqual(pinned.duration, 2.3, accuracy: 1e-9, "pinned at the origin, never under the block's floor")

        // Without a per-block minimum nothing changes for shots and the like
        let plain = TimelineTrim.resolve(edge: .trailing, start: 2, duration: 3, deltaSeconds: -5)
        XCTAssertEqual(plain.duration, 0.5, accuracy: 1e-9)
    }

    func testClippedBlocksAreDrawnAtTheirDurationAndDialoguesAtTheirLabel() {
        let essay = String(repeating: "Alice crosses the room slowly. ", count: 3)
        let action = TimelineSegment(start: 0, duration: 0.5, character: "Action", color: "#FF9500",
                                     text: essay, sceneName: "S", contentType: .action)
        XCTAssertEqual(DurationEstimator.bubbleWidth(for: action, pxPerSec: 60, showThumbs: true), 30, accuracy: 1e-9,
                       "0.5 s at 60 px/s — the text clips inside")
        XCTAssertEqual(DurationEstimator.bubbleWidth(for: action, pxPerSec: 20, showThumbs: true),
                       TimelineLayoutConstants.minClippedBubbleWidth, accuracy: 1e-9,
                       "room for the tail and grips at any zoom")

        let dialogue = TimelineSegment(start: 0, duration: 0.5, character: "Alice", color: "#FFF",
                                       text: essay, sceneName: "S", contentType: .dialogue)
        XCTAssertEqual(DurationEstimator.bubbleWidth(for: dialogue, pxPerSec: 60, showThumbs: false),
                       min(DurationEstimator.dialogueLabelWidth(for: essay, showThumbs: false),
                           TimelineLayoutConstants.maxTextBasedBubbleWidth),
                       accuracy: 1e-9, "a dialogue never hides its line")
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

        viewModel.trimSegment(id: seg.id, newStart: seg.start, newDuration: 6.2)   // above this line's label floor (4.5 s at the default zoom with thumbnails)

        XCTAssertEqual(scene().dialogues[0].manualDuration, 6.2)
        XCTAssertNil(scene().dialogues[0].manualStartTime, "the start did not move")
        XCTAssertEqual(segment("d-1").duration, 6.2, accuracy: 1e-6)

        // The block keeps the dragged size across a rebuild
        viewModel.setProject(viewModel.getProject()!)
        viewModel.refresh()
        XCTAssertEqual(segment("d-1").duration, 6.2, accuracy: 1e-6)
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
        let seg = segment("a-1")   // an action goes right down to the floor, whatever its text

        viewModel.trimSegment(id: seg.id, newStart: seg.start, newDuration: 0.1)

        XCTAssertEqual(scene().actions[0].manualDuration, Double(TimelineTrim.minimumDuration))
        XCTAssertEqual(segment("a-1").duration, TimelineTrim.minimumDuration, accuracy: 1e-6)
    }

    func testADialogueTrimNeverPersistsLessThanItsLabelNeeds() {
        let project = makeProject()
        viewModel.setProject(project)
        viewModel.showScene(project.sequences[0].scenes[0])
        let seg = segment("d-1")
        let floor = TimelineTrim.minimumSeconds(for: seg, pxPerSec: viewModel.pxPerSec, showThumbs: viewModel.showThumbs)
        XCTAssertGreaterThan(floor, TimelineTrim.minimumDuration, "this line needs more than half a second of width")

        viewModel.trimSegment(id: seg.id, newStart: seg.start, newDuration: 0.1)

        XCTAssertEqual(scene().dialogues[0].manualDuration ?? -1, Double(floor), accuracy: 1e-9)
        XCTAssertEqual(segment("d-1").duration, floor, accuracy: 1e-6)

        // Zoomed in, the same label needs less time — the floor follows the zoom
        viewModel.setZoom(viewModel.pxPerSec * 2)
        XCTAssertLessThan(TimelineTrim.minimumSeconds(for: seg, pxPerSec: viewModel.pxPerSec, showThumbs: viewModel.showThumbs), floor)
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

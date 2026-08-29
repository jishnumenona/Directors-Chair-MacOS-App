//
//  SurfaceMergeTests.swift
//  DirectorsChairCoreTests
//
//  Audit 2026-08-28 P0: a surface's stale project copy must never revert
//  edits made elsewhere — only the fields it owns come back.
//

import XCTest
@testable import DirectorsChairCore

final class SurfaceMergeTests: XCTestCase {

    private func fixture() -> Project {
        var project = Project(name: "Film")
        let shot = Shot(uuid: "shot-1", shotId: 1, description: "Wide on the cottage", duration: 4)
        let line = Dialogue(uuid: "d-1", character: "Mara", text: "Run.", chronologyNumber: 1)
        let scene = Scene(uuid: "scene-1", name: "Cottage", description: "Dawn", dialogues: [line], shots: [shot])
        project.sequences = [Sequence(uuid: "seq-1", name: "Act 1", scenes: [scene])]
        return project
    }

    func testTimelineEditsComeBackAndNothingElseDoes() {
        let live0 = fixture()
        // The timeline took its copy here…
        var timelineCopy = live0
        // …then the user edited the schedule, the script and a shot description elsewhere.
        var live = live0
        live.budget = "$5,000"                                   // a production-side edit
        live.sequences[0].scenes[0].dialogues[0].text = "Run. Now."
        live.sequences[0].scenes[0].shots[0].description = "Wide on the cottage, storm coming"
        // Meanwhile the timeline moved the shot and the line and voiced it.
        timelineCopy.sequences[0].scenes[0].shots[0].timelinePosition = 12.5
        timelineCopy.sequences[0].scenes[0].shots[0].duration = 6
        timelineCopy.sequences[0].scenes[0].dialogues[0].manualStartTime = 3.25
        timelineCopy.sequences[0].scenes[0].dialogues[0].audioFilePath = "assets/audio/dialogues/d-1.wav"

        let merged = live.adoptingTimelineEdits(from: timelineCopy)
        XCTAssertEqual(merged.sequences[0].scenes[0].shots[0].timelinePosition, 12.5)
        XCTAssertEqual(merged.sequences[0].scenes[0].shots[0].duration, 6)
        XCTAssertEqual(merged.sequences[0].scenes[0].dialogues[0].manualStartTime, 3.25)
        XCTAssertEqual(merged.sequences[0].scenes[0].dialogues[0].audioFilePath, "assets/audio/dialogues/d-1.wav")
        XCTAssertEqual(merged.budget, "$5,000", "the production edit survives")
        XCTAssertEqual(merged.sequences[0].scenes[0].dialogues[0].text, "Run. Now.", "the script edit survives")
        XCTAssertEqual(merged.sequences[0].scenes[0].shots[0].description, "Wide on the cottage, storm coming")
    }

    func testTimelineMergeIgnoresScenesAndRowsThatNoLongerExist() {
        let live0 = fixture()
        var timelineCopy = live0
        timelineCopy.sequences[0].scenes[0].shots[0].timelinePosition = 1
        var live = live0
        live.sequences[0].scenes[0].shots = []               // the shot was deleted meanwhile
        live.sequences[0].scenes.append(Scene(uuid: "scene-2", name: "Later"))
        let merged = live.adoptingTimelineEdits(from: timelineCopy)
        XCTAssertTrue(merged.sequences[0].scenes[0].shots.isEmpty, "a deleted shot is not resurrected")
        XCTAssertEqual(merged.sequences[0].scenes.count, 2, "a scene added meanwhile stays")
    }

    func testShotsMergeReplacesOnlyTheScenesShots() {
        let live0 = fixture()
        var adapterCopy = live0
        var live = live0
        live.projectBudget = ProjectBudget(currency: "USD")
        live.sequences[0].scenes[0].description = "Dawn, storm coming"
        adapterCopy.sequences[0].scenes[0].shots.append(Shot(uuid: "shot-2", shotId: 2, description: "Insert"))
        adapterCopy.sequences[0].scenes[0].description = "stale"   // the adapter's copy predates the edit

        let merged = live.adoptingShots(from: adapterCopy)
        XCTAssertEqual(merged.sequences[0].scenes[0].shots.map(\.uuid), ["shot-1", "shot-2"])
        XCTAssertEqual(merged.sequences[0].scenes[0].description, "Dawn, storm coming", "not the adapter's stale copy")
        XCTAssertNotNil(merged.projectBudget, "the budget edit survives")
    }

    func testShotsMergeNeverResurrectsADeletedSceneButSeedsAnEmptyProject() {
        let live0 = fixture()
        var adapterCopy = live0
        adapterCopy.sequences[0].scenes.append(Scene(uuid: "scene-ghost", name: "Deleted meanwhile"))
        var live = live0
        let merged = live.adoptingShots(from: adapterCopy)
        XCTAssertEqual(merged.sequences[0].scenes.map(\.uuid), ["scene-1"])

        live.sequences = []
        let seeded = live.adoptingShots(from: adapterCopy)
        XCTAssertEqual(seeded.sequences.count, 1, "an empty project takes the shot list's structure")
    }
}

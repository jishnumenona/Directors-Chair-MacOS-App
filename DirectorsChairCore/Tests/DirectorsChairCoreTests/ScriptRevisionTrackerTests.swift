// DirectorsChairCoreTests/ScriptRevisionTrackerTests.swift
//
// Script revisions (§2.18). The promises under test: locked numbers
// never change once printed, change detection derives from what a scene
// SAYS (stable across launches, no edit hooks to drift), rounds follow
// the industry color order, and inserted scenes take letter numbers
// that keep every existing number true.

import XCTest
@testable import DirectorsChairCore

final class ScriptRevisionTrackerTests: XCTestCase {

    private func makeProject(sceneNames: [String] = ["One", "Two", "Three"]) -> Project {
        var project = Project(name: "Rev Test")
        project.sequences = [Sequence(
            name: "Act 1",
            scenes: sceneNames.map { name in
                var scene = Scene(name: name)
                scene.actions = [Action(description: "\(name) happens.",
                                        chronologyNumber: 1)]
                return scene
            })]
        return project
    }

    func testLockFreezesNumbersAndOpensThePaperTrail() {
        var project = makeProject()
        ScriptRevisionTracker.lock(&project, date: "2026-08-08T00:00:00Z")

        XCTAssertEqual(project.sequences[0].scenes.map(\.lockedNumber),
                       ["1", "2", "3"])
        XCTAssertEqual(project.scriptRevisionColor, "White")
        XCTAssertEqual(project.scriptRevisionHistory.map(\.color), ["White"])
        XCTAssertEqual(project.scriptRevisionBaseline.count, 3)

        // Locking twice must be a no-op — numbers are promises.
        project.sequences[0].scenes[0].lockedNumber = "1"
        ScriptRevisionTracker.lock(&project, date: "2026-08-09T00:00:00Z")
        XCTAssertEqual(project.scriptRevisionHistory.count, 1)
    }

    func testFingerprintIsStableAndTracksWhatTheSceneSays() {
        let scene = makeProject().sequences[0].scenes[0]
        XCTAssertEqual(ScriptRevisionTracker.fingerprint(scene),
                       ScriptRevisionTracker.fingerprint(scene),
                       "same content, same fingerprint — every time")

        var edited = scene
        edited.dialogues.append(Dialogue(character: "Mara",
                                         text: "New line.",
                                         chronologyNumber: 2,
                                         globalChronologyNumber: 2))
        XCTAssertNotEqual(ScriptRevisionTracker.fingerprint(scene),
                          ScriptRevisionTracker.fingerprint(edited),
                          "a new line of dialogue IS a script change")

        var reshot = scene
        reshot.productionStatus = "Shot"
        XCTAssertEqual(ScriptRevisionTracker.fingerprint(scene),
                       ScriptRevisionTracker.fingerprint(reshot),
                       "production bookkeeping is not a script change")
    }

    func testAdvanceStampsOnlyChangedScenesAndResetsTheBaseline() {
        var project = makeProject()
        ScriptRevisionTracker.lock(&project, date: "d0")

        project.sequences[0].scenes[1].actions[0].description = "Rewritten."
        let live = ScriptRevisionTracker.changedSinceRoundStart(project)
        XCTAssertEqual(live, [project.sequences[0].scenes[1].id],
                       "the live marks show the open round's changes")

        let stamped = ScriptRevisionTracker.advance(&project, date: "d1")
        XCTAssertEqual(stamped, ["2"])
        XCTAssertEqual(project.sequences[0].scenes.map(\.revisionColor),
                       [nil, "Blue", nil],
                       "only the changed scene wears the round's color")
        XCTAssertEqual(project.scriptRevisionColor, "Blue")
        XCTAssertEqual(project.scriptRevisionHistory.last?.changedSceneNumbers,
                       ["2"])
        XCTAssertTrue(ScriptRevisionTracker.changedSinceRoundStart(project)
            .isEmpty, "advancing closes the round — marks reset")

        // A second round re-stamps in the next color.
        project.sequences[0].scenes[1].actions[0].description = "Again."
        ScriptRevisionTracker.advance(&project, date: "d2")
        XCTAssertEqual(project.sequences[0].scenes[1].revisionColor, "Pink")
    }

    func testInsertedScenesTakeLetterNumbersExistingNumbersKeep() {
        var project = makeProject()
        ScriptRevisionTracker.lock(&project, date: "d0")

        var inserted = Scene(name: "Inserted")
        inserted.actions = [Action(description: "New.", chronologyNumber: 1)]
        project.sequences[0].scenes.insert(inserted, at: 1)   // between 1 and 2
        var second = Scene(name: "Second insert")
        second.actions = [Action(description: "Newer.", chronologyNumber: 1)]
        project.sequences[0].scenes.insert(second, at: 2)     // after Inserted

        ScriptRevisionTracker.advance(&project, date: "d1")
        XCTAssertEqual(project.sequences[0].scenes.map(\.lockedNumber),
                       ["1", "1A", "1B", "2", "3"],
                       "letters slot in; 1, 2, 3 never move")
        XCTAssertEqual(project.sequences[0].scenes[1].revisionColor, "Blue",
                       "a new scene is by definition changed this round")
    }

    func testHeadInsertsArePrefixedSoTheyReadBeforeSceneOne() {
        var project = makeProject()
        ScriptRevisionTracker.lock(&project, date: "d0")

        var opening = Scene(name: "New opening")
        opening.actions = [Action(description: "Cold open.", chronologyNumber: 1)]
        var colder = Scene(name: "Even earlier")
        colder.actions = [Action(description: "Pre-open.", chronologyNumber: 1)]
        project.sequences[0].scenes.insert(opening, at: 0)
        project.sequences[0].scenes.insert(colder, at: 1)

        ScriptRevisionTracker.advance(&project, date: "d1")
        XCTAssertEqual(project.sequences[0].scenes.map(\.lockedNumber),
                       ["A1", "B1", "1", "2", "3"],
                       "before scene 1 the letter goes in FRONT — 1A would "
                       + "read as after")
    }

    func testColorOrderFollowsTheIndustryProgressionAndWraps() {
        var color: String? = nil
        var seen: [String] = []
        for _ in 0..<10 {
            let next = ScriptRevisionTracker.nextColor(after: color)
            seen.append(next)
            color = next
        }
        XCTAssertEqual(seen, ["Blue", "Pink", "Yellow", "Green", "Goldenrod",
                              "Buff", "Salmon", "Cherry", "2nd Blue",
                              "2nd Pink"])
        XCTAssertEqual(ScriptRevisionTracker.nextColor(after: "White"), "Blue")
    }

    func testLegacyProjectsDecodeWithoutRevisionFields() throws {
        let legacy = Data("""
        {"name": "Old", "sequences": [{"name": "Act 1",
         "scenes": [{"name": "Scene 1"}]}]}
        """.utf8)
        let project = try JSONDecoder().decode(Project.self, from: legacy)
        XCTAssertNil(project.scriptRevisionColor)
        XCTAssertTrue(project.scriptRevisionHistory.isEmpty)
        XCTAssertTrue(project.scriptRevisionBaseline.isEmpty)
        XCTAssertNil(project.sequences[0].scenes[0].lockedNumber)

        // And an unlocked project reports nothing changed — there is no
        // baseline to compare against.
        XCTAssertTrue(ScriptRevisionTracker
            .changedSinceRoundStart(project).isEmpty)
        var mutable = project
        XCTAssertEqual(ScriptRevisionTracker.advance(&mutable, date: "d"), [],
                       "advance before lock is a refusal, not a crash")
    }

    func testRevisionStateRoundTripsThroughJSON() throws {
        var project = makeProject()
        ScriptRevisionTracker.lock(&project, date: "d0")
        project.sequences[0].scenes[0].actions[0].description = "Changed."
        ScriptRevisionTracker.advance(&project, date: "d1")

        let reloaded = try JSONDecoder().decode(
            Project.self, from: JSONEncoder().encode(project))
        XCTAssertEqual(reloaded.scriptRevisionColor, "Blue")
        XCTAssertEqual(reloaded.scriptRevisionHistory.map(\.color),
                       ["White", "Blue"])
        XCTAssertEqual(reloaded.sequences[0].scenes[0].revisionColor, "Blue")
        XCTAssertEqual(reloaded.sequences[0].scenes[0].lockedNumber, "1")
        XCTAssertEqual(reloaded.scriptRevisionBaseline,
                       project.scriptRevisionBaseline)
    }
}

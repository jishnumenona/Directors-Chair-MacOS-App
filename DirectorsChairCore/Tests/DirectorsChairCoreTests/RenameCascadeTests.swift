// DirectorsChairCore/Tests/DirectorsChairCoreTests/RenameCascadeTests.swift
//
// WS2.5b: renaming a character or location must cascade to every string that
// references it — no orphaned references.

import XCTest
@testable import DirectorsChairCore

final class RenameCascadeTests: XCTestCase {

    private func makeProject() -> Project {
        var project = Project(name: "P")

        var scene = Scene(name: "S1")
        scene.location = "Warehouse"
        scene.primaryCharacter = "Alex"
        scene.dialogues = [Dialogue(character: "Alex", text: "Hi", chronologyNumber: 1),
                           Dialogue(character: "Sam", text: "Yo", chronologyNumber: 2)]
        scene.actions = [Action(description: "walks", chronologyNumber: 3)]
        scene.actions[0].characters = ["Alex", "Sam"]
        scene.narrations = [Narration(text: "later", chronologyNumber: 4)]
        scene.narrations[0].characters = ["Alex"]

        var seq = Sequence(name: "Act 1")
        seq.location = "Warehouse"
        seq.scenes = [scene]
        project.sequences = [seq]

        var costume = Costume(name: "Coat")
        costume.character = "Alex"
        project.costumes = [costume]

        var cast = CastMember(actorName: "Jo Doe")
        cast.characterName = "Alex"
        project.castMembers = [cast]

        var card = VisionCard(title: "Look")
        card.character = "Alex"
        project.beats = [card]

        var item = ScheduleItem(sceneName: "S1")
        item.location = "Warehouse"
        project.scheduleItems = [item]

        var task = GanttTask(name: "Shoot S1")
        task.locationNames = ["Warehouse", "Beach"]
        project.ganttTasks = [task]

        return project
    }

    func testCharacterRenameCascadesEverywhere() {
        var p = makeProject()
        let updated = p.cascadeCharacterRename(from: "Alex", to: "Alexandra")

        XCTAssertEqual(updated, 7, "primaryCharacter + dialogue + action + narration + costume + cast + visionCard")
        let scene = p.sequences[0].scenes[0]
        XCTAssertEqual(scene.primaryCharacter, "Alexandra")
        XCTAssertEqual(scene.dialogues[0].character, "Alexandra")
        XCTAssertEqual(scene.dialogues[1].character, "Sam", "other characters untouched")
        XCTAssertEqual(scene.actions[0].characters, ["Alexandra", "Sam"])
        XCTAssertEqual(scene.narrations[0].characters, ["Alexandra"])
        XCTAssertEqual(p.costumes[0].character, "Alexandra")
        XCTAssertEqual(p.castMembers[0].characterName, "Alexandra")
        XCTAssertEqual(p.beats[0].character, "Alexandra")
    }

    func testLocationRenameCascadesEverywhere() {
        var p = makeProject()
        let updated = p.cascadeLocationRename(from: "Warehouse", to: "Dockyard")

        XCTAssertEqual(updated, 4, "sequence + scene + scheduleItem + ganttTask")
        XCTAssertEqual(p.sequences[0].location, "Dockyard")
        XCTAssertEqual(p.sequences[0].scenes[0].location, "Dockyard")
        XCTAssertEqual(p.scheduleItems[0].location, "Dockyard")
        XCTAssertEqual(p.ganttTasks[0].locationNames, ["Dockyard", "Beach"])
    }

    func testRenameNoOpsAreSafe() {
        var p = makeProject()
        XCTAssertEqual(p.cascadeCharacterRename(from: "Alex", to: "Alex"), 0, "same name = no-op")
        XCTAssertEqual(p.cascadeCharacterRename(from: "", to: "X"), 0, "empty old = no-op")
        XCTAssertEqual(p.cascadeCharacterRename(from: "Nobody", to: "X"), 0, "unknown name = 0 refs")
        XCTAssertEqual(p.sequences[0].scenes[0].dialogues[0].character, "Alex", "project untouched")
    }
}

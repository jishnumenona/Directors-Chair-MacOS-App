// DirectorsChair-DesktopTests/AssistantScheduleActionsTests.swift
//
// AI Assistant program, Phase A3.2: schedule CRUD actions with the
// validator in the loop (AD6) — proposals that introduce conflicts carry
// warnings; bad dates/slots/unknown scenes throw with guidance.

import XCTest
@testable import DirectorsChair_Desktop
@testable import DirectorsChairCore
@testable import DirectorsChairServices

@MainActor
final class AssistantScheduleActionsTests: XCTestCase {

    private var projectVM: ProjectViewModel!
    private var registry: ActionRegistry!

    override func setUp() {
        super.setUp()
        var project = Project(name: "Fixture Film")
        project.sequences = [Sequence(name: "Act 1", scenes: [
            Scene(name: "Opening", description: "d1"),
            Scene(name: "Finale", description: "d2"),
        ])]
        // One existing booking with Ada on the morning of 08-01.
        project.scheduleItems = [
            ScheduleItem(sceneName: "Finale", shootDate: "2026-08-01",
                         timeSlot: "Morning", status: "Planned",
                         location: "Rooftop", requiredActors: ["Ada Vale"]),
        ]
        projectVM = ProjectViewModel(project: project)
        registry = AssistantActionFactory.makeRegistry(
            projectViewModel: projectVM, coordinator: nil)
    }

    override func tearDown() {
        projectVM = nil
        registry = nil
        super.tearDown()
    }

    private func action(_ name: String) -> any AssistantAction {
        registry.action(named: name)!
    }

    private func args(_ json: String) -> Data { Data(json.utf8) }

    // MARK: - schedule_scene

    func testScheduleSceneValidatesExecutesAndWarnsOnNewConflict() async throws {
        let schedule = action("schedule_scene")
        // Same day/slot/actor as the existing Finale booking → new conflict.
        let payload = args(#"""
        {"scene": "Opening", "date": "2026-08-01", "time_slot": "morning",
         "cast": ["Ada Vale"], "location": "Stage 4"}
        """#)

        let plan = try schedule.validate(argumentsData: payload)
        XCTAssertFalse(plan.warnings.isEmpty,
                       "double-booking Ada must surface a validator warning")
        XCTAssertEqual(plan.previews.first?.oldValue, "unscheduled")
        XCTAssertTrue(plan.summary.contains("Morning"), "slot is canonicalized")

        _ = try await schedule.execute(argumentsData: payload)
        XCTAssertEqual(projectVM.project.scheduleItems.count, 2)
        XCTAssertEqual(projectVM.project.scheduleItems.last?.sceneName, "Opening")
        XCTAssertEqual(projectVM.project.scheduleItems.last?.timeSlot, "Morning")
        XCTAssertTrue(projectVM.isDirty)
    }

    func testScheduleSceneCleanBookingHasNoWarnings() throws {
        let plan = try action("schedule_scene").validate(argumentsData: args(
            #"{"scene": "Opening", "date": "2026-08-02", "time_slot": "Night"}"#))
        XCTAssertTrue(plan.warnings.isEmpty)
    }

    func testScheduleSceneRejectsBadInputs() {
        let schedule = action("schedule_scene")
        XCTAssertThrowsError(try schedule.validate(argumentsData: args(
            #"{"scene": "Opening", "date": "Aug 1st", "time_slot": "Morning"}"#)))
        XCTAssertThrowsError(try schedule.validate(argumentsData: args(
            #"{"scene": "Opening", "date": "2026-08-01", "time_slot": "Dawn"}"#)))
        XCTAssertThrowsError(try schedule.validate(argumentsData: args(
            #"{"scene": "Ghost", "date": "2026-08-01", "time_slot": "Morning"}"#)))
    }

    // MARK: - update_schedule_item

    func testUpdateScheduleItemMovesDateWithPreviews() async throws {
        let update = action("update_schedule_item")
        let payload = args(#"{"scene": "Finale", "new_date": "2026-08-03", "new_status": "Confirmed"}"#)

        let plan = try update.validate(argumentsData: payload)
        XCTAssertEqual(plan.previews.count, 2)
        XCTAssertEqual(plan.previews.first?.oldValue, "2026-08-01")
        XCTAssertEqual(plan.previews.first?.newValue, "2026-08-03")
        XCTAssertTrue(plan.warnings.isEmpty, "moving to an empty day is clean")

        _ = try await update.execute(argumentsData: payload)
        XCTAssertEqual(projectVM.project.scheduleItems[0].shootDate, "2026-08-03")
        XCTAssertEqual(projectVM.project.scheduleItems[0].status, "Confirmed")
    }

    func testUpdateScheduleItemRequiresAChangeAndAKnownItem() {
        let update = action("update_schedule_item")
        XCTAssertThrowsError(try update.validate(argumentsData: args(
            #"{"scene": "Finale"}"#))) { error in
            XCTAssertTrue("\(error)".contains("nothing to change"))
        }
        XCTAssertThrowsError(try update.validate(argumentsData: args(
            #"{"scene": "Opening", "new_status": "Shot"}"#))) { error in
            XCTAssertTrue("\(error)".contains("no schedule item"))
        }
    }

    // MARK: - remove_schedule_item

    func testRemoveScheduleItemUnschedules() async throws {
        let remove = action("remove_schedule_item")
        let plan = try remove.validate(argumentsData: args(#"{"scene": "Finale"}"#))
        XCTAssertEqual(plan.previews.first?.newValue, "unscheduled")

        _ = try await remove.execute(argumentsData: args(#"{"scene": "Finale"}"#))
        XCTAssertTrue(projectVM.project.scheduleItems.isEmpty)
        // scene data untouched
        XCTAssertEqual(projectVM.project.sequences[0].scenes.count, 2)
    }
}

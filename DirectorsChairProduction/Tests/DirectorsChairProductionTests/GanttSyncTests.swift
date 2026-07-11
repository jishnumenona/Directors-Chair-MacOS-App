// GanttSyncTests.swift
//
// Covers E2E-PROD-003 — the Gantt stays in sync with the schedule. When a
// ScheduleItem is added or edited, GanttViewModel.syncFromScheduleItems()
// projects it into a linked GanttTask (matched by scheduleItemId) rather than
// letting the Gantt drift into a stale second schedule.

import XCTest
@testable import DirectorsChairProduction
@testable import DirectorsChairCore

@MainActor
final class GanttSyncTests: XCTestCase {

    var viewModel: GanttViewModel!

    override func setUp() {
        super.setUp()
        viewModel = GanttViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    private func item(_ name: String, date: String, hours: Double = 8.0, status: String = "Planned") -> ScheduleItem {
        ScheduleItem(sceneName: name, sequenceName: "Act 1", shootDate: date,
                     timeSlot: "Morning", estimatedDurationHours: hours,
                     status: status, location: "Studio A")
    }

    func testScheduleItemCreatesLinkedGanttTask() {
        let si = item("Rooftop chase", date: "2026-04-01")
        viewModel.scheduleItems = [si]

        viewModel.syncFromScheduleItems()

        XCTAssertEqual(viewModel.tasks.count, 1, "one Gantt task per dated schedule item")
        let task = viewModel.tasks[0]
        XCTAssertEqual(task.scheduleItemId, si.id, "task is linked back to its schedule item")
        XCTAssertEqual(task.name, "Rooftop chase")
        XCTAssertEqual(task.startDate, "2026-04-01")
    }

    func testDurationDaysDerivedFromHoursAtEightPerDay() {
        viewModel.scheduleItems = [item("Long day", date: "2026-04-02", hours: 20.0)]
        viewModel.syncFromScheduleItems()
        // ceil(20 / 8) = 3 days.
        XCTAssertEqual(viewModel.tasks.first?.durationDays, 3)
    }

    func testEditingScheduleItemUpdatesLinkedTaskInPlace() {
        var si = item("Interior", date: "2026-04-03", hours: 8.0)
        viewModel.scheduleItems = [si]
        viewModel.syncFromScheduleItems()
        XCTAssertEqual(viewModel.tasks.count, 1)

        // Edit the schedule item (new date + longer duration) and re-sync.
        si.shootDate = "2026-04-10"
        si.estimatedDurationHours = 16.0
        viewModel.scheduleItems = [si]
        viewModel.syncFromScheduleItems()

        XCTAssertEqual(viewModel.tasks.count, 1, "re-sync updates in place, no duplicate task")
        XCTAssertEqual(viewModel.tasks[0].startDate, "2026-04-10", "Gantt reflects the new date")
        XCTAssertEqual(viewModel.tasks[0].durationDays, 2, "Gantt reflects the new duration (ceil 16/8)")
    }

    func testUndatedScheduleItemProducesNoTask() {
        viewModel.scheduleItems = [item("No date yet", date: "")]
        viewModel.syncFromScheduleItems()
        XCTAssertTrue(viewModel.tasks.isEmpty, "an item without a shoot date is not placed on the Gantt")
    }
}

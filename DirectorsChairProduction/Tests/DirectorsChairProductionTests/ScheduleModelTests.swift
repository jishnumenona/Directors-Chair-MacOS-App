// DirectorsChairProduction/Tests/DirectorsChairProductionTests/ScheduleModelTests.swift
//
// Tests for schedule item management, conflict detection, and schedule optimization.

import XCTest
@testable import DirectorsChairProduction
@testable import DirectorsChairCore

@MainActor
final class ScheduleModelTests: XCTestCase {

    var viewModel: ScheduleViewModel!

    override func setUp() {
        super.setUp()
        viewModel = ScheduleViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - ScheduleItem Model

    func testScheduleItemCreation() {
        let item = ScheduleItem(
            sceneName: "Scene 1",
            sequenceName: "Act 1",
            shootDate: "2026-04-01",
            timeSlot: "Morning",
            estimatedDurationHours: 4.0,
            status: "Planned",
            location: "Studio A"
        )

        XCTAssertEqual(item.sceneName, "Scene 1")
        XCTAssertEqual(item.sequenceName, "Act 1")
        XCTAssertEqual(item.shootDate, "2026-04-01")
        XCTAssertEqual(item.timeSlot, "Morning")
        XCTAssertEqual(item.estimatedDurationHours, 4.0)
        XCTAssertEqual(item.status, "Planned")
        XCTAssertEqual(item.location, "Studio A")
        XCTAssertFalse(item.id.isEmpty)
    }

    func testScheduleItemDefaults() {
        let item = ScheduleItem()

        XCTAssertEqual(item.timeSlot, "Full Day")
        XCTAssertEqual(item.estimatedDurationHours, 4.0)
        XCTAssertEqual(item.status, "Planned")
        XCTAssertTrue(item.sceneName.isEmpty)
        XCTAssertTrue(item.requiredActors.isEmpty)
        XCTAssertTrue(item.requiredCrew.isEmpty)
        XCTAssertTrue(item.requiredEquipment.isEmpty)
        XCTAssertEqual(item.priority, 3)
        XCTAssertEqual(item.completionPercentage, 0)
    }

    // MARK: - CRUD Operations

    func testAddScheduleItem() {
        let item = ScheduleItem(sceneName: "Test Scene")
        viewModel.addScheduleItem(item)

        XCTAssertEqual(viewModel.scheduleItems.count, 1)
        XCTAssertEqual(viewModel.scheduleItems.first?.sceneName, "Test Scene")
    }

    func testUpdateScheduleItem() {
        var item = ScheduleItem(sceneName: "Original")
        viewModel.addScheduleItem(item)

        item.sceneName = "Updated"
        viewModel.updateScheduleItem(item)

        XCTAssertEqual(viewModel.scheduleItems.first?.sceneName, "Updated")
    }

    func testRemoveScheduleItem() {
        let item = ScheduleItem(sceneName: "To Remove")
        viewModel.addScheduleItem(item)
        XCTAssertEqual(viewModel.scheduleItems.count, 1)

        viewModel.removeScheduleItem(item)
        XCTAssertTrue(viewModel.scheduleItems.isEmpty)
    }

    func testSetScheduleItems() {
        let items = [
            ScheduleItem(sceneName: "Scene 1"),
            ScheduleItem(sceneName: "Scene 2"),
            ScheduleItem(sceneName: "Scene 3"),
        ]

        viewModel.setScheduleItems(items)
        XCTAssertEqual(viewModel.scheduleItems.count, 3)
    }

    func testClearAllItems() {
        viewModel.addScheduleItem(ScheduleItem(sceneName: "A"))
        viewModel.addScheduleItem(ScheduleItem(sceneName: "B"))

        viewModel.clearAllItems()

        XCTAssertTrue(viewModel.scheduleItems.isEmpty)
        XCTAssertTrue(viewModel.conflicts.isEmpty)
    }

    // MARK: - Conflict Detection: Cast Overlap

    func testDetectCastConflict() {
        let item1 = ScheduleItem(
            sceneName: "Scene 1",
            shootDate: "2026-04-01",
            timeSlot: "Morning",
            location: "Studio A",
            requiredActors: ["Alice", "Bob"]
        )
        let item2 = ScheduleItem(
            sceneName: "Scene 2",
            shootDate: "2026-04-01",
            timeSlot: "Morning",
            location: "Studio A",
            requiredActors: ["Bob", "Charlie"]
        )

        viewModel.addScheduleItem(item1)
        viewModel.addScheduleItem(item2)

        // Conflicts should be detected for Bob being double-booked
        let castConflicts = viewModel.conflicts.filter { $0.type == .castUnavailable }
        XCTAssertFalse(castConflicts.isEmpty,
                      "Should detect cast conflict for Bob")
        XCTAssertTrue(castConflicts.first?.description.contains("Bob") ?? false)
    }

    // MARK: - Conflict Detection: Equipment Overlap

    func testDetectEquipmentConflict() {
        let item1 = ScheduleItem(
            sceneName: "Scene 1",
            shootDate: "2026-04-01",
            timeSlot: "Full Day",
            requiredEquipment: ["Camera A", "Dolly"]
        )
        let item2 = ScheduleItem(
            sceneName: "Scene 2",
            shootDate: "2026-04-01",
            timeSlot: "Morning",
            requiredEquipment: ["Camera A", "Crane"]
        )

        viewModel.addScheduleItem(item1)
        viewModel.addScheduleItem(item2)

        let equipConflicts = viewModel.conflicts.filter { $0.type == .equipmentShortage }
        XCTAssertFalse(equipConflicts.isEmpty,
                      "Should detect equipment conflict for Camera A")
    }

    // MARK: - Conflict Detection: Location Conflict

    func testDetectLocationConflict() {
        let item1 = ScheduleItem(
            sceneName: "Scene 1",
            shootDate: "2026-04-01",
            timeSlot: "Full Day",
            location: "Park"
        )
        let item2 = ScheduleItem(
            sceneName: "Scene 2",
            shootDate: "2026-04-01",
            timeSlot: "Full Day",
            location: "Beach"
        )

        viewModel.addScheduleItem(item1)
        viewModel.addScheduleItem(item2)

        let locationConflicts = viewModel.conflicts.filter { $0.type == .locationConflict }
        XCTAssertFalse(locationConflicts.isEmpty,
                      "Should detect location conflict between Park and Beach")
    }

    // MARK: - No Conflicts When Dates Differ

    func testNoConflictsOnDifferentDates() {
        let item1 = ScheduleItem(
            sceneName: "Scene 1",
            shootDate: "2026-04-01",
            timeSlot: "Morning",
            requiredActors: ["Alice"]
        )
        let item2 = ScheduleItem(
            sceneName: "Scene 2",
            shootDate: "2026-04-02",
            timeSlot: "Morning",
            requiredActors: ["Alice"]
        )

        viewModel.addScheduleItem(item1)
        viewModel.addScheduleItem(item2)

        XCTAssertTrue(viewModel.conflicts.isEmpty,
                     "Same cast on different dates should not conflict")
    }

    // MARK: - Statistics

    func testTotalScheduledHours() {
        viewModel.addScheduleItem(ScheduleItem(estimatedDurationHours: 4.0))
        viewModel.addScheduleItem(ScheduleItem(estimatedDurationHours: 6.0))
        viewModel.addScheduleItem(ScheduleItem(estimatedDurationHours: 2.5))

        XCTAssertEqual(viewModel.totalScheduledHours, 12.5)
    }

    func testUniqueShootDays() {
        viewModel.addScheduleItem(ScheduleItem(shootDate: "2026-04-01"))
        viewModel.addScheduleItem(ScheduleItem(shootDate: "2026-04-01"))
        viewModel.addScheduleItem(ScheduleItem(shootDate: "2026-04-02"))
        viewModel.addScheduleItem(ScheduleItem(shootDate: "2026-04-03"))

        XCTAssertEqual(viewModel.uniqueShootDays, 3)
    }

    func testCompletedItems() {
        viewModel.addScheduleItem(ScheduleItem(status: "Complete"))
        viewModel.addScheduleItem(ScheduleItem(status: "Complete"))
        viewModel.addScheduleItem(ScheduleItem(status: "Planned"))

        XCTAssertEqual(viewModel.completedItems, 2)
    }

    func testProgressPercentage() {
        viewModel.addScheduleItem(ScheduleItem(status: "Complete"))
        viewModel.addScheduleItem(ScheduleItem(status: "Planned"))

        XCTAssertEqual(viewModel.progressPercentage, 50.0, accuracy: 0.01)
    }

    func testProgressPercentageEmpty() {
        XCTAssertEqual(viewModel.progressPercentage, 0)
    }

    // MARK: - Filtering

    func testItemsForDate() {
        viewModel.addScheduleItem(ScheduleItem(sceneName: "A", shootDate: "2026-04-01"))
        viewModel.addScheduleItem(ScheduleItem(sceneName: "B", shootDate: "2026-04-01"))
        viewModel.addScheduleItem(ScheduleItem(sceneName: "C", shootDate: "2026-04-02"))

        let items = viewModel.items(for: "2026-04-01")
        XCTAssertEqual(items.count, 2)
    }

    func testItemsWithStatus() {
        viewModel.addScheduleItem(ScheduleItem(sceneName: "A", status: "Planned"))
        viewModel.addScheduleItem(ScheduleItem(sceneName: "B", status: "Complete"))
        viewModel.addScheduleItem(ScheduleItem(sceneName: "C", status: "Planned"))

        let planned = viewModel.items(with: "Planned")
        XCTAssertEqual(planned.count, 2)
    }

    func testItemsAtLocation() {
        viewModel.addScheduleItem(ScheduleItem(sceneName: "A", location: "Studio A"))
        viewModel.addScheduleItem(ScheduleItem(sceneName: "B", location: "Studio B"))
        viewModel.addScheduleItem(ScheduleItem(sceneName: "C", location: "Studio A"))

        let studioA = viewModel.items(at: "Studio A")
        XCTAssertEqual(studioA.count, 2)
    }

    func testItemsRequiringActor() {
        viewModel.addScheduleItem(ScheduleItem(sceneName: "A", requiredActors: ["Alice", "Bob"]))
        viewModel.addScheduleItem(ScheduleItem(sceneName: "B", requiredActors: ["Charlie"]))
        viewModel.addScheduleItem(ScheduleItem(sceneName: "C", requiredActors: ["Alice"]))

        let aliceItems = viewModel.items(requiring: "Alice")
        XCTAssertEqual(aliceItems.count, 2)
    }

    // MARK: - Auto-Optimize

    func testAutoOptimize() {
        viewModel.addScheduleItem(ScheduleItem(sceneName: "C", shootDate: "2026-04-03", location: "Beach"))
        viewModel.addScheduleItem(ScheduleItem(sceneName: "A", shootDate: "2026-04-01", location: "Studio"))
        viewModel.addScheduleItem(ScheduleItem(sceneName: "B", shootDate: "2026-04-01", location: "Park"))

        viewModel.autoOptimize()

        // After optimization, items should be sorted by date then location
        XCTAssertEqual(viewModel.scheduleItems[0].sceneName, "B") // April 1, Park
        XCTAssertEqual(viewModel.scheduleItems[1].sceneName, "A") // April 1, Studio
        XCTAssertEqual(viewModel.scheduleItems[2].sceneName, "C") // April 3, Beach
    }

    // MARK: - Schedule Optimization Suggestions

    func testSuggestOptimizations() {
        // Add items at the same location on different dates
        viewModel.addScheduleItem(ScheduleItem(sceneName: "A", shootDate: "2026-04-01", location: "Beach"))
        viewModel.addScheduleItem(ScheduleItem(sceneName: "B", shootDate: "2026-04-05", location: "Beach"))

        let suggestions = viewModel.suggestOptimizations()

        XCTAssertFalse(suggestions.isEmpty,
                      "Should suggest consolidating Beach shoots")
    }

    // MARK: - ScheduleItem Codable

    func testScheduleItemCodableRoundTrip() throws {
        let item = ScheduleItem(
            sceneName: "Test Scene",
            sequenceName: "Act 1",
            shootDate: "2026-04-01",
            timeSlot: "Morning",
            estimatedDurationHours: 6.0,
            status: "Confirmed",
            location: "Studio A",
            requiredActors: ["Alice", "Bob"],
            requiredCrew: ["DP", "Gaffer"],
            estimatedCost: 5000.0,
            priority: 1
        )

        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(ScheduleItem.self, from: data)

        XCTAssertEqual(decoded.sceneName, "Test Scene")
        XCTAssertEqual(decoded.shootDate, "2026-04-01")
        XCTAssertEqual(decoded.timeSlot, "Morning")
        XCTAssertEqual(decoded.location, "Studio A")
        XCTAssertEqual(decoded.requiredActors.count, 2)
        XCTAssertEqual(decoded.estimatedCost, 5000.0)
        XCTAssertEqual(decoded.priority, 1)
    }

    // MARK: - Callback

    func testOnScheduleChangedCallback() {
        let expectation = XCTestExpectation(description: "Schedule changed callback")

        viewModel.onScheduleChanged = { items in
            XCTAssertEqual(items.count, 1)
            expectation.fulfill()
        }

        viewModel.addScheduleItem(ScheduleItem(sceneName: "Callback Test"))

        wait(for: [expectation], timeout: 1.0)
    }

    // WS8.3 — a linked Gantt task must re-sync when its schedule item changes,
    // instead of being skipped and left stale (a divergent second schedule).
    func testGanttResyncsLinkedTaskFromScheduleItem() {
        let gantt = GanttViewModel()
        gantt.scheduleItems = [
            ScheduleItem(id: "s1", sceneName: "Scene A", shootDate: "2026-08-01",
                         status: "Planned", estimatedCost: 100)
        ]
        gantt.syncFromScheduleItems()
        XCTAssertEqual(gantt.tasks.count, 1)
        XCTAssertEqual(gantt.tasks.first?.startDate, "2026-08-01")
        XCTAssertEqual(gantt.tasks.first?.estimatedCost, 100)

        // Edit the same schedule item (same id): date, status, cost.
        gantt.scheduleItems = [
            ScheduleItem(id: "s1", sceneName: "Scene A", shootDate: "2026-08-15",
                         status: "Complete", estimatedCost: 250)
        ]
        gantt.syncFromScheduleItems()

        XCTAssertEqual(gantt.tasks.count, 1, "Must not create a duplicate task")
        XCTAssertEqual(gantt.tasks.first?.startDate, "2026-08-15", "Date change must propagate")
        XCTAssertEqual(gantt.tasks.first?.status, "Complete", "Status change must propagate")
        XCTAssertEqual(gantt.tasks.first?.estimatedCost, 250, "Cost change must propagate")
    }
}

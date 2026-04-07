// DirectorsChairProduction/Tests/DirectorsChairProductionTests/EquipmentModelTests.swift
//
// Tests for EquipmentItem, EquipmentAllocation models and EquipmentViewModel logic.

import XCTest
@testable import DirectorsChairProduction
@testable import DirectorsChairCore

@MainActor
final class EquipmentModelTests: XCTestCase {

    var viewModel: EquipmentViewModel!

    override func setUp() {
        super.setUp()
        viewModel = EquipmentViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - EquipmentItem Model

    func testEquipmentItemCreation() {
        let item = EquipmentItem(
            name: "ARRI Alexa Mini",
            category: "Camera",
            subcategory: "Cinema Camera",
            manufacturer: "ARRI",
            model: "Alexa Mini LF",
            quantityOwned: 2,
            quantityAvailable: 1,
            isRental: true,
            rentalDailyRate: 1500.0,
            condition: "Excellent"
        )

        XCTAssertEqual(item.name, "ARRI Alexa Mini")
        XCTAssertEqual(item.category, "Camera")
        XCTAssertEqual(item.subcategory, "Cinema Camera")
        XCTAssertEqual(item.manufacturer, "ARRI")
        XCTAssertEqual(item.model, "Alexa Mini LF")
        XCTAssertEqual(item.quantityOwned, 2)
        XCTAssertEqual(item.quantityAvailable, 1)
        XCTAssertTrue(item.isRental)
        XCTAssertEqual(item.rentalDailyRate, 1500.0)
        XCTAssertEqual(item.condition, "Excellent")
        XCTAssertFalse(item.id.isEmpty)
        XCTAssertTrue(item.id.hasPrefix("equip_"))
    }

    func testEquipmentItemDefaults() {
        let item = EquipmentItem()

        XCTAssertTrue(item.name.isEmpty)
        XCTAssertEqual(item.category, "Camera")
        XCTAssertEqual(item.quantityOwned, 0)
        XCTAssertEqual(item.quantityAvailable, 0)
        XCTAssertFalse(item.isRental)
        XCTAssertEqual(item.rentalDailyRate, 0.0)
        XCTAssertEqual(item.rentalWeeklyRate, 0.0)
        XCTAssertEqual(item.condition, "Good")
        XCTAssertTrue(item.specs.isEmpty)
        XCTAssertFalse(item.rentalManagedExternally)
    }

    // MARK: - EquipmentAllocation Model

    func testEquipmentAllocationCreation() {
        let alloc = EquipmentAllocation(
            equipmentItemId: "equip_123",
            allocationMode: .fullProduction,
            allocatedDates: [],
            quantityAllocated: 2,
            notes: "Needed for entire shoot"
        )

        XCTAssertEqual(alloc.equipmentItemId, "equip_123")
        XCTAssertEqual(alloc.allocationMode, .fullProduction)
        XCTAssertEqual(alloc.quantityAllocated, 2)
        XCTAssertEqual(alloc.notes, "Needed for entire shoot")
        XCTAssertFalse(alloc.id.isEmpty)
        XCTAssertTrue(alloc.id.hasPrefix("alloc_"))
    }

    func testEquipmentAllocationSpecificDays() {
        let alloc = EquipmentAllocation(
            equipmentItemId: "equip_456",
            allocationMode: .specificDays,
            allocatedDates: ["2026-04-01", "2026-04-02", "2026-04-05"],
            quantityAllocated: 1
        )

        XCTAssertEqual(alloc.allocationMode, .specificDays)
        XCTAssertEqual(alloc.allocatedDates.count, 3)
    }

    // MARK: - ProductionAllocationMode

    func testProductionAllocationModeRawValues() {
        XCTAssertEqual(ProductionAllocationMode.fullProduction.rawValue, "full_production")
        XCTAssertEqual(ProductionAllocationMode.specificDays.rawValue, "specific_days")
    }

    // MARK: - Equipment CRUD

    func testAddEquipment() {
        let item = EquipmentItem(name: "Tripod", category: "Grip")
        viewModel.addEquipment(item)

        XCTAssertEqual(viewModel.equipment.count, 1)
        XCTAssertEqual(viewModel.equipment.first?.name, "Tripod")
    }

    func testUpdateEquipment() {
        var item = EquipmentItem(name: "Tripod")
        viewModel.addEquipment(item)

        item.name = "Heavy Duty Tripod"
        viewModel.updateEquipment(item)

        XCTAssertEqual(viewModel.equipment.first?.name, "Heavy Duty Tripod")
    }

    func testRemoveEquipment() {
        let item = EquipmentItem(name: "Tripod")
        viewModel.addEquipment(item)

        // Add allocation for this item
        viewModel.setAllocation(
            for: item.id,
            mode: .fullProduction,
            dates: [],
            quantity: 1
        )
        XCTAssertEqual(viewModel.allocations.count, 1)

        viewModel.removeEquipment(item)

        XCTAssertTrue(viewModel.equipment.isEmpty)
        XCTAssertTrue(viewModel.allocations.isEmpty,
                     "Allocations should be removed when equipment is removed")
    }

    // MARK: - Allocation CRUD

    func testSetAllocationNew() {
        let item = EquipmentItem(name: "Camera")
        viewModel.addEquipment(item)

        viewModel.setAllocation(
            for: item.id,
            mode: .fullProduction,
            dates: [],
            quantity: 1,
            notes: "Main camera"
        )

        XCTAssertEqual(viewModel.allocations.count, 1)
        let alloc = viewModel.allocation(for: item.id)
        XCTAssertNotNil(alloc)
        XCTAssertEqual(alloc?.allocationMode, .fullProduction)
        XCTAssertEqual(alloc?.quantityAllocated, 1)
        XCTAssertEqual(alloc?.notes, "Main camera")
    }

    func testSetAllocationUpdate() {
        let item = EquipmentItem(name: "Camera")
        viewModel.addEquipment(item)

        viewModel.setAllocation(for: item.id, mode: .fullProduction, dates: [], quantity: 1)

        // Update allocation
        viewModel.setAllocation(
            for: item.id,
            mode: .specificDays,
            dates: ["2026-04-01", "2026-04-02"],
            quantity: 2
        )

        XCTAssertEqual(viewModel.allocations.count, 1, "Should update, not add new")
        let alloc = viewModel.allocation(for: item.id)
        XCTAssertEqual(alloc?.allocationMode, .specificDays)
        XCTAssertEqual(alloc?.allocatedDates.count, 2)
        XCTAssertEqual(alloc?.quantityAllocated, 2)
    }

    func testRemoveAllocation() {
        let item = EquipmentItem(name: "Camera")
        viewModel.addEquipment(item)
        viewModel.setAllocation(for: item.id, mode: .fullProduction, dates: [], quantity: 1)

        viewModel.removeAllocation(for: item.id)

        XCTAssertTrue(viewModel.allocations.isEmpty)
        XCTAssertNil(viewModel.allocation(for: item.id))
    }

    // MARK: - Queries

    func testEquipmentInCategory() {
        viewModel.addEquipment(EquipmentItem(name: "ARRI", category: "Camera"))
        viewModel.addEquipment(EquipmentItem(name: "Tripod", category: "Grip"))
        viewModel.addEquipment(EquipmentItem(name: "RED", category: "Camera"))

        let cameras = viewModel.equipment(inCategory: "Camera")
        XCTAssertEqual(cameras.count, 2)
    }

    func testFullProductionEquipment() {
        let cam = EquipmentItem(name: "Camera")
        let light = EquipmentItem(name: "Light")
        viewModel.addEquipment(cam)
        viewModel.addEquipment(light)

        viewModel.setAllocation(for: cam.id, mode: .fullProduction, dates: [], quantity: 1)
        viewModel.setAllocation(for: light.id, mode: .specificDays, dates: ["2026-04-01"], quantity: 1)

        let fullProd = viewModel.fullProductionEquipment()
        XCTAssertEqual(fullProd.count, 1)
        XCTAssertEqual(fullProd.first?.name, "Camera")
    }

    func testSpecificDaysEquipment() {
        let cam = EquipmentItem(name: "Camera")
        let light = EquipmentItem(name: "Light")
        viewModel.addEquipment(cam)
        viewModel.addEquipment(light)

        viewModel.setAllocation(for: cam.id, mode: .fullProduction, dates: [], quantity: 1)
        viewModel.setAllocation(for: light.id, mode: .specificDays, dates: ["2026-04-01"], quantity: 1)

        let specificDays = viewModel.specificDaysEquipment()
        XCTAssertEqual(specificDays.count, 1)
        XCTAssertEqual(specificDays.first?.name, "Light")
    }

    func testUnallocatedEquipment() {
        let cam = EquipmentItem(name: "Camera")
        let tripod = EquipmentItem(name: "Tripod")
        viewModel.addEquipment(cam)
        viewModel.addEquipment(tripod)

        viewModel.setAllocation(for: cam.id, mode: .fullProduction, dates: [], quantity: 1)

        let unallocated = viewModel.unallocatedEquipment()
        XCTAssertEqual(unallocated.count, 1)
        XCTAssertEqual(unallocated.first?.name, "Tripod")
    }

    func testEquipmentForDate() {
        let cam = EquipmentItem(name: "Camera")
        let light = EquipmentItem(name: "Light")
        let sound = EquipmentItem(name: "Sound Mixer")
        viewModel.addEquipment(cam)
        viewModel.addEquipment(light)
        viewModel.addEquipment(sound)

        viewModel.setAllocation(for: cam.id, mode: .fullProduction, dates: [], quantity: 1)
        viewModel.setAllocation(for: light.id, mode: .specificDays, dates: ["2026-04-01", "2026-04-02"], quantity: 1)
        viewModel.setAllocation(for: sound.id, mode: .specificDays, dates: ["2026-04-02"], quantity: 1)

        let april1 = viewModel.equipmentForDate("2026-04-01")
        XCTAssertEqual(april1.count, 2, "Camera (full prod) + Light (specific date)")

        let april2 = viewModel.equipmentForDate("2026-04-02")
        XCTAssertEqual(april2.count, 3, "Camera (full prod) + Light + Sound")

        let april3 = viewModel.equipmentForDate("2026-04-03")
        XCTAssertEqual(april3.count, 1, "Only Camera (full prod)")
    }

    // MARK: - Stats

    func testTotalItems() {
        viewModel.addEquipment(EquipmentItem(name: "A"))
        viewModel.addEquipment(EquipmentItem(name: "B"))
        viewModel.addEquipment(EquipmentItem(name: "C"))

        XCTAssertEqual(viewModel.totalItems, 3)
    }

    func testTotalUnits() {
        viewModel.addEquipment(EquipmentItem(name: "Camera", quantityOwned: 2))
        viewModel.addEquipment(EquipmentItem(name: "Light", quantityOwned: 5))

        XCTAssertEqual(viewModel.totalUnits, 7)
    }

    func testAllocatedCount() {
        let cam = EquipmentItem(name: "Camera")
        let light = EquipmentItem(name: "Light")
        let tripod = EquipmentItem(name: "Tripod")
        viewModel.addEquipment(cam)
        viewModel.addEquipment(light)
        viewModel.addEquipment(tripod)

        viewModel.setAllocation(for: cam.id, mode: .fullProduction, dates: [], quantity: 1)
        viewModel.setAllocation(for: light.id, mode: .specificDays, dates: ["2026-04-01"], quantity: 1)

        XCTAssertEqual(viewModel.allocatedCount, 2)
    }

    func testRentalCostPerDay() {
        viewModel.addEquipment(EquipmentItem(name: "Camera", isRental: true, rentalDailyRate: 1500))
        viewModel.addEquipment(EquipmentItem(name: "Lens", isRental: true, rentalDailyRate: 500))
        viewModel.addEquipment(EquipmentItem(name: "Tripod", isRental: false, rentalDailyRate: 100))

        XCTAssertEqual(viewModel.rentalCostPerDay, 2000,
                      "Only rental items should contribute to rental cost per day")
    }

    // MARK: - Codable Round Trip

    func testEquipmentItemCodableRoundTrip() throws {
        let item = EquipmentItem(
            name: "ARRI Alexa",
            category: "Camera",
            manufacturer: "ARRI",
            model: "Alexa Mini LF",
            quantityOwned: 2,
            quantityAvailable: 1,
            isRental: true,
            rentalDailyRate: 1500.0,
            specs: ["sensor": "LF", "resolution": "4.5K"],
            condition: "Excellent"
        )

        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(EquipmentItem.self, from: data)

        XCTAssertEqual(decoded.name, "ARRI Alexa")
        XCTAssertEqual(decoded.category, "Camera")
        XCTAssertEqual(decoded.manufacturer, "ARRI")
        XCTAssertEqual(decoded.quantityOwned, 2)
        XCTAssertTrue(decoded.isRental)
        XCTAssertEqual(decoded.rentalDailyRate, 1500.0)
        XCTAssertEqual(decoded.specs["sensor"], "LF")
        XCTAssertEqual(decoded.condition, "Excellent")
    }

    func testEquipmentAllocationCodableRoundTrip() throws {
        let alloc = EquipmentAllocation(
            equipmentItemId: "equip_123",
            allocationMode: .specificDays,
            allocatedDates: ["2026-04-01", "2026-04-02"],
            quantityAllocated: 3,
            notes: "Test allocation"
        )

        let data = try JSONEncoder().encode(alloc)
        let decoded = try JSONDecoder().decode(EquipmentAllocation.self, from: data)

        XCTAssertEqual(decoded.equipmentItemId, "equip_123")
        XCTAssertEqual(decoded.allocationMode, .specificDays)
        XCTAssertEqual(decoded.allocatedDates.count, 2)
        XCTAssertEqual(decoded.quantityAllocated, 3)
        XCTAssertEqual(decoded.notes, "Test allocation")
    }

    // MARK: - Callbacks

    func testOnEquipmentChangedCallback() {
        let expectation = XCTestExpectation(description: "Equipment changed callback")

        viewModel.onEquipmentChanged = { items in
            XCTAssertEqual(items.count, 1)
            expectation.fulfill()
        }

        viewModel.addEquipment(EquipmentItem(name: "Test"))

        wait(for: [expectation], timeout: 1.0)
    }

    func testOnAllocationsChangedCallback() {
        let expectation = XCTestExpectation(description: "Allocations changed callback")

        viewModel.onAllocationsChanged = { allocs in
            XCTAssertEqual(allocs.count, 1)
            expectation.fulfill()
        }

        let item = EquipmentItem(name: "Camera")
        viewModel.addEquipment(item)
        viewModel.setAllocation(for: item.id, mode: .fullProduction, dates: [], quantity: 1)

        wait(for: [expectation], timeout: 1.0)
    }
}

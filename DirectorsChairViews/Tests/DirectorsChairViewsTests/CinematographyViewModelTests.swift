// DirectorsChairViews/Tests/DirectorsChairViewsTests/CinematographyViewModelTests.swift
//
// Tests for CinematographyViewModel UUID-related behavior:
// - moveShot() preserves shotIds (no renumbering)
// - duplicateShot() generates new UUID
// - nextShotId computes global max
// - CRUD operations work with UUID-based identity

import XCTest
@testable import DirectorsChairViews
import DirectorsChairCore

@MainActor
final class CinematographyViewModelTests: XCTestCase {

    // MARK: - moveShot() Tests

    func testMoveShotDoesNotRenumberShotIds() {
        let vm = CinematographyViewModel(shots: [
            Shot(shotId: 3, description: "Shot 3"),
            Shot(shotId: 7, description: "Shot 7"),
            Shot(shotId: 12, description: "Shot 12")
        ])

        // Move shot at index 2 (shotId=12) to index 0
        vm.moveShot(from: IndexSet(integer: 2), to: 0)

        // shotIds should be preserved, NOT renumbered to 1,2,3
        XCTAssertEqual(vm.shots[0].shotId, 12)
        XCTAssertEqual(vm.shots[1].shotId, 3)
        XCTAssertEqual(vm.shots[2].shotId, 7)
    }

    func testMoveShotPreservesUUIDs() {
        let shot1 = Shot(shotId: 1, description: "A")
        let shot2 = Shot(shotId: 2, description: "B")
        let shot3 = Shot(shotId: 3, description: "C")

        let uuid1 = shot1.uuid
        let uuid2 = shot2.uuid
        let uuid3 = shot3.uuid

        let vm = CinematographyViewModel(shots: [shot1, shot2, shot3])

        // Move shot 3 to beginning
        vm.moveShot(from: IndexSet(integer: 2), to: 0)

        // UUIDs should be preserved
        XCTAssertEqual(vm.shots[0].uuid, uuid3)
        XCTAssertEqual(vm.shots[1].uuid, uuid1)
        XCTAssertEqual(vm.shots[2].uuid, uuid2)
    }

    func testMoveShotPreservesDescriptions() {
        let vm = CinematographyViewModel(shots: [
            Shot(shotId: 1, description: "Wide establishing"),
            Shot(shotId: 2, description: "Close up"),
            Shot(shotId: 3, description: "Over the shoulder")
        ])

        vm.moveShot(from: IndexSet(integer: 0), to: 3) // Move first to last

        XCTAssertEqual(vm.shots[0].description, "Close up")
        XCTAssertEqual(vm.shots[1].description, "Over the shoulder")
        XCTAssertEqual(vm.shots[2].description, "Wide establishing")
        // shotIds unchanged
        XCTAssertEqual(vm.shots[0].shotId, 2)
        XCTAssertEqual(vm.shots[1].shotId, 3)
        XCTAssertEqual(vm.shots[2].shotId, 1)
    }

    func testMoveShotNotifiesChange() {
        let vm = CinematographyViewModel(shots: [
            Shot(shotId: 1),
            Shot(shotId: 2)
        ])

        let expectation = XCTestExpectation(description: "onShotsChanged called")
        vm.onShotsChanged = { _ in
            expectation.fulfill()
        }

        vm.moveShot(from: IndexSet(integer: 0), to: 2)

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - duplicateShot() Tests

    func testDuplicateShotGeneratesNewUUID() {
        let original = Shot(shotId: 1, description: "Original shot")
        let vm = CinematographyViewModel(shots: [original])

        vm.duplicateShot(original.id)

        XCTAssertEqual(vm.shots.count, 2)
        XCTAssertNotEqual(vm.shots[0].uuid, vm.shots[1].uuid)
        XCTAssertNotEqual(vm.shots[0].id, vm.shots[1].id)
    }

    func testDuplicateShotGetsNextShotId() {
        let vm = CinematographyViewModel(shots: [
            Shot(shotId: 5, description: "Shot 5"),
            Shot(shotId: 10, description: "Shot 10")
        ])

        vm.duplicateShot(vm.shots[0].id)

        // Next shotId should be max(5,10) + 1 = 11
        let duplicated = vm.shots.last!
        XCTAssertEqual(duplicated.shotId, 11)
    }

    func testDuplicateShotCopiesDescription() {
        let vm = CinematographyViewModel(shots: [
            Shot(shotId: 1, description: "Tracking shot of hero")
        ])

        vm.duplicateShot(vm.shots[0].id)

        XCTAssertEqual(vm.shots[1].description, "Tracking shot of hero (copy)")
    }

    func testDuplicateShotSelectsDuplicate() {
        let original = Shot(shotId: 1, description: "Test")
        let vm = CinematographyViewModel(shots: [original])

        vm.duplicateShot(original.id)

        // The duplicated shot should be selected
        XCTAssertEqual(vm.selectedShotId, vm.shots[1].id)
        XCTAssertNotEqual(vm.selectedShotId, original.id)
    }

    func testDuplicateNonexistentShotDoesNothing() {
        let vm = CinematographyViewModel(shots: [Shot(shotId: 1)])
        let originalCount = vm.shots.count

        vm.duplicateShot("nonexistent-id")

        XCTAssertEqual(vm.shots.count, originalCount)
    }

    // MARK: - nextShotId Tests

    func testNextShotIdEmpty() {
        let vm = CinematographyViewModel(shots: [])
        XCTAssertEqual(vm.nextShotId, 1)
    }

    func testNextShotIdReturnsMaxPlusOne() {
        let vm = CinematographyViewModel(shots: [
            Shot(shotId: 3),
            Shot(shotId: 1),
            Shot(shotId: 7)
        ])
        XCTAssertEqual(vm.nextShotId, 8)
    }

    func testNextShotIdWithGaps() {
        let vm = CinematographyViewModel(shots: [
            Shot(shotId: 1),
            Shot(shotId: 100)
        ])
        XCTAssertEqual(vm.nextShotId, 101)
    }

    // MARK: - CRUD Operations with UUID Identity

    func testAddShotPreservesUUID() {
        let vm = CinematographyViewModel()
        let shot = Shot(shotId: 1, description: "New shot")
        let originalUUID = shot.uuid

        vm.addShot(shot)

        XCTAssertEqual(vm.shots.count, 1)
        XCTAssertEqual(vm.shots[0].uuid, originalUUID)
    }

    func testUpdateShotFindsCorrectShotByUUID() {
        let shot1 = Shot(shotId: 1, description: "Shot A")
        let shot2 = Shot(shotId: 1, description: "Shot B") // Same shotId, different UUID
        let vm = CinematographyViewModel(shots: [shot1, shot2])

        // Update shot2 by its UUID-based id
        var updated = shot2
        updated.description = "Modified B"
        vm.updateShot(updated)

        // shot1 should be unchanged
        XCTAssertEqual(vm.shots[0].description, "Shot A")
        // shot2 should be updated
        XCTAssertEqual(vm.shots[1].description, "Modified B")
    }

    func testRemoveShotByUUIDId() {
        let shot1 = Shot(shotId: 1, description: "Keep")
        let shot2 = Shot(shotId: 1, description: "Remove") // Same shotId!
        let vm = CinematographyViewModel(shots: [shot1, shot2])

        vm.removeShot(shot2.id) // Remove by UUID-based id

        XCTAssertEqual(vm.shots.count, 1)
        XCTAssertEqual(vm.shots[0].description, "Keep")
        XCTAssertEqual(vm.shots[0].uuid, shot1.uuid)
    }

    func testSelectShotByUUIDId() {
        let shot1 = Shot(shotId: 1, description: "A")
        let shot2 = Shot(shotId: 1, description: "B")
        let vm = CinematographyViewModel(shots: [shot1, shot2])

        vm.selectShot(shot2.id)
        XCTAssertEqual(vm.selectedShot?.description, "B")
        XCTAssertEqual(vm.selectedShot?.uuid, shot2.uuid)

        vm.selectShot(shot1.id)
        XCTAssertEqual(vm.selectedShot?.description, "A")
        XCTAssertEqual(vm.selectedShot?.uuid, shot1.uuid)
    }

    // MARK: - createNewShot Tests

    func testCreateNewShotGetsUniqueUUID() {
        let vm = CinematographyViewModel(shots: [
            Shot(shotId: 1),
            Shot(shotId: 2)
        ])

        vm.createNewShot()

        XCTAssertNotNil(vm.editingShot)
        // The new shot should have a UUID different from existing ones
        let existingUUIDs = Set(vm.shots.map { $0.uuid })
        XCTAssertFalse(existingUUIDs.contains(vm.editingShot!.uuid))
    }

    func testSaveNewShotPreservesUUID() {
        let vm = CinematographyViewModel(shots: [])

        vm.createNewShot()
        let newShotUUID = vm.editingShot!.uuid

        vm.saveEditedShot()

        XCTAssertEqual(vm.shots.count, 1)
        XCTAssertEqual(vm.shots[0].uuid, newShotUUID)
    }

    // MARK: - Status Updates with UUID

    func testUpdateStatusFindsCorrectShot() {
        let shot1 = Shot(shotId: 1, description: "A")
        let shot2 = Shot(shotId: 1, description: "B")
        let vm = CinematographyViewModel(shots: [shot1, shot2])

        vm.updateShotStatus(shot2.id, status: .approved)

        XCTAssertEqual(vm.shots[0].status, "Planning") // shot1 unchanged
        XCTAssertEqual(vm.shots[1].status, "Approved")  // shot2 updated
    }

    // MARK: - filteredShots Sorting

    func testFilteredShotsSortByShotId() {
        let vm = CinematographyViewModel(shots: [
            Shot(shotId: 5, description: "E"),
            Shot(shotId: 2, description: "B"),
            Shot(shotId: 8, description: "H")
        ])

        let filtered = vm.filteredShots
        XCTAssertEqual(filtered[0].shotId, 2)
        XCTAssertEqual(filtered[1].shotId, 5)
        XCTAssertEqual(filtered[2].shotId, 8)
    }

    // MARK: - Bulk setShots

    func testSetShotsUpdatesSelection() {
        let shot1 = Shot(shotId: 1)
        let vm = CinematographyViewModel(shots: [shot1])
        vm.selectShot(shot1.id)

        // Replace with entirely new shots
        let newShot = Shot(shotId: 2)
        vm.setShots([newShot])

        // Old selection should be invalid, auto-selects first
        XCTAssertEqual(vm.selectedShotId, newShot.id)
    }

    func testSetShotsPreservesValidSelection() {
        let shot1 = Shot(shotId: 1)
        let shot2 = Shot(shotId: 2)
        let vm = CinematographyViewModel(shots: [shot1, shot2])
        vm.selectShot(shot2.id)

        // Set shots that still contain shot2
        vm.setShots([shot1, shot2])

        XCTAssertEqual(vm.selectedShotId, shot2.id)
    }
}

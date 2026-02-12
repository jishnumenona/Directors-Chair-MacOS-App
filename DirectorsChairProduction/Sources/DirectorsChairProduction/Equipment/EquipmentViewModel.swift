// DirectorsChairProduction/Sources/DirectorsChairProduction/Equipment/EquipmentViewModel.swift
//
// Equipment ViewModel - Data Management with Allocation Support

import SwiftUI
import DirectorsChairCore

@MainActor
public class EquipmentViewModel: ObservableObject {
    @Published public var equipment: [EquipmentItem] = []
    @Published public var allocations: [EquipmentAllocation] = []

    public var onEquipmentChanged: (([EquipmentItem]) -> Void)?
    public var onAllocationsChanged: (([EquipmentAllocation]) -> Void)?

    public init() {}

    // MARK: - Equipment CRUD

    public func addEquipment(_ item: EquipmentItem) {
        equipment.append(item)
        onEquipmentChanged?(equipment)
    }

    public func updateEquipment(_ item: EquipmentItem) {
        if let index = equipment.firstIndex(where: { $0.id == item.id }) {
            equipment[index] = item
            onEquipmentChanged?(equipment)
        }
    }

    public func removeEquipment(_ item: EquipmentItem) {
        equipment.removeAll { $0.id == item.id }
        allocations.removeAll { $0.equipmentItemId == item.id }
        onEquipmentChanged?(equipment)
        onAllocationsChanged?(allocations)
    }

    public func setEquipment(_ items: [EquipmentItem]) {
        equipment = items
    }

    // MARK: - Allocation CRUD

    public func setAllocations(_ allocs: [EquipmentAllocation]) {
        allocations = allocs
    }

    public func setAllocation(for equipmentId: String, mode: ProductionAllocationMode, dates: [String], quantity: Int, notes: String = "") {
        if let index = allocations.firstIndex(where: { $0.equipmentItemId == equipmentId }) {
            allocations[index].allocationMode = mode
            allocations[index].allocatedDates = dates
            allocations[index].quantityAllocated = quantity
            allocations[index].notes = notes
        } else {
            let alloc = EquipmentAllocation(
                equipmentItemId: equipmentId,
                allocationMode: mode,
                allocatedDates: dates,
                quantityAllocated: quantity,
                notes: notes
            )
            allocations.append(alloc)
        }
        onAllocationsChanged?(allocations)
    }

    public func removeAllocation(for equipmentId: String) {
        allocations.removeAll { $0.equipmentItemId == equipmentId }
        onAllocationsChanged?(allocations)
    }

    public func allocation(for equipmentId: String) -> EquipmentAllocation? {
        allocations.first { $0.equipmentItemId == equipmentId }
    }

    // MARK: - Queries

    public func equipment(inCategory category: String) -> [EquipmentItem] {
        equipment.filter { $0.category == category }
    }

    public func fullProductionEquipment() -> [EquipmentItem] {
        let ids = Set(allocations.filter { $0.allocationMode == .fullProduction }.map { $0.equipmentItemId })
        return equipment.filter { ids.contains($0.id) }
    }

    public func specificDaysEquipment() -> [EquipmentItem] {
        let ids = Set(allocations.filter { $0.allocationMode == .specificDays }.map { $0.equipmentItemId })
        return equipment.filter { ids.contains($0.id) }
    }

    public func unallocatedEquipment() -> [EquipmentItem] {
        let allocatedIds = Set(allocations.map { $0.equipmentItemId })
        return equipment.filter { !allocatedIds.contains($0.id) }
    }

    public func equipmentForDate(_ date: String) -> [EquipmentItem] {
        let fullIds = Set(allocations.filter { $0.allocationMode == .fullProduction }.map { $0.equipmentItemId })
        let dateIds = Set(allocations.filter { $0.allocationMode == .specificDays && $0.allocatedDates.contains(date) }.map { $0.equipmentItemId })
        let combined = fullIds.union(dateIds)
        return equipment.filter { combined.contains($0.id) }
    }

    // MARK: - Stats

    public var totalItems: Int { equipment.count }

    public var totalUnits: Int {
        equipment.reduce(0) { $0 + $1.quantityOwned }
    }

    public var allocatedCount: Int {
        let allocatedIds = Set(allocations.map { $0.equipmentItemId })
        return equipment.filter { allocatedIds.contains($0.id) }.count
    }

    public var rentalCostPerDay: Double {
        equipment.filter { $0.isRental }.reduce(0) { $0 + $1.rentalDailyRate }
    }
}

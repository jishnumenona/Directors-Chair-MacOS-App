// DirectorsChairProduction/Sources/DirectorsChairProduction/Schedule/ScheduleViewModel.swift
//
// Schedule ViewModel - Production Schedule Data Management
// Manages schedule items, conflict detection, and schedule optimization.

import SwiftUI
import DirectorsChairCore

// MARK: - Schedule Conflict

/// Represents a scheduling conflict
public struct ScheduleConflict: Identifiable {
    public let id = UUID()
    public let type: ConflictType
    public let description: String
    public let affectedItems: [ScheduleItem]
    public let severity: ConflictSeverity

    public enum ConflictType {
        case resourceOverlap
        case locationConflict
        case timeConflict
        case castUnavailable
        case equipmentShortage
    }

    public enum ConflictSeverity {
        case warning
        case error
        case critical
    }
}

// MARK: - Schedule ViewModel

@MainActor
public class ScheduleViewModel: ObservableObject {
    @Published public var scheduleItems: [ScheduleItem] = []
    @Published public var conflicts: [ScheduleConflict] = []
    @Published public var isLoading = false

    // Callbacks for data persistence
    public var onScheduleChanged: (([ScheduleItem]) -> Void)?

    public init(scheduleItems: [ScheduleItem] = []) {
        self.scheduleItems = scheduleItems
    }

    // MARK: - CRUD Operations

    public func addScheduleItem(_ item: ScheduleItem) {
        scheduleItems.append(item)
        detectConflicts()
        notifyChange()
    }

    public func updateScheduleItem(_ item: ScheduleItem) {
        if let index = scheduleItems.firstIndex(where: { $0.id == item.id }) {
            scheduleItems[index] = item
            detectConflicts()
            notifyChange()
        }
    }

    public func removeScheduleItem(_ item: ScheduleItem) {
        scheduleItems.removeAll { $0.id == item.id }
        detectConflicts()
        notifyChange()
    }

    public func removeScheduleItem(at indexSet: IndexSet) {
        scheduleItems.remove(atOffsets: indexSet)
        detectConflicts()
        notifyChange()
    }

    // MARK: - Bulk Operations

    public func setScheduleItems(_ items: [ScheduleItem]) {
        scheduleItems = items
        detectConflicts()
    }

    public func clearAllItems() {
        scheduleItems.removeAll()
        conflicts.removeAll()
        notifyChange()
    }

    // MARK: - Conflict Detection

    public func detectConflicts() {
        var newConflicts: [ScheduleConflict] = []

        // Group items by date
        let itemsByDate = Dictionary(grouping: scheduleItems) { $0.shootDate ?? "unscheduled" }

        for (_, dayItems) in itemsByDate where dayItems.count > 1 {
            // Check for overlapping time slots on the same day
            for i in 0..<dayItems.count {
                for j in (i+1)..<dayItems.count {
                    let item1 = dayItems[i]
                    let item2 = dayItems[j]

                    // Time slot conflict (if same slot or one is Full Day)
                    if item1.timeSlot == item2.timeSlot ||
                       item1.timeSlot == "Full Day" ||
                       item2.timeSlot == "Full Day" {

                        // Check for resource overlap
                        let sharedCast = Set(item1.requiredActors).intersection(Set(item2.requiredActors))
                        if !sharedCast.isEmpty {
                            newConflicts.append(ScheduleConflict(
                                type: .castUnavailable,
                                description: "Cast members \(sharedCast.joined(separator: ", ")) are scheduled for multiple shoots",
                                affectedItems: [item1, item2],
                                severity: .error
                            ))
                        }

                        let sharedCrew = Set(item1.requiredCrew).intersection(Set(item2.requiredCrew))
                        if !sharedCrew.isEmpty {
                            newConflicts.append(ScheduleConflict(
                                type: .resourceOverlap,
                                description: "Crew members \(sharedCrew.joined(separator: ", ")) are scheduled for multiple shoots",
                                affectedItems: [item1, item2],
                                severity: .warning
                            ))
                        }

                        let sharedEquipment = Set(item1.requiredEquipment).intersection(Set(item2.requiredEquipment))
                        if !sharedEquipment.isEmpty {
                            newConflicts.append(ScheduleConflict(
                                type: .equipmentShortage,
                                description: "Equipment \(sharedEquipment.joined(separator: ", ")) is double-booked",
                                affectedItems: [item1, item2],
                                severity: .warning
                            ))
                        }
                    }

                    // Location conflict (different locations, overlapping times)
                    if !item1.location.isEmpty && !item2.location.isEmpty &&
                       item1.location != item2.location &&
                       (item1.timeSlot == item2.timeSlot || item1.timeSlot == "Full Day" || item2.timeSlot == "Full Day") {

                        newConflicts.append(ScheduleConflict(
                            type: .locationConflict,
                            description: "Shoots at different locations (\(item1.location) and \(item2.location)) may conflict",
                            affectedItems: [item1, item2],
                            severity: .warning
                        ))
                    }
                }
            }
        }

        conflicts = newConflicts
    }

    // MARK: - Schedule Optimization

    /// Suggests optimizations for the current schedule
    public func suggestOptimizations() -> [String] {
        var suggestions: [String] = []

        // Group by location
        let itemsByLocation = Dictionary(grouping: scheduleItems.filter { !$0.location.isEmpty }) { $0.location }
        for (location, items) in itemsByLocation where items.count > 1 {
            let uniqueDates = Set(items.compactMap { $0.shootDate })
            if uniqueDates.count > 1 {
                suggestions.append("Consider consolidating \(items.count) shoots at \(location) to reduce location changes")
            }
        }

        // Check for inefficient scheduling
        let itemsByDate = Dictionary(grouping: scheduleItems) { $0.shootDate ?? "unscheduled" }
        for (date, items) in itemsByDate {
            let totalHours = items.reduce(0) { $0 + $1.estimatedDurationHours }
            if totalHours < 4 && date != "unscheduled" {
                suggestions.append("Only \(String(format: "%.1f", totalHours)) hours scheduled on \(date). Consider adding more scenes.")
            }
            if totalHours > 12 {
                suggestions.append("Over \(String(format: "%.1f", totalHours)) hours scheduled on \(date). Consider splitting across days.")
            }
        }

        // Check for gaps in schedule
        let sortedDates = scheduleItems.compactMap { $0.shootDate }.sorted()
        if sortedDates.count > 1 {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"

            for i in 0..<(sortedDates.count - 1) {
                if let date1 = formatter.date(from: sortedDates[i]),
                   let date2 = formatter.date(from: sortedDates[i + 1]) {
                    let gap = Calendar.current.dateComponents([.day], from: date1, to: date2).day ?? 0
                    if gap > 3 {
                        suggestions.append("Gap of \(gap) days between \(sortedDates[i]) and \(sortedDates[i + 1])")
                    }
                }
            }
        }

        return suggestions
    }

    /// Auto-optimize schedule by grouping by location and balancing daily hours
    public func autoOptimize() {
        // Simple optimization: sort by date, then by location
        scheduleItems.sort { item1, item2 in
            // First by date
            if let date1 = item1.shootDate, let date2 = item2.shootDate {
                if date1 != date2 {
                    return date1 < date2
                }
            }
            // Then by location
            return item1.location < item2.location
        }

        detectConflicts()
        notifyChange()
    }

    // MARK: - Statistics

    public var totalScheduledHours: Double {
        scheduleItems.reduce(0) { $0 + $1.estimatedDurationHours }
    }

    public var uniqueShootDays: Int {
        Set(scheduleItems.compactMap { $0.shootDate }).count
    }

    public var completedItems: Int {
        scheduleItems.filter { $0.status == "Complete" }.count
    }

    public var progressPercentage: Double {
        guard !scheduleItems.isEmpty else { return 0 }
        return Double(completedItems) / Double(scheduleItems.count) * 100
    }

    // MARK: - Filtering & Queries

    public func items(for date: String) -> [ScheduleItem] {
        scheduleItems.filter { $0.shootDate == date }
    }

    public func items(with status: String) -> [ScheduleItem] {
        scheduleItems.filter { $0.status == status }
    }

    public func items(at location: String) -> [ScheduleItem] {
        scheduleItems.filter { $0.location == location }
    }

    public func items(requiring actor: String) -> [ScheduleItem] {
        scheduleItems.filter { $0.requiredActors.contains(actor) }
    }

    // MARK: - Private Helpers

    private func notifyChange() {
        onScheduleChanged?(scheduleItems)
    }
}

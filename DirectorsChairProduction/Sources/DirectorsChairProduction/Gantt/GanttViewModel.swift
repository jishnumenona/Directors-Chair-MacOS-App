// DirectorsChairProduction/Sources/DirectorsChairProduction/Gantt/GanttViewModel.swift
//
// ViewModel for Production Gantt Chart

import SwiftUI
import DirectorsChairCore

// MARK: - Supporting Types

public enum GanttZoomLevel: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case month = "Month"

    public var columnWidth: CGFloat {
        switch self {
        case .day: return 36
        case .week: return 24
        case .month: return 12
        }
    }
}

public enum GanttGroupMode: String, CaseIterable {
    case none = "None"
    case category = "Category"
    case location = "Location"
    case status = "Status"
    case assignee = "Assignee"
}

public enum GanttSortMode: String, CaseIterable {
    case startDate = "Start Date"
    case priority = "Priority"
    case category = "Category"
    case status = "Status"
    case name = "Name"
}

public struct GanttConflict: Identifiable {
    public var id = UUID().uuidString
    public var type: String
    public var description: String
    public var affectedTaskIds: [String]
}

// MARK: - GanttViewModel

@MainActor
public class GanttViewModel: ObservableObject {
    // MARK: - Published State

    @Published public var tasks: [GanttTask] = []
    @Published public var selectedTaskId: String?

    // Connected data from project
    @Published public var scheduleItems: [ScheduleItem] = []
    @Published public var castMembers: [CastMember] = []
    @Published public var crewMembers: [CrewMember] = []
    @Published public var characters: [DirectorsChairCore.Character] = []
    @Published public var props: [Prop] = []
    @Published public var equipment: [EquipmentItem] = []
    @Published public var locations: [Location] = []
    @Published public var sequences: [Sequence] = []

    // View state
    @Published public var zoomLevel: GanttZoomLevel = .week
    @Published public var viewportStartDate: Date = Date()
    @Published public var searchText: String = ""

    // Filters
    @Published public var categoryFilter: Set<GanttTaskCategory> = []
    @Published public var statusFilter: Set<String> = []
    @Published public var tagFilter: Set<String> = []

    // Display options
    @Published public var groupBy: GanttGroupMode = .none
    @Published public var sortBy: GanttSortMode = .startDate
    @Published public var showResourceView: Bool = false

    // Callbacks
    public var onTasksChanged: (([GanttTask]) -> Void)?

    public init() {}

    // MARK: - Date Formatter

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private func parseDate(_ string: String) -> Date? {
        Self.dateFormatter.date(from: string)
    }

    private func formatDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    // MARK: - CRUD

    public func addTask(_ task: GanttTask) {
        var t = task
        t.sortOrder = tasks.count
        tasks.append(t)
        notifyChanged()
    }

    public func updateTask(_ task: GanttTask) {
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            var t = task
            t.modifiedDate = GanttTask.isoDateString()
            tasks[idx] = t
            notifyChanged()
        }
    }

    public func removeTask(_ taskId: String) {
        tasks.removeAll { $0.id == taskId }
        // Remove from all dependency lists
        for i in tasks.indices {
            tasks[i].dependsOn.removeAll { $0 == taskId }
        }
        if selectedTaskId == taskId { selectedTaskId = nil }
        notifyChanged()
    }

    public func setTasks(_ newTasks: [GanttTask]) {
        tasks = newTasks
    }

    // MARK: - Sync from Schedule Items

    public func syncFromScheduleItems() {
        let linkedIds = Set(tasks.compactMap { $0.scheduleItemId })
        var added = 0

        for item in scheduleItems {
            guard !linkedIds.contains(item.id) else { continue }
            guard let date = item.shootDate, !date.isEmpty else { continue }

            var task = GanttTask(
                name: item.sceneName,
                category: .shooting,
                scheduleItemId: item.id,
                startDate: date,
                durationDays: max(1, Int(ceil(item.estimatedDurationHours / 8.0))),
                status: mapScheduleStatus(item.status),
                completionPercentage: item.completionPercentage,
                priority: item.priority
            )

            task.locationNames = [item.location].compactMap { $0?.isEmpty == false ? $0 : nil }
            task.assignedCastIds = item.requiredActors
            task.assignedCrewIds = item.requiredCrew
            task.requiredEquipmentIds = item.requiredEquipment
            task.requiredPropIds = item.requiredProps
            task.notes = item.productionNotes ?? ""
            task.estimatedCost = item.estimatedCost ?? 0
            task.actualCost = item.actualCost
            task.sortOrder = tasks.count + added

            tasks.append(task)
            added += 1
        }

        if added > 0 { notifyChanged() }
    }

    private func mapScheduleStatus(_ status: String) -> String {
        switch status {
        case "Planned", "Confirmed": return "Not Started"
        case "In Progress": return "In Progress"
        case "Shot", "Complete": return "Complete"
        case "Cancelled": return "Cancelled"
        case "Postponed": return "On Hold"
        default: return "Not Started"
        }
    }

    // MARK: - Filtering & Sorting

    public var filteredTasks: [GanttTask] {
        var result = tasks

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(query) ||
                $0.taskDescription.lowercased().contains(query) ||
                $0.customTags.contains { $0.lowercased().contains(query) } ||
                $0.locationNames.contains { $0.lowercased().contains(query) }
            }
        }

        if !categoryFilter.isEmpty {
            result = result.filter { categoryFilter.contains($0.category) }
        }
        if !statusFilter.isEmpty {
            result = result.filter { statusFilter.contains($0.status) }
        }
        if !tagFilter.isEmpty {
            result = result.filter { task in
                !tagFilter.isDisjoint(with: Set(task.customTags))
            }
        }

        return sortTasks(result)
    }

    private func sortTasks(_ tasks: [GanttTask]) -> [GanttTask] {
        switch sortBy {
        case .startDate:
            return tasks.sorted { $0.startDate < $1.startDate }
        case .priority:
            return tasks.sorted { $0.priority > $1.priority }
        case .category:
            return tasks.sorted { $0.category.rawValue < $1.category.rawValue }
        case .status:
            return tasks.sorted { statusOrder($0.status) < statusOrder($1.status) }
        case .name:
            return tasks.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    private func statusOrder(_ status: String) -> Int {
        switch status {
        case "In Progress": return 0
        case "Not Started": return 1
        case "On Hold": return 2
        case "Complete": return 3
        case "Cancelled": return 4
        default: return 5
        }
    }

    public var groupedTasks: [(String, [GanttTask])] {
        let filtered = filteredTasks
        switch groupBy {
        case .none:
            return [("All Tasks", filtered)]
        case .category:
            let grouped = Dictionary(grouping: filtered) { $0.category.rawValue }
            return grouped.sorted { $0.key < $1.key }
        case .location:
            var result: [(String, [GanttTask])] = []
            var seen = Set<String>()
            for task in filtered {
                let loc = task.locationNames.first ?? "No Location"
                if !seen.contains(loc) {
                    seen.insert(loc)
                    result.append((loc, filtered.filter { ($0.locationNames.first ?? "No Location") == loc }))
                }
            }
            return result
        case .status:
            let grouped = Dictionary(grouping: filtered) { $0.status }
            return grouped.sorted { statusOrder($0.key) < statusOrder($1.key) }
        case .assignee:
            var result: [(String, [GanttTask])] = []
            var seen = Set<String>()
            for task in filtered {
                let assignee = firstAssigneeName(for: task) ?? "Unassigned"
                if !seen.contains(assignee) {
                    seen.insert(assignee)
                    result.append((assignee, filtered.filter { (firstAssigneeName(for: $0) ?? "Unassigned") == assignee }))
                }
            }
            return result
        }
    }

    private func firstAssigneeName(for task: GanttTask) -> String? {
        if let castId = task.assignedCastIds.first,
           let member = castMembers.first(where: { $0.id == castId }) {
            return member.actorName
        }
        if let crewId = task.assignedCrewIds.first,
           let member = crewMembers.first(where: { $0.id == crewId }) {
            return member.name
        }
        return nil
    }

    // MARK: - Date Range

    public var projectDateRange: (start: Date, end: Date) {
        let today = Date()
        var earliest = today
        var latest = Calendar.current.date(byAdding: .day, value: 30, to: today) ?? today

        for task in tasks {
            if let start = parseDate(task.startDate) {
                if start < earliest { earliest = start }
                if let end = parseDate(task.computedEndDate), end > latest {
                    latest = end
                }
            }
        }

        // Add padding
        earliest = Calendar.current.date(byAdding: .day, value: -3, to: earliest) ?? earliest
        latest = Calendar.current.date(byAdding: .day, value: 7, to: latest) ?? latest

        return (earliest, latest)
    }

    public var totalDays: Int {
        let range = projectDateRange
        return max(1, Calendar.current.dateComponents([.day], from: range.start, to: range.end).day ?? 30)
    }

    // MARK: - Critical Path

    public var criticalPath: Set<String> {
        computeCriticalPath()
    }

    private func computeCriticalPath() -> Set<String> {
        guard !tasks.isEmpty else { return [] }

        let taskMap = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
        var earlyStart: [String: Int] = [:]
        var earlyFinish: [String: Int] = [:]
        var lateStart: [String: Int] = [:]
        var lateFinish: [String: Int] = [:]

        // Forward pass
        func computeEarly(_ id: String) -> Int {
            if let cached = earlyFinish[id] { return cached }
            guard let task = taskMap[id] else { return 0 }

            var es = 0
            for depId in task.dependsOn {
                es = max(es, computeEarly(depId))
            }
            earlyStart[id] = es
            let ef = es + task.durationDays
            earlyFinish[id] = ef
            return ef
        }

        for task in tasks {
            _ = computeEarly(task.id)
        }

        let projectEnd = earlyFinish.values.max() ?? 0

        // Backward pass
        // Find tasks that nothing depends on (end tasks)
        let allDeps = Set(tasks.flatMap { $0.dependsOn })
        let endTasks = tasks.filter { !allDeps.contains($0.id) }

        func computeLate(_ id: String) -> Int {
            if let cached = lateStart[id] { return cached }
            guard let task = taskMap[id] else { return projectEnd }

            let successors = tasks.filter { $0.dependsOn.contains(id) }
            var lf = projectEnd
            for succ in successors {
                lf = min(lf, computeLate(succ.id))
            }
            lateFinish[id] = lf
            let ls = lf - task.durationDays
            lateStart[id] = ls
            return ls
        }

        for task in endTasks {
            lateFinish[task.id] = projectEnd
        }
        for task in tasks {
            _ = computeLate(task.id)
        }

        // Critical = zero float (early start == late start)
        var critical = Set<String>()
        for task in tasks {
            let es = earlyStart[task.id] ?? 0
            let ls = lateStart[task.id] ?? 0
            if es == ls && task.durationDays > 0 {
                critical.insert(task.id)
            }
        }
        return critical
    }

    // MARK: - Dependency Validation

    public func wouldCreateCycle(from: String, to: String) -> Bool {
        // Check if adding dependency from -> to would create a cycle
        // i.e., check if 'from' is reachable from 'to' already
        var visited = Set<String>()
        var stack = [from]
        while let current = stack.popLast() {
            guard !visited.contains(current) else { continue }
            visited.insert(current)
            if current == to { return true }
            if let task = tasks.first(where: { $0.id == current }) {
                stack.append(contentsOf: task.dependsOn)
            }
        }
        return false
    }

    public func validateDependencies() -> [GanttConflict] {
        var conflicts: [GanttConflict] = []
        let taskMap = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })

        for task in tasks {
            for depId in task.dependsOn {
                guard let dep = taskMap[depId] else {
                    conflicts.append(GanttConflict(
                        type: "Missing Dependency",
                        description: "\(task.name) depends on non-existent task",
                        affectedTaskIds: [task.id]
                    ))
                    continue
                }
                // Check timing: dependency should finish before task starts
                if let depEnd = parseDate(dep.computedEndDate),
                   let taskStart = parseDate(task.startDate),
                   depEnd > taskStart {
                    conflicts.append(GanttConflict(
                        type: "Schedule Conflict",
                        description: "\(task.name) starts before \(dep.name) finishes",
                        affectedTaskIds: [task.id, depId]
                    ))
                }
            }
        }
        return conflicts
    }

    // MARK: - Resource Conflicts

    public func resourceConflicts() -> [GanttConflict] {
        var conflicts: [GanttConflict] = []
        let activeTasks = tasks.filter { $0.status != "Complete" && $0.status != "Cancelled" }

        for i in 0..<activeTasks.count {
            for j in (i+1)..<activeTasks.count {
                let a = activeTasks[i]
                let b = activeTasks[j]
                guard tasksOverlap(a, b) else { continue }

                let sharedCast = Set(a.assignedCastIds).intersection(Set(b.assignedCastIds))
                if !sharedCast.isEmpty {
                    let names = sharedCast.compactMap { id in castMembers.first { $0.id == id }?.actorName }.joined(separator: ", ")
                    conflicts.append(GanttConflict(
                        type: "Cast Conflict",
                        description: "\(names) assigned to overlapping tasks: \(a.name) & \(b.name)",
                        affectedTaskIds: [a.id, b.id]
                    ))
                }

                let sharedCrew = Set(a.assignedCrewIds).intersection(Set(b.assignedCrewIds))
                if !sharedCrew.isEmpty {
                    let names = sharedCrew.compactMap { id in crewMembers.first { $0.id == id }?.name }.joined(separator: ", ")
                    conflicts.append(GanttConflict(
                        type: "Crew Conflict",
                        description: "\(names) assigned to overlapping tasks: \(a.name) & \(b.name)",
                        affectedTaskIds: [a.id, b.id]
                    ))
                }

                let sharedEquip = Set(a.requiredEquipmentIds).intersection(Set(b.requiredEquipmentIds))
                if !sharedEquip.isEmpty {
                    let names = sharedEquip.compactMap { id in equipment.first { $0.id == id }?.name }.joined(separator: ", ")
                    conflicts.append(GanttConflict(
                        type: "Equipment Conflict",
                        description: "\(names) needed for overlapping tasks: \(a.name) & \(b.name)",
                        affectedTaskIds: [a.id, b.id]
                    ))
                }
            }
        }
        return conflicts
    }

    private func tasksOverlap(_ a: GanttTask, _ b: GanttTask) -> Bool {
        guard let aStart = parseDate(a.startDate),
              let aEnd = parseDate(a.computedEndDate),
              let bStart = parseDate(b.startDate),
              let bEnd = parseDate(b.computedEndDate) else { return false }
        return aStart <= bEnd && bStart <= aEnd
    }

    // MARK: - Resource Queries

    public func tasksForCast(_ castId: String) -> [GanttTask] {
        filteredTasks.filter { $0.assignedCastIds.contains(castId) }
    }

    public func tasksForCrew(_ crewId: String) -> [GanttTask] {
        filteredTasks.filter { $0.assignedCrewIds.contains(crewId) }
    }

    public func tasksForEquipment(_ equipId: String) -> [GanttTask] {
        filteredTasks.filter { $0.requiredEquipmentIds.contains(equipId) }
    }

    // MARK: - Drag Operations

    public func moveTask(id: String, newStartDate: Date) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[idx].startDate = formatDate(newStartDate)
        tasks[idx].modifiedDate = GanttTask.isoDateString()
        notifyChanged()
    }

    public func resizeTask(id: String, newEndDate: Date) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }),
              let start = parseDate(tasks[idx].startDate) else { return }
        let days = max(1, (Calendar.current.dateComponents([.day], from: start, to: newEndDate).day ?? 1) + 1)
        tasks[idx].durationDays = days
        tasks[idx].endDate = formatDate(newEndDate)
        tasks[idx].modifiedDate = GanttTask.isoDateString()
        notifyChanged()
    }

    // MARK: - Stats

    public var totalTasks: Int { tasks.count }
    public var completedTasks: Int { tasks.filter { $0.status == "Complete" }.count }
    public var progressPercentage: Int {
        guard !tasks.isEmpty else { return 0 }
        return tasks.reduce(0) { $0 + $1.completionPercentage } / tasks.count
    }
    public var totalEstimatedCost: Double {
        tasks.reduce(0) { $0 + $1.estimatedCost }
    }
    public var criticalPathDays: Int {
        let cp = criticalPath
        return tasks.filter { cp.contains($0.id) }.reduce(0) { $0 + $1.durationDays }
    }

    // MARK: - All Custom Tags

    public var allCustomTags: [String] {
        Array(Set(tasks.flatMap { $0.customTags })).sorted()
    }

    // MARK: - Private

    private func notifyChanged() {
        onTasksChanged?(tasks)
    }
}

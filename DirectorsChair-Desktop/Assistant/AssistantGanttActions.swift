//
//  AssistantGanttActions.swift
//  DirectorsChair-Desktop
//
//  AI Assistant program, Phase A3.3: production-plan (Gantt) CRUD actions
//  (F-D3) with the validator in the loop (AD6) — dependency edits run the
//  app's real cycle detector (a cycle is a hard error the model must fix),
//  and the hypothetical plan's new validation problems ride along as
//  warnings. Task references accept an id or a unique task name.
//

import Foundation
import DirectorsChairCore
import DirectorsChairServices
import DirectorsChairProduction

private let stringProp = JSONValue.object(["type": .string("string")])
private let integerProp = JSONValue.object(["type": .string("integer")])
private let boolProp = JSONValue.object(["type": .string("boolean")])
private let stringArrayProp = JSONValue.object(
    ["type": .string("array"), "items": .object(["type": .string("string")])])

private func objectSchema(_ properties: [String: JSONValue],
                          required: [String]) -> JSONValue {
    .object(["type": .string("object"),
             "properties": .object(properties),
             "required": .array(required.map(JSONValue.string))])
}

// MARK: - Shared Gantt helpers

class GanttAssistantAction: ProjectAssistantAction {
    @MainActor func requireDate(_ date: String, field: String) throws {
        guard date.range(of: #"^\d{4}-\d{2}-\d{2}$"#,
                         options: .regularExpression) != nil else {
            throw ActionError("\(field) must be YYYY-MM-DD, got '\(date)'")
        }
    }

    @MainActor func requireCategory(_ raw: String) throws -> GanttTaskCategory {
        guard let match = GanttTaskCategory.allCases.first(where: {
            $0.rawValue.lowercased() == raw.lowercased()
        }) else {
            throw ActionError("category must be one of: "
                + GanttTaskCategory.allCases.map(\.rawValue).joined(separator: ", "))
        }
        return match
    }

    /// Resolves a task reference (id, or unique name, case-insensitive).
    @MainActor func taskIndex(_ reference: String,
                              in tasks: [GanttTask]) throws -> Int {
        if let byId = tasks.firstIndex(where: { $0.id == reference }) {
            return byId
        }
        let byName = tasks.indices.filter {
            tasks[$0].name.lowercased() == reference.lowercased()
        }
        guard let first = byName.first else {
            let known = tasks.map(\.name).joined(separator: ", ")
            throw ActionError("no plan task '\(reference)'"
                + (known.isEmpty ? " — the plan is empty" : " (tasks: \(known))"))
        }
        guard byName.count == 1 else {
            throw ActionError("task name '\(reference)' matches \(byName.count) tasks — use the task id from get_gantt")
        }
        return first
    }

    /// Resolves dependency references to ids, rejecting self-dependencies
    /// and cycles against the hypothetical plan (AD6 — hard errors).
    @MainActor func resolveDependencies(_ references: [String], for taskId: String,
                                        in tasks: [GanttTask]) throws -> [String] {
        let ids = try references.map { tasks[try taskIndex($0, in: tasks)].id }
        if ids.contains(taskId) {
            throw ActionError("a task cannot depend on itself")
        }
        var hypothetical = tasks
        if let index = hypothetical.firstIndex(where: { $0.id == taskId }) {
            hypothetical[index].dependsOn = ids
        }
        let checker = GanttViewModel()
        checker.setTasks(hypothetical)
        for dependency in ids where checker.wouldCreateCycle(from: dependency, to: taskId) {
            let name = tasks.first { $0.id == dependency }?.name ?? dependency
            throw ActionError("depending on '\(name)' would create a dependency cycle")
        }
        return ids
    }

    /// New validation problems the hypothetical plan has that the current
    /// one doesn't — surfaced as warnings, never a silent block.
    @MainActor func newProblems(applying hypothetical: [GanttTask],
                                current: [GanttTask]) -> [String] {
        func descriptions(_ tasks: [GanttTask]) -> [String] {
            let checker = GanttViewModel()
            checker.setTasks(tasks)
            return checker.validateDependencies().map(\.description)
        }
        let existing = Set(descriptions(current))
        return descriptions(hypothetical).filter { !existing.contains($0) }
    }
}

// MARK: - add_gantt_task

final class AddGanttTaskAction: GanttAssistantAction, AssistantAction {
    let name = "add_gantt_task"
    let summary = """
    Add a task to the production plan (Gantt). Dates are YYYY-MM-DD; \
    category one of the plan categories; depends_on takes task names or ids \
    (cycles are rejected).
    """
    let risk = ActionRisk.mutating
    var parameterSchema: JSONValue {
        objectSchema([
            "name": stringProp, "category": stringProp,
            "start_date": stringProp, "end_date": stringProp,
            "milestone": boolProp, "depends_on": stringArrayProp,
        ], required: ["name", "category", "start_date"])
    }

    private struct Arguments: Decodable {
        let name: String, category: String, startDate: String
        let endDate: String?, milestone: Bool?, dependsOn: [String]?
        enum CodingKeys: String, CodingKey {
            case name, category, milestone
            case startDate = "start_date", endDate = "end_date"
            case dependsOn = "depends_on"
        }
    }

    @MainActor private func build(_ args: Arguments,
                                  in pvm: ProjectViewModel) throws -> GanttTask {
        try requireDate(args.startDate, field: "start_date")
        if let end = args.endDate {
            try requireDate(end, field: "end_date")
            guard args.startDate <= end else {
                throw ActionError("end_date is before start_date")
            }
        }
        let category = try requireCategory(args.category)
        let tasks = pvm.project.ganttTasks
        if tasks.contains(where: { $0.name.lowercased() == args.name.lowercased() }) {
            throw ActionError("a task named '\(args.name)' already exists")
        }
        var task = GanttTask(name: args.name, category: category,
                             isMilestone: args.milestone ?? false,
                             startDate: args.startDate, endDate: args.endDate)
        if let deps = args.dependsOn {
            task.dependsOn = try resolveDependencies(deps, for: task.id, in: tasks)
        }
        return task
    }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let pvm = try requireProject()
        let task = try build(args, in: pvm)
        return ActionPlan(
            summary: "Add plan task “\(args.name)” (\(task.category.rawValue))",
            previews: [ActionPreview(
                title: "\(args.name) · \(task.isMilestone ? "milestone" : "task")",
                oldValue: nil,
                newValue: "\(args.startDate)\(args.endDate.map { " → \($0)" } ?? "")")],
            warnings: newProblems(applying: pvm.project.ganttTasks + [task],
                                  current: pvm.project.ganttTasks))
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let pvm = try requireProject()
        let task = try build(args, in: pvm)
        pvm.project.ganttTasks.append(task)
        didMutate(.production)
        return ActionOutcome(resultForModel: #"{"status": "applied"}"#,
                             userSummary: "Added plan task “\(args.name)”")
    }
}

// MARK: - update_gantt_task

final class UpdateGanttTaskAction: GanttAssistantAction, AssistantAction {
    let name = "update_gantt_task"
    let summary = """
    Edit a plan task (by name or id): rename, dates, status, completion \
    0–100, or replace its dependencies (names or ids; cycles are rejected).
    """
    let risk = ActionRisk.mutating
    var parameterSchema: JSONValue {
        objectSchema([
            "task": stringProp, "new_name": stringProp,
            "new_start_date": stringProp, "new_end_date": stringProp,
            "new_status": stringProp, "new_completion": integerProp,
            "new_depends_on": stringArrayProp,
        ], required: ["task"])
    }

    private struct Arguments: Decodable {
        let task: String
        let newName: String?, newStartDate: String?, newEndDate: String?
        let newStatus: String?, newCompletion: Int?, newDependsOn: [String]?
        enum CodingKeys: String, CodingKey {
            case task
            case newName = "new_name", newStartDate = "new_start_date"
            case newEndDate = "new_end_date", newStatus = "new_status"
            case newCompletion = "new_completion", newDependsOn = "new_depends_on"
        }
    }

    @MainActor private func apply(_ args: Arguments, to task: GanttTask,
                                  in tasks: [GanttTask]) throws
    -> (GanttTask, [ActionPreview]) {
        var updated = task
        var previews: [ActionPreview] = []
        func change(_ title: String, _ old: String, _ new: String) {
            previews.append(ActionPreview(title: "\(task.name) · \(title)",
                                          oldValue: old, newValue: new))
        }
        if let name = args.newName {
            change("name", task.name, name)
            updated.name = name
        }
        if let start = args.newStartDate {
            try requireDate(start, field: "new_start_date")
            change("start", task.startDate, start)
            updated.startDate = start
        }
        if let end = args.newEndDate {
            try requireDate(end, field: "new_end_date")
            change("end", task.endDate ?? "—", end)
            updated.endDate = end
        }
        if let status = args.newStatus {
            change("status", task.status, status)
            updated.status = status
        }
        if let completion = args.newCompletion {
            guard (0...100).contains(completion) else {
                throw ActionError("new_completion must be 0–100")
            }
            change("completion", "\(task.completionPercentage)%", "\(completion)%")
            updated.completionPercentage = completion
        }
        if let deps = args.newDependsOn {
            let ids = try resolveDependencies(deps, for: task.id, in: tasks)
            let names = { (list: [String]) in
                list.map { id in tasks.first { $0.id == id }?.name ?? id }
                    .joined(separator: ", ")
            }
            change("depends on", task.dependsOn.isEmpty ? "—" : names(task.dependsOn),
                   ids.isEmpty ? "—" : names(ids))
            updated.dependsOn = ids
        }
        if updated.startDate > (updated.endDate ?? updated.startDate) {
            throw ActionError("end date would be before start date")
        }
        guard !previews.isEmpty else {
            throw ActionError("nothing to change — pass at least one new_* field")
        }
        return (updated, previews)
    }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let tasks = try requireProject().project.ganttTasks
        let index = try taskIndex(args.task, in: tasks)
        let (updated, previews) = try apply(args, to: tasks[index], in: tasks)
        var hypothetical = tasks
        hypothetical[index] = updated
        return ActionPlan(
            summary: "Update plan task “\(tasks[index].name)”",
            previews: previews,
            warnings: newProblems(applying: hypothetical, current: tasks))
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let pvm = try requireProject()
        let tasks = pvm.project.ganttTasks
        let index = try taskIndex(args.task, in: tasks)
        let (updated, _) = try apply(args, to: tasks[index], in: tasks)
        pvm.project.ganttTasks[index] = updated
        didMutate(.production)
        return ActionOutcome(resultForModel: #"{"status": "applied"}"#,
                             userSummary: "Updated plan task “\(updated.name)”")
    }
}

// MARK: - remove_gantt_task

final class RemoveGanttTaskAction: GanttAssistantAction, AssistantAction {
    let name = "remove_gantt_task"
    let summary = "Remove a task from the production plan; dependent tasks lose that dependency."
    let risk = ActionRisk.mutating
    var parameterSchema: JSONValue {
        objectSchema(["task": stringProp], required: ["task"])
    }

    private struct Arguments: Decodable { let task: String }

    @MainActor private func dependents(of id: String,
                                       in tasks: [GanttTask]) -> [String] {
        tasks.filter { $0.dependsOn.contains(id) }.map(\.name)
    }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let tasks = try requireProject().project.ganttTasks
        let index = try taskIndex(args.task, in: tasks)
        let task = tasks[index]
        let dependentNames = dependents(of: task.id, in: tasks)
        return ActionPlan(
            summary: "Remove plan task “\(task.name)”",
            previews: [ActionPreview(title: "\(task.name) · \(task.category.rawValue)",
                                     oldValue: task.startDate, newValue: "removed")],
            warnings: dependentNames.isEmpty ? [] :
                ["\(dependentNames.joined(separator: ", ")) depend\(dependentNames.count == 1 ? "s" : "") on it — that dependency will be dropped"])
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let pvm = try requireProject()
        let index = try taskIndex(args.task, in: pvm.project.ganttTasks)
        let removed = pvm.project.ganttTasks.remove(at: index)
        for otherIndex in pvm.project.ganttTasks.indices {
            pvm.project.ganttTasks[otherIndex].dependsOn.removeAll { $0 == removed.id }
        }
        didMutate(.production)
        return ActionOutcome(resultForModel: #"{"status": "applied"}"#,
                             userSummary: "Removed plan task “\(removed.name)”")
    }
}

// MARK: - Factory extension

extension AssistantActionFactory {
    @MainActor static func ganttActions(projectViewModel: ProjectViewModel?,
                                        coordinator: AppCoordinator?) -> [any AssistantAction] {
        [
            AddGanttTaskAction(projectViewModel: projectViewModel, coordinator: coordinator),
            UpdateGanttTaskAction(projectViewModel: projectViewModel, coordinator: coordinator),
            RemoveGanttTaskAction(projectViewModel: projectViewModel, coordinator: coordinator),
        ]
    }
}

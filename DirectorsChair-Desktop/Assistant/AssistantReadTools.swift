//
//  AssistantReadTools.swift
//  DirectorsChair-Desktop
//
//  AI Assistant program, Phase A3.1: read-only tools the model calls to PULL
//  live project data on demand (F-A1/A3, F-D6) — replacing guesswork over the
//  keyword-matched context dump with exact figures, and running the existing
//  deterministic validators (schedule conflicts, Gantt dependency checks) so
//  answers about conflicts are computed, never inferred. Read-only: the
//  engine executes these inside the loop without approval (AD5). Personal
//  contact, pay rates, and contract data are intentionally NOT exposed.
//

import Foundation
import DirectorsChairCore
import DirectorsChairServices
import DirectorsChairProduction

// MARK: - JSON payload helper

private let payloadEncoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]      // deterministic for evals
    return encoder
}()

private func payload<T: Encodable>(_ value: T) throws -> String {
    guard let json = String(data: try payloadEncoder.encode(value), encoding: .utf8) else {
        throw ActionError("failed to encode tool result")
    }
    return json
}

private func objectSchema(_ properties: [String: JSONValue],
                          required: [String] = []) -> JSONValue {
    .object(["type": .string("object"),
             "properties": .object(properties),
             "required": .array(required.map(JSONValue.string))])
}

private let stringProp = JSONValue.object(["type": .string("string")])

// MARK: - Scenes

final class ListScenesAction: ProjectAssistantAction, AssistantAction {
    let name = "list_scenes"
    let summary = "List every sequence and scene with status and content counts."
    let risk = ActionRisk.readOnly
    var parameterSchema: JSONValue { objectSchema([:]) }

    private struct SceneRow: Encodable {
        let name: String, sequence: String, status: String
        let dialogues: Int, shots: Int
    }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        ActionPlan(summary: "List all scenes")
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let project = try requireProject().project
        let rows = project.sequences.flatMap { sequence in
            sequence.scenes.map { scene in
                SceneRow(name: scene.name, sequence: sequence.name,
                         status: scene.productionStatus,
                         dialogues: scene.dialogues.count, shots: scene.shots.count)
            }
        }
        return ActionOutcome(resultForModel: try payload(rows),
                             userSummary: "Listed \(rows.count) scenes")
    }
}

final class GetSceneAction: ProjectAssistantAction, AssistantAction {
    let name = "get_scene"
    let summary = """
    Read one scene in full: description, notes, status, time of day, \
    weather, location, dialogues (with their [n] edit indices), actions, \
    and shots.
    """
    let risk = ActionRisk.readOnly
    var parameterSchema: JSONValue {
        objectSchema(["scene": stringProp], required: ["scene"])
    }

    private struct Arguments: Decodable { let scene: String }
    private struct Detail: Encodable {
        struct Line: Encodable { let index: Int, character: String, text: String }
        struct ShotRow: Encodable {
            let number: Int, type: String, angle: String, status: String
            let description: String
        }
        let name: String, sequence: String, description: String, notes: String
        let status: String, timeOfDay: String, weather: String, location: String
        let dialogues: [Line], actions: [String], shots: [ShotRow]
    }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        _ = try sceneIndices(named: args.scene, in: try requireProject())
        return ActionPlan(summary: "Read “\(args.scene)”")
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let pvm = try requireProject()
        let (seq, sc) = try sceneIndices(named: args.scene, in: pvm)
        let sequence = pvm.project.sequences[seq]
        let scene = sequence.scenes[sc]
        let detail = Detail(
            name: scene.name, sequence: sequence.name,
            description: scene.description, notes: scene.notes,
            status: scene.productionStatus, timeOfDay: scene.timeOfDay ?? "",
            weather: scene.weather ?? "", location: scene.location ?? "",
            dialogues: scene.dialogues.enumerated().map {
                .init(index: $0.offset, character: $0.element.character,
                      text: $0.element.text)
            },
            actions: scene.actions.map(\.description),
            shots: scene.shots.map {
                .init(number: $0.shotId, type: $0.shotType, angle: $0.cameraAngle,
                      status: $0.status, description: $0.description)
            })
        return ActionOutcome(resultForModel: try payload(detail),
                             userSummary: "Read “\(scene.name)”")
    }
}

// MARK: - Schedule

final class GetScheduleAction: ProjectAssistantAction, AssistantAction {
    let name = "get_schedule"
    let summary = "Read the shooting schedule (optionally filtered by status or date YYYY-MM-DD)."
    let risk = ActionRisk.readOnly
    var parameterSchema: JSONValue {
        objectSchema(["status": stringProp, "date": stringProp])
    }

    private struct Arguments: Decodable { let status: String?; let date: String? }
    private struct Row: Encodable {
        let scene: String, date: String, slot: String, status: String
        let location: String, call: String, wrap: String, hours: Double
        let cast: [String]
    }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        ActionPlan(summary: "Read the schedule")
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let items = try requireProject().project.scheduleItems.filter { item in
            (args.status == nil || item.status.lowercased() == args.status!.lowercased())
            && (args.date == nil || item.shootDate == args.date)
        }
        let rows = items.map {
            Row(scene: $0.sceneName, date: $0.shootDate ?? "unscheduled",
                slot: $0.timeSlot, status: $0.status, location: $0.location,
                call: $0.callTime ?? "", wrap: $0.wrapTime ?? "",
                hours: $0.estimatedDurationHours, cast: $0.requiredActors)
        }
        return ActionOutcome(resultForModel: try payload(rows),
                             userSummary: "Read \(rows.count) schedule items")
    }
}

final class GetScheduleConflictsAction: ProjectAssistantAction, AssistantAction {
    let name = "get_schedule_conflicts"
    let summary = "Run the schedule conflict checker (cast/location/equipment double-bookings) and report findings."
    let risk = ActionRisk.readOnly
    var parameterSchema: JSONValue { objectSchema([:]) }

    private struct Row: Encodable {
        let severity: String, description: String, scenes: [String]
    }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        ActionPlan(summary: "Check the schedule for conflicts")
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let items = try requireProject().project.scheduleItems
        // The app's own deterministic checker (AD6) — never inferred.
        let checker = ScheduleViewModel(scheduleItems: items)
        checker.detectConflicts()
        let rows = checker.conflicts.map {
            Row(severity: "\($0.severity)", description: $0.description,
                scenes: $0.affectedItems.map(\.sceneName))
        }
        return ActionOutcome(
            resultForModel: rows.isEmpty ? #"{"conflicts": []}"# : try payload(rows),
            userSummary: rows.isEmpty ? "No schedule conflicts"
                                      : "Found \(rows.count) schedule conflicts")
    }
}

// MARK: - Gantt

final class GetGanttAction: ProjectAssistantAction, AssistantAction {
    let name = "get_gantt"
    let summary = "Read the production plan (Gantt): tasks, dates, dependencies, completion — plus dependency validation."
    let risk = ActionRisk.readOnly
    var parameterSchema: JSONValue { objectSchema([:]) }

    private struct Result: Encodable {
        struct Task: Encodable {
            let id: String, name: String, category: String
            let start: String, end: String, status: String
            let completion: Int, milestone: Bool, dependsOn: [String]
        }
        struct Problem: Encodable { let type: String, description: String }
        let tasks: [Task]
        let problems: [Problem]
    }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        ActionPlan(summary: "Read the production plan")
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let tasks = try requireProject().project.ganttTasks
        let checker = GanttViewModel()
        checker.setTasks(tasks)
        let problems = checker.validateDependencies()
        let result = Result(
            tasks: tasks.map {
                .init(id: $0.id, name: $0.name, category: $0.category.rawValue,
                      start: $0.startDate, end: $0.endDate ?? "",
                      status: $0.status, completion: $0.completionPercentage,
                      milestone: $0.isMilestone, dependsOn: $0.dependsOn)
            },
            problems: problems.map { .init(type: $0.type, description: $0.description) })
        return ActionOutcome(resultForModel: try payload(result),
                             userSummary: "Read \(tasks.count) plan tasks"
                                + (problems.isEmpty ? "" : " (\(problems.count) dependency problems)"))
    }
}

// MARK: - Budget

final class GetBudgetSummaryAction: ProjectAssistantAction, AssistantAction {
    let name = "get_budget_summary"
    let summary = "Read the budget: totals, and allocated vs spent per category (with account codes)."
    let risk = ActionRisk.readOnly
    var parameterSchema: JSONValue { objectSchema([:]) }

    private struct Result: Encodable {
        struct Category: Encodable {
            let account: String, name: String, group: String
            let allocated: Double, spent: Double
        }
        let currency: String, totalBudget: Double, totalSpent: Double
        let remaining: Double, categories: [Category]
    }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        ActionPlan(summary: "Read the budget summary")
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        guard let budget = try requireProject().project.projectBudget else {
            return ActionOutcome(resultForModel: #"{"budget": null}"#,
                                 userSummary: "No budget set up")
        }
        let result = Result(
            currency: budget.currency,
            totalBudget: budget.totalBudget,
            totalSpent: budget.totalSpent,
            remaining: budget.totalBudget - budget.totalSpent,
            categories: budget.categories.map {
                .init(account: $0.accountCode, name: $0.name,
                      group: $0.categoryGroup, allocated: $0.allocated,
                      spent: $0.spent)
            })
        return ActionOutcome(resultForModel: try payload(result),
                             userSummary: "Read the budget summary")
    }
}

// MARK: - People & equipment

final class GetPeopleAction: ProjectAssistantAction, AssistantAction {
    let name = "get_people"
    let summary = """
    Read cast (actor as character, role type, union, shoot-day count), crew \
    (name, role, department), and teams. Contact and pay details are never \
    included.
    """
    let risk = ActionRisk.readOnly
    var parameterSchema: JSONValue { objectSchema([:]) }

    private struct Result: Encodable {
        struct Cast: Encodable {
            let actor: String, character: String, roleType: String
            let union: String, shootDays: Int
        }
        struct Crew: Encodable { let name: String, role: String, department: String }
        struct TeamRow: Encodable { let name: String, type: String, members: Int }
        let cast: [Cast], crew: [Crew], teams: [TeamRow]
    }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        ActionPlan(summary: "Read cast, crew, and teams")
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let project = try requireProject().project
        // Shoot days = distinct scheduled dates that require the actor.
        func shootDays(for actorName: String) -> Int {
            Set(project.scheduleItems
                .filter { $0.requiredActors.contains(actorName) }
                .compactMap(\.shootDate)).count
        }
        let result = Result(
            cast: project.castMembers.map {
                .init(actor: $0.actorName, character: $0.characterName,
                      roleType: $0.roleType, union: $0.unionStatus,
                      shootDays: shootDays(for: $0.actorName))
            },
            crew: project.crewMembers.map {
                .init(name: $0.name, role: $0.role, department: $0.department)
            },
            teams: project.teams.map {
                .init(name: $0.name, type: $0.teamType,
                      members: $0.castMemberIds.count + $0.crewMemberIds.count)
            })
        return ActionOutcome(
            resultForModel: try payload(result),
            userSummary: "Read \(result.cast.count) cast, \(result.crew.count) crew")
    }
}

final class GetEquipmentAction: ProjectAssistantAction, AssistantAction {
    let name = "get_equipment"
    let summary = "Read the equipment library: quantities, condition, rental status, and allocations."
    let risk = ActionRisk.readOnly
    var parameterSchema: JSONValue { objectSchema([:]) }

    private struct Row: Encodable {
        let name: String, category: String, owned: Int, available: Int
        let rental: Bool, condition: String, allocation: String
    }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        ActionPlan(summary: "Read the equipment library")
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let project = try requireProject().project
        let allocationByItem = Dictionary(
            grouping: project.equipmentAllocations, by: \.equipmentItemId)
        let rows = project.equipmentLibrary.map { item in
            Row(name: item.name, category: item.category,
                owned: item.quantityOwned, available: item.quantityAvailable,
                rental: item.isRental, condition: item.condition,
                allocation: allocationByItem[item.id]?.first
                    .map { "\($0.allocationMode.rawValue)" } ?? "unallocated")
        }
        return ActionOutcome(resultForModel: try payload(rows),
                             userSummary: "Read \(rows.count) equipment items")
    }
}

// MARK: - Factory extension

extension AssistantActionFactory {
    /// The A3.1 read-tool catalog, registered alongside the core actions.
    @MainActor static func readTools(projectViewModel: ProjectViewModel?,
                                     coordinator: AppCoordinator?) -> [any AssistantAction] {
        [
            ListScenesAction(projectViewModel: projectViewModel, coordinator: coordinator),
            GetSceneAction(projectViewModel: projectViewModel, coordinator: coordinator),
            GetScheduleAction(projectViewModel: projectViewModel, coordinator: coordinator),
            GetScheduleConflictsAction(projectViewModel: projectViewModel, coordinator: coordinator),
            GetGanttAction(projectViewModel: projectViewModel, coordinator: coordinator),
            GetBudgetSummaryAction(projectViewModel: projectViewModel, coordinator: coordinator),
            GetPeopleAction(projectViewModel: projectViewModel, coordinator: coordinator),
            GetEquipmentAction(projectViewModel: projectViewModel, coordinator: coordinator),
        ]
    }
}

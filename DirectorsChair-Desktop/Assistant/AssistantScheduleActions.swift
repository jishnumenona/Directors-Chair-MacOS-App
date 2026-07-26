//
//  AssistantScheduleActions.swift
//  DirectorsChair-Desktop
//
//  AI Assistant program, Phase A3.2: schedule CRUD actions (F-D1/D2) with
//  the validator IN THE LOOP (AD6) — every proposal applies the change to a
//  copy of the schedule, runs the app's real conflict checker, and carries
//  any NEW conflicts as warnings to both the model and the review card.
//  Batch reshuffles are the multi-item TurnPlan: the model proposes several
//  of these in one turn and the user approves them together.
//

import Foundation
import DirectorsChairCore
import DirectorsChairServices
import DirectorsChairProduction

private let stringProp = JSONValue.object(["type": .string("string")])
private let stringArrayProp = JSONValue.object(
    ["type": .string("array"), "items": .object(["type": .string("string")])])

private func objectSchema(_ properties: [String: JSONValue],
                          required: [String]) -> JSONValue {
    .object(["type": .string("object"),
             "properties": .object(properties),
             "required": .array(required.map(JSONValue.string))])
}

// MARK: - Shared schedule helpers

class ScheduleAssistantAction: ProjectAssistantAction {
    static let validSlots = ["Morning", "Afternoon", "Full Day", "Night"]

    @MainActor func requireDate(_ date: String) throws {
        guard date.range(of: #"^\d{4}-\d{2}-\d{2}$"#,
                         options: .regularExpression) != nil else {
            throw ActionError("date must be YYYY-MM-DD, got '\(date)'")
        }
    }

    @MainActor func requireSlot(_ slot: String) throws -> String {
        guard let match = Self.validSlots.first(where: {
            $0.lowercased() == slot.lowercased()
        }) else {
            throw ActionError("timeSlot must be one of: "
                              + Self.validSlots.joined(separator: ", "))
        }
        return match
    }

    /// Finds the schedule item for a scene (optionally disambiguated by
    /// date). Throws with the scheduled inventory when missing.
    @MainActor func itemIndex(scene: String, date: String?,
                              in items: [ScheduleItem]) throws -> Int {
        let matches = items.indices.filter {
            items[$0].sceneName == scene
            && (date == nil || items[$0].shootDate == date)
        }
        guard let first = matches.first else {
            let known = items.map {
                "\($0.sceneName) (\($0.shootDate ?? "unscheduled"))"
            }.joined(separator: ", ")
            throw ActionError("no schedule item for scene '\(scene)'"
                + (date.map { " on \($0)" } ?? "")
                + (known.isEmpty ? " — the schedule is empty" : " (scheduled: \(known))"))
        }
        guard matches.count == 1 else {
            throw ActionError("scene '\(scene)' is scheduled \(matches.count) times — pass \"date\" to pick one")
        }
        return first
    }

    /// The validator in the loop (AD6): conflicts the hypothetical schedule
    /// has that the current one doesn't.
    @MainActor func newConflicts(applying hypothetical: [ScheduleItem],
                                 current: [ScheduleItem]) -> [String] {
        func descriptions(_ items: [ScheduleItem]) -> [String] {
            let checker = ScheduleViewModel(scheduleItems: items)
            checker.detectConflicts()
            return checker.conflicts.map(\.description)
        }
        let existing = Set(descriptions(current))
        return descriptions(hypothetical).filter { !existing.contains($0) }
    }
}

// MARK: - schedule_scene

final class ScheduleSceneAction: ScheduleAssistantAction, AssistantAction {
    let name = "schedule_scene"
    let summary = """
    Add a scene to the shooting schedule (date YYYY-MM-DD, timeSlot \
    Morning|Afternoon|Full Day|Night, optional location/cast/call/wrap). \
    The conflict checker runs on the result; new conflicts come back as \
    warnings.
    """
    let risk = ActionRisk.mutating
    var parameterSchema: JSONValue {
        objectSchema([
            "scene": stringProp, "date": stringProp, "time_slot": stringProp,
            "location": stringProp, "cast": stringArrayProp,
            "call_time": stringProp, "wrap_time": stringProp,
        ], required: ["scene", "date", "time_slot"])
    }

    private struct Arguments: Decodable {
        let scene: String, date: String, timeSlot: String
        let location: String?, cast: [String]?
        let callTime: String?, wrapTime: String?
        enum CodingKeys: String, CodingKey {
            case scene, date, location, cast
            case timeSlot = "time_slot"
            case callTime = "call_time"
            case wrapTime = "wrap_time"
        }
    }

    @MainActor private func build(_ args: Arguments,
                                  in pvm: ProjectViewModel) throws -> ScheduleItem {
        try requireDate(args.date)
        let slot = try requireSlot(args.timeSlot)
        _ = try sceneIndices(named: args.scene, in: pvm)   // scene must exist
        var item = ScheduleItem(sceneName: args.scene, shootDate: args.date,
                                timeSlot: slot)
        if let location = args.location { item.location = location }
        if let cast = args.cast { item.requiredActors = cast }
        item.callTime = args.callTime
        item.wrapTime = args.wrapTime
        return item
    }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let pvm = try requireProject()
        let item = try build(args, in: pvm)
        let warnings = newConflicts(
            applying: pvm.project.scheduleItems + [item],
            current: pvm.project.scheduleItems)
        return ActionPlan(
            summary: "Schedule “\(args.scene)” on \(args.date) (\(item.timeSlot))",
            previews: [ActionPreview(title: "\(args.scene) · shoot day",
                                     oldValue: "unscheduled",
                                     newValue: "\(args.date) · \(item.timeSlot)")],
            warnings: warnings)
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let pvm = try requireProject()
        let item = try build(args, in: pvm)
        pvm.project.scheduleItems.append(item)
        didMutate(.production)
        return ActionOutcome(resultForModel: #"{"status": "applied"}"#,
                             userSummary: "Scheduled “\(args.scene)” on \(args.date)")
    }
}

// MARK: - update_schedule_item

final class UpdateScheduleItemAction: ScheduleAssistantAction, AssistantAction {
    let name = "update_schedule_item"
    let summary = """
    Move or edit a scheduled scene: change date, time slot, status, \
    location, cast, call/wrap. Identify it by scene (plus "date" if the \
    scene is scheduled more than once). New conflicts come back as warnings.
    """
    let risk = ActionRisk.mutating
    var parameterSchema: JSONValue {
        objectSchema([
            "scene": stringProp, "date": stringProp,
            "new_date": stringProp, "new_time_slot": stringProp,
            "new_status": stringProp, "new_location": stringProp,
            "new_cast": stringArrayProp,
            "new_call_time": stringProp, "new_wrap_time": stringProp,
        ], required: ["scene"])
    }

    private struct Arguments: Decodable {
        let scene: String, date: String?
        let newDate: String?, newTimeSlot: String?, newStatus: String?
        let newLocation: String?, newCast: [String]?
        let newCallTime: String?, newWrapTime: String?
        enum CodingKeys: String, CodingKey {
            case scene, date
            case newDate = "new_date", newTimeSlot = "new_time_slot"
            case newStatus = "new_status", newLocation = "new_location"
            case newCast = "new_cast"
            case newCallTime = "new_call_time", newWrapTime = "new_wrap_time"
        }
    }

    @MainActor private func apply(_ args: Arguments, to item: ScheduleItem)
    throws -> (ScheduleItem, [ActionPreview]) {
        var updated = item
        var previews: [ActionPreview] = []
        func change(_ title: String, _ old: String, _ new: String) {
            previews.append(ActionPreview(title: "\(item.sceneName) · \(title)",
                                          oldValue: old, newValue: new))
        }
        if let date = args.newDate {
            try requireDate(date)
            change("date", item.shootDate ?? "unscheduled", date)
            updated.shootDate = date
        }
        if let slot = args.newTimeSlot {
            let resolved = try requireSlot(slot)
            change("slot", item.timeSlot, resolved)
            updated.timeSlot = resolved
        }
        if let status = args.newStatus {
            change("status", item.status, status)
            updated.status = status
        }
        if let location = args.newLocation {
            change("location", item.location, location)
            updated.location = location
        }
        if let cast = args.newCast {
            change("cast", item.requiredActors.joined(separator: ", "),
                   cast.joined(separator: ", "))
            updated.requiredActors = cast
        }
        if let call = args.newCallTime {
            change("call", item.callTime ?? "—", call)
            updated.callTime = call
        }
        if let wrap = args.newWrapTime {
            change("wrap", item.wrapTime ?? "—", wrap)
            updated.wrapTime = wrap
        }
        guard !previews.isEmpty else {
            throw ActionError("nothing to change — pass at least one new_* field")
        }
        return (updated, previews)
    }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let pvm = try requireProject()
        let items = pvm.project.scheduleItems
        let index = try itemIndex(scene: args.scene, date: args.date, in: items)
        let (updated, previews) = try apply(args, to: items[index])
        var hypothetical = items
        hypothetical[index] = updated
        return ActionPlan(
            summary: "Update the “\(args.scene)” shoot"
                + (args.newDate.map { " → \($0)" } ?? ""),
            previews: previews,
            warnings: newConflicts(applying: hypothetical, current: items))
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let pvm = try requireProject()
        let index = try itemIndex(scene: args.scene, date: args.date,
                                  in: pvm.project.scheduleItems)
        let (updated, _) = try apply(args, to: pvm.project.scheduleItems[index])
        pvm.project.scheduleItems[index] = updated
        didMutate(.production)
        return ActionOutcome(resultForModel: #"{"status": "applied"}"#,
                             userSummary: "Updated the “\(args.scene)” shoot")
    }
}

// MARK: - remove_schedule_item

final class RemoveScheduleItemAction: ScheduleAssistantAction, AssistantAction {
    let name = "remove_schedule_item"
    let summary = "Remove a scene from the shooting schedule (the scene itself is untouched)."
    let risk = ActionRisk.mutating
    var parameterSchema: JSONValue {
        objectSchema(["scene": stringProp, "date": stringProp],
                     required: ["scene"])
    }

    private struct Arguments: Decodable { let scene: String, date: String? }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let items = try requireProject().project.scheduleItems
        let index = try itemIndex(scene: args.scene, date: args.date, in: items)
        let item = items[index]
        return ActionPlan(
            summary: "Unschedule “\(args.scene)”",
            previews: [ActionPreview(
                title: "\(args.scene) · shoot day",
                oldValue: "\(item.shootDate ?? "unscheduled") · \(item.timeSlot)",
                newValue: "unscheduled")])
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let pvm = try requireProject()
        let index = try itemIndex(scene: args.scene, date: args.date,
                                  in: pvm.project.scheduleItems)
        pvm.project.scheduleItems.remove(at: index)
        didMutate(.production)
        return ActionOutcome(resultForModel: #"{"status": "applied"}"#,
                             userSummary: "Unscheduled “\(args.scene)”")
    }
}

// MARK: - Factory extension

extension AssistantActionFactory {
    @MainActor static func scheduleActions(projectViewModel: ProjectViewModel?,
                                           coordinator: AppCoordinator?) -> [any AssistantAction] {
        [
            ScheduleSceneAction(projectViewModel: projectViewModel, coordinator: coordinator),
            UpdateScheduleItemAction(projectViewModel: projectViewModel, coordinator: coordinator),
            RemoveScheduleItemAction(projectViewModel: projectViewModel, coordinator: coordinator),
        ]
    }
}

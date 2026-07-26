//
//  AssistantWorldActions.swift
//  DirectorsChair-Desktop
//
//  AI Assistant program, Phase A4 slice 2 (completes A4.3 + A4.4):
//  world-building actions — locations, props, costumes with wardrobe
//  assignment — plus shot editing with canonical statuses. Same contract
//  as the rest of the catalog: proposals with previews, collisions as
//  hard errors, unknown-character references as warnings.
//

import Foundation
import DirectorsChairCore
import DirectorsChairServices

private let stringProp = JSONValue.object(["type": .string("string")])
private let integerProp = JSONValue.object(["type": .string("integer")])

private func objectSchema(_ properties: [String: JSONValue],
                          required: [String]) -> JSONValue {
    .object(["type": .string("object"),
             "properties": .object(properties),
             "required": .array(required.map(JSONValue.string))])
}

// MARK: - add_location

final class AddLocationAction: ProjectAssistantAction, AssistantAction {
    let name = "add_location"
    let summary = "Add a location to the project (name, optional description)."
    let risk = ActionRisk.mutating
    var parameterSchema: JSONValue {
        objectSchema(["name": stringProp, "description": stringProp],
                     required: ["name"])
    }

    private struct Arguments: Decodable { let name: String, description: String? }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let pvm = try requireProject()
        if pvm.project.locations.contains(where: {
            $0.name.lowercased() == args.name.lowercased()
        }) {
            throw ActionError("a location named '\(args.name)' already exists")
        }
        return ActionPlan(
            summary: "Add location “\(args.name)”",
            previews: [ActionPreview(title: "locations", oldValue: nil,
                                     newValue: args.name)])
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        _ = try validate(argumentsData: argumentsData)
        let pvm = try requireProject()
        pvm.project.locations.append(Location(name: args.name,
                                              description: args.description ?? ""))
        didMutate(.general)
        return ActionOutcome(resultForModel: #"{"status": "applied"}"#,
                             userSummary: "Added location “\(args.name)”")
    }
}

// MARK: - add_prop

final class AddPropAction: ProjectAssistantAction, AssistantAction {
    let name = "add_prop"
    let summary = "Add a prop (name, optional description and category e.g. Weapon, Furniture, Document)."
    let risk = ActionRisk.mutating
    var parameterSchema: JSONValue {
        objectSchema(["name": stringProp, "description": stringProp,
                      "category": stringProp],
                     required: ["name"])
    }

    private struct Arguments: Decodable {
        let name: String, description: String?, category: String?
    }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let pvm = try requireProject()
        if pvm.project.props.contains(where: {
            $0.name.lowercased() == args.name.lowercased()
        }) {
            throw ActionError("a prop named '\(args.name)' already exists")
        }
        return ActionPlan(
            summary: "Add prop “\(args.name)”",
            previews: [ActionPreview(
                title: "props · \(args.category ?? "uncategorized")",
                oldValue: nil, newValue: args.name)])
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        _ = try validate(argumentsData: argumentsData)
        let pvm = try requireProject()
        var prop = Prop(name: args.name, description: args.description ?? "")
        if let category = args.category { prop.category = category }
        pvm.project.props.append(prop)
        didMutate(.general)
        return ActionOutcome(resultForModel: #"{"status": "applied"}"#,
                             userSummary: "Added prop “\(args.name)”")
    }
}

// MARK: - add_costume

final class AddCostumeAction: ProjectAssistantAction, AssistantAction {
    let name = "add_costume"
    let summary = "Add a costume, optionally assigned to a character (wardrobe), with notes."
    let risk = ActionRisk.mutating
    var parameterSchema: JSONValue {
        objectSchema(["name": stringProp, "character": stringProp,
                      "notes": stringProp],
                     required: ["name"])
    }

    private struct Arguments: Decodable {
        let name: String, character: String?, notes: String?
    }

    @MainActor private func check(_ args: Arguments) throws
    -> (ProjectViewModel, [String]) {
        let pvm = try requireProject()
        if pvm.project.costumes.contains(where: {
            $0.name.lowercased() == args.name.lowercased()
        }) {
            throw ActionError("a costume named '\(args.name)' already exists")
        }
        var warnings: [String] = []
        if let character = args.character,
           !pvm.project.characters.contains(where: {
               $0.name.lowercased() == character.lowercased()
           }) {
            warnings.append("“\(character)” is not a character in the story design")
        }
        return (pvm, warnings)
    }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let (_, warnings) = try check(args)
        return ActionPlan(
            summary: "Add costume “\(args.name)”"
                + (args.character.map { " for \($0)" } ?? ""),
            previews: [ActionPreview(
                title: "wardrobe · \(args.character ?? "unassigned")",
                oldValue: nil, newValue: args.name)],
            warnings: warnings)
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let (pvm, _) = try check(args)
        pvm.project.costumes.append(Costume(name: args.name,
                                            character: args.character,
                                            notes: args.notes ?? ""))
        didMutate(.general)
        return ActionOutcome(resultForModel: #"{"status": "applied"}"#,
                             userSummary: "Added costume “\(args.name)”")
    }
}

// MARK: - update_shot

final class UpdateShotAction: ProjectAssistantAction, AssistantAction {
    static let statuses = ["Planning", "Ready", "Shooting", "Review", "Approved"]

    let name = "update_shot"
    let summary = """
    Edit a shot by its number: status (Planning|Ready|Shooting|Review|\
    Approved), description, shot_type, or camera_angle.
    """
    let risk = ActionRisk.mutating
    var parameterSchema: JSONValue {
        objectSchema([
            "shot": integerProp, "new_status": stringProp,
            "new_description": stringProp, "new_shot_type": stringProp,
            "new_camera_angle": stringProp,
        ], required: ["shot"])
    }

    private struct Arguments: Decodable {
        let shot: Int
        let newStatus: String?, newDescription: String?
        let newShotType: String?, newCameraAngle: String?
        enum CodingKeys: String, CodingKey {
            case shot
            case newStatus = "new_status"
            case newDescription = "new_description"
            case newShotType = "new_shot_type"
            case newCameraAngle = "new_camera_angle"
        }
    }

    @MainActor private func shotLocation(_ number: Int, in pvm: ProjectViewModel)
    throws -> (Int, Int, Int) {
        for seq in pvm.project.sequences.indices {
            for sc in pvm.project.sequences[seq].scenes.indices {
                if let shot = pvm.project.sequences[seq].scenes[sc].shots
                    .firstIndex(where: { $0.shotId == number }) {
                    return (seq, sc, shot)
                }
            }
        }
        throw ActionError("no shot #\(number) — use get_scene or navigate to find shot numbers")
    }

    @MainActor private func apply(_ args: Arguments, to shot: Shot) throws
    -> (Shot, [ActionPreview]) {
        var updated = shot
        var previews: [ActionPreview] = []
        func change(_ title: String, _ old: String, _ new: String) {
            previews.append(ActionPreview(title: "shot #\(shot.shotId) · \(title)",
                                          oldValue: old, newValue: new))
        }
        if let status = args.newStatus {
            guard let canonical = Self.statuses.first(where: {
                $0.lowercased() == status.lowercased()
            }) else {
                throw ActionError("new_status must be one of: "
                                  + Self.statuses.joined(separator: ", "))
            }
            change("status", shot.status, canonical)
            updated.status = canonical
        }
        if let description = args.newDescription {
            change("description", String(shot.description.prefix(80)),
                   String(description.prefix(80)))
            updated.description = description
        }
        if let type = args.newShotType {
            change("type", shot.shotType, type)
            updated.shotType = type
        }
        if let angle = args.newCameraAngle {
            change("angle", shot.cameraAngle, angle)
            updated.cameraAngle = angle
        }
        guard !previews.isEmpty else {
            throw ActionError("nothing to change — pass at least one new_* field")
        }
        return (updated, previews)
    }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let pvm = try requireProject()
        let (seq, sc, shot) = try shotLocation(args.shot, in: pvm)
        let (_, previews) = try apply(
            args, to: pvm.project.sequences[seq].scenes[sc].shots[shot])
        return ActionPlan(summary: "Update shot #\(args.shot)", previews: previews)
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let pvm = try requireProject()
        let (seq, sc, shot) = try shotLocation(args.shot, in: pvm)
        let (updated, _) = try apply(
            args, to: pvm.project.sequences[seq].scenes[sc].shots[shot])
        pvm.project.sequences[seq].scenes[sc].shots[shot] = updated
        didMutate(.shots)
        return ActionOutcome(resultForModel: #"{"status": "applied"}"#,
                             userSummary: "Updated shot #\(args.shot)")
    }
}

// MARK: - Factory extension

extension AssistantActionFactory {
    @MainActor static func worldActions(projectViewModel: ProjectViewModel?,
                                        coordinator: AppCoordinator?) -> [any AssistantAction] {
        [
            AddLocationAction(projectViewModel: projectViewModel, coordinator: coordinator),
            AddPropAction(projectViewModel: projectViewModel, coordinator: coordinator),
            AddCostumeAction(projectViewModel: projectViewModel, coordinator: coordinator),
            UpdateShotAction(projectViewModel: projectViewModel, coordinator: coordinator),
        ]
    }
}

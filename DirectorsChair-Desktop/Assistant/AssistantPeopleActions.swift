//
//  AssistantPeopleActions.swift
//  DirectorsChair-Desktop
//
//  AI Assistant program, Phase A3.5: cast/crew/equipment-library actions
//  (F-D5). Deliberately narrow: the assistant can create roster and
//  library entries but NEVER touches pay, contact, or emergency-contact
//  fields — those stay in the dedicated editors. Equipment allocation is
//  deferred with purchase orders.
//

import Foundation
import DirectorsChairCore
import DirectorsChairServices

private let stringProp = JSONValue.object(["type": .string("string")])
private let integerProp = JSONValue.object(["type": .string("integer")])
private let boolProp = JSONValue.object(["type": .string("boolean")])

private func objectSchema(_ properties: [String: JSONValue],
                          required: [String]) -> JSONValue {
    .object(["type": .string("object"),
             "properties": .object(properties),
             "required": .array(required.map(JSONValue.string))])
}

// MARK: - add_cast_member

final class AddCastMemberAction: ProjectAssistantAction, AssistantAction {
    static let roleTypes = ["Principal", "Supporting", "Background", "Extra",
                            "Stunt Double"]

    let name = "add_cast_member"
    let summary = """
    Add an actor to the cast roster (actor name, the character they play, \
    optional role_type Principal|Supporting|Background|Extra|Stunt Double \
    and union status). Pay and contact details are managed in the app only.
    """
    let risk = ActionRisk.mutating
    let minimumTier = ProductTier.creator  // §3.7: assistant production actions are Creator+
    var parameterSchema: JSONValue {
        objectSchema([
            "actor": stringProp, "character": stringProp,
            "role_type": stringProp, "union_status": stringProp,
        ], required: ["actor", "character"])
    }

    private struct Arguments: Decodable {
        let actor: String, character: String
        let roleType: String?, unionStatus: String?
        enum CodingKeys: String, CodingKey {
            case actor, character
            case roleType = "role_type"
            case unionStatus = "union_status"
        }
    }

    @MainActor private func check(_ args: Arguments) throws
    -> (ProjectViewModel, String, [String]) {
        let pvm = try requireProject()
        let roleType = try args.roleType.map { raw -> String in
            guard let match = Self.roleTypes.first(where: {
                $0.lowercased() == raw.lowercased()
            }) else {
                throw ActionError("role_type must be one of: "
                                  + Self.roleTypes.joined(separator: ", "))
            }
            return match
        } ?? "Principal"
        if pvm.project.castMembers.contains(where: {
            $0.actorName.lowercased() == args.actor.lowercased()
            && $0.characterName.lowercased() == args.character.lowercased()
        }) {
            throw ActionError("\(args.actor) is already cast as \(args.character)")
        }
        var warnings: [String] = []
        if !pvm.project.characters.contains(where: {
            $0.name.lowercased() == args.character.lowercased()
        }) {
            warnings.append("“\(args.character)” is not a character in the story design")
        }
        return (pvm, roleType, warnings)
    }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let (_, roleType, warnings) = try check(args)
        return ActionPlan(
            summary: "Cast \(args.actor) as \(args.character)",
            previews: [ActionPreview(title: "\(args.actor) · \(roleType)",
                                     oldValue: nil, newValue: args.character)],
            warnings: warnings)
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let (pvm, roleType, _) = try check(args)
        pvm.project.castMembers.append(CastMember(
            actorName: args.actor, characterName: args.character,
            roleType: roleType,
            unionStatus: args.unionStatus ?? "Non-Union"))
        didMutate(.production)
        return ActionOutcome(resultForModel: #"{"status": "applied"}"#,
                             userSummary: "Cast \(args.actor) as \(args.character)")
    }
}

// MARK: - add_crew_member

final class AddCrewMemberAction: ProjectAssistantAction, AssistantAction {
    let name = "add_crew_member"
    let summary = """
    Add a crew member (name, role e.g. Gaffer, optional department). \
    Pay and contact details are managed in the app only.
    """
    let risk = ActionRisk.mutating
    let minimumTier = ProductTier.creator  // §3.7: assistant production actions are Creator+
    var parameterSchema: JSONValue {
        objectSchema(["name": stringProp, "role": stringProp,
                      "department": stringProp],
                     required: ["name", "role"])
    }

    private struct Arguments: Decodable {
        let name: String, role: String, department: String?
    }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let pvm = try requireProject()
        if pvm.project.crewMembers.contains(where: {
            $0.name.lowercased() == args.name.lowercased()
            && $0.role.lowercased() == args.role.lowercased()
        }) {
            throw ActionError("\(args.name) is already on the crew as \(args.role)")
        }
        return ActionPlan(
            summary: "Add \(args.name) to the crew as \(args.role)",
            previews: [ActionPreview(
                title: "\(args.name) · \(args.department ?? "Production")",
                oldValue: nil, newValue: args.role)])
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let pvm = try requireProject()
        pvm.project.crewMembers.append(CrewMember(
            name: args.name, role: args.role,
            department: args.department ?? "Production"))
        didMutate(.production)
        return ActionOutcome(resultForModel: #"{"status": "applied"}"#,
                             userSummary: "Added \(args.name) (\(args.role))")
    }
}

// MARK: - add_equipment_item

final class AddEquipmentItemAction: ProjectAssistantAction, AssistantAction {
    let name = "add_equipment_item"
    let summary = "Add an item to the equipment library (name, category, optional quantity and rental flag)."
    let risk = ActionRisk.mutating
    let minimumTier = ProductTier.creator  // §3.7: assistant production actions are Creator+
    var parameterSchema: JSONValue {
        objectSchema([
            "name": stringProp, "category": stringProp,
            "quantity": integerProp, "rental": boolProp,
        ], required: ["name", "category"])
    }

    private struct Arguments: Decodable {
        let name: String, category: String
        let quantity: Int?, rental: Bool?
    }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        if let quantity = args.quantity, quantity < 1 {
            throw ActionError("quantity must be at least 1")
        }
        let pvm = try requireProject()
        if pvm.project.equipmentLibrary.contains(where: {
            $0.name.lowercased() == args.name.lowercased()
        }) {
            throw ActionError("'\(args.name)' is already in the equipment library")
        }
        return ActionPlan(
            summary: "Add \(args.name) to the equipment library",
            previews: [ActionPreview(
                title: "\(args.name) · \(args.category)",
                oldValue: nil,
                newValue: "×\(args.quantity ?? 1)\(args.rental == true ? " (rental)" : "")")])
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        _ = try validate(argumentsData: argumentsData)
        let pvm = try requireProject()
        var item = EquipmentItem(name: args.name, category: args.category)
        item.quantityOwned = args.quantity ?? 1
        item.quantityAvailable = args.quantity ?? 1
        item.isRental = args.rental ?? false
        pvm.project.equipmentLibrary.append(item)
        didMutate(.production)
        return ActionOutcome(resultForModel: #"{"status": "applied"}"#,
                             userSummary: "Added \(args.name) to equipment")
    }
}

// MARK: - Factory extension

extension AssistantActionFactory {
    @MainActor static func peopleActions(projectViewModel: ProjectViewModel?,
                                         coordinator: AppCoordinator?) -> [any AssistantAction] {
        [
            AddCastMemberAction(projectViewModel: projectViewModel, coordinator: coordinator),
            AddCrewMemberAction(projectViewModel: projectViewModel, coordinator: coordinator),
            AddEquipmentItemAction(projectViewModel: projectViewModel, coordinator: coordinator),
        ]
    }
}

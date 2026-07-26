//
//  AssistantScriptActions.swift
//  DirectorsChair-Desktop
//
//  AI Assistant program, Phase A4.2 completion: the non-dialogue script
//  items (action lines, narration) and dialogue reordering. Whole-scene
//  drafting is compositional by design: the model proposes add_scene +
//  a batch of add_dialogue / add_scene_action / add_narration calls in
//  one turn, and the TurnPlan card shows the entire draft line-by-line.
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

// MARK: - add_scene_action

final class AddSceneActionAction: ProjectAssistantAction, AssistantAction {
    let name = "add_scene_action"
    let summary = "Add an action line (stage direction) to a scene's script."
    let risk = ActionRisk.mutating
    var parameterSchema: JSONValue {
        objectSchema(["scene": stringProp, "text": stringProp],
                     required: ["scene", "text"])
    }

    private struct Arguments: Decodable { let scene: String, text: String }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        _ = try sceneIndices(named: args.scene, in: try requireProject())
        return ActionPlan(
            summary: "Add an action line to “\(args.scene)”",
            previews: [ActionPreview(title: "\(args.scene) · action",
                                     oldValue: nil,
                                     newValue: String(args.text.prefix(160)))])
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let pvm = try requireProject()
        let (seq, sc) = try sceneIndices(named: args.scene, in: pvm)
        pvm.project.sequences[seq].scenes[sc].actions.append(
            Action(description: args.text))
        didMutate(.script)
        return ActionOutcome(resultForModel: #"{"status": "applied"}"#,
                             userSummary: "Added an action line to “\(args.scene)”")
    }
}

// MARK: - add_narration

final class AddNarrationAction: ProjectAssistantAction, AssistantAction {
    let name = "add_narration"
    let summary = "Add a narration (voice-over) line to a scene's script."
    let risk = ActionRisk.mutating
    var parameterSchema: JSONValue {
        objectSchema(["scene": stringProp, "text": stringProp],
                     required: ["scene", "text"])
    }

    private struct Arguments: Decodable { let scene: String, text: String }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        _ = try sceneIndices(named: args.scene, in: try requireProject())
        return ActionPlan(
            summary: "Add narration to “\(args.scene)”",
            previews: [ActionPreview(title: "\(args.scene) · narration",
                                     oldValue: nil,
                                     newValue: String(args.text.prefix(160)))])
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let pvm = try requireProject()
        let (seq, sc) = try sceneIndices(named: args.scene, in: pvm)
        pvm.project.sequences[seq].scenes[sc].narrations.append(
            Narration(text: args.text))
        didMutate(.script)
        return ActionOutcome(resultForModel: #"{"status": "applied"}"#,
                             userSummary: "Added narration to “\(args.scene)”")
    }
}

// MARK: - move_dialogue

final class MoveDialogueAction: ProjectAssistantAction, AssistantAction {
    let name = "move_dialogue"
    let summary = """
    Reorder a dialogue line within a scene: move the line at [from_index] \
    to [to_index] (the [n] indices shown in PROJECT DATA and get_scene).
    """
    let risk = ActionRisk.mutating
    var parameterSchema: JSONValue {
        objectSchema(["scene": stringProp, "from_index": integerProp,
                      "to_index": integerProp],
                     required: ["scene", "from_index", "to_index"])
    }

    private struct Arguments: Decodable {
        let scene: String, fromIndex: Int, toIndex: Int
        enum CodingKeys: String, CodingKey {
            case scene
            case fromIndex = "from_index"
            case toIndex = "to_index"
        }
    }

    @MainActor private func check(_ args: Arguments) throws
    -> (ProjectViewModel, Int, Int) {
        let pvm = try requireProject()
        let (seq, sc) = try sceneIndices(named: args.scene, in: pvm)
        let dialogues = pvm.project.sequences[seq].scenes[sc].dialogues
        guard dialogues.indices.contains(args.fromIndex),
              dialogues.indices.contains(args.toIndex) else {
            throw ActionError("indices must be within 0–\(max(dialogues.count - 1, 0)) "
                              + "(scene has \(dialogues.count) dialogues)")
        }
        guard args.fromIndex != args.toIndex else {
            throw ActionError("from_index and to_index are the same — nothing to move")
        }
        return (pvm, seq, sc)
    }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let (pvm, seq, sc) = try check(args)
        let line = pvm.project.sequences[seq].scenes[sc].dialogues[args.fromIndex]
        return ActionPlan(
            summary: "Move \(line.character)'s line [\(args.fromIndex)] → [\(args.toIndex)] in “\(args.scene)”",
            previews: [ActionPreview(
                title: "\(line.character) · \(String(line.text.prefix(60)))",
                oldValue: "position [\(args.fromIndex)]",
                newValue: "position [\(args.toIndex)]")])
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let (pvm, seq, sc) = try check(args)
        let line = pvm.project.sequences[seq].scenes[sc].dialogues
            .remove(at: args.fromIndex)
        pvm.project.sequences[seq].scenes[sc].dialogues
            .insert(line, at: args.toIndex)
        didMutate(.script)
        return ActionOutcome(resultForModel: #"{"status": "applied"}"#,
                             userSummary: "Moved a line in “\(args.scene)”")
    }
}

// MARK: - Factory extension

extension AssistantActionFactory {
    @MainActor static func scriptActions(projectViewModel: ProjectViewModel?,
                                         coordinator: AppCoordinator?) -> [any AssistantAction] {
        [
            AddSceneActionAction(projectViewModel: projectViewModel, coordinator: coordinator),
            AddNarrationAction(projectViewModel: projectViewModel, coordinator: coordinator),
            MoveDialogueAction(projectViewModel: projectViewModel, coordinator: coordinator),
        ]
    }
}

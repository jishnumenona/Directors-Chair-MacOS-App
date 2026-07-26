//
//  AssistantCreativeActions.swift
//  DirectorsChair-Desktop
//
//  AI Assistant program, Phase A4 (A4.1 + creation cores of A4.2–A4.4):
//  the assistant can now BUILD story structure — sequences, scenes, scene
//  field edits, dialogue lines, shots, characters — always as proposals
//  with previews (AD5). Name collisions are rejected (every later lookup
//  is by name); referencing an unknown character in dialogue is a warning
//  (walk-on parts are legitimate), never a silent accept.
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

// MARK: - add_sequence

final class AddSequenceAction: ProjectAssistantAction, AssistantAction {
    let name = "add_sequence"
    let summary = "Add a sequence (act/chapter) to the story structure."
    let risk = ActionRisk.mutating
    var parameterSchema: JSONValue {
        objectSchema(["name": stringProp, "description": stringProp],
                     required: ["name"])
    }

    private struct Arguments: Decodable { let name: String, description: String? }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let pvm = try requireProject()
        if pvm.project.sequences.contains(where: {
            $0.name.lowercased() == args.name.lowercased()
        }) {
            throw ActionError("a sequence named '\(args.name)' already exists")
        }
        return ActionPlan(
            summary: "Add sequence “\(args.name)”",
            previews: [ActionPreview(title: "structure",
                                     oldValue: nil, newValue: args.name)])
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        _ = try validate(argumentsData: argumentsData)
        let pvm = try requireProject()
        pvm.project.sequences.append(Sequence(name: args.name,
                                              description: args.description))
        didMutate(.structure)
        return ActionOutcome(resultForModel: #"{"status": "applied"}"#,
                             userSummary: "Added sequence “\(args.name)”")
    }
}

// MARK: - add_scene

final class AddSceneAction: ProjectAssistantAction, AssistantAction {
    let name = "add_scene"
    let summary = """
    Add a scene to a sequence (optionally after an existing scene, with \
    description, time_of_day, weather, location).
    """
    let risk = ActionRisk.mutating
    var parameterSchema: JSONValue {
        objectSchema([
            "name": stringProp, "sequence": stringProp,
            "description": stringProp, "after": stringProp,
            "time_of_day": stringProp, "weather": stringProp,
            "location": stringProp,
        ], required: ["name", "sequence"])
    }

    private struct Arguments: Decodable {
        let name: String, sequence: String
        let description: String?, after: String?
        let timeOfDay: String?, weather: String?, location: String?
        enum CodingKeys: String, CodingKey {
            case name, sequence, description, after, weather, location
            case timeOfDay = "time_of_day"
        }
    }

    @MainActor private func check(_ args: Arguments) throws
    -> (ProjectViewModel, Int, Int) {
        let pvm = try requireProject()
        guard let seqIndex = pvm.project.sequences.firstIndex(where: {
            $0.name.lowercased() == args.sequence.lowercased()
        }) else {
            let known = pvm.project.sequences.map(\.name).joined(separator: ", ")
            throw ActionError("no sequence '\(args.sequence)'"
                + (known.isEmpty ? "" : " (sequences: \(known))"))
        }
        let allScenes = pvm.project.sequences.flatMap(\.scenes)
        if allScenes.contains(where: { $0.name.lowercased() == args.name.lowercased() }) {
            throw ActionError("a scene named '\(args.name)' already exists")
        }
        var insertAt = pvm.project.sequences[seqIndex].scenes.count
        if let after = args.after {
            guard let afterIndex = pvm.project.sequences[seqIndex].scenes
                .firstIndex(where: { $0.name.lowercased() == after.lowercased() }) else {
                throw ActionError("scene '\(after)' is not in sequence '\(args.sequence)'")
            }
            insertAt = afterIndex + 1
        }
        return (pvm, seqIndex, insertAt)
    }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let (_, _, insertAt) = try check(args)
        return ActionPlan(
            summary: "Add scene “\(args.name)” to \(args.sequence)",
            previews: [ActionPreview(
                title: "\(args.sequence) · position \(insertAt + 1)",
                oldValue: nil,
                newValue: args.name
                    + (args.description.map { " — \(String($0.prefix(80)))" } ?? ""))])
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let (pvm, seqIndex, insertAt) = try check(args)
        var scene = Scene(name: args.name, description: args.description ?? "")
        scene.timeOfDay = args.timeOfDay
        scene.weather = args.weather
        scene.location = args.location
        pvm.project.sequences[seqIndex].scenes.insert(scene, at: insertAt)
        didMutate(.structure)
        return ActionOutcome(resultForModel: #"{"status": "applied"}"#,
                             userSummary: "Added scene “\(args.name)”")
    }
}

// MARK: - update_scene_fields

final class UpdateSceneFieldsAction: ProjectAssistantAction, AssistantAction {
    static let statuses = ["Planning", "Scheduled", "Ready", "Shooting",
                           "Shot", "Complete"]

    let name = "update_scene_fields"
    let summary = """
    Edit a scene's production fields: time_of_day, weather, location, \
    status (Planning|Scheduled|Ready|Shooting|Shot|Complete), or notes. \
    (For the description, use update_scene_description.)
    """
    let risk = ActionRisk.mutating
    var parameterSchema: JSONValue {
        objectSchema([
            "scene": stringProp, "time_of_day": stringProp,
            "weather": stringProp, "location": stringProp,
            "status": stringProp, "notes": stringProp,
        ], required: ["scene"])
    }

    private struct Arguments: Decodable {
        let scene: String
        let timeOfDay: String?, weather: String?, location: String?
        let status: String?, notes: String?
        enum CodingKeys: String, CodingKey {
            case scene, weather, location, status, notes
            case timeOfDay = "time_of_day"
        }
    }

    @MainActor private func apply(_ args: Arguments, to scene: Scene) throws
    -> (Scene, [ActionPreview]) {
        var updated = scene
        var previews: [ActionPreview] = []
        func change(_ title: String, _ old: String, _ new: String) {
            previews.append(ActionPreview(title: "\(scene.name) · \(title)",
                                          oldValue: old, newValue: new))
        }
        if let timeOfDay = args.timeOfDay {
            change("time of day", scene.timeOfDay ?? "—", timeOfDay)
            updated.timeOfDay = timeOfDay
        }
        if let weather = args.weather {
            change("weather", scene.weather ?? "—", weather)
            updated.weather = weather
        }
        if let location = args.location {
            change("location", scene.location ?? "—", location)
            updated.location = location
        }
        if let status = args.status {
            guard let canonical = Self.statuses.first(where: {
                $0.lowercased() == status.lowercased()
            }) else {
                throw ActionError("status must be one of: "
                                  + Self.statuses.joined(separator: ", "))
            }
            change("status", scene.productionStatus, canonical)
            updated.productionStatus = canonical
        }
        if let notes = args.notes {
            change("notes", String(scene.notes.prefix(80)), String(notes.prefix(80)))
            updated.notes = notes
        }
        guard !previews.isEmpty else {
            throw ActionError("nothing to change — pass at least one field")
        }
        return (updated, previews)
    }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let pvm = try requireProject()
        let (seq, sc) = try sceneIndices(named: args.scene, in: pvm)
        let (_, previews) = try apply(args, to: pvm.project.sequences[seq].scenes[sc])
        return ActionPlan(summary: "Update “\(args.scene)” fields",
                          previews: previews)
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let pvm = try requireProject()
        let (seq, sc) = try sceneIndices(named: args.scene, in: pvm)
        let (updated, _) = try apply(args, to: pvm.project.sequences[seq].scenes[sc])
        pvm.project.sequences[seq].scenes[sc] = updated
        didMutate(.script)
        return ActionOutcome(resultForModel: #"{"status": "applied"}"#,
                             userSummary: "Updated “\(args.scene)” fields")
    }
}

// MARK: - add_dialogue

final class AddDialogueAction: ProjectAssistantAction, AssistantAction {
    let name = "add_dialogue"
    let summary = """
    Add a dialogue line to a scene (optionally at a [n] index; otherwise \
    appended at the end).
    """
    let risk = ActionRisk.mutating
    var parameterSchema: JSONValue {
        objectSchema([
            "scene": stringProp, "character": stringProp, "text": stringProp,
            "at_index": integerProp,
        ], required: ["scene", "character", "text"])
    }

    private struct Arguments: Decodable {
        let scene: String, character: String, text: String
        let atIndex: Int?
        enum CodingKeys: String, CodingKey {
            case scene, character, text
            case atIndex = "at_index"
        }
    }

    @MainActor private func check(_ args: Arguments) throws
    -> (ProjectViewModel, Int, Int, Int, [String]) {
        let pvm = try requireProject()
        let (seq, sc) = try sceneIndices(named: args.scene, in: pvm)
        let dialogues = pvm.project.sequences[seq].scenes[sc].dialogues
        let insertAt = args.atIndex ?? dialogues.count
        guard (0...dialogues.count).contains(insertAt) else {
            throw ActionError("at_index \(insertAt) out of range "
                              + "(scene has \(dialogues.count) dialogues)")
        }
        var warnings: [String] = []
        if !pvm.project.characters.contains(where: {
            $0.name.lowercased() == args.character.lowercased()
        }) {
            warnings.append("“\(args.character)” is not a character in the story design")
        }
        return (pvm, seq, sc, insertAt, warnings)
    }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let (_, _, _, insertAt, warnings) = try check(args)
        return ActionPlan(
            summary: "Add \(args.character)'s line at [\(insertAt)] in “\(args.scene)”",
            previews: [ActionPreview(title: "\(args.character) · [\(insertAt)]",
                                     oldValue: nil,
                                     newValue: String(args.text.prefix(160)))],
            warnings: warnings)
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let (pvm, seq, sc, insertAt, _) = try check(args)
        pvm.project.sequences[seq].scenes[sc].dialogues.insert(
            Dialogue(character: args.character, text: args.text), at: insertAt)
        didMutate(.script)
        return ActionOutcome(resultForModel: #"{"status": "applied"}"#,
                             userSummary: "Added \(args.character)'s line in “\(args.scene)”")
    }
}

// MARK: - add_shot

final class AddShotAction: ProjectAssistantAction, AssistantAction {
    let name = "add_shot"
    let summary = """
    Add a shot to a scene's shot list (description, optional shot_type and \
    camera_angle). The shot number is assigned automatically.
    """
    let risk = ActionRisk.mutating
    var parameterSchema: JSONValue {
        objectSchema([
            "scene": stringProp, "description": stringProp,
            "shot_type": stringProp, "camera_angle": stringProp,
        ], required: ["scene", "description"])
    }

    private struct Arguments: Decodable {
        let scene: String, description: String
        let shotType: String?, cameraAngle: String?
        enum CodingKeys: String, CodingKey {
            case scene, description
            case shotType = "shot_type"
            case cameraAngle = "camera_angle"
        }
    }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let pvm = try requireProject()
        _ = try sceneIndices(named: args.scene, in: pvm)
        let nextId = (pvm.project.sequences.flatMap(\.scenes)
            .flatMap(\.shots).map(\.shotId).max() ?? 0) + 1
        return ActionPlan(
            summary: "Add shot #\(nextId) to “\(args.scene)”",
            previews: [ActionPreview(
                title: "\(args.scene) · shot #\(nextId)",
                oldValue: nil,
                newValue: String(args.description.prefix(120)))])
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let pvm = try requireProject()
        let (seq, sc) = try sceneIndices(named: args.scene, in: pvm)
        let nextId = (pvm.project.sequences.flatMap(\.scenes)
            .flatMap(\.shots).map(\.shotId).max() ?? 0) + 1
        var shot = Shot(shotId: nextId, description: args.description)
        if let angle = args.cameraAngle { shot.cameraAngle = angle }
        if let type = args.shotType { shot.shotType = type }
        pvm.project.sequences[seq].scenes[sc].shots.append(shot)
        didMutate(.shots)
        return ActionOutcome(resultForModel: #"{"status": "applied", "shot": \#(nextId)}"#,
                             userSummary: "Added shot #\(nextId) to “\(args.scene)”")
    }
}

// MARK: - add_character

final class AddCharacterAction: ProjectAssistantAction, AssistantAction {
    let name = "add_character"
    let summary = "Add a character to the story design (optional about/occupation/goal/fear/backstory)."
    let risk = ActionRisk.mutating
    var parameterSchema: JSONValue {
        objectSchema([
            "name": stringProp, "about": stringProp, "occupation": stringProp,
            "goal": stringProp, "fear": stringProp, "backstory": stringProp,
        ], required: ["name"])
    }

    private struct Arguments: Decodable {
        let name: String
        let about: String?, occupation: String?, goal: String?
        let fear: String?, backstory: String?
    }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let pvm = try requireProject()
        if pvm.project.characters.contains(where: {
            $0.name.lowercased() == args.name.lowercased()
        }) {
            throw ActionError("a character named '\(args.name)' already exists")
        }
        return ActionPlan(
            summary: "Add character “\(args.name)”",
            previews: [ActionPreview(
                title: "story design",
                oldValue: nil,
                newValue: args.name
                    + (args.about.map { " — \(String($0.prefix(80)))" } ?? ""))])
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        _ = try validate(argumentsData: argumentsData)
        let pvm = try requireProject()
        var character = Character(name: args.name)
        if let about = args.about { character.about = about }
        if let occupation = args.occupation { character.occupation = occupation }
        if let goal = args.goal { character.primaryGoal = goal }
        if let fear = args.fear { character.primaryFear = fear }
        if let backstory = args.backstory { character.backgroundStory = backstory }
        pvm.project.characters.append(character)
        didMutate(.general)
        return ActionOutcome(resultForModel: #"{"status": "applied"}"#,
                             userSummary: "Added character “\(args.name)”")
    }
}

// MARK: - Factory extension

extension AssistantActionFactory {
    @MainActor static func creativeActions(projectViewModel: ProjectViewModel?,
                                           coordinator: AppCoordinator?) -> [any AssistantAction] {
        [
            AddSequenceAction(projectViewModel: projectViewModel, coordinator: coordinator),
            AddSceneAction(projectViewModel: projectViewModel, coordinator: coordinator),
            UpdateSceneFieldsAction(projectViewModel: projectViewModel, coordinator: coordinator),
            AddDialogueAction(projectViewModel: projectViewModel, coordinator: coordinator),
            AddShotAction(projectViewModel: projectViewModel, coordinator: coordinator),
            AddCharacterAction(projectViewModel: projectViewModel, coordinator: coordinator),
        ]
    }
}

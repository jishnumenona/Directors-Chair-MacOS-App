//
//  AssistantActions.swift
//  DirectorsChair-Desktop
//
//  AI Assistant program, Phase A2.5: the first real AssistantActions — the
//  six legacy modify_project edit types (now one typed, schema'd action
//  each), navigation, and web search, wrapping the SAME app seams the old
//  regex-tag path used. Mutating actions validate against live state and
//  preview old→new; the engine proposes them and the TurnPlan card applies
//  them after user approval (AD5).
//

import Foundation
import DirectorsChairCore
import DirectorsChairServices

// MARK: - Schema helpers

private let stringProp = JSONValue.object(["type": .string("string")])
private let numberProp = JSONValue.object(["type": .string("number")])
private let integerProp = JSONValue.object(["type": .string("integer")])

private func objectSchema(_ properties: [String: JSONValue],
                          required: [String]) -> JSONValue {
    .object(["type": .string("object"),
             "properties": .object(properties),
             "required": .array(required.map(JSONValue.string))])
}

private func decodeArguments<T: Decodable>(_ type: T.Type, from data: Data,
                                           action: String) throws -> T {
    do {
        return try JSONDecoder().decode(type, from: data)
    } catch {
        throw ActionError("invalid arguments for \(action): \(error.localizedDescription)")
    }
}

// MARK: - Shared base

/// Holds the weak app seams every action needs. Actions are @MainActor at
/// their validate/execute entry points (protocol contract), so touching the
/// view models here is safe.
class ProjectAssistantAction: @unchecked Sendable {
    weak var projectViewModel: ProjectViewModel?
    weak var coordinator: AppCoordinator?

    init(projectViewModel: ProjectViewModel?, coordinator: AppCoordinator?) {
        self.projectViewModel = projectViewModel
        self.coordinator = coordinator
    }

    @MainActor func requireProject() throws -> ProjectViewModel {
        guard let projectViewModel else {
            throw ActionError("no project is open")
        }
        return projectViewModel
    }

    @MainActor func character(named name: String,
                              in pvm: ProjectViewModel) throws -> Int {
        guard let index = pvm.project.characters.firstIndex(where: { $0.name == name }) else {
            let known = pvm.project.characters.map(\.name).joined(separator: ", ")
            throw ActionError("character '\(name)' not found (characters: \(known))")
        }
        return index
    }

    @MainActor func sceneIndices(named name: String, in pvm: ProjectViewModel)
    throws -> (sequence: Int, scene: Int) {
        for seqIdx in pvm.project.sequences.indices {
            if let scIdx = pvm.project.sequences[seqIdx].scenes
                .firstIndex(where: { $0.name == name }) {
                return (seqIdx, scIdx)
            }
        }
        throw ActionError("scene '\(name)' not found")
    }

    @MainActor func didMutate(_ event: AppCoordinator.ProjectEvent) {
        projectViewModel?.isDirty = true
        coordinator?.notifyProjectChanged(event)
    }
}

// MARK: - Read-only actions

final class WebSearchAction: ProjectAssistantAction, AssistantAction {
    let name = "web_search"
    let summary = "Search the web for filmmaking knowledge or references."
    let risk = ActionRisk.readOnly
    var parameterSchema: JSONValue {
        objectSchema(["query": stringProp], required: ["query"])
    }

    private struct Arguments: Decodable { let query: String }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try decodeArguments(Arguments.self, from: argumentsData, action: name)
        guard !args.query.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ActionError("query must not be empty")
        }
        return ActionPlan(summary: "Search the web for “\(args.query)”")
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try decodeArguments(Arguments.self, from: argumentsData, action: name)
        let results = await WebSearchClient.shared.search(query: args.query)
        let lines = results.prefix(5).map {
            "- \($0.title) (\($0.url)): \($0.snippet)"
        }.joined(separator: "\n")
        return ActionOutcome(
            resultForModel: lines.isEmpty ? "No results." : lines,
            userSummary: "Searched: \(args.query)")
    }
}

final class NavigateAction: ProjectAssistantAction, AssistantAction {
    let name = "navigate"
    let summary = """
    Open an app view and optionally select an entity. Views: overview, script, \
    bubble, scenes, assets, visionBoard, shotList, production, storyDesign, \
    curation, playback, settings, projects. Optional: scene, character, \
    sequence, location (names), shot (number), production_tab \
    (Schedule|Gantt|Cast & Crew|Accounting|Equipment).
    """
    let risk = ActionRisk.readOnly
    var parameterSchema: JSONValue {
        objectSchema([
            "view": stringProp, "scene": stringProp, "character": stringProp,
            "sequence": stringProp, "location": stringProp, "shot": integerProp,
            "production_tab": stringProp,
        ], required: ["view"])
    }

    private struct Arguments: Decodable {
        let view: String
        let scene: String?
        let character: String?
        let sequence: String?
        let location: String?
        let shot: Int?
        let productionTab: String?
        enum CodingKeys: String, CodingKey {
            case view, scene, character, sequence, location, shot
            case productionTab = "production_tab"
        }
    }

    private static let viewMap: [String: AppView] = [
        "overview": .overview, "script": .script, "bubble": .bubble,
        "scenes": .scenes, "assets": .assets, "visionBoard": .visionBoard,
        "shotList": .shotList, "production": .production,
        "storyDesign": .storyDesign, "curation": .curation,
        "playback": .playback, "settings": .settings, "projects": .projects,
    ]

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try decodeArguments(Arguments.self, from: argumentsData, action: name)
        guard Self.viewMap[args.view] != nil else {
            throw ActionError("unknown view '\(args.view)'")
        }
        return ActionPlan(summary: "Open \(args.view)")
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try decodeArguments(Arguments.self, from: argumentsData, action: name)
        guard let view = Self.viewMap[args.view] else {
            throw ActionError("unknown view '\(args.view)'")
        }
        coordinator?.navigateTo(view)
        if let tab = args.productionTab {
            let canonical: [String: String] = [
                "schedule": "Schedule", "gantt": "Gantt",
                "cast & crew": "Cast & Crew", "cast and crew": "Cast & Crew",
                "cast": "Cast & Crew", "crew": "Cast & Crew",
                "accounting": "Accounting", "budget": "Accounting",
                "equipment": "Equipment"]
            if let resolved = canonical[tab.lowercased()] {
                coordinator?.selectedProductionTab = resolved
            }
        }
        let project = projectViewModel?.project
        let allScenes = project?.sequences.flatMap(\.scenes) ?? []
        var selected: [String] = []
        if let name = args.character,
           let match = project?.characters.first(where: { $0.name == name }) {
            coordinator?.selectCharacter(match); selected.append(name)
        }
        if let name = args.scene,
           let match = allScenes.first(where: { $0.name == name }) {
            coordinator?.selectScene(match); selected.append(name)
        }
        if let name = args.sequence,
           let match = project?.sequences.first(where: { $0.name == name }) {
            coordinator?.selectSequence(match); selected.append(name)
        }
        if let name = args.location,
           let match = project?.locations.first(where: { $0.name == name }) {
            coordinator?.selectLocation(match); selected.append(name)
        }
        if let number = args.shot,
           let match = allScenes.flatMap(\.shots).first(where: { $0.shotId == number }) {
            coordinator?.selectShot(match); selected.append("shot #\(number)")
        }
        let detail = selected.isEmpty ? "" : " (\(selected.joined(separator: ", ")))"
        return ActionOutcome(
            resultForModel: #"{"status": "navigated"}"#,
            userSummary: "Opened \(args.view)\(detail)")
    }
}

// MARK: - Mutating actions

final class UpdateCharacterTraitAction: ProjectAssistantAction, AssistantAction {
    let name = "update_character_trait"
    let summary = "Set one personality trait (0–100) on a character."
    let risk = ActionRisk.mutating
    var parameterSchema: JSONValue {
        objectSchema(["character": stringProp, "trait": stringProp,
                      "value": numberProp, "reason": stringProp],
                     required: ["character", "trait", "value"])
    }

    private struct Arguments: Decodable {
        let character: String
        let trait: String
        let value: Double
        let reason: String?
    }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try decodeArguments(Arguments.self, from: argumentsData, action: name)
        guard (0...100).contains(args.value) else {
            throw ActionError("value must be between 0 and 100")
        }
        let pvm = try requireProject()
        let index = try character(named: args.character, in: pvm)
        let old = pvm.project.characters[index].traits[args.trait]
        return ActionPlan(
            summary: "Set \(args.character)'s \(args.trait) to \(Int(args.value))",
            previews: [ActionPreview(title: "\(args.character) · \(args.trait)",
                                     oldValue: old.map { "\(Int($0))" } ?? "unset",
                                     newValue: "\(Int(args.value))")])
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try decodeArguments(Arguments.self, from: argumentsData, action: name)
        let pvm = try requireProject()
        let index = try character(named: args.character, in: pvm)
        pvm.project.characters[index].traits[args.trait] = args.value
        didMutate(.general)
        return ActionOutcome(resultForModel: #"{"status": "applied"}"#,
                             userSummary: "Updated \(args.character)'s \(args.trait)")
    }
}

final class UpdateCharacterBioAction: ProjectAssistantAction, AssistantAction {
    let name = "update_character_bio"
    let summary = "Edit a character's occupation, goal, fear, backstory, or about."
    let risk = ActionRisk.mutating
    var parameterSchema: JSONValue {
        objectSchema([
            "character": stringProp,
            "field": .object(["type": .string("string"),
                              "enum": .array(["occupation", "goal", "fear",
                                              "backstory", "about"].map(JSONValue.string))]),
            "value": stringProp, "reason": stringProp,
        ], required: ["character", "field", "value"])
    }

    private struct Arguments: Decodable {
        let character: String
        let field: String
        let value: String
        let reason: String?
    }

    @MainActor private func read(_ field: String,
                                 _ char: DirectorsChairCore.Character) -> String? {
        switch field {
        case "occupation": return char.occupation
        case "goal": return char.primaryGoal
        case "fear": return char.primaryFear
        case "backstory": return char.backgroundStory
        case "about": return char.about
        default: return nil
        }
    }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try decodeArguments(Arguments.self, from: argumentsData, action: name)
        guard ["occupation", "goal", "fear", "backstory", "about"].contains(args.field) else {
            throw ActionError("field must be occupation|goal|fear|backstory|about")
        }
        let pvm = try requireProject()
        let index = try character(named: args.character, in: pvm)
        let old = read(args.field, pvm.project.characters[index]) ?? "—"
        return ActionPlan(
            summary: "Update \(args.character)'s \(args.field)",
            previews: [ActionPreview(title: "\(args.character) · \(args.field)",
                                     oldValue: String(old.prefix(120)),
                                     newValue: String(args.value.prefix(120)))])
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try decodeArguments(Arguments.self, from: argumentsData, action: name)
        let pvm = try requireProject()
        let index = try character(named: args.character, in: pvm)
        switch args.field {
        case "occupation": pvm.project.characters[index].occupation = args.value
        case "goal": pvm.project.characters[index].primaryGoal = args.value
        case "fear": pvm.project.characters[index].primaryFear = args.value
        case "backstory": pvm.project.characters[index].backgroundStory = args.value
        case "about": pvm.project.characters[index].about = args.value
        default: throw ActionError("field must be occupation|goal|fear|backstory|about")
        }
        didMutate(.general)
        return ActionOutcome(resultForModel: #"{"status": "applied"}"#,
                             userSummary: "Updated \(args.character)'s \(args.field)")
    }
}

final class UpdateSceneDescriptionAction: ProjectAssistantAction, AssistantAction {
    let name = "update_scene_description"
    let summary = "Replace a scene's description."
    let risk = ActionRisk.mutating
    var parameterSchema: JSONValue {
        objectSchema(["scene": stringProp, "text": stringProp, "reason": stringProp],
                     required: ["scene", "text"])
    }

    private struct Arguments: Decodable {
        let scene: String
        let text: String
        let reason: String?
    }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try decodeArguments(Arguments.self, from: argumentsData, action: name)
        let pvm = try requireProject()
        let (seq, sc) = try sceneIndices(named: args.scene, in: pvm)
        let old = pvm.project.sequences[seq].scenes[sc].description
        return ActionPlan(
            summary: "Rewrite the description of “\(args.scene)”",
            previews: [ActionPreview(title: "\(args.scene) · description",
                                     oldValue: String(old.prefix(160)),
                                     newValue: String(args.text.prefix(160)))])
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try decodeArguments(Arguments.self, from: argumentsData, action: name)
        let pvm = try requireProject()
        let (seq, sc) = try sceneIndices(named: args.scene, in: pvm)
        pvm.project.sequences[seq].scenes[sc].description = args.text
        didMutate(.script)
        return ActionOutcome(resultForModel: #"{"status": "applied"}"#,
                             userSummary: "Updated “\(args.scene)”")
    }
}

final class UpdateDialogueAction: ProjectAssistantAction, AssistantAction {
    let name = "update_dialogue"
    let summary = """
    Rewrite one dialogue line. "index" is the [n] shown beside the dialogue \
    in the project data.
    """
    let risk = ActionRisk.mutating
    var parameterSchema: JSONValue {
        objectSchema(["scene": stringProp, "index": integerProp,
                      "text": stringProp, "reason": stringProp],
                     required: ["scene", "index", "text"])
    }

    private struct Arguments: Decodable {
        let scene: String
        let index: Int
        let text: String
        let reason: String?
    }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try decodeArguments(Arguments.self, from: argumentsData, action: name)
        let pvm = try requireProject()
        let (seq, sc) = try sceneIndices(named: args.scene, in: pvm)
        let dialogues = pvm.project.sequences[seq].scenes[sc].dialogues
        guard dialogues.indices.contains(args.index) else {
            throw ActionError("dialogue index \(args.index) out of range "
                              + "(scene has \(dialogues.count) dialogues)")
        }
        let old = dialogues[args.index]
        return ActionPlan(
            summary: "Rewrite \(old.character)'s line [\(args.index)] in “\(args.scene)”",
            previews: [ActionPreview(title: "\(old.character) · [\(args.index)]",
                                     oldValue: String(old.text.prefix(160)),
                                     newValue: String(args.text.prefix(160)))])
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try decodeArguments(Arguments.self, from: argumentsData, action: name)
        let pvm = try requireProject()
        let (seq, sc) = try sceneIndices(named: args.scene, in: pvm)
        guard pvm.project.sequences[seq].scenes[sc].dialogues.indices
            .contains(args.index) else {
            throw ActionError("dialogue index \(args.index) out of range")
        }
        pvm.project.sequences[seq].scenes[sc].dialogues[args.index].text = args.text
        didMutate(.script)
        return ActionOutcome(resultForModel: #"{"status": "applied"}"#,
                             userSummary: "Rewrote line [\(args.index)] in “\(args.scene)”")
    }
}

final class UpdateProjectMetadataAction: ProjectAssistantAction, AssistantAction {
    let name = "update_project_metadata"
    let summary = "Set the project's genre, status, tagline, logline, or description."
    let risk = ActionRisk.mutating
    var parameterSchema: JSONValue {
        objectSchema([
            "field": .object(["type": .string("string"),
                              "enum": .array(["genre", "status", "tagline",
                                              "logline", "description"].map(JSONValue.string))]),
            "value": stringProp, "reason": stringProp,
        ], required: ["field", "value"])
    }

    private struct Arguments: Decodable {
        let field: String
        let value: String
        let reason: String?
    }

    @MainActor private func read(_ field: String, _ project: Project) -> String? {
        switch field {
        case "genre": return project.genre
        case "status": return project.status
        case "tagline": return project.overviewTagline
        case "logline": return project.overviewLogline
        case "description": return project.description
        default: return nil
        }
    }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try decodeArguments(Arguments.self, from: argumentsData, action: name)
        let pvm = try requireProject()
        guard let old = read(args.field, pvm.project) else {
            throw ActionError("field must be genre|status|tagline|logline|description")
        }
        return ActionPlan(
            summary: "Set the project \(args.field)",
            previews: [ActionPreview(title: "project · \(args.field)",
                                     oldValue: String(old.prefix(120)),
                                     newValue: String(args.value.prefix(120)))])
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try decodeArguments(Arguments.self, from: argumentsData, action: name)
        let pvm = try requireProject()
        switch args.field {
        case "genre": pvm.project.genre = args.value
        case "status": pvm.project.status = args.value
        case "tagline": pvm.project.overviewTagline = args.value
        case "logline": pvm.project.overviewLogline = args.value
        case "description": pvm.project.description = args.value
        default: throw ActionError("field must be genre|status|tagline|logline|description")
        }
        didMutate(.general)
        return ActionOutcome(resultForModel: #"{"status": "applied"}"#,
                             userSummary: "Set the project \(args.field)")
    }
}

final class AddRelationshipAction: ProjectAssistantAction, AssistantAction {
    let name = "add_relationship"
    let summary = "Add or update a relationship between two characters."
    let risk = ActionRisk.mutating
    var parameterSchema: JSONValue {
        objectSchema(["character": stringProp, "target": stringProp,
                      "relationship": stringProp, "reason": stringProp],
                     required: ["character", "target", "relationship"])
    }

    private struct Arguments: Decodable {
        let character: String
        let target: String
        let relationship: String
        let reason: String?
    }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try decodeArguments(Arguments.self, from: argumentsData, action: name)
        let pvm = try requireProject()
        let index = try character(named: args.character, in: pvm)
        let old = pvm.project.characters[index].relationships?[args.target]
        return ActionPlan(
            summary: "\(args.character) → \(args.target): \(args.relationship)",
            previews: [ActionPreview(title: "\(args.character) → \(args.target)",
                                     oldValue: old ?? "none",
                                     newValue: args.relationship)])
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try decodeArguments(Arguments.self, from: argumentsData, action: name)
        let pvm = try requireProject()
        let index = try character(named: args.character, in: pvm)
        if pvm.project.characters[index].relationships == nil {
            pvm.project.characters[index].relationships = [:]
        }
        pvm.project.characters[index].relationships?[args.target] = args.relationship
        didMutate(.general)
        return ActionOutcome(resultForModel: #"{"status": "applied"}"#,
                             userSummary: "Linked \(args.character) → \(args.target)")
    }
}

// MARK: - Factory

enum AssistantActionFactory {
    /// The assistant's current action catalog. Rebuilt per turn so weak seams
    /// track the live view models.
    @MainActor static func makeRegistry(projectViewModel: ProjectViewModel?,
                                        coordinator: AppCoordinator?) -> ActionRegistry {
        var registry = ActionRegistry()
        var actions: [any AssistantAction] = [
            WebSearchAction(projectViewModel: projectViewModel, coordinator: coordinator),
            NavigateAction(projectViewModel: projectViewModel, coordinator: coordinator),
            UpdateCharacterTraitAction(projectViewModel: projectViewModel, coordinator: coordinator),
            UpdateCharacterBioAction(projectViewModel: projectViewModel, coordinator: coordinator),
            UpdateSceneDescriptionAction(projectViewModel: projectViewModel, coordinator: coordinator),
            UpdateDialogueAction(projectViewModel: projectViewModel, coordinator: coordinator),
            UpdateProjectMetadataAction(projectViewModel: projectViewModel, coordinator: coordinator),
            AddRelationshipAction(projectViewModel: projectViewModel, coordinator: coordinator),
        ]
        actions += readTools(projectViewModel: projectViewModel,
                             coordinator: coordinator)   // A3.1
        actions += scheduleActions(projectViewModel: projectViewModel,
                                   coordinator: coordinator)   // A3.2
        for action in actions {
            do {
                try registry.register(action)
            } catch {
                // Names are compile-time constants; a failure here is a
                // programmer error caught by AssistantActionsTests.
                assertionFailure("action registration failed: \(error)")
            }
        }
        return registry
    }
}

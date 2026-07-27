//
//  AssistantPipelineActions.swift
//  DirectorsChair-Desktop
//
//  AI Assistant program, Phase A5.6: the heavyweight pipelines as chat
//  actions (F-E6), led by screenplay import — "here's my screenplay, set
//  up my project." Wraps the existing 5-pass ScreenplayImporter verbatim
//  (the pipeline is the seam); the action grafts the imported structure
//  into the CURRENT project so the whole-turn Undo snapshot covers regret.
//  Approval happens BEFORE the pipeline runs (its five text passes are the
//  spend); the runner is injected for offline tests.
//

import Foundation
import DirectorsChairCore
import DirectorsChairServices

private let stringProp = JSONValue.object(["type": .string("string")])

private func objectSchema(_ properties: [String: JSONValue],
                          required: [String]) -> JSONValue {
    .object(["type": .string("object"),
             "properties": .object(properties),
             "required": .array(required.map(JSONValue.string))])
}

// MARK: - import_screenplay

final class ImportScreenplayAction: ProjectAssistantAction, AssistantAction {
    /// Five Gemini text passes over a feature screenplay ≈ pennies; stated
    /// conservatively. (Text is metered server-side like everything else.)
    static let estimatedImportCost = 0.05

    typealias RunImport = @MainActor (URL, String) async throws -> ScreenplayImporter.ImportResult

    let name = "import_screenplay"
    let summary = """
    Set up the current project from a screenplay PDF: runs the app's \
    5-pass AI import (metadata, characters, production elements, scene \
    list, scene contents) and fills this project's structure — sequences, \
    scenes, dialogue, characters, locations, props. Takes a minute or two \
    and REPLACES the current story structure (undoable). "path" is the \
    PDF's file path.
    """
    let risk = ActionRisk.spending
    var parameterSchema: JSONValue {
        objectSchema(["path": stringProp], required: ["path"])
    }

    private let runImport: RunImport

    init(projectViewModel: ProjectViewModel?, coordinator: AppCoordinator?,
         runImport: @escaping RunImport) {
        self.runImport = runImport
        super.init(projectViewModel: projectViewModel, coordinator: coordinator)
    }

    private struct Arguments: Decodable { let path: String }

    @MainActor private func resolvedURL(_ args: Arguments) throws -> URL {
        let expanded = (args.path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ActionError("no file at '\(args.path)'")
        }
        guard url.pathExtension.lowercased() == "pdf" else {
            throw ActionError("screenplay import currently accepts PDF files only")
        }
        return url
    }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let pvm = try requireProject()
        let url = try resolvedURL(args)
        let sceneCount = pvm.project.sequences.flatMap(\.scenes).count
        var warnings: [String] = []
        if sceneCount > 0 {
            warnings.append("replaces the current structure (\(sceneCount) scenes, \(pvm.project.characters.count) characters) — Undo restores it")
        }
        return ActionPlan(
            summary: "Import “\(url.lastPathComponent)” into this project (~$\(String(format: "%.2f", Self.estimatedImportCost)), 1–2 min)",
            previews: [ActionPreview(
                title: "5-pass AI screenplay import",
                oldValue: sceneCount == 0 ? "empty project" : "\(sceneCount) scenes",
                newValue: "full structure from \(url.lastPathComponent)")],
            warnings: warnings,
            estimatedCost: Self.estimatedImportCost)
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let pvm = try requireProject()
        let url = try resolvedURL(args)

        let result = try await runImport(url, pvm.project.name)

        // Graft the imported structure into the CURRENT project — identity
        // and settings stay; story content is replaced (Undo covers it).
        pvm.project.sequences = result.project.sequences
        pvm.project.characters = result.project.characters
        pvm.project.locations = result.project.locations
        pvm.project.props = result.project.props
        if !result.project.genre.isEmpty { pvm.project.genre = result.project.genre }
        if !result.project.description.isEmpty {
            pvm.project.description = result.project.description
        }
        didMutate(.structure)

        let stats = result.stats
        return ActionOutcome(
            resultForModel: """
            {"status": "applied", "scenes": \(stats.sceneCount), \
            "characters": \(stats.characterCount), "dialogues": \(stats.dialogueCount), \
            "locations": \(stats.locationCount), "props": \(stats.propCount)}
            """,
            userSummary: "Imported \(stats.sceneCount) scenes, "
                + "\(stats.characterCount) characters, \(stats.dialogueCount) dialogue lines, "
                + "\(stats.locationCount) locations, \(stats.propCount) props")
    }
}


// MARK: - write_character_biography

final class WriteCharacterBiographyAction: ProjectAssistantAction, AssistantAction {
    typealias GenerateBackstory = @Sendable (
        _ name: String, _ age: String, _ occupation: String,
        _ keyTraits: [String], _ storyContext: String) async throws -> String

    let name = "write_character_biography"
    let summary = """
    Write a character's background story with AI, from their name, age, \
    occupation, top personality traits, and the project's story context — \
    the same generator as Story Design's Biography button. Replaces the \
    existing backstory (undoable). Runs on approval (~$0.01).
    """
    let risk = ActionRisk.spending
    var parameterSchema: JSONValue {
        objectSchema(["character": stringProp], required: ["character"])
    }

    private let generateBackstory: GenerateBackstory

    init(projectViewModel: ProjectViewModel?, coordinator: AppCoordinator?,
         generateBackstory: @escaping GenerateBackstory) {
        self.generateBackstory = generateBackstory
        super.init(projectViewModel: projectViewModel, coordinator: coordinator)
    }

    private struct Arguments: Decodable { let character: String }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let pvm = try requireProject()
        let index = try character(named: args.character, in: pvm)
        let existing = pvm.project.characters[index].backgroundStory
        return ActionPlan(
            summary: "Write \(args.character)'s biography (~$0.01)",
            previews: [ActionPreview(
                title: "\(args.character) · backstory",
                oldValue: (existing?.isEmpty ?? true) ? "none"
                    : String(existing!.prefix(120)),
                newValue: "AI-written biography (generated on apply)")],
            estimatedCost: 0.01)
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let pvm = try requireProject()
        let index = try character(named: args.character, in: pvm)
        let subject = pvm.project.characters[index]
        // Same inputs as the Story Design seam: top-5 traits + story context.
        let keyTraits = subject.traits.sorted { $0.value > $1.value }
            .prefix(5).map(\.key)
        let backstory = try await generateBackstory(
            subject.name, "\(subject.age)", subject.occupation ?? "",
            Array(keyTraits), pvm.project.overviewSummary)
        pvm.project.characters[index].backgroundStory = backstory
        didMutate(.general)
        return ActionOutcome(
            resultForModel: #"{"status": "applied"}"#,
            userSummary: "Wrote \(args.character)'s biography")
    }
}


// MARK: - calibrate_character_traits

final class CalibrateCharacterTraitsAction: ProjectAssistantAction, AssistantAction {
    typealias Analyze = @MainActor (Character, Project) async throws -> CharacterAnalysisResult

    let name = "calibrate_character_traits"
    let summary = """
    Calibrate a character's personality trait scores with AI from their \
    dialogue and actions across the script — the same analyzer as Story \
    Design's trait analysis, storing confidence and reasoning alongside \
    the scores. Replaces current trait values (undoable). Runs on \
    approval (~$0.02).
    """
    let risk = ActionRisk.spending
    var parameterSchema: JSONValue {
        objectSchema(["character": stringProp], required: ["character"])
    }

    private let analyze: Analyze

    init(projectViewModel: ProjectViewModel?, coordinator: AppCoordinator?,
         analyze: @escaping Analyze) {
        self.analyze = analyze
        super.init(projectViewModel: projectViewModel, coordinator: coordinator)
    }

    private struct Arguments: Decodable { let character: String }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let pvm = try requireProject()
        let index = try character(named: args.character, in: pvm)
        let subject = pvm.project.characters[index]
        let topTraits = subject.traits.sorted { $0.value > $1.value }
            .prefix(3).map { "\($0.key) \(Int($0.value))" }
            .joined(separator: ", ")
        return ActionPlan(
            summary: "Calibrate \(args.character)'s traits from the script (~$0.02)",
            previews: [ActionPreview(
                title: "\(args.character) · traits",
                oldValue: topTraits.isEmpty ? "unscored" : topTraits,
                newValue: "AI-calibrated scores + confidence (on apply)")],
            estimatedCost: 0.02)
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let pvm = try requireProject()
        let index = try character(named: args.character, in: pvm)
        let result = try await analyze(pvm.project.characters[index], pvm.project)

        // Mirrors the Story Design seam's writes exactly.
        for (trait, score) in result.traitScores {
            pvm.project.characters[index].traits[trait] = score
        }
        pvm.project.characters[index].traitsConfidenceScore = result.confidenceScore
        pvm.project.characters[index].traitsAiReasoning = result.reasoning
        pvm.project.characters[index].traitsLastCalibrated = Date()
        if let build = result.physicalAttributes["build"] {
            pvm.project.characters[index].build = build
        }
        if let hairColor = result.physicalAttributes["hair_color"] {
            pvm.project.characters[index].hairColor = hairColor
        }
        didMutate(.general)
        return ActionOutcome(
            resultForModel: #"{"status": "applied", "traits": \#(result.traitScores.count), "confidence": \#(Int(result.confidenceScore))}"#,
            userSummary: "Calibrated \(result.traitScores.count) traits for \(args.character) "
                + "(\(Int(result.confidenceScore))% confidence)")
    }
}

// MARK: - analyze_timeline

final class AnalyzeTimelineAction: ProjectAssistantAction, AssistantAction {
    typealias SceneTuple = (scene: DirectorsChairCore.Scene, sceneName: String,
                            sequenceIndex: Int, sceneIndex: Int)
    typealias Analyze = @MainActor ([SceneTuple]) async throws -> TimelineAnalysisResult

    let name = "analyze_timeline"
    let summary = """
    Run the 4-pass AI timeline analysis over the script (all scenes, or \
    one named scene) and apply its improvements to the timeline. The cost \
    estimate comes from the app's own calculator. Undoable. Runs on \
    approval.
    """
    let risk = ActionRisk.spending
    var parameterSchema: JSONValue {
        objectSchema(["scene": stringProp], required: [])
    }

    private let analyze: Analyze

    init(projectViewModel: ProjectViewModel?, coordinator: AppCoordinator?,
         analyze: @escaping Analyze) {
        self.analyze = analyze
        super.init(projectViewModel: projectViewModel, coordinator: coordinator)
    }

    private struct Arguments: Decodable { let scene: String? }

    @MainActor private func scenesToAnalyze(_ args: Arguments,
                                            in pvm: ProjectViewModel) throws -> [SceneTuple] {
        var scenes: [SceneTuple] = []
        if let name = args.scene {
            let (seq, sc) = try sceneIndices(named: name, in: pvm)
            scenes.append((pvm.project.sequences[seq].scenes[sc],
                           pvm.project.sequences[seq].scenes[sc].name, seq, sc))
        } else {
            for (seqIdx, sequence) in pvm.project.sequences.enumerated() {
                for (scnIdx, scene) in sequence.scenes.enumerated() {
                    scenes.append((scene, scene.name, seqIdx, scnIdx))
                }
            }
        }
        guard !scenes.isEmpty else {
            throw ActionError("the project has no scenes to analyze")
        }
        return scenes
    }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let pvm = try requireProject()
        let scenes = try scenesToAnalyze(args, in: pvm)
        // The app's real cost calculator — same numbers as the UI dialog.
        let estimate = TimelineAnalyzer.estimateCost(scenes: scenes)
        guard estimate.sceneCount > 0 else {
            throw ActionError("the selected scenes have no script content to analyze")
        }
        return ActionPlan(
            summary: "Analyze \(estimate.sceneCount) scene\(estimate.sceneCount == 1 ? "" : "s") "
                + "(\(estimate.estimatedCalls) AI calls ≈ $\(String(format: "%.2f", estimate.estimatedCostUSD)))",
            previews: [ActionPreview(
                title: args.scene.map { "timeline · \($0)" } ?? "timeline · whole project",
                oldValue: nil,
                newValue: "4-pass analysis + timeline improvements (on apply)")],
            estimatedCost: estimate.estimatedCostUSD)
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let pvm = try requireProject()
        let scenes = try scenesToAnalyze(args, in: pvm)
        let result = try await analyze(scenes)
        TimelineAnalyzer.applyChanges(to: &pvm.project, from: result)
        didMutate(.script)
        return ActionOutcome(
            resultForModel: #"{"status": "applied", "scenes": \#(scenes.count)}"#,
            userSummary: "Timeline analysis applied across \(scenes.count) scene\(scenes.count == 1 ? "" : "s")")
    }
}

// MARK: - Factory extension

extension AssistantActionFactory {
    @MainActor static func pipelineActions(projectViewModel: ProjectViewModel?,
                                           coordinator: AppCoordinator?) -> [any AssistantAction] {
        [
            ImportScreenplayAction(
                projectViewModel: projectViewModel, coordinator: coordinator,
                runImport: { url, name in
                    try await ScreenplayImporter.importFromPDF(
                        url: url, projectName: name, progress: nil)
                }),
            WriteCharacterBiographyAction(
                projectViewModel: projectViewModel, coordinator: coordinator,
                generateBackstory: { name, age, occupation, traits, context in
                    try await AIServiceClient.shared.generateCharacterBackstory(
                        characterName: name, age: age, occupation: occupation,
                        keyTraits: traits, storyContext: context)
                }),
            CalibrateCharacterTraitsAction(
                projectViewModel: projectViewModel, coordinator: coordinator,
                analyze: { character, project in
                    try await CharacterAnalyzer(project: project,
                                                aiClient: AIServiceClient.shared)
                        .analyzeCharacter(character) { _ in }
                }),
            AnalyzeTimelineAction(
                projectViewModel: projectViewModel, coordinator: coordinator,
                analyze: { scenes in
                    try await TimelineAnalyzer().analyzeScenes(scenes: scenes,
                                                               progressCallback: nil)
                }),
        ]
    }
}

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
        ]
    }
}

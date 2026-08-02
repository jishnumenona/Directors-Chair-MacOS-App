//
//  AssistantBatchActions.swift
//  DirectorsChair-Desktop
//
//  AI Assistant program, Phase A5.5: batch orchestration (F-E5) —
//  "generate images for ALL my characters/locations" as ONE tool call, so
//  project-wide sweeps don't burn the 8-call turn budget. The batch is an
//  orchestrator over the existing per-entity actions (their validation,
//  pipelines, and conventions are reused verbatim); its plan lists every
//  entity with per-entity costs and carries the batch total that the
//  review card surfaces against the $5 guideline.
//

import Foundation
import DirectorsChairCore
import DirectorsChairServices

private let integerProp = JSONValue.object(["type": .string("integer")])

private func objectSchema(_ properties: [String: JSONValue],
                          required: [String]) -> JSONValue {
    .object(["type": .string("object"),
             "properties": .object(properties),
             "required": .array(required.map(JSONValue.string))])
}

// MARK: - generate_missing_images

final class GenerateMissingImagesAction: ProjectAssistantAction, AssistantAction {
    let name = "generate_missing_images"
    let summary = """
    Generate images for EVERY character and location that has none yet, in \
    one batch: each character gets its reference set, each location its \
    primary establishing shot. Use this for project-wide sweeps instead of \
    many per-entity calls. SPENDS ~$0.04 per image; the approval card shows \
    the per-entity breakdown and the batch total. Optional "limit" caps how \
    many entities are included.
    """
    let risk = ActionRisk.spending
    let minimumTier = ProductTier.creator  // §3.7: generation actions are Creator+
    var parameterSchema: JSONValue {
        objectSchema(["limit": integerProp], required: [])
    }

    private let characterAction: GenerateCharacterImagesAction
    private let locationAction: GenerateLocationImagesAction

    init(projectViewModel: ProjectViewModel?, coordinator: AppCoordinator?,
         characterAction: GenerateCharacterImagesAction,
         locationAction: GenerateLocationImagesAction) {
        self.characterAction = characterAction
        self.locationAction = locationAction
        super.init(projectViewModel: projectViewModel, coordinator: coordinator)
    }

    private struct Arguments: Decodable { let limit: Int? }

    private enum Target {
        case character(name: String, missingAngles: Int)
        case location(name: String)

        var cost: Double {
            switch self {
            case .character(_, let missing):
                return Double(missing) * CharacterImagePipeline.estimatedCostPerImage
            case .location:
                return CharacterImagePipeline.estimatedCostPerImage
            }
        }
    }

    @MainActor private func targets(_ args: Arguments) throws
    -> (ProjectViewModel, [Target]) {
        let limit = args.limit ?? Int.max
        guard limit > 0 else {
            throw ActionError("limit must be at least 1")
        }
        let pvm = try requireProject()
        var found: [Target] = []
        for character in pvm.project.characters {
            let missing = CharacterImagePipeline.defaultAngles.filter {
                CharacterImagePipeline.storedPath(on: character, for: $0) == nil
            }.count
            if missing > 0 {
                found.append(.character(name: character.name, missingAngles: missing))
            }
        }
        for location in pvm.project.locations where location.primaryImage == nil {
            found.append(.location(name: location.name))
        }
        guard !found.isEmpty else {
            throw ActionError("every character and location already has images — nothing to generate")
        }
        return (pvm, Array(found.prefix(limit)))
    }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let (_, targets) = try targets(args)
        let total = targets.reduce(0) { $0 + $1.cost }
        let imageCount = Int((total / CharacterImagePipeline.estimatedCostPerImage).rounded())
        return ActionPlan(
            summary: "Generate \(imageCount) missing image\(imageCount == 1 ? "" : "s") "
                + "across \(targets.count) entit\(targets.count == 1 ? "y" : "ies") "
                + "(~$\(String(format: "%.2f", total)))",
            previews: targets.map { target in
                switch target {
                case .character(let name, let missing):
                    return ActionPreview(
                        title: "character · \(name)",
                        oldValue: nil,
                        newValue: "\(missing) reference image\(missing == 1 ? "" : "s") (~$\(String(format: "%.2f", target.cost)))")
                case .location(let name):
                    return ActionPreview(
                        title: "location · \(name)",
                        oldValue: nil,
                        newValue: "primary establishing shot (~$\(String(format: "%.2f", target.cost)))")
                }
            },
            estimatedCost: total)
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let (_, targets) = try targets(args)
        var completed = 0
        var failures: [String] = []
        for target in targets {
            do {
                switch target {
                case .character(let name, _):
                    _ = try await characterAction.execute(argumentsData:
                        Data(#"{"character": "\#(name)"}"#.utf8))
                case .location(let name):
                    _ = try await locationAction.execute(argumentsData:
                        Data(#"{"location": "\#(name)"}"#.utf8))
                }
                completed += 1
            } catch {
                // One entity failing must not sink the sweep — report it.
                failures.append("\(targetName(target)): \(error.localizedDescription)")
            }
        }
        didMutate(.general)
        let failureNote = failures.isEmpty ? ""
            : " (failed: \(failures.joined(separator: "; ")))"
        return ActionOutcome(
            resultForModel: #"{"status": "applied", "entities": \#(completed), "failures": \#(failures.count)}"#,
            userSummary: "Generated images for \(completed) of \(targets.count) entities\(failureNote)")
    }

    private func targetName(_ target: Target) -> String {
        switch target {
        case .character(let name, _): return name
        case .location(let name): return name
        }
    }
}

// MARK: - Factory extension

extension AssistantActionFactory {
    @MainActor static func batchActions(projectViewModel: ProjectViewModel?,
                                        coordinator: AppCoordinator?,
                                        characterAction: GenerateCharacterImagesAction,
                                        locationAction: GenerateLocationImagesAction) -> [any AssistantAction] {
        [
            GenerateMissingImagesAction(projectViewModel: projectViewModel,
                                        coordinator: coordinator,
                                        characterAction: characterAction,
                                        locationAction: locationAction),
        ]
    }
}

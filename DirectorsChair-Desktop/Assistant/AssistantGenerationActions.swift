//
//  AssistantGenerationActions.swift
//  DirectorsChair-Desktop
//
//  AI Assistant program, Phase A5 slice 1: generation orchestration —
//  the assistant can propose SPENDING work (AD5): generate a character's
//  reference image set from chat. The proposal carries an explicit
//  per-image cost estimate on the review card; nothing is generated
//  until the user approves. The pipeline mirrors the Story Design
//  feature's conventions exactly (prompt builder, asset paths, character
//  fields), with the network call injected so tests run offline.
//

import Foundation
import DirectorsChairCore
import DirectorsChairServices
import DirectorsChairViews

private let stringProp = JSONValue.object(["type": .string("string")])
private let boolProp = JSONValue.object(["type": .string("boolean")])
private let stringArrayProp = JSONValue.object(
    ["type": .string("array"), "items": .object(["type": .string("string")])])

private func objectSchema(_ properties: [String: JSONValue],
                          required: [String]) -> JSONValue {
    .object(["type": .string("object"),
             "properties": .object(properties),
             "required": .array(required.map(JSONValue.string))])
}

// MARK: - Pipeline

/// Generates and stores one character reference image per angle, following
/// the SAME conventions as the Story Design generation path
/// (ContentView+CentralStack): prompts via StoryDesignPromptBuilder, files
/// under assets/characters/<name>/<face|body>/…png, paths stored on the
/// matching Character field. The provider call is injected for testability.
@MainActor
struct CharacterImagePipeline {
    /// (prompt, referencePNGBase64?) → PNG data.
    typealias Generate = @Sendable (String, String?) async throws -> Data

    /// Matches gateway cost.py (google_imagen per image) — reconcile there.
    static let estimatedCostPerImage = 0.04
    /// The reference set the Story Design feature produces.
    static let defaultAngles = ["base", "three_quarter_left", "three_quarter_right"]
    static let allAngles = defaultAngles + ["profile_left", "profile_right", "back"]

    let projectViewModel: ProjectViewModel
    let generate: Generate

    static func storedPath(on character: Character, for angle: String) -> String? {
        switch angle {
        case "base": return character.baseImage
        case "front": return character.imageFront
        case "three_quarter_left": return character.imageThreeQuarterLeft
        case "three_quarter_right": return character.imageThreeQuarterRight
        case "profile_left": return character.imageProfileLeft
        case "profile_right": return character.imageProfileRight
        case "back": return character.imageBack
        default: return nil
        }
    }

    // Mirrors ContentView+CentralStack.sanitizeAssetName (private there).
    static func sanitizeAssetName(_ name: String) -> String {
        var sanitized = name
        for bad in [" ", "/", "\\", ":", "(", ")"] {
            sanitized = sanitized.replacingOccurrences(of: bad, with: "_")
        }
        sanitized = sanitized.replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\"", with: "")
        while sanitized.contains("__") {
            sanitized = sanitized.replacingOccurrences(of: "__", with: "_")
        }
        sanitized = sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        if sanitized.count > 100 { sanitized = String(sanitized.prefix(100)) }
        return sanitized.isEmpty ? "Unnamed" : sanitized
    }

    // Mirrors ContentView+CentralStack.getAssetPath (private there).
    static func assetPath(for angle: String) -> (subfolder: String, filename: String) {
        switch angle {
        case "base", "front": return ("face", "front")
        case "three_quarter_left": return ("face", "three_quarter_left")
        case "three_quarter_right": return ("face", "three_quarter_right")
        case "profile_left": return ("face", "profile")
        case "profile_right": return ("face", "profile_right")
        case "back": return ("body", "back")
        default: return ("face", "front")
        }
    }

    static func prompt(for character: Character, angle: String) -> String {
        let base: String
        if let custom = character.baseImagePrompt, !custom.isEmpty {
            base = custom
        } else {
            base = StoryDesignPromptBuilder.characterAppearancePrompt(character: character)
        }
        let angleClause: String
        switch angle {
        case "base": angleClause = "Front-facing neutral studio reference portrait, head and shoulders, even lighting."
        case "three_quarter_left": angleClause = "Same person as the reference image, three-quarter view turned to their left, identical appearance and lighting."
        case "three_quarter_right": angleClause = "Same person as the reference image, three-quarter view turned to their right, identical appearance and lighting."
        case "profile_left": angleClause = "Same person as the reference image, exact left profile, identical appearance and lighting."
        case "profile_right": angleClause = "Same person as the reference image, exact right profile, identical appearance and lighting."
        case "back": angleClause = "Same person as the reference image, seen from behind, identical appearance and lighting."
        default: angleClause = ""
        }
        return "\(base)\n\n\(angleClause)"
    }

    private func loadReferenceBase64(for character: Character) -> String? {
        guard let basePath = character.baseImage,
              let projectFile = projectViewModel.projectPath else { return nil }
        let url = projectFile.deletingLastPathComponent()
            .appendingPathComponent(basePath)
        return (try? Data(contentsOf: url))?.base64EncodedString()
    }

    /// Generates one angle, saves it, and stores the relative path on the
    /// character. Returns the relative path.
    func generateAndStore(characterId: String, angle: String) async throws -> String {
        guard let index = projectViewModel.project.characters
            .firstIndex(where: { $0.id == characterId }) else {
            throw ActionError("character no longer exists")
        }
        let character = projectViewModel.project.characters[index]
        guard let projectFile = projectViewModel.projectPath else {
            throw ActionError("the project has not been saved yet")
        }

        let reference = angle == "base" ? nil : loadReferenceBase64(for: character)
        let imageData = try await generate(
            Self.prompt(for: character, angle: angle), reference)

        let sanitized = Self.sanitizeAssetName(character.name)
        let (subfolder, filename) = Self.assetPath(for: angle)
        let projectDir = projectFile.deletingLastPathComponent()
        let directory = projectDir
            .appendingPathComponent("assets")
            .appendingPathComponent("characters")
            .appendingPathComponent(sanitized)
            .appendingPathComponent(subfolder)
        try FileManager.default.createDirectory(at: directory,
                                                withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("\(filename).png")
        try imageData.write(to: fileURL)

        let relativePath = "assets/characters/\(sanitized)/\(subfolder)/\(filename).png"
        switch angle {
        case "base":
            projectViewModel.project.characters[index].baseImage = relativePath
        case "front":
            projectViewModel.project.characters[index].imageFront = relativePath
        case "three_quarter_left":
            projectViewModel.project.characters[index].imageThreeQuarterLeft = relativePath
        case "three_quarter_right":
            projectViewModel.project.characters[index].imageThreeQuarterRight = relativePath
        case "profile_left":
            projectViewModel.project.characters[index].imageProfileLeft = relativePath
        case "profile_right":
            projectViewModel.project.characters[index].imageProfileRight = relativePath
        case "back":
            projectViewModel.project.characters[index].imageBack = relativePath
        default:
            projectViewModel.project.characters[index].baseImage = relativePath
        }
        projectViewModel.isDirty = true
        return relativePath
    }
}

// MARK: - generate_character_images

final class GenerateCharacterImagesAction: ProjectAssistantAction, AssistantAction {
    let name = "generate_character_images"
    let summary = """
    Generate a character's reference images (base portrait + angle views) \
    from their story-design appearance. This SPENDS AI credits (~$0.04 per \
    image) and runs only after the user approves. By default generates the \
    standard set, skipping images that already exist; pass regenerate=true \
    to redo existing ones, or "angles" to pick specific views \
    (base|three_quarter_left|three_quarter_right|profile_left|\
    profile_right|back).
    """
    let risk = ActionRisk.spending
    let minimumTier = ProductTier.creator  // §3.7: generation actions are Creator+
    var parameterSchema: JSONValue {
        objectSchema([
            "character": stringProp,
            "angles": stringArrayProp,
            "regenerate": boolProp,
        ], required: ["character"])
    }

    private let makeGenerate: @MainActor () -> CharacterImagePipeline.Generate

    init(projectViewModel: ProjectViewModel?, coordinator: AppCoordinator?,
         makeGenerate: @escaping @MainActor () -> CharacterImagePipeline.Generate) {
        self.makeGenerate = makeGenerate
        super.init(projectViewModel: projectViewModel, coordinator: coordinator)
    }

    private struct Arguments: Decodable {
        let character: String
        let angles: [String]?
        let regenerate: Bool?
    }

    @MainActor private func plannedAngles(_ args: Arguments) throws
    -> (ProjectViewModel, Int, [String]) {
        let pvm = try requireProject()
        let index = try character(named: args.character, in: pvm)
        let subject = pvm.project.characters[index]

        var angles = args.angles ?? CharacterImagePipeline.defaultAngles
        if let invalid = angles.first(where: {
            !CharacterImagePipeline.allAngles.contains($0)
        }) {
            throw ActionError("unknown angle '\(invalid)' — use: "
                + CharacterImagePipeline.allAngles.joined(separator: ", "))
        }
        if args.regenerate != true {
            angles = angles.filter {
                CharacterImagePipeline.storedPath(on: subject, for: $0) == nil
            }
        }
        guard !angles.isEmpty else {
            throw ActionError("all requested images already exist for "
                + "\(args.character) — pass regenerate=true to redo them")
        }
        // The base portrait anchors the angle views — always generate it
        // first when it's part of the plan.
        angles.sort { $0 == "base" && $1 != "base" }
        return (pvm, index, angles)
    }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let (_, _, angles) = try plannedAngles(args)
        let cost = Double(angles.count) * CharacterImagePipeline.estimatedCostPerImage
        return ActionPlan(
            summary: "Generate \(angles.count) image\(angles.count == 1 ? "" : "s") "
                + "for \(args.character) (~$\(String(format: "%.2f", cost)))",
            previews: angles.map { angle in
                ActionPreview(
                    title: "\(args.character) · \(angle.replacingOccurrences(of: "_", with: " "))",
                    oldValue: nil,
                    newValue: "generate (~$\(String(format: "%.2f", CharacterImagePipeline.estimatedCostPerImage)))")
            },
            estimatedCost: cost)
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let (pvm, index, angles) = try plannedAngles(args)
        let characterId = pvm.project.characters[index].id
        let pipeline = CharacterImagePipeline(projectViewModel: pvm,
                                              generate: makeGenerate())
        var generated: [String] = []
        for angle in angles {
            _ = try await pipeline.generateAndStore(characterId: characterId,
                                                    angle: angle)
            generated.append(angle)
        }
        didMutate(.general)
        return ActionOutcome(
            resultForModel: #"{"status": "applied", "generated": \#(generated.count)}"#,
            userSummary: "Generated \(generated.count) image\(generated.count == 1 ? "" : "s") for \(args.character)")
    }
}

// MARK: - Factory extension

extension AssistantActionFactory {
    @MainActor static func generationActions(projectViewModel: ProjectViewModel?,
                                             coordinator: AppCoordinator?) -> [any AssistantAction] {
        [
            GenerateCharacterImagesAction(
                projectViewModel: projectViewModel, coordinator: coordinator,
                makeGenerate: {
                    { prompt, referenceBase64 in
                        let request = ImageGenerationRequest(
                            prompt: prompt,
                            provider: .googleImagen,
                            aspectRatio: "1:1",
                            numberOfImages: 1,
                            referenceImageBase64: referenceBase64,
                            referenceMimeType: referenceBase64 != nil ? "image/png" : nil)
                        let response = try await AIServiceClient.shared.generateImage(request)
                        guard let data = response.images.first else {
                            throw ActionError("the image service returned no image")
                        }
                        return data
                    }
                }),
        ]
    }
}

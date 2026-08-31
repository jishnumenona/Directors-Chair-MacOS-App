//
//  AssistantImageActions.swift
//  DirectorsChair-Desktop
//
//  AI Assistant program, Phase A5.2: image generation from chat for scenes,
//  locations, and the vision board — the remaining image surfaces after
//  A5.1's character pipeline. Same contract: spending-risk proposals with
//  explicit per-image cost previews, approval before any spend (AD5), the
//  exact file/field conventions of the app's own generation paths, and the
//  provider call injected so tests run offline.
//

import Foundation
import DirectorsChairCore
import DirectorsChairServices
import DirectorsChairViews

private let stringProp = JSONValue.object(["type": .string("string")])
private let stringArrayProp = JSONValue.object(
    ["type": .string("array"), "items": .object(["type": .string("string")])])

private func objectSchema(_ properties: [String: JSONValue],
                          required: [String]) -> JSONValue {
    .object(["type": .string("object"),
             "properties": .object(properties),
             "required": .array(required.map(JSONValue.string))])
}

/// (prompt, aspectRatio, referencePNGBase64?) → PNG data.
/// (prompt, aspectRatio, referencePNGBase64?, brief) → PNG data. The brief
/// tells the on-device engine what kind of picture this is; without one a
/// location plate was drawn as a mood-board scene and gained a chef
/// (DC-0071).
typealias AssistantImageGenerate =
    @Sendable (String, String, String?, VisualBrief?) async throws -> Data

private func money(_ count: Int) -> String {
    String(format: "$%.2f",
           Double(count) * CharacterImagePipeline.estimatedCostPerImage)
}

// MARK: - generate_scene_image

final class GenerateSceneImageAction: ProjectAssistantAction, AssistantAction {
    let name = "generate_scene_image"
    let summary = """
    Generate a scene's overview image (16:9 cinematic keyframe) from its \
    script content, or from a custom prompt. SPENDS ~$0.04; runs only \
    after the user approves. Overwrites the scene's existing overview.
    """
    let risk = ActionRisk.spending
    let minimumTier = ProductTier.creator  // §3.7: generation actions are Creator+
    var parameterSchema: JSONValue {
        objectSchema(["scene": stringProp, "custom_prompt": stringProp],
                     required: ["scene"])
    }

    private let makeGenerate: @MainActor () -> AssistantImageGenerate

    init(projectViewModel: ProjectViewModel?, coordinator: AppCoordinator?,
         makeGenerate: @escaping @MainActor () -> AssistantImageGenerate) {
        self.makeGenerate = makeGenerate
        super.init(projectViewModel: projectViewModel, coordinator: coordinator)
    }

    private struct Arguments: Decodable {
        let scene: String
        let customPrompt: String?
        enum CodingKeys: String, CodingKey {
            case scene
            case customPrompt = "custom_prompt"
        }
    }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let pvm = try requireProject()
        let (seq, sc) = try sceneIndices(named: args.scene, in: pvm)
        let existing = pvm.project.sequences[seq].scenes[sc].sceneOverviewImage
        return ActionPlan(
            summary: "Generate the “\(args.scene)” overview image (~\(money(1)))",
            previews: [ActionPreview(
                title: "\(args.scene) · overview image",
                oldValue: existing == nil ? "none" : "existing image",
                newValue: "generate 16:9 (~\(money(1)))")],
            estimatedCost: CharacterImagePipeline.estimatedCostPerImage)
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let pvm = try requireProject()
        let (seq, sc) = try sceneIndices(named: args.scene, in: pvm)
        guard let projectFile = pvm.projectPath else {
            throw ActionError("the project has not been saved yet")
        }
        let scene = pvm.project.sequences[seq].scenes[sc]
        let prompt = args.customPrompt
            ?? SceneCardHelpers.buildSceneOverviewPrompt(scene: scene)
        // The same character reference SceneDetailView sends (DC-0071:
        // the assistant's scene image had no likeness to anchor to).
        let reference = CharacterReferenceHelper.referenceImage(
            forScene: scene, characters: pvm.project.characters,
            projectDirectory: projectFile.deletingLastPathComponent())
        let imageData = try await makeGenerate()(
            prompt, "16:9", reference?.base64,
            VisualBrief(purpose: .scene, subject: StoryboardSubjects.subject(for: scene)))

        // Mirrors SceneDetailView+Generation: assets/scenes/<name>/overview_latest.png
        let sanitized = SceneCardHelpers.sanitizeFilename(scene.name)
        let directory = projectFile.deletingLastPathComponent()
            .appendingPathComponent("assets")
            .appendingPathComponent("scenes")
            .appendingPathComponent(sanitized)
        try FileManager.default.createDirectory(at: directory,
                                                withIntermediateDirectories: true)
        try imageData.write(to: directory.appendingPathComponent("overview_latest.png"))
        try? prompt.write(to: directory.appendingPathComponent("prompt.txt"),
                          atomically: true, encoding: .utf8)

        let relativePath = "assets/scenes/\(sanitized)/overview_latest.png"
        pvm.project.sequences[seq].scenes[sc].sceneOverviewImage = relativePath
        didMutate(.script)
        return ActionOutcome(resultForModel: #"{"status": "applied"}"#,
                             userSummary: "Generated the “\(args.scene)” overview image")
    }
}

// MARK: - generate_location_images

final class GenerateLocationImagesAction: ProjectAssistantAction, AssistantAction {
    let name = "generate_location_images"
    let summary = """
    Generate a location's images: the primary establishing view and/or named \
    variations (e.g. night, rain, golden_hour), each ~$0.04, generated only \
    after the user approves. Variations use the primary image as reference.
    """
    let risk = ActionRisk.spending
    let minimumTier = ProductTier.creator  // §3.7: generation actions are Creator+
    var parameterSchema: JSONValue {
        objectSchema(["location": stringProp, "variations": stringArrayProp],
                     required: ["location"])
    }

    private let makeGenerate: @MainActor () -> AssistantImageGenerate

    init(projectViewModel: ProjectViewModel?, coordinator: AppCoordinator?,
         makeGenerate: @escaping @MainActor () -> AssistantImageGenerate) {
        self.makeGenerate = makeGenerate
        super.init(projectViewModel: projectViewModel, coordinator: coordinator)
    }

    private struct Arguments: Decodable {
        let location: String
        let variations: [String]?
    }

    @MainActor private func check(_ args: Arguments) throws
    -> (ProjectViewModel, Int, [String]) {
        let pvm = try requireProject()
        guard let index = pvm.project.locations.firstIndex(where: {
            $0.name.lowercased() == args.location.lowercased()
        }) else {
            let known = pvm.project.locations.map(\.name).joined(separator: ", ")
            throw ActionError("no location '\(args.location)'"
                + (known.isEmpty ? "" : " (locations: \(known))"))
        }
        var variations = (args.variations ?? ["primary"]).map {
            $0.lowercased().replacingOccurrences(of: " ", with: "_")
        }
        if let bad = variations.first(where: {
            $0.range(of: #"^[a-z0-9_]{1,40}$"#, options: .regularExpression) == nil
        }) {
            throw ActionError("variation names must be short words, got '\(bad)'")
        }
        // Primary anchors the variations — generate it first when included.
        variations.sort { $0 == "primary" && $1 != "primary" }
        return (pvm, index, variations)
    }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let (pvm, index, variations) = try check(args)
        let location = pvm.project.locations[index]
        var warnings: [String] = []
        if !variations.contains("primary") && location.primaryImage == nil {
            warnings.append("“\(location.name)” has no primary image to reference — consider including \"primary\"")
        }
        return ActionPlan(
            summary: "Generate \(variations.count) image\(variations.count == 1 ? "" : "s") "
                + "for \(location.name) (~\(money(variations.count)))",
            previews: variations.map { variation in
                ActionPreview(title: "\(location.name) · \(variation)",
                              oldValue: nil,
                              newValue: "generate (~\(money(1)))")
            },
            warnings: warnings,
            estimatedCost: Double(variations.count) * CharacterImagePipeline.estimatedCostPerImage)
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let (pvm, index, variations) = try check(args)
        guard let projectFile = pvm.projectPath else {
            throw ActionError("the project has not been saved yet")
        }
        let location = pvm.project.locations[index]
        let sanitized = CharacterImagePipeline.sanitizeAssetName(location.name)
        let directory = projectFile.deletingLastPathComponent()
            .appendingPathComponent("assets")
            .appendingPathComponent("locations")
            .appendingPathComponent(sanitized)
        try FileManager.default.createDirectory(at: directory,
                                                withIntermediateDirectories: true)

        func referenceBase64() -> String? {
            guard let primary = pvm.project.locations[index].primaryImage else { return nil }
            let url = projectFile.deletingLastPathComponent()
                .appendingPathComponent(primary)
            return (try? Data(contentsOf: url))?.base64EncodedString()
        }

        var generated = 0
        for variation in variations {
            let prompt: String
            if variation == "primary" {
                prompt = "Cinematic establishing shot of \(location.name). "
                    + location.description
            } else {
                prompt = "The same location as the reference image — "
                    + "\(location.name) — now at/with \(variation.replacingOccurrences(of: "_", with: " ")), "
                    + "identical framing and geography. " + location.description
            }
            let reference = variation == "primary" ? nil : referenceBase64()
            let imageData = try await makeGenerate()(prompt, "16:9", reference,
                                                     Self.brief(for: location, variation: variation))
            try imageData.write(to: directory.appendingPathComponent("\(variation).png"))

            // Mirrors ContentView+CentralStack: primary sets primaryImage;
            // every generated path joins images[] once.
            let relativePath = "assets/locations/\(sanitized)/\(variation).png"
            if variation == "primary" {
                pvm.project.locations[index].primaryImage = relativePath
            }
            if !pvm.project.locations[index].images.contains(relativePath) {
                pvm.project.locations[index].images.append(relativePath)
            }
            generated += 1
        }
        didMutate(.general)
        return ActionOutcome(
            resultForModel: #"{"status": "applied", "generated": \#(generated)}"#,
            userSummary: "Generated \(generated) image\(generated == 1 ? "" : "s") for \(location.name)")
    }
}

// MARK: - generate_vision_board_image

final class GenerateVisionBoardImageAction: ProjectAssistantAction, AssistantAction {
    let name = "generate_vision_board_image"
    let summary = """
    Generate a cinematic mood-board image for the vision board from a text \
    description. SPENDS ~$0.04; runs only after the user approves.
    """
    let risk = ActionRisk.spending
    // §3.4 + §6 (owner decision 2026-08-12): vision-card AI images are
    // FREE — the Free allowance's generation taste. Quota-metered
    // server-side like every spend; the sole Free spending action beside
    // import_screenplay.
    let minimumTier = ProductTier.free
    var parameterSchema: JSONValue {
        objectSchema(["prompt": stringProp], required: ["prompt"])
    }

    private let makeGenerate: @MainActor () -> AssistantImageGenerate

    init(projectViewModel: ProjectViewModel?, coordinator: AppCoordinator?,
         makeGenerate: @escaping @MainActor () -> AssistantImageGenerate) {
        self.makeGenerate = makeGenerate
        super.init(projectViewModel: projectViewModel, coordinator: coordinator)
    }

    private struct Arguments: Decodable { let prompt: String }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        guard !args.prompt.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ActionError("prompt must not be empty")
        }
        _ = try requireProject()
        return ActionPlan(
            summary: "Add a vision-board image (~\(money(1)))",
            previews: [ActionPreview(
                title: "vision board",
                oldValue: nil,
                newValue: String(args.prompt.prefix(120)) + " (~\(money(1)))")],
            estimatedCost: CharacterImagePipeline.estimatedCostPerImage)
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let pvm = try requireProject()
        guard let projectFile = pvm.projectPath else {
            throw ActionError("the project has not been saved yet")
        }
        // Mirrors the A0 vision-board executor: prompt prefix, 16:9.
        let prompt = "Cinematic mood-board reference image: \(args.prompt). "
        let imageData = try await makeGenerate()(prompt, "16:9", nil, nil)

        // Collision-safe write through the Slice-2 store — epoch filenames
        // collide when two generations land in the same second.
        let store = VisionBoardAssetStore(
            projectBase: projectFile.deletingLastPathComponent())
        let staged = try store.stage(
            imageData, fileName: "vision_\(Int(Date().timeIntervalSince1970)).png")
        let relativePath = try store.finalize(staged)
        store.discardStaging()

        // A real card on the master board (Slice 3) — the file used to be
        // orphaned on disk while the board showed nothing. Deterministic
        // grid placement: consecutive generations land on adjacent slots.
        var card = VisionCard(title: String(args.prompt.prefix(60)),
                              imagePath: relativePath)
        let boardCards = pvm.project.beats.filter { $0.boardId == card.boardId }
        let slot = VisionCanvasGeometry.nextFreeGridSlot(
            cardSize: CGSize(width: 200, height: 200),
            existing: boardCards.map {
                CGRect(x: $0.canvasX ?? 0, y: $0.canvasY ?? 0,
                       width: $0.canvasWidth ?? 200, height: $0.canvasHeight ?? 200)
            })
        card.canvasX = slot.x
        card.canvasY = slot.y
        card.canvasWidth = 200
        card.canvasHeight = 200
        card.zOrder = (pvm.project.beats.map(\.zOrder).max() ?? 0) + 1
        pvm.project.beats.append(card)

        pvm.isDirty = true
        didMutate(.general)
        return ActionOutcome(resultForModel: #"{"status": "applied"}"#,
                             userSummary: "Added a vision-board card")
    }
}

// MARK: - Factory extension

extension AssistantActionFactory {
    @MainActor static func imageActions(projectViewModel: ProjectViewModel?,
                                        coordinator: AppCoordinator?) -> [any AssistantAction] {
        let makeGenerate: @MainActor () -> AssistantImageGenerate = {
            { prompt, aspectRatio, referenceBase64, brief in
                let request = ImageGenerationRequest(
                    prompt: prompt,
                    provider: AIProviderSelection.shared.provider(for: .image),
                    aspectRatio: aspectRatio,
                    numberOfImages: 1,
                    referenceImageBase64: referenceBase64,
                    referenceMimeType: referenceBase64 != nil ? "image/png" : nil,
                    brief: brief,
                    // DC-0090: scene and location previews at the project size;
                    // vision-board pictures keep the ratio the user asked for.
                    targetSize: brief.map { [.scene, .location].contains($0.purpose) } == true ? .projectPreview : nil)
                let response = try await AIServiceClient.shared.generateImage(request)
                guard let data = response.images.first else {
                    throw ActionError("the image service returned no image")
                }
                return data
            }
        }
        return [
            GenerateSceneImageAction(projectViewModel: projectViewModel,
                                     coordinator: coordinator, makeGenerate: makeGenerate),
            GenerateLocationImagesAction(projectViewModel: projectViewModel,
                                         coordinator: coordinator, makeGenerate: makeGenerate),
            GenerateVisionBoardImageAction(projectViewModel: projectViewModel,
                                           coordinator: coordinator, makeGenerate: makeGenerate),
        ]
    }
}

extension GenerateLocationImagesAction {
    /// The brief the on-device engine draws from — the place itself, the
    /// variation as a property of the place (DC-0071: drawn without a
    /// purpose, "Cinematic establishing shot of the kitchen" became a chef
    /// at the range in every plate and variation).
    static func brief(for location: Location, variation: String) -> VisualBrief {
        let place = location.description.isEmpty
            ? location.name
            : "\(location.name): \(location.description)"
        let subject = variation == "primary" ? place : "\(place) — \(variationPhrase(variation))"
        return VisualBrief(purpose: .location, subject: subject)
    }

    static func variationPhrase(_ variation: String) -> String {
        switch variation {
        case "day": return "in full daylight"
        case "night": return "at night"
        case "golden_hour": return "at golden hour, low warm sun and long shadows"
        case "overcast": return "under a flat overcast sky"
        case "wide": return "a wide view taking in the whole place"
        case "detail": return "a close view of its most telling detail"
        default: return "at \(variation.replacingOccurrences(of: "_", with: " "))"
        }
    }
}

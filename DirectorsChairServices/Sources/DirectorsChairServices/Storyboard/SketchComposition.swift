// DirectorsChairServices/Storyboard/SketchComposition.swift
//
// DC-0110 — the sketch studio's composer: one structured description of a
// sketch-driven generation, one composition of it into the request.
//
// Every mechanism here was proven on the live model before shipping
// (scratchpad/sketchprobe, 2026-08-31):
//   • "planning sketch — none of its ink may appear" → composition followed,
//     zero pencil lines in the photograph (naive wording pasted them on top);
//   • red numbered tags on the sketch, with TAG NUMBER == ATTACHED IMAGE
//     NUMBER → the character portrait was rendered at the tagged shape with
//     exact likeness;
//   • edit mode reuses the marked-copy + edit-guard wording proven for
//     annotation edits (cloud-edit-markup lesson, 2026-08-29).

import Foundation

/// One story element the sketch references: what it is, what it's called,
/// and the picture that defines it.
public struct SketchElement: Equatable, Sendable {
    /// "character" | "costume" | "prop" | "location" | "shot".
    public var kind: String
    public var name: String
    public var imageData: Data

    public init(kind: String, name: String, imageData: Data) {
        self.kind = kind
        self.name = name
        self.imageData = imageData
    }
}

/// An element mapped to a drawn shape: where its tag sits on the sketch.
public struct SketchPlacement: Equatable, Sendable {
    public var element: SketchElement
    /// Normalised tag centre (0…1, top-left origin) — informational; the
    /// model reads the BADGE on the tagged sketch, never these numbers.
    public var x: Double
    public var y: Double

    public init(element: SketchElement, x: Double, y: Double) {
        self.element = element
        self.x = x
        self.y = y
    }
}

/// Everything one studio generation is made of.
public struct SketchStudioInput: Equatable, Sendable {
    public enum Mode: Equatable, Sendable {
        /// A fresh frame from the sketch alone.
        case create
        /// A change to an existing picture: the sketch is drawn over it.
        case edit
    }
    public var mode: Mode
    /// The user's own words for the shot (seeded from the shot's style/
    /// framing/camera/description — never the scene bundle).
    public var sceneText: String
    /// The sketch as the model sees it: strokes (over the base in edit
    /// mode) with the numbered badges baked in.
    public var taggedSketchPNG: Data
    /// Edit mode: the clean picture being edited.
    public var basePNG: Data?
    /// Tagged elements, in badge-number order.
    public var placements: [SketchPlacement]
    /// Untagged references ("this exists in the shot/world, match it").
    public var generalReferences: [SketchElement]
    public var aspectRatio: String
    public var targetSize: ImageTargetSize?

    public init(mode: Mode, sceneText: String, taggedSketchPNG: Data,
                basePNG: Data? = nil, placements: [SketchPlacement] = [],
                generalReferences: [SketchElement] = [],
                aspectRatio: String = "16:9", targetSize: ImageTargetSize? = nil) {
        self.mode = mode
        self.sceneText = sceneText
        self.taggedSketchPNG = taggedSketchPNG
        self.basePNG = basePNG
        self.placements = placements
        self.generalReferences = generalReferences
        self.aspectRatio = aspectRatio
        self.targetSize = targetSize
    }
}

public enum SketchStudioComposer {

    /// The badge number of the first placement — equal to the attached-image
    /// number of its element picture, which is what makes the mapping work.
    public static func firstTagNumber(for mode: SketchStudioInput.Mode) -> Int {
        mode == .create ? 2 : 3     // create: [sketch, elements…]; edit: [base, marked sketch, elements…]
    }

    // MARK: Wording

    /// What a TAGGED element asks for, by kind — likeness language proven
    /// per kind on the live model.
    static func placedClause(_ element: SketchElement, tag: Int) -> String {
        switch element.kind {
        case "character":
            return "- The figure at tag \(tag) is the character \(element.name): render the person from Image \(tag) there — same face, hair and skin — at the size and position the shape suggests."
        case "costume":
            return "- At tag \(tag): the figure there wears the costume \"\(element.name)\" — match the garments, colors and style of Image \(tag) exactly."
        case "prop":
            return "- The shape at tag \(tag) is the prop \"\(element.name)\": render the object from Image \(tag) there — same design, shape, colors and materials."
        case "location":
            return "- Tag \(tag) marks where the place in Image \(tag) (\(element.name)) is seen: render those exact surroundings there."
        case "shot":
            return "- Tag \(tag) points at what Image \(tag) — the finished frame \(element.name) — shows at that spot: keep it consistent with that frame."
        default:
            return "- The shape at tag \(tag) stands for \(element.name): render what Image \(tag) shows there, faithfully."
        }
    }

    /// What an UNTAGGED reference asks for.
    static func generalClause(_ element: SketchElement, image: Int) -> String {
        switch element.kind {
        case "location":
            return "- Image \(image) is the LOCATION (\(element.name)): the whole shot takes place in this exact environment — match its layout, architecture, light and atmosphere."
        case "character":
            return "- Image \(image) is the character \(element.name): wherever they appear, match their face, hair and skin exactly."
        case "costume":
            return "- Image \(image) is the costume \"\(element.name)\": whoever wears it, match the garments exactly."
        case "prop":
            return "- Image \(image) is the prop \"\(element.name)\": wherever it appears, match its design exactly."
        case "shot":
            return "- Image \(image) is the finished preview of \(element.name) from the same scene: keep continuity with it — the same place, light, cast and wardrobe — without copying its framing."
        default:
            return "- Image \(image) is a reference (\(element.name)): match it faithfully."
        }
    }

    /// The full prompt, exactly as sent.
    public static func prompt(for input: SketchStudioInput) -> String {
        var lines: [String] = []
        let scene = input.sceneText.trimmingCharacters(in: .whitespacesAndNewlines)
        var image = firstTagNumber(for: input.mode)
        switch input.mode {
        case .create:
            if !scene.isEmpty { lines.append(scene); lines.append("") }
            lines.append("Image 1 is a rough hand-drawn PLANNING sketch of this shot's composition — only a map: each crude shape stands for a real thing, and the red numbered tags say what each shape is. A tag's number is the number of the attached image that shows the real thing.")
        case .edit:
            lines.append("Edit the FIRST attached picture. Image 2 is the same picture with rough hand-drawn pencil marks and red numbered tags showing what to change or add and where — the marks are only a plan: none of the pencil ink or tags may appear in the result.")
            lines.append("Make exactly these changes and nothing else:")
            if !scene.isEmpty { lines.append("- \(scene)") }
        }
        for placement in input.placements {
            lines.append(placedClause(placement.element, tag: image))
            image += 1
        }
        for reference in input.generalReferences {
            lines.append(generalClause(reference, image: image))
            image += 1
        }
        switch input.mode {
        case .create:
            lines.append("Place each real subject where its tagged shape sits and match the sketched framing. Do NOT copy, trace or overlay the sketch's ink or the red tags — none of them may appear in the photograph.")
            lines.append("Render one photorealistic cinematic frame.")
        case .edit:
            lines.append("Everything else — the people, place, composition, framing, lighting and film look — must stay exactly as in the first picture. Return the edited first picture with the same framing, without any pencil marks or tags.")
        }
        return lines.joined(separator: "\n")
    }

    /// The ordered picture list — order IS the numbering the prompt uses.
    public static func referenceImages(for input: SketchStudioInput) -> [ReferenceImage] {
        var refs: [ReferenceImage] = []
        func add(_ data: Data, label: String) {
            refs.append(ReferenceImage(base64: data.base64EncodedString(),
                                       mimeType: "image/png", label: label))
        }
        switch input.mode {
        case .create:
            add(input.taggedSketchPNG, label: "sketch:plan")
        case .edit:
            if let base = input.basePNG { add(base, label: "base:picture to edit") }
            add(input.taggedSketchPNG, label: "sketch:marked plan")
        }
        for placement in input.placements {
            add(placement.element.imageData, label: "\(placement.element.kind):\(placement.element.name)")
        }
        for reference in input.generalReferences {
            add(reference.imageData, label: "\(reference.kind):\(reference.name)")
        }
        return refs
    }

    /// The request, ready for AIServiceClient.generateImage. The prompt is
    /// complete in itself — the client must NOT prepend its own reference
    /// preamble (referenceImages labels here are for the review sheet and
    /// logs, not for prefixing).
    public static func request(for input: SketchStudioInput) -> ImageGenerationRequest {
        ImageGenerationRequest(
            prompt: prompt(for: input),
            provider: AIProviderSelection.shared.provider(for: .image),
            aspectRatio: input.aspectRatio,
            numberOfImages: 1,
            referenceImages: referenceImages(for: input),
            brief: VisualBrief(purpose: input.mode == .edit ? .edit : .shot,
                               subject: input.sceneText.isEmpty
                                   ? "the sketched composition" : input.sceneText),
            isEdit: input.mode == .edit,
            targetSize: input.targetSize)
    }
}

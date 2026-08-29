import Foundation
import DirectorsChairCore

// DC-0073 — one description of an annotation edit for every surface.
//
// Before this, seven surfaces (scene, shot, keyframe, character angle,
// costume angle, location variation, vision board) each assembled their
// own request in one of two prompt wordings, decided for themselves which
// picture rode as the reference, and sometimes forgot the pins. The
// on-device engine recognised an edit by sniffing the prompt's first
// words. This file is the single path: the editor produces an
// `AnnotationEdit`, the composer turns it into the one request shape,
// and `AIServiceClient.editImage` runs it.

/// One pin: where on the picture, what to change there, and (optionally)
/// how far the change may reach — a fraction of the picture's shorter
/// side; nil means the engine's default reach.
public struct AnnotationPin: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var text: String
    public var number: Int
    public var radius: Double?

    /// The pin is an instruction for the whole picture (radius ≥ 1).
    public var coversWholePicture: Bool { (radius ?? 0) >= KeyframeAnnotation.wholePictureRadius }

    public init(x: Double, y: Double, text: String, number: Int, radius: Double? = nil) {
        self.x = x
        self.y = y
        self.text = text
        self.number = number
        self.radius = radius
    }

    public init(_ annotation: KeyframeAnnotation) {
        self.init(x: annotation.normalizedX, y: annotation.normalizedY,
                  text: annotation.text, number: annotation.number, radius: annotation.radius)
    }
}

/// An annotation edit as a surface describes it: the picture being edited,
/// the pins, what kind of picture it is (in the user's words), the prompt
/// the picture was made from (cloud context), and any pictures that should
/// ride along behind the source for likeness (a shot's scene set).
public struct AnnotationEdit: Equatable, Sendable {
    /// PNG bytes of the picture being edited — always the first picture
    /// the engine sees.
    public var source: Data
    public var pins: [AnnotationPin]
    /// "scene preview", "shot preview", "keyframe", "character image" … —
    /// read aloud in the instructions ("Edit this shot preview …").
    public var context: String
    /// The prompt the picture was generated from, appended for the cloud
    /// model's benefit; the on-device engine never sees it.
    public var originalPrompt: String?
    /// Pictures that ride behind the source for the cloud model (likeness
    /// context). The on-device repaint sends the source alone.
    public var contextPictures: [ReferenceImage]
    /// The surface's own aspect ratio, as it always sent it.
    public var aspectRatio: String
    /// DC-0090: the size the edited picture is delivered at (nil = as drawn).
    public var targetSize: ImageTargetSize?
    /// The label the source carries when pictures travel as a labelled
    /// set (the wording the shot surface always used).
    public var sourceLabel: String

    public init(source: Data, pins: [AnnotationPin], context: String,
                originalPrompt: String? = nil, contextPictures: [ReferenceImage] = [],
                aspectRatio: String = "16:9", sourceLabel: String? = nil,
                targetSize: ImageTargetSize? = nil) {
        self.source = source
        self.targetSize = targetSize
        self.pins = pins
        self.context = context
        self.originalPrompt = originalPrompt
        self.contextPictures = contextPictures
        self.aspectRatio = aspectRatio
        self.sourceLabel = sourceLabel ?? "Current \(context) to edit"
    }

    public init(source: Data, annotations: [KeyframeAnnotation], context: String,
                originalPrompt: String? = nil, contextPictures: [ReferenceImage] = [],
                aspectRatio: String = "16:9", sourceLabel: String? = nil,
                targetSize: ImageTargetSize? = nil) {
        self.init(source: source, pins: annotations.map(AnnotationPin.init), context: context,
                  originalPrompt: originalPrompt, contextPictures: contextPictures,
                  aspectRatio: aspectRatio, sourceLabel: sourceLabel, targetSize: targetSize)
    }
}

/// The one composition of an annotation edit into a request.
public enum AnnotationEditComposer {
    /// The instruction text — the wording the cloud request was proven
    /// with (byte-identical to the pin editor's former builder): numbered
    /// changes with their positions, then the keep-everything rule.
    public static func instructions(pins: [AnnotationPin], context: String) -> String {
        guard !pins.isEmpty else { return "" }
        let whole = pins.filter(\.coversWholePicture)
        let spots = pins.filter { !$0.coversWholePicture }
        var prompt = ""
        if !whole.isEmpty {
            // Owner 2026-08-29: re-imagine the whole picture from one instruction.
            prompt += "Edit this \(context) as a whole: " + whole.map(\.text).joined(separator: "; ") + ".\n"
            prompt += "Re-imagine the entire picture to match; keep its subject, place and framing unless the instruction says otherwise.\n"
        }
        if !spots.isEmpty {
            prompt += whole.isEmpty ? "Edit this \(context) with the following changes:\n" : "Also, at these spots:\n"
            for pin in spots.sorted(by: { $0.number < $1.number }) {
                let region = "(\(Int(pin.x * 100))%, \(Int(pin.y * 100))%)"
                prompt += "\(pin.number). At \(region): \(pin.text)\n"
            }
            prompt += "Keep all other areas unchanged."
        }
        return prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The full cloud prompt: the changes, then the edit guard. The original
    /// generation prompt is NEVER appended any more — with it the model
    /// re-generated the whole picture instead of editing it (owner report
    /// 2026-08-29: one character's face asked for, a new picture returned).
    public static func prompt(for edit: AnnotationEdit) -> String {
        let instructions = instructions(pins: edit.pins, context: edit.context)
        guard !instructions.isEmpty else { return "" }
        return instructions + "\n\n" + editGuard(for: edit)
    }

    /// What an edit is allowed to touch, and what each attached reference
    /// picture is for. Pure — pinned by tests.
    public static func editGuard(for edit: AnnotationEdit) -> String {
        let wholeOnly = !edit.pins.isEmpty && edit.pins.allSatisfy(\.coversWholePicture)
        var lines: [String] = [wholeOnly
            ? "This is an edit of the attached picture: re-imagine it as instructed, keeping its subject, place and framing unless the instruction says otherwise."
            : "This is an edit of the attached picture. Change only what is listed above and keep everything else — the people, place, composition, framing, lighting and style — exactly as in the picture."]
        for reference in edit.contextPictures {
            let parts = reference.label.split(separator: ":", maxSplits: 1).map(String.init)
            let name = parts.count > 1 ? parts[1] : reference.label
            lines.append("The reference labelled \"\(reference.label)\" shows \(name); use it only for the change that mentions it.")
        }
        return lines.joined(separator: "\n")
    }

    /// The pins as the regions the on-device engine repaints.
    /// The pins as the regions the on-device engine repaints. A whole-picture
    /// pin has no region: the engine then edits the entire picture by
    /// instruction instead of inpainting a spot.
    public static func regions(for edit: AnnotationEdit) -> [EditRegion] {
        edit.pins.filter { !$0.coversWholePicture }.map { pin in
            pin.radius.map { EditRegion(x: pin.x, y: pin.y, radius: $0) } ?? EditRegion(x: pin.x, y: pin.y)
        }
    }

    /// The request for a provider. Cloud: the source (plus any context
    /// pictures) and the full prompt — a single picture travels as the
    /// single reference field, a set as the labelled list, exactly as the
    /// surfaces sent them. On-device: the source alone, the `.edit` brief
    /// with just the numbered changes, and the regions.
    public static func request(for edit: AnnotationEdit, provider: AIProvider) -> ImageGenerationRequest {
        let prompt = prompt(for: edit)
        let instructions = instructions(pins: edit.pins, context: edit.context)
        let brief = VisualBrief(purpose: .edit, subject: StoryboardSubjects.editInstruction(from: instructions))
        let sendsSet = provider != .onDevice && !edit.contextPictures.isEmpty
        let sourceBase64 = edit.source.base64EncodedString()
        return ImageGenerationRequest(
            prompt: prompt,
            provider: provider,
            aspectRatio: edit.aspectRatio,
            numberOfImages: 1,
            referenceImageBase64: sendsSet ? nil : sourceBase64,
            referenceMimeType: sendsSet ? nil : "image/png",
            referenceImages: sendsSet
                ? [ReferenceImage(base64: sourceBase64, mimeType: "image/png", label: edit.sourceLabel)] + edit.contextPictures
                : nil,
            brief: brief,
            editRegions: regions(for: edit),
            isEdit: true)
    }
}

/// What an edit was made from, kept beside the result so it can be shown,
/// replayed on the other provider, or undone as an edit later.
public struct AnnotationEditRecord: Codable, Equatable, Sendable {
    public struct Pin: Codable, Equatable, Sendable {
        public var x: Double, y: Double, text: String, number: Int, radius: Double?
    }
    public var context: String
    public var provider: String
    public var prompt: String
    public var pins: [Pin]
    public var date: Date

    public init(edit: AnnotationEdit, provider: AIProvider, date: Date = Date()) {
        context = edit.context
        self.provider = provider.rawValue
        prompt = AnnotationEditComposer.prompt(for: edit)
        pins = edit.pins.map { Pin(x: $0.x, y: $0.y, text: $0.text, number: $0.number, radius: $0.radius) }
        self.date = date
    }

    /// The sidecar path for a result file: `preview_2026.png` → `preview_2026.edit.json`.
    public static func sidecarURL(for result: URL) -> URL {
        result.deletingPathExtension().appendingPathExtension("edit.json")
    }

    /// Writes the record beside the result; a failure to write provenance
    /// never fails the edit.
    @discardableResult
    public func write(besides result: URL) -> Bool {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(self) else { return false }
        return (try? data.write(to: Self.sidecarURL(for: result))) != nil
    }
}

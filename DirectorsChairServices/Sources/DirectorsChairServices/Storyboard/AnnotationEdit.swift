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

    /// The cloud prompt as it is actually sent: the changes located by the
    /// numbered circles on the marked copy (positions in words when the
    /// picture can't be marked), then the edit guard. The original generation
    /// prompt is NEVER appended — with it the model re-generated the whole
    /// picture instead of editing it (owner report 2026-08-29).
    public static func prompt(for edit: AnnotationEdit) -> String {
        cloudPayload(for: edit).prompt
    }

    /// The wording alone; `located` = the picture carries the numbered circles.
    public static func prompt(for edit: AnnotationEdit, located: Bool) -> String {
        guard !edit.pins.isEmpty else { return "" }
        return [cloudInstructions(for: edit, located: located), editGuard(for: edit, located: located)]
            .filter { !$0.isEmpty }.joined(separator: "\n")
    }

    /// What a cloud edit sends: the marked copy and the prompt that reads its
    /// circles — or, when the picture can't be marked (no spot pins, undecodable
    /// bytes), the clean picture and positions in words. Proven on the live
    /// model 2026-08-29: percentages were ignored or hit the wrong person; a
    /// numbered circle put the change on the right one.
    public static func cloudPayload(for edit: AnnotationEdit) -> (prompt: String, source: Data) {
        if let marked = AnnotationMarkup.marked(source: edit.source, pins: edit.pins) {
            return (prompt(for: edit, located: true), marked)
        }
        return (prompt(for: edit, located: false), edit.source)
    }

    /// Each attached reference picture by its position AFTER the picture being
    /// edited — the model sees pictures in order, never our labels.
    public static func attachedPictureNumbers(for edit: AnnotationEdit) -> [(name: String, kind: String, number: Int)] {
        edit.contextPictures.enumerated().map { index, reference in
            let parts = reference.label.split(separator: ":", maxSplits: 1).map(String.init)
            let kind = parts.count > 1 ? parts[0] : "reference"
            let name = parts.count > 1 ? parts[1] : reference.label
            return (name: name, kind: kind, number: index + 2)
        }
    }

    private static let ordinalWords = [2: "SECOND", 3: "THIRD", 4: "FOURTH", 5: "FIFTH", 6: "SIXTH",
                                       7: "SEVENTH", 8: "EIGHTH", 9: "NINTH", 10: "TENTH"]

    /// "the SECOND attached picture" / "attached picture 11".
    static func pictureReference(_ number: Int) -> String {
        ordinalWords[number].map { "the \($0) attached picture" } ?? "attached picture \(number)"
    }

    /// How a reference of each kind is named, and what of it must carry
    /// over — "same face, hair and skin" is what made the live model apply a
    /// likeness (2 of 2 probes) where the bare name did not.
    private static func subjectPhrase(forKind kind: String) -> (noun: String, keep: String)? {
        switch kind {
        case "character": return ("the person in", " — same face, hair and skin as in that picture")
        case "location": return ("the place in", "")
        case "prop": return ("the object in", "")
        case "costume": return ("the outfit in", " — same garments and colours as in that picture")
        default: return nil
        }
    }

    /// A pin's text with "@Alex" / "#Desert road" / "$Lantern" / "&Shot #3"
    /// turned into "the person in the SECOND attached picture (Alex — same
    /// face, hair and skin as in that picture)" when that picture is attached
    /// (the phrasing the live model acted on), else the bare name.
    public static func rewriteMentions(_ text: String, for edit: AnnotationEdit) -> String {
        var out = text
        let numbered = attachedPictureNumbers(for: edit).sorted { $0.name.count > $1.name.count }
        for entry in numbered {
            for trigger in ["@", "#", "$", "&"] {
                let token = trigger + entry.name
                guard out.range(of: token, options: .caseInsensitive) != nil else { continue }
                let picture = pictureReference(entry.number)
                let replacement = subjectPhrase(forKind: entry.kind).map { "\($0.noun) \(picture) (\(entry.name)\($0.keep))" }
                    ?? "\(picture) (\(entry.name))"
                out = out.replacingOccurrences(of: token, with: replacement, options: .caseInsensitive)
            }
        }
        // A mention without an attached picture keeps its name, minus the symbol.
        out = out.replacingOccurrences(of: "(^|[\\s(])[@#$&](?=[A-Za-z])", with: "$1", options: .regularExpression)
        return out.trimmingCharacters(in: .whitespaces)
    }

    /// The cloud wording. Located: each spot is a numbered circle drawn on the
    /// FIRST attached picture; otherwise a position in plain words.
    static func cloudInstructions(for edit: AnnotationEdit, located: Bool) -> String {
        let whole = edit.pins.filter(\.coversWholePicture)
        let spots = edit.pins.filter { !$0.coversWholePicture }.sorted { $0.number < $1.number }
        var lines: [String] = []
        if !whole.isEmpty {
            let asked = whole.map { rewriteMentions($0.text, for: edit) }.joined(separator: "; ")
            lines.append("Edit the FIRST attached picture. Re-imagine it as follows: \(asked).")
            lines.append("Keep its subject, place and framing unless the instruction says otherwise.")
        }
        guard !spots.isEmpty else { return lines.joined(separator: "\n") }
        if located {
            let numbers = spots.map { String($0.number) }
            let marks = spots.count == 1
                ? "A red circle numbered \(numbers[0]) has been drawn on it to mark where the change goes"
                : "Red circles numbered \(numbers.joined(separator: ", ")) have been drawn on it to mark where each change goes"
            lines.append((whole.isEmpty ? "Edit the FIRST attached picture. " : "") + marks
                         + "; the output must not contain the circles or the numbers.")
            lines.append(whole.isEmpty ? "Make exactly these changes and nothing else:" : "Also make exactly these changes at the marked spots:")
            for pin in spots {
                lines.append("\(pin.number). Inside circle \(pin.number): \(rewriteMentions(pin.text, for: edit))")
            }
        } else {
            lines.append(whole.isEmpty
                ? "Edit the FIRST attached picture. Make exactly these changes and nothing else:"
                : "Also make exactly these changes at these spots:")
            for pin in spots {
                lines.append("\(pin.number). At about \(Int(pin.x * 100))% across and \(Int(pin.y * 100))% down from the top-left corner: \(rewriteMentions(pin.text, for: edit))")
            }
        }
        return lines.joined(separator: "\n")
    }

    /// What an edit is allowed to touch, and what each attached reference
    /// picture is for. Pure — pinned by tests.
    public static func editGuard(for edit: AnnotationEdit, located: Bool = false) -> String {
        let wholeOnly = !edit.pins.isEmpty && edit.pins.allSatisfy(\.coversWholePicture)
        var lines: [String] = []
        if !wholeOnly {
            lines.append("Everything else — the other people, the place, the composition and framing, the lighting and the film look — must stay exactly as in the picture. Return the edited picture with the same framing"
                         + (located ? ", without the markers." : "."))
        }
        for entry in attachedPictureNumbers(for: edit) {
            let picture = pictureReference(entry.number)
            lines.append("\(picture.prefix(1).uppercased() + picture.dropFirst()) shows \(entry.name) (\(entry.kind)); use it only for the change that names it.")
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
        let cloud = provider != .onDevice
        // Cloud: the marked copy and the wording that reads its circles.
        // On-device: the clean picture — the repaint inpaints inside the regions.
        let payload = cloud ? cloudPayload(for: edit) : (prompt: prompt(for: edit, located: false), source: edit.source)
        let prompt = payload.prompt
        let instructions = instructions(pins: edit.pins, context: edit.context)
        let brief = VisualBrief(purpose: .edit, subject: StoryboardSubjects.editInstruction(from: instructions))
        let sendsSet = cloud && !edit.contextPictures.isEmpty
        let sourceBase64 = payload.source.base64EncodedString()
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
        prompt = provider == .onDevice
            ? AnnotationEditComposer.prompt(for: edit, located: false)
            : AnnotationEditComposer.prompt(for: edit)
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

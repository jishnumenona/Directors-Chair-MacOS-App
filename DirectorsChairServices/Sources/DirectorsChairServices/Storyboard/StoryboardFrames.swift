// DirectorsChairServices/Storyboard/StoryboardFrames.swift
//
// The pure halves of the scene/shot storyboard surfaces (DC-0064):
// subject text built from the models, and frame persistence following
// the project's existing asset conventions (relative path stored on the
// entity; timestamped file plus a stable *_latest.png). Callers own the
// asset DIRECTORY (their sanitizers already name scene/shot folders);
// this owns only file naming and IO — one writer, testable in SPM.

import CoreGraphics
import Foundation
import ImageIO
import DirectorsChairCore

// MARK: - Subjects

/// Turns project entities into the plain drawing language the styler
/// wraps. Pure and deterministic: same entities, same subject —
/// regeneration is a seed change, not a prompt lottery. Every builder
/// speaks about WHAT is in the picture; medium, lens and quality words
/// belong to the styler (DC-0066 lesson: they were drawn literally).
public enum StoryboardSubjects {

    /// The shot's own description leads; the scene supplies setting and
    /// mood facts the description usually omits (slug-line style); the
    /// project's location record and the characters present add the
    /// detail that makes a frame recognisably THIS film.
    public static func subject(for shot: Shot, in scene: Scene?,
                               locations: [Location] = [],
                               characters: [Character] = []) -> String {
        var parts: [String] = []
        let description = plainSubject(from: shot.description)
        if !description.isEmpty { parts.append(description) }
        if let scene {
            var setting: [String] = []
            let name = scene.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty { setting.append(name) }
            if let location = scene.location, !location.isEmpty { setting.append(humanizeSlugLines(location)) }
            if let timeOfDay = scene.timeOfDay, !timeOfDay.isEmpty { setting.append(timeOfDay) }
            if let weather = scene.weather, !weather.isEmpty { setting.append(weather) }
            if !setting.isEmpty { parts.append("Setting: \(setting.joined(separator: ", "))") }
            if parts.count == 1 && description.isEmpty {
                // A shot with no description still deserves a drawable subject.
                let summary = plainSubject(from: scene.sceneOverviewSummary ?? scene.description)
                if !summary.isEmpty { parts.append(summary) }
            }
            if let locationName = scene.location,
               let record = locations.first(where: { $0.name.lowercased() == locationName.lowercased() }),
               !record.description.isEmpty {
                parts.append("The place: \(plainSubject(from: String(record.description.prefix(200))))")
            }
            // The shot's own cast: the people its description names. Only
            // when it names nobody ("three figures in single file") does the
            // scene's cast stand in (DC-0071: an insert of one hand listed
            // all three characters as "in the frame" and drew them all).
            let cast = self.cast(for: shot, in: scene, characters: characters)
            if !cast.isEmpty {
                let described = cast.map { describe($0, in: scene) }
                // A counted cast line ("One person in the frame") steers the
                // drawing better than a list alone (DC-0072).
                parts.append(castLead(count: cast.count) + described.joined(separator: "; "))
            }
        }
        if parts.isEmpty { parts.append("Untitled shot") }
        return sentences(parts)
    }

    /// The people a shot puts in the frame: the project characters its
    /// description names — anyone, not only those who speak in the scene
    /// (DC-0072: "Teo at the cottage wall" listed Noor and Idris, the
    /// scene's speakers, because Teo has no line in that scene). A shot
    /// that names nobody shows the scene's cast. At most three.
    public static func cast(for shot: Shot, in scene: Scene, characters: [Character]) -> [Character] {
        // The director's explicit cast first, in the order they were added
        // (usability batch 2026-08-28: "Add" in the shot's Characters section).
        let explicit = shot.characters.compactMap { name in
            characters.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
        }
        let description = plainSubject(from: shot.description)
        let named = characters.filter { candidate in
            mentions(description, name: candidate.name)
                && !explicit.contains { $0.name.caseInsensitiveCompare(candidate.name) == .orderedSame }
        }
        var chosen = explicit + named
        if chosen.isEmpty { chosen = charactersPresent(in: scene, from: characters) }
        return Array(chosen.prefix(3))
    }

    /// The cast line's opening for a given head count.
    public static func castLead(count: Int) -> String {
        switch count {
        case 1: return "One person in the frame: "
        case 2: return "Two people in the frame: "
        case 3: return "Three people in the frame: "
        default: return "People in the frame: "
        }
    }

    /// Matches any cast-line opening the subject builders write.
    public static let castLinePattern = #"(?:One person|Two people|Three people|People) in the frame:"#

    /// The part of a subject before its cast line — the description proper.
    public static func description(before subject: String) -> String {
        guard let range = subject.range(of: castLinePattern, options: .regularExpression) else { return subject }
        return String(subject[..<range.lowerBound])
    }

    /// Whether `text` names a character — the full name or its first word,
    /// whole-word and case-insensitive ("Teo" is not in "meteor").
    public static func mentions(_ text: String, name: String) -> Bool {
        let haystack = text.lowercased()
        let full = name.trimmingCharacters(in: .whitespaces).lowercased()
        let candidates = [full] + (full.split(separator: " ").first.map { [String($0)] } ?? [])
        for candidate in candidates where candidate.count > 1 {
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: candidate) + "\\b"
            if haystack.range(of: pattern, options: .regularExpression) != nil { return true }
        }
        return false
    }

    /// Whether the text names a PROP (DC-0079): its full name, or the head
    /// noun of a multi-word name ("Storm Lantern" is "the brass storm
    /// lantern" in a shot line), singular or plural, whole-word and
    /// case-insensitive. Unlike `mentions`, the first word never counts —
    /// "The Letter" must not match every "the".
    public static func mentionsProp(_ text: String, name: String) -> Bool {
        let haystack = text.lowercased()
        let full = name.trimmingCharacters(in: .whitespaces).lowercased()
        guard full.count > 1 else { return false }
        var candidates = [full]
        let words = full.split(separator: " ").map(String.init)
        if words.count > 1, let head = words.last, head.count >= 4 { candidates.append(head) }
        for candidate in candidates {
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: candidate) + "s?\\b"
            if haystack.range(of: pattern, options: .regularExpression) != nil { return true }
        }
        return false
    }

    /// Camera facts as drawing direction, in words the model reads as
    /// viewpoint rather than as objects: no "camera", no "lens" (both get
    /// drawn as things — a shot once rendered an actual camera).
    public static func notes(for shot: Shot) -> String? {
        var terms: [String] = []
        let type = shot.shotType.trimmingCharacters(in: .whitespacesAndNewlines)
        if !type.isEmpty {
            terms.append(type.lowercased().hasSuffix("shot") ? type.lowercased() : "\(type.lowercased()) shot")
        }
        let angle = shot.cameraAngle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !angle.isEmpty && angle.lowercased() != "eye level" {
            terms.append("from a \(angle.lowercased()) angle")
        } else if !angle.isEmpty {
            terms.append("at eye level")
        }
        if let lens = shot.lensMm {
            if lens <= 24 { terms.append("wide-angle perspective with deep space") }
            else if lens >= 85 { terms.append("compressed telephoto perspective") }
        }
        if shot.movement != "Static" && !shot.movement.isEmpty {
            terms.append("a sense of \(shot.movement.lowercased()) movement")
        }
        return terms.isEmpty ? nil : terms.joined(separator: ", ")
    }

    /// A scene frame is its establishing image: name, slug-line facts,
    /// then the best prose the project has for it.
    public static func subject(for scene: Scene) -> String {
        var parts: [String] = []
        let name = scene.name.trimmingCharacters(in: .whitespacesAndNewlines)
        var setting: [String] = []
        if let location = scene.location, !location.isEmpty { setting.append(humanizeSlugLines(location)) }
        if let timeOfDay = scene.timeOfDay, !timeOfDay.isEmpty { setting.append(timeOfDay) }
        if let weather = scene.weather, !weather.isEmpty { setting.append(weather) }
        let head = [name, setting.joined(separator: ", ")].filter { !$0.isEmpty }
        if !head.isEmpty { parts.append(head.joined(separator: " — ")) }
        let prose = plainSubject(from: scene.sceneOverviewSummary ?? scene.description)
        if !prose.isEmpty { parts.append(prose) }
        if parts.isEmpty { parts.append("Untitled scene") }
        return sentences(parts)
    }

    /// A character as a design study: who they are, physically and in
    /// what they wear, stated plainly (age or "adult" up front — the
    /// model draws unspecified people as generic mannequins).
    public static func subject(for character: Character) -> String {
        var parts = [describe(character, in: nil)]
        let about = plainSubject(from: String(character.about.prefix(240)))
        if !about.isEmpty { parts.append(about) }
        return sentences(parts)
    }

    /// A costume as a design sheet: the wearer in two strokes, then every
    /// garment, era, palette and fabric the costume record holds.
    public static func subject(for costume: CharacterCostume, wornBy character: Character) -> String {
        var wearer: [String] = []
        wearer.append(ageWord(character))
        if !character.gender.isEmpty && character.gender.lowercased() != "neutral" {
            wearer.append(character.gender.lowercased())
        }
        if !character.build.isEmpty && character.build != "Average" {
            wearer.append("\(character.build.lowercased()) build")
        }
        var parts = ["\(character.name), \(wearer.joined(separator: " "))"]
        var outfit = "wearing \(costume.name)"
        var garments: [String] = []
        if let top = costume.garmentTop, !top.isEmpty { garments.append(top) }
        if let bottom = costume.garmentBottom, !bottom.isEmpty { garments.append(bottom) }
        if let outer = costume.outerwear, !outer.isEmpty { garments.append(outer) }
        if let head = costume.headwear, !head.isEmpty { garments.append(head) }
        if let foot = costume.footwear, !foot.isEmpty { garments.append(foot) }
        if !garments.isEmpty { outfit += " — \(garments.joined(separator: ", "))" }
        parts.append(outfit)
        let description = plainSubject(from: costume.description)
        if !description.isEmpty { parts.append(description) }
        var facts: [String] = []
        if let era = costume.era, !era.isEmpty { facts.append("\(era) period") }
        if let style = costume.styleCategory, !style.isEmpty { facts.append("\(style) style") }
        if let palette = costume.colorPalette, !palette.isEmpty {
            facts.append("colours \(palette.joined(separator: ", "))")
        }
        if let fabric = costume.primaryFabric, !fabric.isEmpty { facts.append("\(fabric) fabric") }
        if !facts.isEmpty { parts.append(facts.joined(separator: ", ")) }
        return sentences(parts)
    }

    /// One character in a sentence — the shared description used inside
    /// shot subjects and as the head of a character study.
    public static func describe(_ character: Character, in scene: Scene?) -> String {
        var traits: [String] = []
        traits.append(ageWord(character))
        if !character.gender.isEmpty && character.gender.lowercased() != "neutral" {
            traits.append(character.gender.lowercased())
        }
        var line = "\(character.name): \(traits.joined(separator: " "))"
        var details: [String] = []
        if !character.build.isEmpty && character.build != "Average" {
            details.append("\(character.build.lowercased()) build")
        }
        // Hair only when the record names a colour (the default is a hex
        // swatch); the default style "Medium, Straight" already carries
        // the length, so the length is only added when the style omits it.
        if !character.hairColor.isEmpty && !character.hairColor.hasPrefix("#") {
            var hair = [character.hairColor.lowercased()]
            let style = character.hairStyle.lowercased().replacingOccurrences(of: ",", with: "")
            let length = character.hairLength.lowercased()
            if !length.isEmpty && !style.contains(length) { hair.append(length) }
            if !style.isEmpty { hair.append(style) }
            details.append("\(hair.joined(separator: " ")) hair")
        }
        if !character.eyeColorDescription.isEmpty { details.append("\(character.eyeColorDescription.lowercased()) eyes") }
        if !character.skinTone.isEmpty && !character.skinTone.hasPrefix("#") { details.append("\(character.skinTone.lowercased()) skin") }
        if !character.distinguishingFeatures.isEmpty { details.append(plainSubject(from: character.distinguishingFeatures)) }
        if let attire = attire(for: character, in: scene) { details.append("wearing \(attire)") }
        if let occupation = character.occupation, !occupation.isEmpty { details.append("a \(occupation.lowercased())") }
        if !details.isEmpty { line += ", " + details.joined(separator: ", ") }
        return line
    }

    /// Framing for the character-sheet angle keys the appearance and
    /// costume tabs use, in drawing language.
    public static func characterFraming(angle: String) -> String {
        switch angle {
        case "three_quarter_left":
            return "Three-quarter view turned to their left, head-and-shoulders portrait centered on the page, plain white background."
        case "three_quarter_right":
            return "Three-quarter view turned to their right, head-and-shoulders portrait centered on the page, plain white background."
        case "profile_left", "profile":
            return "Exact left profile, head-and-shoulders portrait centered on the page, plain white background."
        case "profile_right":
            return "Exact right profile, head-and-shoulders portrait centered on the page, plain white background."
        case "back":
            return "Back view showing the back of the head and shoulders, centered on the page, plain white background."
        default:
            return StoryboardPromptStyler.defaultFraming(for: .character)
        }
    }

    public static func costumeFraming(angle: String) -> String {
        let view: String
        switch angle {
        case "back": view = "back view"
        case "profile", "profile_left": view = "left side view"
        case "profile_right": view = "right side view"
        case "three_quarter_left": view = "three-quarter view turned to their left"
        case "three_quarter_right": view = "three-quarter view turned to their right"
        default: view = "front view"
        }
        return "Full figure standing in a \(view) from head to feet, centered on the page, arms relaxed, plain white background, garments drawn clearly with fabric folds and seam detail; one figure only, nothing else on the page."
    }

    // MARK: Reading a reference picture

    /// Whether an encoded picture is (near-)monochrome — an ink sketch, a
    /// pencil study — sampled on a coarse grid. Decides whether a
    /// continuity edit keeps the ink lock.
    public static func isNearMonochrome(_ data: Data, threshold: Double = 0.04) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return false }
        let side = 64
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let ok: Bool = pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8,
                                          bytesPerRow: side * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return false }
            context.interpolationQuality = .low
            context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard ok else { return false }
        var divergence = 0.0
        for i in 0 ..< (side * side) {
            let r = Double(pixels[i * 4]) / 255, g = Double(pixels[i * 4 + 1]) / 255, b = Double(pixels[i * 4 + 2]) / 255
            divergence += abs(r - g) + abs(g - b)
        }
        return divergence / Double(side * side) < threshold
    }

    // MARK: Inferring purpose from provider prompts

    /// The surface a legacy (brief-less) provider prompt came from, read
    /// off the fixed phrases its builder adds — so the assistant's scene,
    /// location and character actions get the same purpose-led drawing
    /// as the UI surfaces (framing, subject lead, reference clause).
    public static func inferredPurpose(fromPrompt prompt: String) -> VisualPurpose {
        let p = prompt.lowercased()
        if p.hasPrefix("edit this ") { return .edit }
        if p.contains("prop concept image") { return .prop }
        if p.contains("costume design reference") || p.contains("costume design sheet") { return .costume }
        if p.contains("studio reference portrait") || p.contains("character turnaround sheet")
            || p.contains("same person as the reference image") { return .character }
        if p.contains("professional film production design") { return .location }
        if p.contains("establishing shot") && p.contains("cinematic film still") { return .scene }
        if p.contains("cinematic film still") { return .shot }
        return .moodboard
    }

    // MARK: Cleaning provider prompts

    /// Phrases the cloud-provider prompt builders add that mean nothing
    /// to a drawing — or actively wreck one. Z-Image draws what it is
    /// told: "film still" made a photograph, "16:9 widescreen" drew a
    /// panel border, reference-image instructions and quoted dialogue
    /// got lettered onto the page (DC-0066 root cause).
    static let boilerplate: [String] = [
        "Cinematic film still", "professional cinematography",
        "dramatic lighting", "cinematic color grading", "movie quality",
        "16:9 widescreen composition", "Widescreen 16:9 landscape composition",
        "full frame edge-to-edge", "no black bars or letterboxing",
        "film grain", "35mm film aesthetic", "photorealistic",
        "ultra-realistic photograph", "natural lighting",
        "shallow depth of field", "bokeh background", "deep focus", "sharp throughout",
        "cinematic still frame", "dramatic movie lighting",
        "Cinematic mood-board reference image:",
        "Evocative, high production value, no text, no watermarks.",
        "professional film production design", "cinematic quality",
        "professional filmmaking", "cinematic depth", "natural perspective",
        "compressed perspective", "telephoto lens", "wide angle lens", "expansive view",
        "3D rendered character", "CGI", "Pixar-quality", "subsurface scattering",
        "classical oil painting", "rich textures", "museum quality", "fine brush work",
        "watercolor painting", "soft washes", "visible brush strokes", "paper texture",
        "anime style", "Japanese animation", "cel-shaded", "large expressive eyes",
        "comic book art", "bold ink outlines", "halftone dots", "vibrant colors",
        "digital illustration", "hand-drawn style", "detailed line art with color",
        "IMPORTANT: Generate the EXACT SAME person as shown in the reference image. Match the face, skin tone, hair, clothing, and art style precisely. This is a different angle of the same character, not a new character.",
        "EXACT SAME location as reference, maintain architectural details and environment precisely.",
        "character turnaround sheet", "consistent character appearance across all angles",
        "Same person as the reference image,", "identical appearance and lighting",
        "even lighting", "studio reference portrait",
        "costume design reference", "full body shot",
        "Match the character's face, body, and skin tone exactly from the \"character\" reference.",
        // The Prop Shop's concept prompt (DC-0071): the marker names the
        // purpose, the photography tail would fight the app's look.
        "Professional film-production prop concept image:",
        "Studio product photography on a neutral dark background, high detail, realistic materials, no people, no text.",
    ]

    /// Word swaps for terms the model draws literally.
    static let substitutions: [(String, String)] = [
        ("looking directly at camera", "looking straight ahead"),
        ("looking at the camera", "looking straight ahead"),
        ("toward the camera", "toward the viewer"),
        ("towards the camera", "toward the viewer"),
        ("at camera", "straight ahead"),
        ("to camera", "straight ahead"),
    ]

    /// Screenplay slug lines ("INT. BELLHAVEN ESTATE HOUSE - PARLOR - DAY")
    /// are lettered onto the page verbatim by an image model; turn them
    /// into plain description ("inside the Bellhaven Estate House, parlor,
    /// day") and calm any all-caps run into title case.
    public static func humanizeSlugLines(_ text: String) -> String {
        var out = text
        out = out.replacingOccurrences(of: #"\bINT\.?/EXT\.?\s*"#, with: "inside and outside ", options: .regularExpression)
        out = out.replacingOccurrences(of: #"\bINT\.?\s+"#, with: "inside the ", options: .regularExpression)
        out = out.replacingOccurrences(of: #"\bEXT\.?\s+"#, with: "outside the ", options: .regularExpression)
        // Runs of two or more ALL-CAPS words (slug bodies) → Title Case, and
        // the slug's " - " separators → ", ".
        if let regex = try? NSRegularExpression(pattern: #"\b[A-Z][A-Z'’]+(?:[ \-]+[A-Z][A-Z'’]+)+\b"#) {
            let ns = out as NSString
            var result = out
            for match in regex.matches(in: out, range: NSRange(location: 0, length: ns.length)).reversed() {
                let run = ns.substring(with: match.range)
                let titled = run.replacingOccurrences(of: #"\s*-\s*"#, with: ", ", options: .regularExpression)
                    .capitalized
                result = (result as NSString).replacingCharacters(in: match.range, with: titled)
            }
            out = result
        }
        return out
    }

    /// Strips a provider prompt down to its picture content: boilerplate
    /// out, quoted "mood" dialogue out, camera words swapped, separators
    /// tidied. Idempotent on already-plain text.
    public static func plainSubject(from prompt: String) -> String {
        var text = humanizeSlugLines(prompt)
        // Quoted dialogue used as a mood hint becomes lettering on the page.
        text = text.replacingOccurrences(
            of: #"mood:\s*"[^"]*"\.{0,3}"#, with: "", options: [.regularExpression, .caseInsensitive])
        for phrase in boilerplate {
            text = text.replacingOccurrences(of: phrase, with: "", options: .caseInsensitive)
        }
        for (from, to) in substitutions {
            text = text.replacingOccurrences(of: from, with: to, options: .caseInsensitive)
        }
        // Tidy what the removals left behind: ", ," / ". ." / dangling separators.
        text = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        // A comma/semicolon directly followed by another separator is a leftover.
        text = text.replacingOccurrences(of: #"\s*[,;]\s*(?=[,;.])"#, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: #"(\s*\.\s*){2,}"#, with: ". ", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\s+([,.;])"#, with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: #"^[\s,.;]+|[\s,;]+$"#, with: "", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The plain instruction inside an annotation-edit prompt ("Edit this
    /// image by making the following changes …: 1. red scarf at position
    /// (40%, 55%)") — the numbered changes, one per line, positions kept
    /// (klein reads them as rough placement).
    public static func editInstruction(from prompt: String) -> String {
        let lines = prompt.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        // Positions become edit regions (DC-0069); as text they only
        // tempt the model to letter coordinates onto the picture.
        let changes = lines
            .filter { $0.range(of: #"^\d+\."#, options: .regularExpression) != nil }
            .map { $0.replacingOccurrences(of: #"\s*at position \(\d+%,\s*\d+%\)"#, with: "",
                                           options: .regularExpression) }
            .map { $0.replacingOccurrences(of: #"^(\d+\.)\s*At \(\d+%,\s*\d+%\):\s*"#, with: "$1 ",
                                           options: .regularExpression) }
        if !changes.isEmpty { return changes.joined(separator: "\n") }
        var text = prompt
        text = text.replacingOccurrences(
            of: "Edit this image by making the following changes while keeping everything else identical:",
            with: "", options: .caseInsensitive)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Helpers

    /// Joins parts as sentences without doubling full stops when a part
    /// already ends with one.
    static func sentences(_ parts: [String]) -> String {
        parts.map { part in
            var p = part.trimmingCharacters(in: .whitespacesAndNewlines)
            while p.hasSuffix(".") { p.removeLast() }
            return p
        }.filter { !$0.isEmpty }.joined(separator: ". ")
    }

    static func ageWord(_ character: Character) -> String {
        character.age > 0 ? "\(character.age)-year-old" : "adult"
    }

    /// The costume a character wears in a scene: the scene's explicit
    /// assignment, else the active costume, else the first; else the
    /// legacy free-text costume field.
    static func attire(for character: Character, in scene: Scene?) -> String? {
        if let costumes = character.costumes, !costumes.isEmpty {
            let chosen: CharacterCostume
            if let assignedId = scene?.costumeAssignments?[character.name],
               let assigned = costumes.first(where: { $0.costumeId == assignedId }) {
                chosen = assigned
            } else if let index = character.activeCostumeIndex, costumes.indices.contains(index) {
                chosen = costumes[index]
            } else {
                chosen = costumes[0]
            }
            var garments: [String] = []
            if let top = chosen.garmentTop, !top.isEmpty { garments.append(top) }
            if let bottom = chosen.garmentBottom, !bottom.isEmpty { garments.append(bottom) }
            if let outer = chosen.outerwear, !outer.isEmpty { garments.append(outer) }
            return garments.isEmpty ? chosen.name : "\(chosen.name) (\(garments.joined(separator: ", ")))"
        }
        if let costume = character.costume, !costume.isEmpty { return costume }
        return nil
    }

    /// Characters appearing in a scene by dialogue or action, in project order.
    static func charactersPresent(in scene: Scene, from characters: [Character]) -> [Character] {
        var names = Set<String>()
        for dialogue in scene.dialogues { names.insert(dialogue.character) }
        for action in scene.actions { for name in action.characters { names.insert(name) } }
        return characters.filter { names.contains($0.name) }
    }
}

// MARK: - Persistence

public enum StoryboardFrameStore {

    public struct SavedFrame: Equatable, Sendable {
        /// The stable path callers store on the entity ("…/storyboard_latest.png").
        public let relativePath: String
        /// The immutable history copy written alongside it.
        public let timestampedRelativePath: String
    }

    public static let latestFilename = "storyboard_latest.png"

    /// Writes the frame under projectBase/relativeDirectory as a
    /// timestamped PNG plus the overwritten *_latest.png, mirroring the
    /// scene-overview/shot-preview convention exactly (history is cheap,
    /// the stored pointer is stable).
    public static func save(png: Data, projectBasePath: URL,
                            relativeDirectory: String,
                            timestamp: Date = Date()) throws -> SavedFrame {
        let directory = projectBasePath.appendingPathComponent(relativeDirectory,
                                                               isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let stamped = "storyboard_\(formatter.string(from: timestamp)).png"

        try png.write(to: directory.appendingPathComponent(stamped))
        try png.write(to: directory.appendingPathComponent(latestFilename))

        return SavedFrame(
            relativePath: "\(relativeDirectory)/\(latestFilename)",
            timestampedRelativePath: "\(relativeDirectory)/\(stamped)")
    }
}

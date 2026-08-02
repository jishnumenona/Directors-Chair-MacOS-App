// DirectorsChairServices/Sync/ProjectOverviewBuilder.swift
//
// §12A overview projection, desktop half. The web portal's project
// Overview tab renders a pitch deck the server stores verbatim
// (app.project_overview); the intake endpoint existed but the desktop
// never pushed — every synced project showed "No overview yet". This
// builder projects a Project into the deck shape ProjectView.tsx
// renders, referencing images as same-origin blob URLs
// (/api/v1/projects/{id}/blobs/{sha}) — the sync push has already
// uploaded those exact files as SHA-addressed blobs.

import Foundation
import DirectorsChairCore

public enum ProjectOverviewBuilder {

    /// Builds the deck payload. Images that can't be resolved/hashed are
    /// simply omitted — the portal renders initials/placeholders.
    public static func deck(project: Project, projectDir: URL,
                            projectID: String) -> [String: Any] {
        func blobURL(_ path: String?) -> String? {
            guard let path, !path.isEmpty else { return nil }
            let url = path.hasPrefix("/")
                ? URL(fileURLWithPath: path)
                : projectDir.appendingPathComponent(path)
            // Only files inside the project dir are in the sync manifest;
            // anything outside was never uploaded, so emitting its sha
            // would 404 in the portal. Omit it → placeholder instead.
            let root = projectDir.resolvingSymlinksInPath().path
            guard url.resolvingSymlinksInPath().path
                .hasPrefix(root.hasSuffix("/") ? root : root + "/") else { return nil }
            guard let data = try? Data(contentsOf: url) else { return nil }
            // /raw redirects to the presigned object so <img src> works;
            // the bare blob endpoint returns JSON for the sync engine.
            return "/api/v1/projects/\(projectID)/blobs/"
                + SyncHashing.sha256Hex(data) + "/raw"
        }

        var deck: [String: Any] = [:]
        func put(_ key: String, _ value: String?) {
            if let value, !value.isEmpty { deck[key] = value }
        }
        put("title", project.name)
        put("tagline", project.overviewTagline)
        put("logline", project.overviewLogline)
        put("pitch", project.overviewSummary)
        put("genre", project.genre)
        put("status", project.status)
        put("director", project.director)
        put("production_company", project.productionCompany)
        put("project_type", project.projectType)
        put("runtime", project.targetDuration)
        put("poster", blobURL(project.overviewPosterPath))

        deck["characters"] = project.characters.map {
            characterCard($0, project: project, blobURL: blobURL)
        }

        // §12B.3 Screenplay tab: derived from scenes exactly like the
        // desktop's script editor — the screenplay is a projection, never
        // stored, so an empty scenes list simply omits the tab.
        let screenplay = screenplayElements(project: project)
        if !screenplay.isEmpty {
            deck["screenplay"] = ["title": project.name, "elements": screenplay]
        }

        deck["locations"] = project.locations.map { location -> [String: Any] in
            var entry: [String: Any] = ["name": location.name]
            if let image = blobURL(location.primaryImage) {
                entry["image"] = image
            }
            return entry
        }

        var sceneCount = 0
        var shotCount = 0
        // The renderer requires BOTH shapes: shots nested per scene AND a
        // flat top-level shot board (ProjectView dereferences deck.shots
        // unconditionally — its absence crashed the page).
        var shotBoard: [[String: Any]] = []
        deck["scenes"] = project.sequences.flatMap { sequence in
            sequence.scenes.map { scene -> [String: Any] in
                sceneCount += 1
                var entry: [String: Any] = ["id": scene.id,
                                            "name": scene.name,
                                            "sequence": sequence.name]
                if !scene.description.isEmpty {
                    entry["summary"] = scene.description
                }
                if let image = blobURL(scene.sceneOverviewImage) {
                    entry["image"] = image
                }
                // ONE full storyboard card per shot, shared by the nested
                // per-scene lists (the portal's Scenes + Shot list tabs
                // render scenes[].shots) AND the flat top-level board (the
                // Overview tab). The nested entries used to be bare
                // {id, shot_type} — every shot rendered imageless in the
                // Shot list tab even though the blobs were all uploaded.
                entry["shots"] = scene.shots.map { shot -> [String: Any] in
                    shotCount += 1
                    var card: [String: Any] = ["id": "\(scene.id)#\(shot.shotId)",
                                               "number": shot.shotId,
                                               "scene": scene.name,
                                               "shot_type": shot.shotType]
                    func field(_ key: String, _ value: String?) {
                        if let value, !value.isEmpty { card[key] = value }
                    }
                    field("camera_angle", shot.cameraAngle)
                    field("movement", shot.movement)
                    field("aperture", shot.aperture)
                    field("status", shot.status)
                    field("description", shot.description)
                    if let lens = shot.lensMm { card["lens_mm"] = lens }
                    if let duration = shot.duration { card["duration"] = duration }
                    // The AI-generated preview is what the desktop's own shot
                    // cards display; reference imagery is the fallback.
                    if let image = blobURL(shot.previewImage)
                        ?? blobURL(shot.referenceMedia.first(
                            where: { $0.type == .image })?.path) {
                        card["image"] = image
                    }
                    shotBoard.append(card)
                    return card
                }
                return entry
            }
        }
        deck["shots"] = shotBoard

        deck["stats"] = ["characters": project.characters.count,
                         "locations": project.locations.count,
                         "scenes": sceneCount,
                         "shots": shotCount]
        return deck
    }

    // MARK: - Character sheet (portal per-character page)

    /// The desktop's TraitCategory grouping (PersonalityTraitsTab): five
    /// Big-Five categories × five Title-Case facet keys, values 0–100.
    /// Colors are the portal/seed convention.
    static let oceanFacets: [(category: String, color: String, facets: [String])] = [
        ("Openness", "#9B59B6",
         ["Creativity", "Curiosity", "Imagination", "Open-mindedness", "Artistic Interest"]),
        ("Conscientiousness", "#3498DB",
         ["Organization", "Diligence", "Reliability", "Self-discipline", "Ambition"]),
        ("Extraversion", "#E67E22",
         ["Sociability", "Energy", "Assertiveness", "Enthusiasm", "Talkativeness"]),
        ("Agreeableness", "#27AE60",
         ["Empathy", "Cooperation", "Trust", "Kindness", "Politeness"]),
        ("Neuroticism", "#E74C3C",
         ["Anxiety", "Moodiness", "Sensitivity", "Irritability", "Self-consciousness"]),
    ]

    /// Full character sheet, matching the portal's OverviewCharacter wire
    /// type (api.ts). Every field optional-omitted: the page gates each tab
    /// on the fields that actually arrived.
    private static func characterCard(_ character: Character, project: Project,
                                      blobURL: (String?) -> String?) -> [String: Any] {
        var entry: [String: Any] = ["id": character.name, "name": character.name]
        func put(_ key: String, _ value: String?) {
            if let value, !value.isEmpty { entry[key] = value }
        }
        put("role", character.role)
        put("color", character.color)
        put("about", character.about)
        if let portrait = blobURL(character.avatar ?? character.baseImage
                                  ?? character.imageFront) {
            entry["portrait"] = portrait
        }
        // Angle gallery — labels are the portal's React keys (unique).
        let angleSources: [(String, String?)] = [
            ("Front", character.imageFront),
            ("3/4 Left", character.imageThreeQuarterLeft),
            ("3/4 Right", character.imageThreeQuarterRight),
            ("Profile Left", character.imageProfileLeft),
            ("Profile Right", character.imageProfileRight),
            ("Back", character.imageBack),
        ]
        let angles = angleSources.compactMap { label, path -> [String: Any]? in
            guard let src = blobURL(path) else { return nil }
            return ["label": label, "src": src]
        }
        if !angles.isEmpty { entry["angles"] = angles }
        // Biography
        put("full_name", character.fullName)
        put("nickname", character.nickname)
        put("occupation", character.occupation)
        put("affiliation", character.affiliation)
        put("background_story", character.backgroundStory)
        put("primary_goal", character.primaryGoal)
        put("secondary_goal", character.secondaryGoal)
        put("hidden_motivation", character.hiddenMotivation)
        put("primary_fear", character.primaryFear)
        put("weakness", character.weakness)
        put("flaw", character.flaw)
        put("arc", character.characterArcNotes)
        // Physical
        put("gender", character.gender)
        if character.age > 0 { entry["age"] = character.age }
        if let height = character.heightCm { entry["height_cm"] = height }
        if let weight = character.weightKg { entry["weight_kg"] = weight }
        put("build", character.build)
        put("hair_color", character.hairColor)
        put("hair_style", character.hairStyle)
        put("hair_length", character.hairLength)
        put("eye_color", character.eyeColor)
        put("eye_color_description", character.eyeColorDescription)
        put("eye_shape", character.eyeShape)
        put("skin_tone", character.skinTone)
        put("ethnicity", character.ethnicity)
        put("facial_structure", character.facialStructure)
        put("distinguishing_features", character.distinguishingFeatures)
        // Personality
        let ocean = oceanCategories(from: character.traits)
        if !ocean.isEmpty { entry["ocean"] = ocean }
        if let confidence = character.traitsConfidenceScore {
            entry["traits_confidence"] = confidence
        }
        put("traits_reasoning", character.traitsAiReasoning)
        // Voice
        put("voice", character.voice)
        put("voice_tone", character.voiceTone)
        put("voice_personality", character.voicePersonality)
        put("voice_pace", character.voicePace)
        put("voice_age", character.voiceAge)
        put("voice_accent", character.voiceAccent)
        put("voice_style", character.voiceStyle)
        // Relationships (desktop stores name → relation)
        if let relationships = character.relationships, !relationships.isEmpty {
            entry["relationships"] = relationships.keys.sorted().map {
                ["name": $0, "relation": relationships[$0] ?? ""]
            }
        }
        // Scenes — the desktop records scene ids; the portal lists names.
        let names = sceneNames(for: character, project: project)
        if !names.isEmpty { entry["scene_names"] = names }
        // Wardrobe
        let costumes = (character.costumes ?? []).map { costumeCard($0, blobURL: blobURL) }
        if !costumes.isEmpty { entry["costumes"] = costumes }
        return entry
    }

    private static func oceanCategories(from traits: [String: Double]) -> [[String: Any]] {
        oceanFacets.compactMap { category, color, facets in
            let present = facets.compactMap { name -> [String: Any]? in
                guard let value = traits[name] else { return nil }
                return ["name": name, "value": value]
            }
            guard !present.isEmpty else { return nil }
            return ["category": category, "color": color, "traits": present]
        }
    }

    private static func sceneNames(for character: Character, project: Project) -> [String] {
        guard let appearances = character.sceneAppearances, !appearances.isEmpty else { return [] }
        var nameByID: [String: String] = [:]
        for sequence in project.sequences {
            for scene in sequence.scenes { nameByID[scene.id] = scene.name }
        }
        var seen: Set<String> = []
        // Names double as the portal's React keys — dedupe keeps them unique.
        return appearances.compactMap { id in
            let name = nameByID[id] ?? id
            return seen.insert(name).inserted ? name : nil
        }
    }

    private static func costumeCard(_ costume: CharacterCostume,
                                    blobURL: (String?) -> String?) -> [String: Any] {
        var card: [String: Any] = ["name": costume.name]
        func put(_ key: String, _ value: String?) {
            if let value, !value.isEmpty { card[key] = value }
        }
        put("description", costume.description)
        put("era", costume.era)
        put("style", costume.styleCategory)
        put("garment_top", costume.garmentTop)
        put("garment_bottom", costume.garmentBottom)
        put("footwear", costume.footwear)
        put("outerwear", costume.outerwear)
        put("headwear", costume.headwear)
        if let palette = costume.colorPalette, !palette.isEmpty {
            card["color_palette"] = palette
        }
        if let accessories = costume.accessories, !accessories.isEmpty {
            card["accessories"] = accessories
        }
        if let image = blobURL(costume.imageFront) ?? blobURL(costume.imageFullBody) {
            card["image"] = image
        }
        return card
    }

    // MARK: - Screenplay projection (portal Screenplay tab)

    /// Same walk as the desktop script editor's ProjectToScriptConverter
    /// (app target, not importable here), reduced to the seven element
    /// types the portal styles. Editor-only elements (notes, blank lines)
    /// are dropped; sound cues render as conventional SFX action lines.
    static func screenplayElements(project: Project) -> [[String: String]] {
        var elements: [[String: String]] = []
        func add(_ type: String, _ text: String) {
            let cleaned = plainText(text)
            guard !cleaned.isEmpty else { return }
            elements.append(["type": type, "text": cleaned])
        }
        for sequence in project.sequences {
            if !sequence.name.isEmpty { add("section", sequence.name.uppercased()) }
            for scene in sequence.scenes {
                add("scene_heading", sceneHeading(scene: scene, sequence: sequence))
                add("action", scene.description)
                var lastSpeaker: String?
                for item in scriptItems(of: scene) {
                    switch item {
                    case .dialogue(let dialogue):
                        let speaker = dialogue.character.uppercased()
                        add("character", speaker == lastSpeaker
                            ? speaker + " (CONT'D)" : speaker)
                        lastSpeaker = speaker
                        if !dialogue.tags.isEmpty {
                            add("parenthetical",
                                "(\(dialogue.tags.joined(separator: ", ")))")
                        }
                        add("dialogue", dialogue.text)
                    case .action(let action):
                        add("action", action.description)
                    case .narration(let narration):
                        add("action", narration.text)
                    case .sound(let note):
                        add("action", "SFX: \(note.soundType.uppercased()) — \(note.description)")
                    }
                }
            }
        }
        return elements
    }

    private enum SceneItem {
        case dialogue(Dialogue)
        case action(Action)
        case narration(Narration)
        case sound(SoundNote)

        var chronology: Int {
            switch self {
            case .dialogue(let d): return d.chronologyNumber
            case .action(let a): return a.chronologyNumber
            case .narration(let n): return n.chronologyNumber
            case .sound(let s): return s.chronologyNumber
            }
        }
    }

    /// Top-level items in scene chronology order; sub-bubbles attached to a
    /// dialogue stay out of the script (the editor does the same).
    private static func scriptItems(of scene: Scene) -> [SceneItem] {
        var items: [SceneItem] = scene.dialogues.map { .dialogue($0) }
        items += scene.actions.filter { $0.parentDialogueId == nil }.map { .action($0) }
        items += scene.narrations.filter { $0.parentDialogueId == nil }.map { .narration($0) }
        items += scene.soundNotes.map { .sound($0) }
        return items.sorted { $0.chronology < $1.chronology }
    }

    /// Slug-line normalization, mirroring the desktop editor: location (or
    /// the sequence's, or the scene name), uppercased, defaulted to DAY,
    /// prefixed INT. unless already INT/EXT-qualified.
    private static func sceneHeading(scene: Scene, sequence: Sequence) -> String {
        let base = [scene.location, sequence.location]
            .compactMap { $0 }.first { !$0.isEmpty } ?? scene.name
        var heading = base.uppercased()
        if !heading.contains(" - ") { heading += " - DAY" }
        if !heading.hasPrefix("INT") && !heading.hasPrefix("EXT") {
            heading = "INT. " + heading
        }
        return heading
    }

    /// Dialogue/action text may carry editor HTML; the portal renders plain
    /// text only.
    private static func plainText(_ text: String) -> String {
        guard text.contains("<") else {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
            .replacingOccurrences(of: "<br ?/?>", with: "\n",
                                  options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

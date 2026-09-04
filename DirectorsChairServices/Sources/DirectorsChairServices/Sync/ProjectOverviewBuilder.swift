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

    /// The picture that fronts a project everywhere — the desktop's hero
    /// banner, the web deck's hero, the cloud project cards: the first
    /// entry of the poster list the hero banner writes, then the single
    /// pre-list field, then the project icon — the order the banner shows
    /// them. (The deck read only the pre-list field, so every poster set
    /// through the banner was missing on the web.)
    public static func posterPath(for project: Project) -> String? {
        let candidates = project.overviewPosterPaths
            + [project.overviewPosterPath ?? "", project.projectIcon]
        return candidates.first { !$0.isEmpty }
    }

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
        put("poster", blobURL(posterPath(for: project)))

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

        // Final parity sweep: props, vision board, production suite
        // (ProjectOverviewBuilder+Production.swift). Empty sections are
        // omitted — the portal gates each tab on its data arriving.
        let propCards = project.props.map { propCard($0, blobURL: blobURL) }
        if !propCards.isEmpty { deck["props"] = propCards }
        let vision = visionCards(project: project, blobURL: blobURL)
        if !vision.isEmpty { deck["vision_board"] = vision }
        if let production = productionSection(project: project) {
            deck["production"] = production
        }

        deck["locations"] = project.locations.map {
            locationCard($0, project: project, blobURL: blobURL)
        }

        var sceneCount = 0
        var shotCount = 0
        // The renderer requires BOTH shapes: shots nested per scene AND a
        // flat top-level shot board (ProjectView dereferences deck.shots
        // unconditionally — its absence crashed the page).
        var shotBoard: [[String: Any]] = []
        let styleNameByID = Dictionary(project.filmStyles.map { ($0.id, $0.name) },
                                       uniquingKeysWith: { first, _ in first })
        let colorByCharacter = Dictionary(project.characters.map { ($0.name, $0.color) },
                                          uniquingKeysWith: { first, _ in first })
        deck["scenes"] = project.sequences.flatMap { sequence in
            sequence.scenes.map { scene -> [String: Any] in
                sceneCount += 1
                var entry: [String: Any] = ["id": scene.id,
                                            "name": scene.name,
                                            "sequence": sequence.name]
                if !scene.description.isEmpty {
                    entry["summary"] = scene.description
                }
                if !scene.notes.isEmpty {
                    entry["notes"] = scene.notes
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
                    field("lighting", shot.lightingStyle)
                    field("notes", shot.notes)
                    if let override = shot.styleOverride {
                        field("style", styleNameByID[override] ?? override)
                    }
                    if let lens = shot.lensMm { card["lens_mm"] = lens }
                    if let duration = shot.duration { card["duration"] = duration }
                    if !shot.takes.isEmpty { card["takes"] = shot.takes.count }
                    // The shot page lists the content the shot covers,
                    // resolved from the desktop's Connections links.
                    let dialogueLines = shot.linkedDialogueIds.compactMap { id in
                        scene.dialogues.first { $0.uuid == id }
                    }.map { "\($0.character.uppercased()): \(plainText($0.text))" }
                    if !dialogueLines.isEmpty { card["dialogue_lines"] = dialogueLines }
                    let actionLines = shot.linkedActionIds.compactMap { id in
                        scene.actions.first { $0.uuid == id }
                    }.map { plainText($0.description) }
                    if !actionLines.isEmpty { card["action_lines"] = actionLines }
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
                // Bubble view: the scene's content as chronological chat
                // bubbles, dialogue carrying the speaker's color. Includes
                // sub-bubbles (unlike the screenplay projection) — the
                // desktop bubble view shows them too.
                let bubbles = bubbleItems(of: scene, colorByCharacter: colorByCharacter)
                if !bubbles.isEmpty { entry["bubbles"] = bubbles }
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

    // MARK: - Location detail (portal Story → Locations)

    /// Full location card matching the portal's OverviewLocation wire type.
    /// The dict-typed desktop fields (styleAttributes, cinematographyDefaults)
    /// use the keys the desktop UI writes: mood/architecture/palette and
    /// lighting_style/time_of_day/angle.
    private static func locationCard(_ location: Location, project: Project,
                                     blobURL: (String?) -> String?) -> [String: Any] {
        var entry: [String: Any] = ["id": location.uuid, "name": location.name]
        func put(_ key: String, _ value: String?) {
            if let value, !value.isEmpty { entry[key] = value }
        }
        put("type", location.locationType)
        put("description", location.description)
        put("address", location.address)
        put("gps", location.gpsCoordinates)
        put("notes", location.notes)
        if !location.tags.isEmpty { entry["tags"] = location.tags }
        if let image = blobURL(location.primaryImage) { entry["image"] = image }
        let variations = location.images.filter { $0 != location.primaryImage }
            .enumerated().compactMap { index, path -> [String: Any]? in
                guard let src = blobURL(path) else { return nil }
                return ["label": "View \(index + 1)", "src": src]
            }
        if !variations.isEmpty { entry["variations"] = variations }
        let style = location.styleAttributes
        let attrs = location.attributes
        put("mood", style["mood"] ?? attrs["mood"])
        put("architecture", style["architecture"] ?? style["architectural_style"])
        // The portal renders palette entries as color swatches — only hex
        // values survive; descriptive palettes ("dust, oak, brass") don't.
        if let palette = style["color_palette"] ?? style["palette"] {
            let swatches = palette.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.hasPrefix("#") }
            if !swatches.isEmpty { entry["color_palette"] = swatches }
        }
        let cine = location.cinematographyDefaults
        put("cine_angle", cine["angle"] ?? cine["camera_angle"])
        put("cine_lighting", cine["lighting_style"] ?? cine["lighting"])
        put("cine_time", cine["time_of_day"] ?? attrs["time_of_day"])
        let context = project.sequences.flatMap(\.scenes)
            .filter { $0.location == location.name }.map(\.name)
        if !context.isEmpty { entry["scene_context"] = context }
        return entry
    }

    // MARK: - Bubble view (portal scene detail)

    /// The scene's content as chronological chat bubbles — dialogue in the
    /// speaker's color with tone tags; actions, narrations, and sound cues
    /// as neutral flow bubbles. Sub-bubbles are included (the desktop
    /// bubble view shows them attached to their dialogue).
    private static func bubbleItems(of scene: Scene,
                                    colorByCharacter: [String: String]) -> [[String: Any]] {
        var items: [(chronology: Int, bubble: [String: Any])] = []
        for dialogue in scene.dialogues {
            var bubble: [String: Any] = ["kind": "dialogue",
                                         "text": plainText(dialogue.text),
                                         "character": dialogue.character]
            if let color = colorByCharacter[dialogue.character], !color.isEmpty {
                bubble["color"] = color
            }
            if !dialogue.tags.isEmpty { bubble["tags"] = dialogue.tags }
            items.append((dialogue.chronologyNumber, bubble))
        }
        for action in scene.actions {
            items.append((action.chronologyNumber,
                          ["kind": "action", "text": plainText(action.description)]))
        }
        for narration in scene.narrations {
            items.append((narration.chronologyNumber,
                          ["kind": "narration", "text": plainText(narration.text)]))
        }
        for note in scene.soundNotes {
            items.append((note.chronologyNumber,
                          ["kind": "sound",
                           "text": "\(note.soundType.uppercased()): \(note.description)"]))
        }
        return items.sorted { $0.chronology < $1.chronology }
            .map(\.bubble)
            .filter { ($0["text"] as? String)?.isEmpty == false }
    }

    // MARK: - Character sheet (portal per-character page)

    /// The desktop's TraitCategory grouping (PersonalityTraitsTab): five
    /// Big-Five categories × five Title-Case facet keys, values 0–100.
    /// Colors are the portal/seed convention.
    static let oceanFacets: [(category: String, color: String, facets: [String])] =
        zip(TraitVocabulary.categories, ["#9B59B6", "#3498DB", "#E67E22", "#27AE60", "#E74C3C"])
            .map { (category: $0.name, color: $1, facets: $0.facets) }

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

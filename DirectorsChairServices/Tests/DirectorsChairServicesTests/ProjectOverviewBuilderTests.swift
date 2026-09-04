// DirectorsChairServicesTests/ProjectOverviewBuilderTests.swift
//
// §12A desktop half: the pitch-deck projection pushed after sync.

import XCTest
@testable import DirectorsChairServices
@testable import DirectorsChairCore

final class ProjectOverviewBuilderTests: XCTestCase {

    func testDeckProjectsFieldsStatsAndBlobURLs() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("overview-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: dir.appendingPathComponent("assets"),
            withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let imageData = Data("png-bytes".utf8)
        try imageData.write(to: dir.appendingPathComponent("assets/maya.png"))
        let sha = SyncHashing.sha256Hex(imageData)

        var project = Project(name: "Test Film")
        project.genre = "Drama"
        project.overviewTagline = "One chair."
        var maya = Character(name: "Maya")
        maya.avatar = "assets/maya.png"
        let ghost = Character(name: "Ghost")   // no artwork
        project.characters = [maya, ghost]
        var scene = Scene(name: "Opening", description: "Night. Rain.")
        scene.shots = [Shot(shotId: 1, shotType: "Wide")]
        project.sequences = [Sequence(name: "Act 1", scenes: [scene])]
        project.locations = [Location(name: "Rooftop")]

        let deck = ProjectOverviewBuilder.deck(project: project,
                                               projectDir: dir,
                                               projectID: "p-123")

        XCTAssertEqual(deck["title"] as? String, "Test Film")
        XCTAssertEqual(deck["tagline"] as? String, "One chair.")
        XCTAssertEqual(deck["genre"] as? String, "Drama")
        XCTAssertNil(deck["logline"], "empty fields are omitted, not empty strings")

        let characters = deck["characters"] as? [[String: Any]]
        XCTAssertEqual(characters?.count, 2)
        XCTAssertEqual(characters?[0]["portrait"] as? String,
                       "/api/v1/projects/p-123/blobs/\(sha)/raw",
                       "same-origin browser-fetchable blob URLs by content sha")
        XCTAssertNil(characters?[1]["portrait"], "missing artwork omitted")

        let scenes = deck["scenes"] as? [[String: Any]]
        XCTAssertEqual(scenes?.count, 1)
        XCTAssertEqual(scenes?[0]["summary"] as? String, "Night. Rain.")
        XCTAssertEqual((scenes?[0]["shots"] as? [[String: Any]])?.first?["shot_type"] as? String,
                       "Wide")

        let board = deck["shots"] as? [[String: Any]]
        XCTAssertEqual(board?.count, 1,
                       "flat shot board — ProjectView dereferences it unconditionally")
        XCTAssertEqual(board?.first?["scene"] as? String, "Opening")
        XCTAssertEqual(board?.first?["shot_type"] as? String, "Wide")
        XCTAssertEqual(board?.first?["id"] as? String, "\(scene.id)#1",
                       "board ids unique across scenes")

        let stats = deck["stats"] as? [String: Int]
        XCTAssertEqual(stats, ["characters": 2, "locations": 1,
                               "scenes": 1, "shots": 1])

        XCTAssertTrue(JSONSerialization.isValidJSONObject(deck),
                      "the deck must serialize for the PUT body")
    }

    /// The hero banner writes `overviewPosterPaths`; the deck used to read
    /// only the pre-list `overviewPosterPath`, so every poster set through
    /// the banner was missing on the web (owner, 2026-09-04: "The overview
    /// page on the webapp is missing the poster").
    func testDeckPosterFollowsTheHeroBannerPosterList() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("overview-poster-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: dir.appendingPathComponent("assets/icons"),
            withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let posterData = Data("poster-bytes".utf8)
        let iconData = Data("icon-bytes".utf8)
        try posterData.write(to: dir.appendingPathComponent("assets/poster.png"))
        try iconData.write(to: dir.appendingPathComponent("assets/icons/icon.png"))
        let posterURL = "/api/v1/projects/p-1/blobs/\(SyncHashing.sha256Hex(posterData))/raw"
        let iconURL = "/api/v1/projects/p-1/blobs/\(SyncHashing.sha256Hex(iconData))/raw"

        var banner = Project(name: "Banner")
        banner.overviewPosterPaths = ["", "assets/poster.png"]   // blanks are skipped
        banner.overviewPosterPath = "assets/never-written.png"   // the pre-list field must not win
        banner.projectIcon = "assets/icons/icon.png"
        XCTAssertEqual(ProjectOverviewBuilder.deck(project: banner, projectDir: dir,
                                                   projectID: "p-1")["poster"] as? String,
                       posterURL, "the banner's first poster fronts the deck")

        var legacy = Project(name: "Legacy")
        legacy.overviewPosterPath = "assets/poster.png"
        legacy.projectIcon = "assets/icons/icon.png"
        XCTAssertEqual(ProjectOverviewBuilder.deck(project: legacy, projectDir: dir,
                                                   projectID: "p-1")["poster"] as? String,
                       posterURL, "projects saved before the list still resolve")

        var iconOnly = Project(name: "Icon")
        iconOnly.projectIcon = "assets/icons/icon.png"
        XCTAssertEqual(ProjectOverviewBuilder.deck(project: iconOnly, projectDir: dir,
                                                   projectID: "p-1")["poster"] as? String,
                       iconURL, "the icon fronts a project with no poster, as the banner does")

        XCTAssertNil(ProjectOverviewBuilder.deck(project: Project(name: "Bare"), projectDir: dir,
                                                 projectID: "p-1")["poster"])
    }

    func testShotBoardUsesPreviewImageWithReferenceMediaFallback() throws {
        // The owner's field report (2026-08-02): every synced shot rendered
        // imageless in the portal. AI-generated shot images live in
        // shot.previewImage — what the desktop's own shot cards display —
        // but the deck only consulted referenceMedia (0/50 on the affected
        // project). previewImage wins; reference imagery is the fallback.
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("overview-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: dir.appendingPathComponent("assets/shots"),
            withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let previewData = Data("preview-png".utf8)
        try previewData.write(to: dir.appendingPathComponent("assets/shots/latest.png"))
        let referenceData = Data("reference-png".utf8)
        try referenceData.write(to: dir.appendingPathComponent("assets/shots/ref.png"))

        var withPreview = Shot(shotId: 1, shotType: "Wide")
        withPreview.previewImage = "assets/shots/latest.png"
        withPreview.referenceMedia = [ReferenceMedia(type: .image,
                                                     path: "assets/shots/ref.png")]
        var referenceOnly = Shot(shotId: 2, shotType: "Close")
        referenceOnly.referenceMedia = [ReferenceMedia(type: .image,
                                                       path: "assets/shots/ref.png")]
        var previewFileMissing = Shot(shotId: 3, shotType: "Medium")
        previewFileMissing.previewImage = "assets/shots/deleted.png"
        previewFileMissing.referenceMedia = [ReferenceMedia(type: .image,
                                                            path: "assets/shots/ref.png")]

        var scene = Scene(name: "Opening", description: "")
        scene.shots = [withPreview, referenceOnly, previewFileMissing]
        var project = Project(name: "Test Film")
        project.sequences = [Sequence(name: "Act 1", scenes: [scene])]

        let deck = ProjectOverviewBuilder.deck(project: project,
                                               projectDir: dir,
                                               projectID: "p-123")
        let board = deck["shots"] as? [[String: Any]]
        let previewURL = "/api/v1/projects/p-123/blobs/\(SyncHashing.sha256Hex(previewData))/raw"
        let referenceURL = "/api/v1/projects/p-123/blobs/\(SyncHashing.sha256Hex(referenceData))/raw"
        XCTAssertEqual(board?[0]["image"] as? String, previewURL,
                       "previewImage wins over reference media")
        XCTAssertEqual(board?[1]["image"] as? String, referenceURL,
                       "reference imagery still resolves when no preview exists")
        XCTAssertEqual(board?[2]["image"] as? String, referenceURL,
                       "an unreadable preview file falls back, not omits")

        // The portal's Scenes + Shot list tabs render scenes[].shots — the
        // nested entries must carry the same full storyboard card (they
        // used to be bare {id, shot_type}, so every shot in the Shot list
        // tab rendered imageless — the 2026-08-02 field report).
        let scenes = deck["scenes"] as? [[String: Any]]
        let nested = scenes?[0]["shots"] as? [[String: Any]]
        XCTAssertEqual(nested?[0]["image"] as? String, previewURL,
                       "nested per-scene shots must carry the image too")
        XCTAssertEqual(nested?[1]["image"] as? String, referenceURL)
        XCTAssertEqual(nested?[0]["number"] as? Int, 1,
                       "shot display number for the storyboard card")
        XCTAssertEqual(nested?[0]["camera_angle"] as? String, "Medium")
        XCTAssertEqual(nested?[0]["lens_mm"] as? Int, 50)
        XCTAssertEqual(nested?[0]["movement"] as? String, "Static")
        XCTAssertEqual(nested?[0]["status"] as? String, "Planning")
        XCTAssertTrue(JSONSerialization.isValidJSONObject(deck),
                      "the enriched deck must serialize for the PUT body")
    }

    func testBlobURLOmitsFilesOutsideProjectDir() throws {
        // A path outside the project dir is never in the sync manifest, so
        // its sha would 404 in the portal — omit it (placeholder) instead
        // of emitting a broken image URL.
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("overview-\(UUID().uuidString)")
        let dir = parent.appendingPathComponent("project")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }
        let outside = parent.appendingPathComponent("outside.png")
        try Data("outside-png".utf8).write(to: outside)

        var project = Project(name: "Test Film")
        var maya = Character(name: "Maya")
        maya.avatar = outside.path                       // absolute, outside
        var ghost = Character(name: "Ghost")
        ghost.avatar = "../outside.png"                  // relative escape
        project.characters = [maya, ghost]

        let deck = ProjectOverviewBuilder.deck(project: project,
                                               projectDir: dir,
                                               projectID: "p-123")
        let characters = deck["characters"] as? [[String: Any]]
        XCTAssertNil(characters?[0]["portrait"],
                     "absolute path outside the project dir must be omitted")
        XCTAssertNil(characters?[1]["portrait"],
                     "dot-dot escape outside the project dir must be omitted")
    }

    func testCharacterCardCarriesFullSheet() throws {
        // The portal's per-character page (CharacterPage.tsx) gates seven
        // tabs on these fields; the deck used to send only {id, name,
        // portrait}, so every character page rendered empty (owner field
        // report 2026-08-02).
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("overview-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: dir.appendingPathComponent("assets"),
            withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try Data("face".utf8).write(to: dir.appendingPathComponent("assets/face.png"))
        try Data("front".utf8).write(to: dir.appendingPathComponent("assets/front.png"))
        try Data("costume".utf8).write(to: dir.appendingPathComponent("assets/costume.png"))

        var maya = Character(name: "Maya")
        maya.role = "Protagonist"
        maya.about = "An archivist of vanishing things."
        maya.baseImage = "assets/face.png"
        maya.imageFront = "assets/front.png"
        maya.fullName = "Maya Elise Voss"
        maya.occupation = "Photographer"
        maya.characterArcNotes = "Learns to stop framing life."
        maya.gender = "female"
        maya.age = 34
        maya.heightCm = 170
        maya.build = "Slim"
        maya.hairColor = "#3b2f2a"
        maya.eyeColor = "#5a7d6f"
        maya.eyeColorDescription = "Grey-green"
        maya.voice = "Kore"
        maya.voiceTone = "Intense"
        maya.traits = ["Creativity": 55, "Curiosity": 68, "Anxiety": 78]
        maya.traitsConfidenceScore = 78
        maya.relationships = ["Eli": "Brother", "Dana": "Rival"]
        var costume = CharacterCostume(name: "Estate Grays")
        costume.imageFront = "assets/costume.png"
        costume.era = "Contemporary"
        costume.colorPalette = ["#444444", "#888888"]
        maya.costumes = [costume]

        let scene = Scene(name: "Opening", description: "")
        var project = Project(name: "Test Film")
        project.sequences = [Sequence(name: "Act 1", scenes: [scene])]
        maya.sceneAppearances = [scene.id, "no-such-scene"]
        project.characters = [maya]

        let deck = ProjectOverviewBuilder.deck(project: project,
                                               projectDir: dir, projectID: "p-1")
        let card = (deck["characters"] as? [[String: Any]])?.first

        XCTAssertEqual(card?["role"] as? String, "Protagonist")
        XCTAssertEqual(card?["full_name"] as? String, "Maya Elise Voss")
        XCTAssertEqual(card?["occupation"] as? String, "Photographer")
        XCTAssertEqual(card?["arc"] as? String, "Learns to stop framing life.")
        XCTAssertEqual(card?["age"] as? Int, 34)
        XCTAssertEqual(card?["height_cm"] as? Double, 170)
        XCTAssertEqual(card?["hair_color"] as? String, "#3b2f2a")
        XCTAssertEqual(card?["eye_color_description"] as? String, "Grey-green")
        XCTAssertEqual(card?["voice_tone"] as? String, "Intense")
        XCTAssertNotNil(card?["portrait"], "base image resolves to a blob URL")

        let angles = card?["angles"] as? [[String: Any]]
        XCTAssertEqual(angles?.map { $0["label"] as? String }, ["Front"],
                       "only resolvable angle images are emitted")

        let ocean = card?["ocean"] as? [[String: Any]]
        XCTAssertEqual(ocean?.count, 2, "only categories with calibrated facets")
        XCTAssertEqual(ocean?[0]["category"] as? String, "Openness")
        let facets = ocean?[0]["traits"] as? [[String: Any]]
        XCTAssertEqual(facets?.map { $0["name"] as? String }, ["Creativity", "Curiosity"])
        XCTAssertEqual(ocean?[1]["category"] as? String, "Neuroticism")
        XCTAssertEqual(card?["traits_confidence"] as? Double, 78)

        let relationships = card?["relationships"] as? [[String: String]]
        XCTAssertEqual(relationships,
                       [["name": "Dana", "relation": "Rival"],
                        ["name": "Eli", "relation": "Brother"]],
                       "deterministic name-sorted order")

        XCTAssertEqual(card?["scene_names"] as? [String], ["Opening", "no-such-scene"],
                       "ids resolve to names; unknown ids pass through")

        let costumes = card?["costumes"] as? [[String: Any]]
        XCTAssertEqual(costumes?.first?["name"] as? String, "Estate Grays")
        XCTAssertEqual(costumes?.first?["era"] as? String, "Contemporary")
        XCTAssertEqual(costumes?.first?["color_palette"] as? [String], ["#444444", "#888888"])
        XCTAssertNotNil(costumes?.first?["image"])

        XCTAssertTrue(JSONSerialization.isValidJSONObject(deck))
    }

    func testScreenplayProjectionRendersStandardElements() throws {
        // The portal's Screenplay tab renders {type, text} elements; the
        // desktop derives the script from scenes (no stored screenplay).
        var scene = Scene(name: "Estate", description: "A quiet parlor.")
        scene.location = "INT. PARLOR - NIGHT"
        scene.dialogues = [
            Dialogue(character: "Mara", text: "That was my father's.",
                     tags: ["O.S."], chronologyNumber: 1),
            Dialogue(character: "Mara", text: "<b>Sorry.</b>", chronologyNumber: 3),
        ]
        scene.actions = [Action(description: "She lifts the camera.",
                                chronologyNumber: 2)]
        scene.soundNotes = [SoundNote(description: "shutter click",
                                      soundType: "effects", chronologyNumber: 4)]
        var bare = Scene(name: "Rooftop", description: "")
        bare.location = "Rooftop"
        var project = Project(name: "Test Film")
        project.sequences = [Sequence(name: "Act 1", scenes: [scene, bare])]

        let elements = ProjectOverviewBuilder.screenplayElements(project: project)

        XCTAssertEqual(elements, [
            ["type": "section", "text": "ACT 1"],
            ["type": "scene_heading", "text": "INT. PARLOR - NIGHT"],
            ["type": "action", "text": "A quiet parlor."],
            ["type": "character", "text": "MARA"],
            ["type": "parenthetical", "text": "(O.S.)"],
            ["type": "dialogue", "text": "That was my father's."],
            ["type": "action", "text": "She lifts the camera."],
            ["type": "character", "text": "MARA (CONT'D)"],
            ["type": "dialogue", "text": "Sorry."],
            ["type": "action", "text": "SFX: EFFECTS — shutter click"],
            ["type": "scene_heading", "text": "INT. ROOFTOP - DAY"],
        ], "standard screenplay walk: slug normalization, CONT'D, tag "
           + "parentheticals, HTML stripped, SFX as action lines")

        // And the deck carries it under the wire shape the tab gates on.
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("overview-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let deck = ProjectOverviewBuilder.deck(project: project,
                                               projectDir: dir, projectID: "p-1")
        let screenplay = deck["screenplay"] as? [String: Any]
        XCTAssertEqual(screenplay?["title"] as? String, "Test Film")
        XCTAssertEqual((screenplay?["elements"] as? [[String: String]])?.count,
                       elements.count)

        let empty = ProjectOverviewBuilder.screenplayElements(project: Project(name: "Empty"))
        XCTAssertTrue(empty.isEmpty, "no scenes → no screenplay key → no tab")
    }

    func testLocationCardCarriesDetailAndSceneContext() throws {
        // The portal's Story → Locations detail pane renders type, tags,
        // gallery, atmosphere, cinematography, and "appears in" — and its
        // rail selects by id. The deck used to send only {name, image}, so
        // clicking locations never switched (owner field report 2026-08-02).
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("overview-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: dir.appendingPathComponent("assets"),
            withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try Data("primary".utf8).write(to: dir.appendingPathComponent("assets/primary.png"))
        try Data("alt".utf8).write(to: dir.appendingPathComponent("assets/alt.png"))

        var estate = Location(name: "Estate House")
        estate.locationType = "indoor"
        estate.description = "Sun through dust."
        estate.tags = ["interior", "period-adjacent"]
        estate.images = ["assets/primary.png", "assets/alt.png"]
        estate.primaryImage = "assets/primary.png"
        estate.styleAttributes = ["mood": "hushed",
                                  "architecture": "1920s foursquare",
                                  "palette": "dust, oak, brass"]
        estate.cinematographyDefaults = ["lighting_style": "Window key, no fill",
                                         "time_of_day": "Day"]
        estate.notes = "Ask about the parlor."
        estate.angles = [LocationAngle(name: "Wide from the gate", description: "Cranes behind.",
                                       image: "assets/alt.png"),
                         LocationAngle(name: "Reverse toward the bar")]
        var swatched = Location(name: "Darkroom")
        swatched.styleAttributes = ["palette": "#331111, #886644"]

        var scene = Scene(name: "Opening", description: "")
        scene.location = "Estate House"
        var project = Project(name: "Test Film")
        project.locations = [estate, swatched]
        project.sequences = [Sequence(name: "Act 1", scenes: [scene])]

        let deck = ProjectOverviewBuilder.deck(project: project,
                                               projectDir: dir, projectID: "p-1")
        let cards = deck["locations"] as? [[String: Any]]

        XCTAssertEqual(cards?[0]["id"] as? String, estate.uuid,
                       "stable id — the rail selects and keys on it")
        XCTAssertEqual(cards?[0]["type"] as? String, "indoor")
        XCTAssertEqual(cards?[0]["description"] as? String, "Sun through dust.")
        XCTAssertEqual(cards?[0]["tags"] as? [String], ["interior", "period-adjacent"])
        XCTAssertEqual(cards?[0]["mood"] as? String, "hushed")
        XCTAssertEqual(cards?[0]["architecture"] as? String, "1920s foursquare")
        XCTAssertEqual(cards?[0]["cine_lighting"] as? String, "Window key, no fill")
        XCTAssertEqual(cards?[0]["cine_time"] as? String, "Day")
        XCTAssertEqual(cards?[0]["notes"] as? String, "Ask about the parlor.")
        XCTAssertEqual(cards?[0]["scene_context"] as? [String], ["Opening"])
        XCTAssertNotNil(cards?[0]["image"])
        let variations = cards?[0]["variations"] as? [[String: Any]]
        XCTAssertEqual(variations?.count, 1, "non-primary gallery images")
        XCTAssertEqual(variations?.first?["label"] as? String, "View 1")
        // DC-0125: named angles travel with the card, pictured or not.
        let angles = cards?[0]["angles"] as? [[String: Any]]
        XCTAssertEqual(angles?.map { $0["name"] as? String }, ["Wide from the gate", "Reverse toward the bar"])
        XCTAssertEqual(angles?.first?["description"] as? String, "Cranes behind.")
        XCTAssertNotNil(angles?.first?["image"], "a kept angle picture is a blob URL")
        XCTAssertNil(angles?.last?["image"], "an angle without a picture has none")
        XCTAssertNil(cards?[0]["color_palette"],
                     "descriptive palettes are not CSS colors — dropped")
        XCTAssertEqual(cards?[1]["color_palette"] as? [String],
                       ["#331111", "#886644"], "hex palettes become swatches")
        XCTAssertTrue(JSONSerialization.isValidJSONObject(deck))
    }

    func testShotLinkedContentAndSceneBubbles() throws {
        // The shot page lists the dialogue/action the shot covers (resolved
        // from Connections links); the scene detail renders the bubble view.
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("overview-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let line = Dialogue(character: "Mara", text: "That was my father's.",
                            tags: ["O.S."], chronologyNumber: 1)
        var beat = Action(description: "She lifts the camera.", chronologyNumber: 2)
        beat.parentDialogueId = line.uuid            // sub-bubble
        var shot = Shot(shotId: 1, shotType: "Wide")
        shot.lightingStyle = "Low-key"
        shot.linkedDialogueIds = [line.uuid]
        shot.linkedActionIds = [beat.uuid]
        var scene = Scene(name: "Opening", description: "")
        scene.dialogues = [line]
        scene.actions = [beat]
        scene.soundNotes = [SoundNote(description: "shutter click",
                                      soundType: "effects", chronologyNumber: 3)]
        scene.shots = [shot]
        var mara = Character(name: "Mara")
        mara.color = "#4a9eff"
        var project = Project(name: "Test Film")
        project.characters = [mara]
        project.sequences = [Sequence(name: "Act 1", scenes: [scene])]

        let deck = ProjectOverviewBuilder.deck(project: project,
                                               projectDir: dir, projectID: "p-1")

        let card = (deck["shots"] as? [[String: Any]])?.first
        XCTAssertEqual(card?["lighting"] as? String, "Low-key")
        XCTAssertEqual(card?["dialogue_lines"] as? [String],
                       ["MARA: That was my father's."])
        XCTAssertEqual(card?["action_lines"] as? [String],
                       ["She lifts the camera."])

        let sceneEntry = (deck["scenes"] as? [[String: Any]])?.first
        let bubbles = sceneEntry?["bubbles"] as? [[String: Any]]
        XCTAssertEqual(bubbles?.map { $0["kind"] as? String },
                       ["dialogue", "action", "sound"],
                       "chronological, sub-bubbles included")
        XCTAssertEqual(bubbles?[0]["character"] as? String, "Mara")
        XCTAssertEqual(bubbles?[0]["color"] as? String, "#4a9eff",
                       "dialogue bubble carries the speaker's color")
        XCTAssertEqual(bubbles?[0]["tags"] as? [String], ["O.S."])
        XCTAssertEqual(bubbles?[2]["text"] as? String, "EFFECTS: shutter click")

        // The screenplay projection still excludes the sub-bubble action.
        let elements = ProjectOverviewBuilder.screenplayElements(project: project)
        XCTAssertFalse(elements.contains { $0["text"] == "She lifts the camera." },
                       "sub-bubbles stay out of the script, as on desktop")
    }

    func testPropsVisionAndProductionProjection() throws {
        // Final parity sweep: the portal's Story→Props, Vision board, and
        // Production tabs gate on deck sections the desktop never sent.
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("overview-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: dir.appendingPathComponent("assets"),
            withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try Data("prop".utf8).write(to: dir.appendingPathComponent("assets/prop.png"))
        try Data("vision".utf8).write(to: dir.appendingPathComponent("assets/vision.png"))

        var project = Project(name: "Test Film")

        var rangefinder = Prop(name: "Rangefinder", thumbnail: "assets/prop.png")
        rangefinder.category = "Camera"
        rangefinder.status = "In Use"
        rangefinder.description = "The key object."
        rangefinder.detailedSpecs = "1950s, engraved."
        rangefinder.continuityNotes = "Strap frays in Act 2."
        rangefinder.sceneNames = ["Opening", "Opening", "Finale"]
        project.props = [rangefinder]

        var palette = VisionCard(title: "Palette")
        palette.cardType = "color_palette"
        palette.colorPalette = ["#0b2a34", "#0b2a34", "dust"]
        palette.position = 0
        var note = VisionCard(title: "Director's note")
        note.cardType = "text"
        note.text = "Listening, not spectacle."
        note.department = "production_design"
        note.position = 1
        var still = VisionCard(title: "Aurora")
        still.cardType = "image"
        still.imagePath = "assets/vision.png"
        still.pinned = true
        still.position = 2
        project.beats = [note, still, palette]   // out of position order

        var day = ScheduleItem()
        day.sceneName = "Day 1 — interiors"
        day.shootDate = "2026-08-15"
        day.status = "Planned"
        day.estimatedDurationHours = 8
        day.requiredActors = ["Nadia Sorel", "Nadia Sorel"]
        project.scheduleItems = [day]

        var task = GanttTask(name: "Shoot", category: .shooting)
        task.startDate = "2026-08-15"
        task.durationDays = 2
        task.completionPercentage = 40
        var lock = GanttTask(name: "Script lock", category: .preProduction)
        lock.startDate = "2026-07-20"
        lock.isMilestone = true
        project.ganttTasks = [task, lock]

        var lead = CastMember(actorName: "Nadia Sorel", characterName: "Mara")
        lead.roleType = "Principal"
        project.castMembers = [lead]
        var dp = CrewMember(name: "Marisol Vega", role: "DP")
        dp.department = "Camera"
        project.crewMembers = [dp]
        var unit = Team(name: "A-Camera Unit")
        unit.crewMemberIds = [dp.id]
        unit.teamLeadId = dp.id
        project.teams = [unit]

        project.projectBudget = ProjectBudget(
            categories: [BudgetCategory(name: "Camera", allocated: 320),
                         BudgetCategory(name: "Camera", allocated: 80),
                         BudgetCategory(name: "Cast", allocated: 480)],
            expenses: [Expense(category: "Camera", amount: 140,
                               department: "Camera")],
            totalBudget: 18_500)

        var camera = EquipmentItem(name: "Sony FX6")
        camera.category = "Camera"
        camera.isRental = true
        camera.rentalDailyRate = 285
        var allocation = EquipmentAllocation(equipmentItemId: camera.id)
        allocation.allocationMode = .fullProduction
        project.equipmentLibrary = [camera]
        project.equipmentAllocations = [allocation]

        let deck = ProjectOverviewBuilder.deck(project: project,
                                               projectDir: dir, projectID: "p-1")

        let props = deck["props"] as? [[String: Any]]
        XCTAssertEqual(props?.first?["name"] as? String, "Rangefinder")
        XCTAssertEqual(props?.first?["specs"] as? String, "1950s, engraved.")
        XCTAssertEqual(props?.first?["continuity"] as? String, "Strap frays in Act 2.")
        XCTAssertEqual(props?.first?["scenes"] as? [String], ["Opening", "Finale"],
                       "scene chips are React keys — deduped")
        XCTAssertNotNil(props?.first?["image"])

        let vision = deck["vision_board"] as? [[String: Any]]
        XCTAssertEqual(vision?.map { $0["title"] as? String },
                       ["Palette", "Director's note", "Aurora"],
                       "cards ordered by position")
        XCTAssertEqual(vision?[0]["color_palette"] as? [String], ["#0b2a34"],
                       "hex-only, deduped swatches")
        XCTAssertEqual(vision?[1]["department"] as? String, "Production Design")
        XCTAssertEqual(vision?[2]["pinned"] as? Bool, true)
        XCTAssertNotNil(vision?[2]["image"])

        let production = deck["production"] as? [String: Any]
        let schedule = production?["schedule"] as? [[String: Any]]
        XCTAssertEqual(schedule?.first?["shoot_date"] as? String, "2026-08-15")
        XCTAssertEqual(schedule?.first?["cast"] as? [String], ["Nadia Sorel"],
                       "chips deduped")
        let gantt = production?["gantt"] as? [[String: Any]]
        XCTAssertEqual(gantt?[0]["end_date"] as? String, "2026-08-16",
                       "duration folds into end_date — the portal draws bars from it")
        XCTAssertEqual(gantt?[1]["is_milestone"] as? Bool, true)
        XCTAssertNil(gantt?[1]["end_date"], "milestones render as markers")
        let cast = production?["cast"] as? [[String: Any]]
        XCTAssertEqual(cast?.first?["shoot_days"] as? Int, 1,
                       "derived from schedule membership")
        let teams = production?["teams"] as? [[String: Any]]
        XCTAssertEqual(teams?.first?["lead"] as? String, "Marisol Vega",
                       "lead id resolves to a name")
        let budget = production?["budget"] as? [String: Any]
        let categories = budget?["categories"] as? [[String: Any]]
        XCTAssertEqual(categories?.count, 2,
                       "duplicate category names merge — the portal keys rows by name")
        XCTAssertEqual(categories?.first?["allocated"] as? Double, 400)
        XCTAssertEqual((budget?["by_department"] as? [[String: Any]])?.first?["name"] as? String,
                       "Camera")
        let equipment = production?["equipment"] as? [[String: Any]]
        XCTAssertEqual(equipment?.first?["allocation"] as? String, "Full production")
        XCTAssertEqual(equipment?.first?["rental_daily_rate"] as? Double, 285)

        XCTAssertTrue(JSONSerialization.isValidJSONObject(deck))

        // Empty projects omit all three sections (tabs stay hidden).
        let bare = ProjectOverviewBuilder.deck(project: Project(name: "Bare"),
                                               projectDir: dir, projectID: "p-2")
        XCTAssertNil(bare["props"])
        XCTAssertNil(bare["vision_board"])
        XCTAssertNil(bare["production"])
    }

    func testDecodeProjectHandlesISO8601DatesFromPersistence() throws {
        // Persistence writes dates as ISO-8601 (ProjectPersistence's
        // encoder); the overview push must decode the same dialect. The
        // owner's project silently skipped every push because a bare
        // JSONDecoder threw on Character.createdAt.
        var project = Project(name: "Dated")
        var maya = Character(name: "Maya")
        maya.createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        maya.traitsLastCalibrated = Date(timeIntervalSince1970: 1_750_000_000)
        project.characters = [maya]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(project)

        XCTAssertThrowsError(try JSONDecoder().decode(Project.self, from: data),
                             "bare decoder rejects ISO dates — the original bug")
        let decoded = try SyncEngine.decodeProject(data)
        XCTAssertEqual(decoded.characters.first?.createdAt,
                       Date(timeIntervalSince1970: 1_700_000_000))
    }

    /// DC-0074: the user's notes on a scene and on a shot reach the portal's
    /// deck — a shot's on its card, a scene's on its entry — and never as an
    /// empty field.
    func testSceneAndShotNotesAreProjected() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("dc-notes-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        var noted = Shot(shotId: 1, description: "Wide on the gallery")
        noted.notes = "Fog machine below the rail."
        let plain = Shot(shotId: 2, description: "Insert")
        var scene = Scene(name: "Last Light", description: "Dusk on the gallery")
        scene.notes = "Golden-hour window 19:40–20:05."
        scene.shots = [noted, plain]
        var project = Project(name: "Keeper's Light")
        project.sequences = [Sequence(name: "One night", scenes: [scene])]

        let deck = ProjectOverviewBuilder.deck(project: project, projectDir: dir, projectID: "p-1")
        let board = try XCTUnwrap(deck["shots"] as? [[String: Any]])
        XCTAssertEqual(board[0]["notes"] as? String, "Fog machine below the rail.")
        XCTAssertNil(board[1]["notes"], "no empty notes field on the card")
        let scenes = try XCTUnwrap(deck["scenes"] as? [[String: Any]])
        XCTAssertEqual(scenes[0]["notes"] as? String, "Golden-hour window 19:40–20:05.")
    }
}

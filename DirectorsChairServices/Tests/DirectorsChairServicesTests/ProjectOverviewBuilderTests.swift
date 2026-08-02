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
}

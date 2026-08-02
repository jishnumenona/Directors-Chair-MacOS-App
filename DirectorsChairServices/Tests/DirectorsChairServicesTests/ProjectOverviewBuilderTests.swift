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

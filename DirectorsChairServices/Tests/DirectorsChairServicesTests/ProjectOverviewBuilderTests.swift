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
                       "/api/v1/projects/p-123/blobs/\(sha)",
                       "images become same-origin blob URLs by content sha")
        XCTAssertNil(characters?[1]["portrait"], "missing artwork omitted")

        let scenes = deck["scenes"] as? [[String: Any]]
        XCTAssertEqual(scenes?.count, 1)
        XCTAssertEqual(scenes?[0]["summary"] as? String, "Night. Rain.")
        XCTAssertEqual((scenes?[0]["shots"] as? [[String: Any]])?.first?["shot_type"] as? String,
                       "Wide")

        let stats = deck["stats"] as? [String: Int]
        XCTAssertEqual(stats, ["characters": 2, "locations": 1,
                               "scenes": 1, "shots": 1])

        XCTAssertTrue(JSONSerialization.isValidJSONObject(deck),
                      "the deck must serialize for the PUT body")
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

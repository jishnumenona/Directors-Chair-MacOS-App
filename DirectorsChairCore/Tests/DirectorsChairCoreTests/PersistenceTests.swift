// DirectorsChairCore/Tests/DirectorsChairCoreTests/PersistenceTests.swift
//
// Tests for JSON persistence round-trip compatibility

import XCTest
@testable import DirectorsChairCore

final class PersistenceTests: XCTestCase {

    var persistence: ProjectPersistence!
    var tempDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()
        persistence = ProjectPersistence(enableBackups: false)
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DirectorsChairTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try await super.tearDown()
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try FileManager.default.removeItem(at: tempDirectory)
        }
    }

    // MARK: - Basic Save/Load Tests

    func testSaveAndLoadEmptyProject() async throws {
        // Create minimal project
        let originalProject = Project(name: "Test Project")
        let fileURL = tempDirectory.appendingPathComponent("project.json")

        // Save project
        try await persistence.save(originalProject, to: fileURL)

        // Verify file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        // Load project
        let loadedProject = try await persistence.load(from: fileURL)

        // Verify basic properties
        XCTAssertEqual(loadedProject.name, originalProject.name)
        XCTAssertEqual(loadedProject.description, originalProject.description)
        XCTAssertEqual(loadedProject.director, originalProject.director)
    }

    func testSaveAndLoadProjectWithCharacters() async throws {
        // Create project with characters
        let character1 = Character(name: "John Doe", role: "Protagonist")
        let character2 = Character(name: "Jane Smith", role: "Antagonist")
        let originalProject = Project(
            name: "Character Test",
            characters: [character1, character2]
        )
        let fileURL = tempDirectory.appendingPathComponent("project.json")

        // Save and load
        try await persistence.save(originalProject, to: fileURL)
        let loadedProject = try await persistence.load(from: fileURL)

        // Verify characters
        XCTAssertEqual(loadedProject.characters.count, 2)
        XCTAssertEqual(loadedProject.characters[0].name, "John Doe")
        XCTAssertEqual(loadedProject.characters[1].name, "Jane Smith")
    }

    func testSaveAndLoadComplexProject() async throws {
        // Create comprehensive project
        let character = Character(name: "Test Character", role: "Lead")
        let prop = Prop(name: "Magic Sword", description: "Ancient weapon")
        let costume = Costume(name: "Hero Outfit", notes: "Primary costume")
        let location = Location(name: "Castle", description: "Main location")
        let visionCard = VisionCard(title: "Opening Shot", description: "Sunrise over castle")
        let filmStyle = FilmStyle(name: "Cinematic", description: "High contrast, warm tones")
        let castMember = CastMember(actorName: "Actor Name", characterName: "Test Character")
        let crewMember = CrewMember(name: "Director Name", role: "Director")

        let originalProject = Project(
            name: "Complex Test Project",
            description: "A test project with all data types",
            director: "Test Director",
            genre: "Action",
            projectType: "Motion Film",
            characters: [character],
            props: [prop],
            costumes: [costume],
            locations: [location],
            beats: [visionCard],
            filmStyles: [filmStyle],
            castMembers: [castMember],
            crewMembers: [crewMember]
        )

        let fileURL = tempDirectory.appendingPathComponent("complex_project.json")

        // Save and load
        try await persistence.save(originalProject, to: fileURL)
        let loadedProject = try await persistence.load(from: fileURL)

        // Verify all collections
        XCTAssertEqual(loadedProject.name, originalProject.name)
        XCTAssertEqual(loadedProject.characters.count, 1)
        XCTAssertEqual(loadedProject.props.count, 1)
        XCTAssertEqual(loadedProject.costumes.count, 1)
        XCTAssertEqual(loadedProject.locations.count, 1)
        XCTAssertEqual(loadedProject.beats.count, 1)
        XCTAssertEqual(loadedProject.filmStyles.count, 1)
        XCTAssertEqual(loadedProject.castMembers.count, 1)
        XCTAssertEqual(loadedProject.crewMembers.count, 1)

        // Verify nested properties
        XCTAssertEqual(loadedProject.characters[0].name, "Test Character")
        XCTAssertEqual(loadedProject.props[0].name, "Magic Sword")
        XCTAssertEqual(loadedProject.costumes[0].name, "Hero Outfit")
    }

    // MARK: - JSON Format Tests

    func testJSONKeysUseSnakeCase() async throws {
        let project = Project(
            name: "Snake Case Test",
            basePath: "/test/path",
            productionCompany: "Test Company"
        )
        let fileURL = tempDirectory.appendingPathComponent("project.json")

        // Save project
        try await persistence.save(project, to: fileURL)

        // Read raw JSON
        let jsonData = try Data(contentsOf: fileURL)
        let jsonString = String(data: jsonData, encoding: .utf8)!

        // base_path is device-local runtime state and must NOT be serialized.
        XCTAssertFalse(jsonString.contains("\"base_path\""),
                       "base_path must not be written to the portable wire format")
        // Verify snake_case keys are present
        XCTAssertTrue(jsonString.contains("\"production_company\""))
        XCTAssertTrue(jsonString.contains("\"project_type\""))
    }

    func testJSONIsPrettyPrinted() async throws {
        let project = Project(name: "Pretty Print Test")
        let fileURL = tempDirectory.appendingPathComponent("project.json")

        // Save project
        try await persistence.save(project, to: fileURL)

        // Read raw JSON
        let jsonString = try String(contentsOf: fileURL, encoding: .utf8)

        // Verify pretty printing (contains newlines and indentation)
        XCTAssertTrue(jsonString.contains("\n"))
        XCTAssertTrue(jsonString.contains("  ")) // Indentation
    }

    // MARK: - Error Handling Tests

    func testLoadNonexistentFile() async throws {
        let fileURL = tempDirectory.appendingPathComponent("nonexistent.json")

        do {
            _ = try await persistence.load(from: fileURL)
            XCTFail("Should throw fileNotFound error")
        } catch let error as ProjectError {
            if case .fileNotFound = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    func testLoadInvalidJSON() async throws {
        let fileURL = tempDirectory.appendingPathComponent("invalid.json")

        // Write invalid JSON
        let invalidJSON = "{ invalid json }"
        try invalidJSON.write(to: fileURL, atomically: true, encoding: .utf8)

        do {
            _ = try await persistence.load(from: fileURL)
            XCTFail("Should throw an error for invalid JSON")
        } catch let error as ProjectError {
            // Accept either decodingFailed or invalidJSON - both are valid for malformed JSON
            switch error {
            case .decodingFailed, .invalidJSON:
                break // Expected
            default:
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - Validation Tests

    func testValidateValidFile() async throws {
        let project = Project(name: "Valid Project")
        let fileURL = tempDirectory.appendingPathComponent("valid.json")

        try await persistence.save(project, to: fileURL)

        let isValid = await persistence.validate(url: fileURL)
        XCTAssertTrue(isValid)
    }

    func testValidateInvalidFile() async throws {
        let fileURL = tempDirectory.appendingPathComponent("invalid.json")
        try "invalid".write(to: fileURL, atomically: true, encoding: .utf8)

        let isValid = await persistence.validate(url: fileURL)
        XCTAssertFalse(isValid)
    }
}


// MARK: - Backup rotation (audit 2026-08-28)

final class BackupRotationTests: XCTestCase {
    /// Copies of a file replaced in place all shared one birth time, so the
    /// ring sorted on creation date dropped arbitrary — usually the newest —
    /// backups. It now keeps the five most recent writes.
    func testRotationKeepsTheFiveNewestBackups() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("backup-rotation-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("project.json")
        let persistence = ProjectPersistence(maxBackups: 5)
        for version in 1...7 {
            try await persistence.save(Project(name: "v\(version)"), to: url)
            try await Task.sleep(nanoseconds: 1_050_000_000)   // distinct write times and names
        }
        let backups = try FileManager.default.contentsOfDirectory(at: dir.appendingPathComponent(".backups"),
                                                                  includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("project_") }
        XCTAssertEqual(backups.count, 5)
        let names = try backups.map { try JSONDecoder().decode(Project.self, from: Data(contentsOf: $0)).name }
        XCTAssertEqual(Set(names), ["v2", "v3", "v4", "v5", "v6"],
                       "the backups are of the six previous files; the oldest (v1) is the one to go")
    }
}

import XCTest
@testable import DirectorsChair_Desktop

/// JSON Compatibility Test Suite
///
/// CRITICAL: This is the #1 test priority for the Swift migration.
/// These tests validate that the Swift app can load Python-generated project.json files
/// and that Python can load Swift-generated project.json files (round-trip compatibility).
///
/// Reference: docs/agents/agent_5_qa/INSTRUCTIONS.md - Phase 1, Task 2
final class JSONCompatibilityTests: XCTestCase {

    var testFixturesURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Get the test bundle and locate fixtures directory
        let bundle = Bundle(for: type(of: self))
        testFixturesURL = bundle.resourceURL?
            .appendingPathComponent("Fixtures")

        XCTAssertNotNil(testFixturesURL, "Test fixtures directory must exist")
    }

    override func tearDownWithError() throws {
        testFixturesURL = nil
        try super.tearDownWithError()
    }

    // MARK: - Basic JSON Loading Tests

    func testLoadMinimalPythonProject() throws {
        // Load a minimal project.json created by Python app
        let minimalProjectURL = testFixturesURL
            .appendingPathComponent("minimal_project.json")

        guard FileManager.default.fileExists(atPath: minimalProjectURL.path) else {
            XCTFail("minimal_project.json fixture not found")
            return
        }

        let data = try Data(contentsOf: minimalProjectURL)

        // Decode to Swift Project model
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // TODO: Once DirectorsChairCore module is implemented by Agent 1,
        // uncomment this line:
        // let project = try decoder.decode(Project.self, from: data)

        // TODO: Validate basic fields
        // XCTAssertEqual(project.name, "Minimal Test Project")
        // XCTAssertEqual(project.projectType, "Skit")
        // XCTAssertEqual(project.status, "Pre-production")
        // XCTAssertEqual(project.languages, ["English"])
        // XCTAssertEqual(project.sequences.count, 1)
        // XCTAssertEqual(project.sequences[0].scenes.count, 1)

        // For now, just validate JSON structure
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json)
        XCTAssertEqual(json?["name"] as? String, "Minimal Test Project")
        XCTAssertEqual(json?["project_type"] as? String, "Skit")
    }

    func testLoadComprehensivePythonProject() throws {
        // Load a comprehensive project.json with all fields populated
        let comprehensiveProjectURL = testFixturesURL
            .appendingPathComponent("comprehensive_project.json")

        guard FileManager.default.fileExists(atPath: comprehensiveProjectURL.path) else {
            XCTFail("comprehensive_project.json fixture not found")
            return
        }

        let data = try Data(contentsOf: comprehensiveProjectURL)

        // Decode to Swift Project model
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // TODO: Once DirectorsChairCore module is implemented by Agent 1,
        // uncomment these validations:
        // let project = try decoder.decode(Project.self, from: data)

        // TODO: Validate project metadata
        // XCTAssertEqual(project.name, "Comprehensive Test Project")
        // XCTAssertEqual(project.description, "A feature film about space exploration")
        // XCTAssertEqual(project.director, "Jane Director")
        // XCTAssertEqual(project.productionCompany, "Test Studios")
        // XCTAssertEqual(project.genre, "Sci-Fi")
        // XCTAssertEqual(project.projectType, "Motion Film")
        // XCTAssertEqual(project.targetDuration, "120 minutes")
        // XCTAssertEqual(project.budget, "$5,000,000")

        // TODO: Validate characters (2 characters with full details)
        // XCTAssertEqual(project.characters.count, 2)
        // let sarah = project.characters[0]
        // XCTAssertEqual(sarah.name, "Captain Sarah Chen")
        // XCTAssertEqual(sarah.role, "Protagonist")
        // XCTAssertEqual(sarah.gender, "female")
        // XCTAssertEqual(sarah.age, 35)
        // XCTAssertEqual(sarah.heightCm, 170.0)
        // XCTAssertEqual(sarah.build, "Athletic")
        // XCTAssertEqual(sarah.courage, 90)
        // XCTAssertEqual(sarah.intelligence, 85)

        // TODO: Validate dialogues
        // let scene = project.sequences[0].scenes[0]
        // XCTAssertEqual(scene.dialogues.count, 3)
        // XCTAssertEqual(scene.dialogues[0].character, "Captain Sarah Chen")
        // XCTAssertEqual(scene.dialogues[0].text, "All systems check. Are we ready for departure?")
        // XCTAssertEqual(scene.dialogues[0].tags, ["commanding", "confident"])

        // For now, validate JSON structure
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json)
        XCTAssertEqual(json?["name"] as? String, "Comprehensive Test Project")

        // Validate characters array
        let characters = json?["characters"] as? [[String: Any]]
        XCTAssertEqual(characters?.count, 2)
        XCTAssertEqual(characters?[0]["name"] as? String, "Captain Sarah Chen")
        XCTAssertEqual(characters?[0]["age"] as? Int, 35)
    }

    // MARK: - Character Model Tests

    func testCharacterWith70PlusFields() throws {
        let comprehensiveProjectURL = testFixturesURL
            .appendingPathComponent("comprehensive_project.json")
        let data = try Data(contentsOf: comprehensiveProjectURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        let characters = json?["characters"] as? [[String: Any]]
        XCTAssertNotNil(characters)
        XCTAssertGreaterThanOrEqual(characters?.count ?? 0, 1)

        let sarah = characters?[0]

        // Validate basic fields
        XCTAssertEqual(sarah?["name"] as? String, "Captain Sarah Chen")
        XCTAssertEqual(sarah?["role"] as? String, "Protagonist")
        XCTAssertEqual(sarah?["color"] as? String, "#4A90E2")
        XCTAssertEqual(sarah?["text_color"] as? String, "#FFFFFF")

        // Validate physical appearance fields
        XCTAssertEqual(sarah?["height_cm"] as? Double, 170.0)
        XCTAssertEqual(sarah?["weight_kg"] as? Double, 65.0)
        XCTAssertEqual(sarah?["build"] as? String, "Athletic")
        XCTAssertEqual(sarah?["age"] as? Int, 35)
        XCTAssertEqual(sarah?["hair_color"] as? String, "#2C1810")
        XCTAssertEqual(sarah?["eye_shape"] as? String, "Almond")
        XCTAssertEqual(sarah?["skin_tone"] as? String, "#D4A574")
        XCTAssertEqual(sarah?["ethnicity"] as? String, "Asian")
        XCTAssertEqual(sarah?["facial_structure"] as? String, "Oval")

        // Validate 25 personality traits
        XCTAssertEqual(sarah?["openness"] as? Int, 75)
        XCTAssertEqual(sarah?["conscientiousness"] as? Int, 85)
        XCTAssertEqual(sarah?["extraversion"] as? Int, 60)
        XCTAssertEqual(sarah?["agreeableness"] as? Int, 70)
        XCTAssertEqual(sarah?["neuroticism"] as? Int, 30)
        XCTAssertEqual(sarah?["courage"] as? Int, 90)
        XCTAssertEqual(sarah?["intelligence"] as? Int, 85)
        XCTAssertEqual(sarah?["empathy"] as? Int, 75)
        XCTAssertEqual(sarah?["loyalty"] as? Int, 95)
        XCTAssertEqual(sarah?["honesty"] as? Int, 90)

        // Validate biography fields
        XCTAssertNotNil(sarah?["biography_backstory"])
        XCTAssertNotNil(sarah?["biography_occupation"])
        XCTAssertNotNil(sarah?["biography_education"])
        XCTAssertNotNil(sarah?["biography_goals"])

        // Validate image fields
        XCTAssertNotNil(sarah?["base_image"])
        XCTAssertNotNil(sarah?["image_front"])
        XCTAssertNotNil(sarah?["image_three_quarter_left"])

        // Validate relationships
        let relationships = sarah?["relationships"] as? [[String: Any]]
        XCTAssertNotNil(relationships)
        XCTAssertEqual(relationships?.count, 1)

        // Validate costumes
        let costumes = sarah?["costumes"] as? [[String: Any]]
        XCTAssertNotNil(costumes)
        XCTAssertEqual(costumes?.count, 1)
    }

    // MARK: - Round-Trip Compatibility Tests

    func testSwiftPythonRoundTrip() throws {
        // TODO: This test will be implemented once Agent 1 completes DirectorsChairCore

        // 1. Load Python project
        // let pythonProjectURL = testFixturesURL.appendingPathComponent("comprehensive_project.json")
        // let pythonProject = try loadProject(from: pythonProjectURL)

        // 2. Save with Swift
        // let tempURL = FileManager.default.temporaryDirectory
        //     .appendingPathComponent("swift_save_\(UUID().uuidString).json")
        // try ProjectPersistence().saveProject(pythonProject, to: tempURL)

        // 3. Verify JSON structure unchanged
        // let originalJSON = try loadJSONDictionary(pythonProjectURL)
        // let swiftJSON = try loadJSONDictionary(tempURL)

        // 4. Deep comparison of all fields
        // XCTAssertEqual(Set(originalJSON.keys), Set(swiftJSON.keys), "Top-level keys must match")
        // compareJSONDictionaries(originalJSON, swiftJSON)

        // 5. Cleanup
        // try? FileManager.default.removeItem(at: tempURL)

        XCTExpectFailure("This test requires DirectorsChairCore module from Agent 1")
        XCTFail("Round-trip test not yet implemented - waiting on Agent 1")
    }

    func testJSONFieldNaming() throws {
        // Validate that CodingKeys correctly map snake_case (Python) to camelCase (Swift)
        let comprehensiveProjectURL = testFixturesURL
            .appendingPathComponent("comprehensive_project.json")
        let data = try Data(contentsOf: comprehensiveProjectURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Verify Python uses snake_case
        XCTAssertNotNil(json?["project_type"])
        XCTAssertNotNil(json?["target_duration"])
        XCTAssertNotNil(json?["production_company"])
        XCTAssertNotNil(json?["project_notes"])
        XCTAssertNotNil(json?["default_film_style"])

        let characters = json?["characters"] as? [[String: Any]]
        let sarah = characters?[0]
        XCTAssertNotNil(sarah?["text_color"])
        XCTAssertNotNil(sarah?["height_cm"])
        XCTAssertNotNil(sarah?["hair_color"])
        XCTAssertNotNil(sarah?["eye_shape"])
        XCTAssertNotNil(sarah?["base_image"])

        // TODO: Once Agent 1 implements CodingKeys, verify Swift decodes correctly:
        // let project = try decoder.decode(Project.self, from: data)
        // XCTAssertEqual(project.projectType, "Motion Film")  // camelCase in Swift
        // XCTAssertEqual(project.targetDuration, "120 minutes")
        // XCTAssertEqual(sarah.textColor, "#FFFFFF")
        // XCTAssertEqual(sarah.heightCm, 170.0)
    }

    // MARK: - Performance Tests

    func testLoadPerformance() throws {
        let comprehensiveProjectURL = testFixturesURL
            .appendingPathComponent("comprehensive_project.json")

        // Target: <500ms for typical project
        measure {
            do {
                let data = try Data(contentsOf: comprehensiveProjectURL)
                let _ = try JSONSerialization.jsonObject(with: data)

                // TODO: Once Agent 1 implements Project model:
                // let decoder = JSONDecoder()
                // let _ = try decoder.decode(Project.self, from: data)
            } catch {
                XCTFail("Failed to load project: \(error)")
            }
        }
    }

    // MARK: - Helper Methods

    private func loadJSONDictionary(_ url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "JSONCompatibilityTests", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Invalid JSON structure"])
        }
        return json
    }

    private func compareJSONDictionaries(_ dict1: [String: Any], _ dict2: [String: Any],
                                        path: String = "root") {
        // Deep comparison utility for round-trip validation
        for key in dict1.keys {
            XCTAssertNotNil(dict2[key], "Missing key '\(key)' at path '\(path)'")

            // TODO: Implement deep comparison logic
            // Compare values recursively for nested dictionaries and arrays
        }
    }
}

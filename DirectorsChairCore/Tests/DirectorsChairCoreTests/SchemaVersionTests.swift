// SchemaVersionTests.swift
//
// WS2.4 — verify project.json carries a schema_version, legacy files decode as
// v1, and the loader refuses documents from a newer major version.

import XCTest
@testable import DirectorsChairCore

final class SchemaVersionTests: XCTestCase {

    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("dc-schema-\(UUID().uuidString).json")
    }

    func testNewProjectCarriesCurrentSchemaVersion() {
        XCTAssertEqual(Project(name: "x").schemaVersion, Project.currentSchemaVersion)
    }

    func testEncodedJSONContainsSchemaVersionKey() throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(Project(name: "x"))
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(json.contains("\"schema_version\""),
                      "Persisted project must include the schema_version key")
    }

    func testLegacyFileWithoutVersionDecodesAsV1() throws {
        // A pre-versioning document has no schema_version key.
        let legacy = #"{ "name": "Legacy Project" }"#
        let project = try JSONDecoder().decode(Project.self, from: Data(legacy.utf8))
        XCTAssertEqual(project.schemaVersion, 1)
        XCTAssertEqual(project.name, "Legacy Project")
    }

    func testLoadRefusesNewerSchemaVersion() async throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let future = Project.currentSchemaVersion + 1
        let json = "{ \"name\": \"From The Future\", \"schema_version\": \(future) }"
        try Data(json.utf8).write(to: url)

        let persistence = ProjectPersistence(enableBackups: false)
        do {
            _ = try await persistence.load(from: url)
            XCTFail("Loading a newer-version file should throw")
        } catch let ProjectError.unsupportedSchemaVersion(found, supported) {
            XCTAssertEqual(found, future)
            XCTAssertEqual(supported, Project.currentSchemaVersion)
        }
    }

    func testCurrentVersionRoundTripsThroughPersistence() async throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let persistence = ProjectPersistence(enableBackups: false)

        try await persistence.save(Project(name: "RoundTrip"), to: url)
        let loaded = try await persistence.load(from: url)
        XCTAssertEqual(loaded.schemaVersion, Project.currentSchemaVersion)
        XCTAssertEqual(loaded.name, "RoundTrip")
    }

    // WS2.6 — basePath is device-local: not serialized, but populated at load
    // from the file's own directory so it is always correct on any machine.
    func testLoadPopulatesBasePathFromFileLocation() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dc-proj-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("project.json")
        let persistence = ProjectPersistence(enableBackups: false)

        // Save with a bogus basePath — it must not survive into the file.
        var project = Project(name: "Portable")
        project.basePath = "/some/other/machine/path"
        try await persistence.save(project, to: url)

        let json = String(decoding: try Data(contentsOf: url), as: UTF8.self)
        XCTAssertFalse(json.contains("base_path"), "basePath must not be serialized")
        XCTAssertFalse(json.contains("/some/other/machine/path"))

        let loaded = try await persistence.load(from: url)
        XCTAssertEqual(loaded.basePath, dir.path,
                       "load must populate basePath from the file's own directory")
    }
}

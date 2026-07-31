// DirectorsChair-DesktopTests/ExampleProjectInstallTests.swift
//
// Asset-bundle extraction for downloadable example projects: a real zip
// (built with ditto, the same tool the installer uses) merges into the
// project directory; hostile bundles — symlinks, ../ escapes — are
// rejected wholesale.

import XCTest
@testable import DirectorsChair_Desktop

final class ExampleProjectInstallTests: XCTestCase {

    private var workDir: URL!
    private var projectDir: URL!

    override func setUpWithError() throws {
        workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("example-install-\(UUID().uuidString)")
        projectDir = workDir.appendingPathComponent("Project")
        try FileManager.default.createDirectory(at: projectDir,
                                                withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: workDir)
    }

    /// Zips the given directory's CONTENTS the way the publisher will.
    private func zip(contentsOf dir: URL) throws -> Data {
        let zipFile = workDir.appendingPathComponent("\(UUID().uuidString).zip")
        let ditto = Process()
        ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        ditto.arguments = ["-c", "-k", dir.path, zipFile.path]
        try ditto.run()
        ditto.waitUntilExit()
        XCTAssertEqual(ditto.terminationStatus, 0)
        return try Data(contentsOf: zipFile)
    }

    private func makeBundleSource() throws -> URL {
        let source = workDir.appendingPathComponent("bundle-src")
        try FileManager.default.createDirectory(
            at: source.appendingPathComponent("assets/characters/mara"),
            withIntermediateDirectories: true)
        try Data("png-bytes".utf8).write(
            to: source.appendingPathComponent("assets/characters/mara/portrait.png"))
        try Data("poster".utf8).write(
            to: source.appendingPathComponent("poster.png"))
        return source
    }

    func testBundleMergesIntoProjectDirectory() throws {
        // Pre-existing file (project.json written in step 4) must survive.
        try Data("{}".utf8).write(
            to: projectDir.appendingPathComponent("project.json"))
        let data = try zip(contentsOf: makeBundleSource())

        try ExampleProjectManager.installAssets(zipData: data, into: projectDir)

        XCTAssertEqual(try String(contentsOf: projectDir
            .appendingPathComponent("assets/characters/mara/portrait.png"),
            encoding: .utf8), "png-bytes")
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: projectDir.appendingPathComponent("poster.png").path))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: projectDir.appendingPathComponent("project.json").path))
    }

    func testExistingFileIsReplacedNotDuplicated() throws {
        try Data("old".utf8).write(to: projectDir.appendingPathComponent("poster.png"))
        let data = try zip(contentsOf: makeBundleSource())

        try ExampleProjectManager.installAssets(zipData: data, into: projectDir)

        XCTAssertEqual(try String(contentsOf: projectDir
            .appendingPathComponent("poster.png"), encoding: .utf8), "poster")
    }

    func testSymlinkEntriesAreRejected() throws {
        let source = try makeBundleSource()
        try FileManager.default.createSymbolicLink(
            at: source.appendingPathComponent("evil-link"),
            withDestinationURL: URL(fileURLWithPath: "/etc/hosts"))
        let data = try zip(contentsOf: source)

        XCTAssertThrowsError(try ExampleProjectManager.installAssets(
            zipData: data, into: projectDir)) { error in
            XCTAssertTrue("\(error)".contains("symlink"))
        }
    }

    func testGarbageDataIsRejected() {
        XCTAssertThrowsError(try ExampleProjectManager.installAssets(
            zipData: Data("not a zip".utf8), into: projectDir))
    }
}

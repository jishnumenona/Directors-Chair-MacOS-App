//
//  ProjectSnapshotStoreTests.swift
//
//  Restore points the user can trust: names round-trip their meaning,
//  dailies fire once per day and age out at the cap, on-demand
//  snapshots never age out, and nothing counts as a snapshot unless it
//  can actually restore.
//

import XCTest
@testable import DirectorsChairCore

final class ProjectSnapshotStoreTests: XCTestCase {

    private var projectURL: URL!

    override func setUpWithError() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("snapshots-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        projectURL = dir.appendingPathComponent("project.json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(
            at: projectURL.deletingLastPathComponent())
    }

    func testAFileNameCarriesItsWholeMeaning() {
        let date = Date(timeIntervalSince1970: 1_754_000_000)
        let name = ProjectSnapshotStore.fileName(
            date: date, label: "Before the big recut", automatic: false)
        let parsed = ProjectSnapshotStore.parse(fileName: name)

        XCTAssertEqual(parsed?.label, "Before the big recut")
        XCTAssertEqual(parsed?.automatic, false)
        XCTAssertEqual(parsed!.date.timeIntervalSince1970,
                       date.timeIntervalSince1970, accuracy: 1,
                       "no index file that could desync — the name IS the record")
    }

    func testHostileLabelsAreDefanged() {
        let name = ProjectSnapshotStore.fileName(
            date: Date(), label: "../../etc/passwd; rm -rf /",
            automatic: false)
        XCTAssertFalse(name.contains(".."))
        XCTAssertFalse(name.contains("/"))
        XCTAssertFalse(name.contains(";"))
    }

    func testCreateListRestoreRoundTrip() async throws {
        let store = ProjectSnapshotStore()
        var project = Project(name: "Original Cut")
        project.budget = "1000000"

        try await store.create(project, forProjectAt: projectURL,
                               label: "Locked reel 3")

        let listed = await store.list(forProjectAt: projectURL)
        XCTAssertEqual(listed.count, 1)
        XCTAssertEqual(listed[0].label, "Locked reel 3")
        XCTAssertFalse(listed[0].isAutomatic)
        XCTAssertGreaterThan(listed[0].sizeBytes, 0)

        let restored = try await store.restore(listed[0])
        XCTAssertEqual(restored.name, "Original Cut")
        XCTAssertEqual(restored.budget, "1000000")
    }

    func testTheDailyFiresOncePerDayOnly() async throws {
        let store = ProjectSnapshotStore()
        let project = Project(name: "P")
        // 9am TODAY in the local calendar — "+6 hours" must stay inside
        // the same local day whatever hour this test runs at (the first
        // cut used Date() and failed when the suite ran near midnight).
        let morning = Calendar.current.startOfDay(for: Date())
            .addingTimeInterval(9 * 3600)

        let first = try await store.createDailyIfDue(
            project, forProjectAt: projectURL, now: morning)
        XCTAssertNotNil(first)

        let afternoon = morning.addingTimeInterval(6 * 3600)
        let second = try await store.createDailyIfDue(
            project, forProjectAt: projectURL, now: afternoon)
        XCTAssertNil(second, "one restore point per day, not per open")

        XCTAssertTrue(ProjectSnapshotStore.dailyIsDue(
            newestAutomatic: morning,
            now: morning.addingTimeInterval(48 * 3600)))
        XCTAssertTrue(ProjectSnapshotStore.dailyIsDue(newestAutomatic: nil))
    }

    func testDailiesAgeOutAtTheCapButUserSnapshotsNeverDo() async throws {
        let store = ProjectSnapshotStore(dailyCap: 3)
        let project = Project(name: "P")
        let start = Date(timeIntervalSince1970: 1_754_000_000)

        try await store.create(project, forProjectAt: projectURL,
                               label: "Keep me forever",
                               date: start.addingTimeInterval(-999_999))
        for day in 0..<6 {
            try await store.create(
                project, forProjectAt: projectURL, label: "Daily",
                automatic: true,
                date: start.addingTimeInterval(Double(day) * 86_400))
        }

        let listed = await store.list(forProjectAt: projectURL)
        XCTAssertEqual(listed.filter(\.isAutomatic).count, 3,
                       "dailies pruned to the cap")
        XCTAssertEqual(listed.filter { !$0.isAutomatic }.count, 1,
                       "the user's own snapshot is untouchable")
        // And the SURVIVING dailies are the newest three.
        let survivingDays = listed.filter(\.isAutomatic).map(\.date).sorted()
        XCTAssertEqual(survivingDays.first!,
                       start.addingTimeInterval(3 * 86_400))
    }

    func testForeignFilesInTheDirectoryAreIgnored() async throws {
        let store = ProjectSnapshotStore()
        let dir = ProjectSnapshotStore.snapshotsDirectory(
            forProjectAt: projectURL)
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        try Data("junk".utf8).write(
            to: dir.appendingPathComponent(".DS_Store"))
        try Data("junk".utf8).write(
            to: dir.appendingPathComponent("notes.txt"))

        let listed = await store.list(forProjectAt: projectURL)
        XCTAssertTrue(listed.isEmpty)
    }

    func testDeleteRemovesExactlyOne() async throws {
        let store = ProjectSnapshotStore()
        let project = Project(name: "P")
        try await store.create(project, forProjectAt: projectURL,
                               label: "one",
                               date: Date(timeIntervalSinceNow: -60))
        try await store.create(project, forProjectAt: projectURL,
                               label: "two")

        let before = await store.list(forProjectAt: projectURL)
        try await store.delete(before.first!)
        let after = await store.list(forProjectAt: projectURL)
        XCTAssertEqual(after.map(\.label), ["one"])
    }
}

// DirectorsChairViewsTests/ExportQueueTests.swift
//
// The background export queue's contract (§2.18): strictly one job at a
// time in enqueue order, a failure explains itself and never blocks the
// jobs behind it, and Clear removes history without touching work in
// flight.

import XCTest
@testable import DirectorsChairViews

@MainActor
final class ExportQueueTests: XCTestCase {

    private var temp: URL!

    override func setUp() {
        super.setUp()
        temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExportQueueTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(
            at: temp, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: temp)
        super.tearDown()
    }

    private func waitUntil(timeout: TimeInterval = 5,
                           _ predicate: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if predicate() { return true }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return predicate()
    }

    func testJobsRunOneAtATimeInEnqueueOrder() async {
        let queue = ExportQueue()
        let gate = DispatchSemaphore(value: 0)
        let order = OrderRecorder()
        let first = temp.appendingPathComponent("first.txt")
        let second = temp.appendingPathComponent("second.txt")

        queue.enqueue(title: "First", destination: first) {
            gate.wait()
            order.record("first")
            try "one".write(to: first, atomically: true, encoding: .utf8)
        }
        queue.enqueue(title: "Second", destination: second) {
            order.record("second")
            try "two".write(to: second, atomically: true, encoding: .utf8)
        }

        let firstRunning = await waitUntil {
            queue.jobs.first?.state == .running
        }
        XCTAssertTrue(firstRunning)
        XCTAssertEqual(queue.jobs.last?.state, .queued,
                       "the second job must WAIT — one export at a time")

        gate.signal()
        let bothDone = await waitUntil {
            queue.jobs.allSatisfy { $0.state == .done }
        }
        XCTAssertTrue(bothDone)
        XCTAssertEqual(order.entries, ["first", "second"],
                       "completion must follow enqueue order")
        XCTAssertEqual(try? String(contentsOf: second, encoding: .utf8), "two",
                       "the job's write must actually land")
    }

    func testAFailureExplainsItselfAndTheQueueMovesOn() async {
        let queue = ExportQueue()
        let good = temp.appendingPathComponent("good.txt")

        queue.enqueue(title: "Doomed",
                      destination: temp.appendingPathComponent("nope.txt")) {
            throw NSError(domain: "test", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "the disk said no"])
        }
        queue.enqueue(title: "Fine", destination: good) {
            try "fine".write(to: good, atomically: true, encoding: .utf8)
        }

        let settled = await waitUntil {
            queue.jobs.allSatisfy { $0.state.isFinished }
        }
        XCTAssertTrue(settled)
        XCTAssertEqual(queue.jobs[0].state, .failed("the disk said no"),
                       "the failure carries the reason, not just redness")
        XCTAssertEqual(queue.jobs[1].state, .done,
                       "one failure must never dam the queue")
    }

    func testClearFinishedKeepsUnfinishedWork() async {
        let queue = ExportQueue()
        let gate = DispatchSemaphore(value: 0)
        let done = temp.appendingPathComponent("done.txt")

        queue.enqueue(title: "Already done", destination: done) {
            try "x".write(to: done, atomically: true, encoding: .utf8)
        }
        _ = await waitUntil { queue.jobs.first?.state == .done }

        queue.enqueue(title: "Held", destination: temp.appendingPathComponent("h")) {
            gate.wait()
        }
        queue.enqueue(title: "Waiting", destination: temp.appendingPathComponent("w")) {}
        _ = await waitUntil { queue.jobs.contains { $0.state == .running } }

        queue.clearFinished()
        XCTAssertEqual(queue.jobs.map(\.title), ["Held", "Waiting"],
                       "history goes, live work stays")
        XCTAssertTrue(queue.hasUnfinished)

        gate.signal()
        let allDone = await waitUntil {
            queue.jobs.allSatisfy { $0.state.isFinished }
        }
        XCTAssertTrue(allDone)
        XCTAssertFalse(queue.hasUnfinished)
    }
    func testMainActorJobsKeepSerialOrderWithBackgroundJobs() async {
        // PDF renders on the main actor; a mixed queue must still be one
        // job at a time in enqueue order.
        let queue = ExportQueue()
        let order = OrderRecorder()
        queue.enqueue(title: "bg1", destination: temp.appendingPathComponent("1")) {
            order.record("bg1")
        }
        queue.enqueueOnMain(title: "main", destination: temp.appendingPathComponent("2")) {
            order.record("main")
        }
        queue.enqueue(title: "bg2", destination: temp.appendingPathComponent("3")) {
            order.record("bg2")
        }
        let allDone = await waitUntil {
            queue.jobs.allSatisfy { $0.state == .done }
        }
        XCTAssertTrue(allDone)
        XCTAssertEqual(order.entries, ["bg1", "main", "bg2"])
    }
}

/// Thread-safe completion recorder — job closures run off-main.
private final class OrderRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []
    var entries: [String] {
        lock.lock(); defer { lock.unlock() }
        return storage
    }
    func record(_ entry: String) {
        lock.lock(); defer { lock.unlock() }
        storage.append(entry)
    }
}

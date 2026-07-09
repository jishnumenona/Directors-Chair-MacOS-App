//
//  PerfInstrumentation.swift
//  DirectorsChairCore
//
//  Lightweight, always-compiled instrumentation for the UI-performance
//  workstream (see document/summary/directorschair-ui-performance-audit.html).
//
//  Three tools:
//  - PerfSignpost: os_signpost intervals on the audited hot paths, visible in
//    Instruments and (via PerfCounters) collectable programmatically.
//  - PerfCounters: cheap named counters + duration accumulators for the
//    scenario runner's JSON output ("body evaluations per 10s of typing").
//  - MainThreadHangWatchdog: samples main-run-loop responsiveness and counts
//    hitches — the single best "does it feel sluggish" number.
//

import Foundation
import os

// MARK: - Signposts

public enum PerfSignpost {
    public static let signposter = OSSignposter(subsystem: "com.directorschair.perf",
                                                category: "hotpaths")

    /// Wrap a hot path: emits an os_signpost interval AND accumulates the
    /// duration into PerfCounters under the same name.
    @inlinable
    public static func measure<T>(_ name: StaticString, _ body: () throws -> T) rethrows -> T {
        let state = signposter.beginInterval(name)
        let start = DispatchTime.now().uptimeNanoseconds
        defer {
            signposter.endInterval(name, state)
            let elapsed = DispatchTime.now().uptimeNanoseconds - start
            PerfCounters.shared.record(name: "\(name)", nanoseconds: elapsed)
        }
        return try body()
    }
}

// MARK: - Counters

/// Thread-safe named counters and duration accumulators. Near-zero cost when
/// idle; reset + snapshot around a measured scenario.
public final class PerfCounters: @unchecked Sendable {
    public static let shared = PerfCounters()

    public struct Stat: Codable, Sendable {
        public var count: Int = 0
        public var totalNs: UInt64 = 0
        public var maxNs: UInt64 = 0
        public var totalMs: Double { Double(totalNs) / 1_000_000 }
        public var maxMs: Double { Double(maxNs) / 1_000_000 }
        public var avgMs: Double { count > 0 ? totalMs / Double(count) : 0 }
    }

    private var stats: [String: Stat] = [:]
    private let lock = NSLock()

    /// Count an occurrence (e.g. one view-body evaluation).
    public func increment(_ name: String) {
        lock.lock(); defer { lock.unlock() }
        stats[name, default: Stat()].count += 1
    }

    /// Record a timed occurrence.
    public func record(name: String, nanoseconds: UInt64) {
        lock.lock(); defer { lock.unlock() }
        var s = stats[name, default: Stat()]
        s.count += 1
        s.totalNs &+= nanoseconds
        s.maxNs = max(s.maxNs, nanoseconds)
        stats[name] = s
    }

    public func reset() {
        lock.lock(); defer { lock.unlock() }
        stats.removeAll()
    }

    public func snapshot() -> [String: Stat] {
        lock.lock(); defer { lock.unlock() }
        return stats
    }
}

// MARK: - Hang Watchdog

/// Counts main-thread stalls by round-tripping a tiny block through the main
/// queue at a fixed cadence and measuring how late it runs. Stalls above the
/// hitch threshold (a dropped frame) and the hang threshold (a visible
/// freeze) are counted separately; the worst stall is kept.
public final class MainThreadHangWatchdog: @unchecked Sendable {

    public struct Report: Codable, Sendable {
        public var samples: Int = 0
        public var hitches16ms: Int = 0
        public var hangs100ms: Int = 0
        public var worstMs: Double = 0
        public var totalStallMs: Double = 0
    }

    private let interval: TimeInterval
    private let queue = DispatchQueue(label: "com.directorschair.perf.watchdog", qos: .userInteractive)
    private var timer: DispatchSourceTimer?
    private var report = Report()
    private let lock = NSLock()

    public init(interval: TimeInterval = 0.05) {
        self.interval = interval
    }

    public func start() {
        stop()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + interval, repeating: interval, leeway: .milliseconds(1))
        t.setEventHandler { [weak self] in
            guard let self else { return }
            let sent = DispatchTime.now()
            DispatchQueue.main.async {
                let latencyMs = Double(DispatchTime.now().uptimeNanoseconds - sent.uptimeNanoseconds) / 1_000_000
                self.lock.lock()
                self.report.samples += 1
                if latencyMs > 16 { self.report.hitches16ms += 1 }
                if latencyMs > 100 { self.report.hangs100ms += 1 }
                if latencyMs > 16 { self.report.totalStallMs += latencyMs }
                self.report.worstMs = max(self.report.worstMs, latencyMs)
                self.lock.unlock()
            }
        }
        timer = t
        t.resume()
    }

    public func stop() {
        timer?.cancel()
        timer = nil
    }

    public func snapshot() -> Report {
        lock.lock(); defer { lock.unlock() }
        return report
    }

    public func reset() {
        lock.lock(); defer { lock.unlock() }
        report = Report()
    }
}

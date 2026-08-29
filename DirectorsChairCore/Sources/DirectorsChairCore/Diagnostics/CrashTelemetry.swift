//
//  CrashTelemetry.swift
//  DirectorsChairCore
//
//  Crash telemetry (P1, backlog §2.17) — no third-party SDK, no
//  in-crash heroics, nothing transmitted anywhere.
//
//  The design leans on two boring, reliable facts instead of fragile
//  crash-time handlers:
//    1. A session lock file exists exactly while the app runs. Finding
//       one at launch means the last exit was unclean — crash, force
//       quit, power loss.
//    2. macOS already writes a full .ips crash report for every real
//       crash. We never duplicate that work; we FIND the report that
//       matches the dead session and summarize it.
//  Between launches the app keeps a tiny ambient breadcrumb file
//  (frontmost view, project scale) updated on cheap occasions, so a
//  report can say what the user was doing without any code needing to
//  run while the process dies.
//
//  Privacy: reports are archived locally under Application Support and
//  shown to the user. Nothing leaves the machine; the transport seam
//  below is deliberately empty until a server endpoint exists AND the
//  user opts in.
//

import Foundation

public struct CrashReport: Codable, Equatable, Sendable {
    public var detectedAt: Date
    public var sessionStart: Date
    public var uptimeSeconds: Double
    public var appVersion: String
    public var osVersion: String
    public var lastView: String?
    public var projectName: String?
    public var projectShots: Int?
    /// From the matched .ips, when one exists.
    public var terminationSummary: String?
    public var crashedThreadFrames: [String]
}

/// Where a report would be SENT, someday, with consent. Empty on
/// purpose: claiming telemetry while a POST goes nowhere would be worse
/// than saying "stored locally", which is the truth.
public protocol CrashReportTransport: Sendable {
    func send(_ report: CrashReport) async throws
}

public actor CrashTelemetry {

    public static let shared = CrashTelemetry()

    private let directory: URL
    private let diagnosticsDirectory: URL
    private let processName: String

    public init(directory: URL? = nil,
                diagnosticsDirectory: URL? = nil,
                processName: String = "DirectorsChair") {
        self.directory = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DirectorsChair/Telemetry",
                                    isDirectory: true)
        self.diagnosticsDirectory = diagnosticsDirectory ?? FileManager
            .default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs/DiagnosticReports",
                                    isDirectory: true)
        self.processName = processName
    }

    private nonisolated var lockURL: URL { directory.appendingPathComponent("session.lock") }
    private nonisolated var stateURL: URL { directory.appendingPathComponent("state.json") }
    public nonisolated var reportsDirectory: URL {
        directory.appendingPathComponent("reports", isDirectory: true)
    }

    // MARK: - Session lifecycle

    private struct SessionLock: Codable {
        var start: Date
        var appVersion: String
        var pid: Int32
    }

    private struct Breadcrumbs: Codable {
        var lastView: String?
        var projectName: String?
        var projectShots: Int?
    }

    /// Call once at launch, AFTER launchCheck. Writes the lock that a
    /// clean exit removes.
    public func beginSession(appVersion: String) {
        try? FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true)
        let lock = SessionLock(start: Date(), appVersion: appVersion,
                               pid: ProcessInfo.processInfo.processIdentifier)
        if let data = try? JSONEncoder.telemetry.encode(lock) {
            try? data.write(to: lockURL, options: .atomic)
        }
    }

    /// The clean goodbye. Anything that skips this — crash, kill -9,
    /// power loss — is what launchCheck detects next time.
    public func endSessionCleanly() {
        endSessionCleanlyNow()
    }

    /// The same goodbye, callable synchronously from the main thread while
    /// it is busy terminating: applicationWillTerminate used to spawn a
    /// main-actor task and block on it, which cannot run there — every
    /// clean quit stalled 2 s and left the lock behind, so the next launch
    /// reported a crash that never happened (audit 2026-08-28).
    public nonisolated func endSessionCleanlyNow() {
        try? FileManager.default.removeItem(at: lockURL)
        try? FileManager.default.removeItem(at: stateURL)
    }

    /// Ambient context, updated on cheap occasions (view switches,
    /// project loads) — never in a crash path.
    public func noteState(lastView: String?, projectName: String?,
                          projectShots: Int?) {
        try? FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true)
        let crumbs = Breadcrumbs(lastView: lastView,
                                 projectName: projectName,
                                 projectShots: projectShots)
        if let data = try? JSONEncoder.telemetry.encode(crumbs) {
            try? data.write(to: stateURL, options: .atomic)
        }
    }

    // MARK: - Launch check

    /// Looks for the corpse of the previous session. Returns a report if
    /// the last exit was unclean (archiving it under reports/), and
    /// always clears the stale lock so one crash produces one report.
    public func launchCheck(appVersion: String,
                            osVersion: String,
                            now: Date = Date()) -> CrashReport? {
        guard let lockData = try? Data(contentsOf: lockURL),
              let lock = try? JSONDecoder.telemetry.decode(
                  SessionLock.self, from: lockData) else {
            return nil
        }
        defer {
            try? FileManager.default.removeItem(at: lockURL)
            try? FileManager.default.removeItem(at: stateURL)
        }

        let crumbs = (try? Data(contentsOf: stateURL)).flatMap {
            try? JSONDecoder.telemetry.decode(Breadcrumbs.self, from: $0)
        }
        let ips = newestDiagnosticReport(since: lock.start, until: now)

        var report = CrashReport(
            detectedAt: now,
            sessionStart: lock.start,
            uptimeSeconds: now.timeIntervalSince(lock.start),
            appVersion: lock.appVersion,
            osVersion: osVersion,
            lastView: crumbs?.lastView,
            projectName: crumbs?.projectName,
            projectShots: crumbs?.projectShots,
            terminationSummary: nil,
            crashedThreadFrames: [])
        if let ips {
            let parsed = Self.summarize(ipsData: ips)
            report.terminationSummary = parsed.summary
            report.crashedThreadFrames = parsed.frames
        }
        archive(report)
        return report
    }

    /// The newest .ips for OUR process written during the dead session.
    /// A crash from some other app the same evening must never be
    /// pinned on us.
    private func newestDiagnosticReport(since: Date, until: Date) -> Data? {
        guard let names = try? FileManager.default
            .contentsOfDirectory(atPath: diagnosticsDirectory.path) else {
            return nil
        }
        let candidates = names
            .filter { $0.hasPrefix(processName) && $0.hasSuffix(".ips") }
            .map { diagnosticsDirectory.appendingPathComponent($0) }
            .compactMap { url -> (URL, Date)? in
                guard let modified = (try? FileManager.default
                    .attributesOfItem(atPath: url.path))?[.modificationDate]
                    as? Date else { return nil }
                // A minute of slack either side: crash writing isn't
                // instant, clocks aren't either.
                guard modified >= since.addingTimeInterval(-60),
                      modified <= until.addingTimeInterval(60) else {
                    return nil
                }
                return (url, modified)
            }
            .sorted { $0.1 > $1.1 }
        guard let newest = candidates.first else { return nil }
        return try? Data(contentsOf: newest.0)
    }

    /// An .ips file is a JSON header line followed by a JSON body.
    /// Extract the human-relevant sentence and the first frames of the
    /// crashed thread — never the whole file (paths and register dumps
    /// are noise at best).
    static func summarize(ipsData: Data) -> (summary: String?,
                                             frames: [String]) {
        guard let text = String(data: ipsData, encoding: .utf8),
              let bodyStart = text.firstIndex(of: "\n") else {
            return (nil, [])
        }
        let bodyData = Data(text[text.index(after: bodyStart)...].utf8)
        guard let body = try? JSONSerialization
            .jsonObject(with: bodyData) as? [String: Any] else {
            return (nil, [])
        }

        var summary: String?
        if let exception = body["exception"] as? [String: Any] {
            let type = exception["type"] as? String ?? "crash"
            let signal = exception["signal"] as? String ?? ""
            summary = "\(type) (\(signal))"
        }
        if let termination = body["termination"] as? [String: Any],
           let indicator = termination["indicator"] as? String {
            summary = [summary, indicator]
                .compactMap { $0 }.joined(separator: " — ")
        }

        var frames: [String] = []
        if let faultingIndex = body["faultingThread"] as? Int,
           let threads = body["threads"] as? [[String: Any]],
           faultingIndex < threads.count,
           let rawFrames = threads[faultingIndex]["frames"]
               as? [[String: Any]],
           let images = body["usedImages"] as? [[String: Any]] {
            for frame in rawFrames.prefix(5) {
                let symbol = frame["symbol"] as? String ?? "?"
                let imageName: String
                if let index = frame["imageIndex"] as? Int,
                   index < images.count {
                    imageName = images[index]["name"] as? String ?? "?"
                } else {
                    imageName = "?"
                }
                frames.append("\(imageName): \(symbol)")
            }
        }
        return (summary, frames)
    }

    private func archive(_ report: CrashReport) {
        try? FileManager.default.createDirectory(
            at: reportsDirectory, withIntermediateDirectories: true)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime,
                                   .withDashSeparatorInDate]
        let name = "crash-" + formatter.string(from: report.detectedAt)
            .replacingOccurrences(of: ":", with: "") + ".json"
        if let data = try? JSONEncoder.telemetry.encode(report) {
            try? data.write(to: reportsDirectory
                .appendingPathComponent(name), options: .atomic)
        }
    }
}

private extension JSONEncoder {
    static var telemetry: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return encoder
    }
}

private extension JSONDecoder {
    static var telemetry: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

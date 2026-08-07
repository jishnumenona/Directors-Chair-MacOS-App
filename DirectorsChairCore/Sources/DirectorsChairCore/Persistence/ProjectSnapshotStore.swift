//
//  ProjectSnapshotStore.swift
//  DirectorsChairCore
//
//  Versioned project snapshots (P1, backlog §2.17).
//
//  The rotating .backups directory protects against a bad WRITE — five
//  generations, overwritten constantly, invisible. Snapshots protect
//  against a bad WEEK: user-meaningful restore points that survive
//  rotation, browsable by date and label, restorable at will. Two kinds:
//  automatic dailies (first open of the day, pruned to a cap) and
//  on-demand snapshots (never pruned automatically — the user made them
//  deliberately). A snapshot captures the DOCUMENT (project.json);
//  media on disk is referenced, not copied — the same contract as the
//  server's revision history.
//

import Foundation

public struct ProjectSnapshot: Identifiable, Equatable, Sendable {
    public let id: String            // file name
    public let url: URL
    public let date: Date
    public let label: String         // "Daily" or the user's words
    public let isAutomatic: Bool
    public let sizeBytes: Int64
}

public actor ProjectSnapshotStore {

    public static let shared = ProjectSnapshotStore()

    /// Automatic dailies kept; on-demand snapshots are never auto-pruned.
    public let dailyCap: Int

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(dailyCap: Int = 14) {
        self.dailyCap = dailyCap
        encoder = JSONEncoder()
        // Byte-for-byte the same format the project file uses, so a
        // snapshot IS a project file.
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Layout (pure, testable)

    public nonisolated static func snapshotsDirectory(
        forProjectAt projectURL: URL) -> URL {
        projectURL.deletingLastPathComponent()
            .appendingPathComponent(".snapshots", isDirectory: true)
    }

    /// snapshot-20260806-231502-auto-Daily.json — sortable by name,
    /// self-describing without an index file that could desync.
    nonisolated static func fileName(date: Date, label: String,
                                     automatic: Bool) -> String {
        let stamp = Self.stampFormatter.string(from: date)
        let kind = automatic ? "auto" : "user"
        let safeLabel = label.replacingOccurrences(
            of: "[^A-Za-z0-9 _-]", with: "", options: .regularExpression)
            .replacingOccurrences(of: " ", with: "_")
            .prefix(40)
        return "snapshot-\(stamp)-\(kind)-\(safeLabel).json"
    }

    nonisolated static func parse(fileName: String)
        -> (date: Date, label: String, automatic: Bool)? {
        guard fileName.hasPrefix("snapshot-"),
              fileName.hasSuffix(".json") else { return nil }
        let core = fileName.dropFirst("snapshot-".count)
            .dropLast(".json".count)
        let parts = core.split(separator: "-", maxSplits: 3,
                               omittingEmptySubsequences: false)
        guard parts.count == 4,
              let date = Self.stampFormatter.date(
                  from: "\(parts[0])-\(parts[1])") else { return nil }
        let automatic = parts[2] == "auto"
        let label = parts[3].replacingOccurrences(of: "_", with: " ")
        return (date, String(label), automatic)
    }

    private nonisolated static let stampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    /// Whether the first-open-of-the-day snapshot is due. Pure, so the
    /// calendar rule is testable.
    public nonisolated static func dailyIsDue(
        newestAutomatic: Date?, now: Date = Date(),
        calendar: Calendar = .current) -> Bool {
        guard let newestAutomatic else { return true }
        return !calendar.isDate(newestAutomatic, inSameDayAs: now)
    }

    // MARK: - Operations

    public func list(forProjectAt projectURL: URL) -> [ProjectSnapshot] {
        let dir = Self.snapshotsDirectory(forProjectAt: projectURL)
        guard let names = try? FileManager.default
            .contentsOfDirectory(atPath: dir.path) else { return [] }
        return names.compactMap { name -> ProjectSnapshot? in
            guard let parsed = Self.parse(fileName: name) else { return nil }
            let url = dir.appendingPathComponent(name)
            let size = (try? FileManager.default
                .attributesOfItem(atPath: url.path))?[.size] as? Int64 ?? 0
            return ProjectSnapshot(id: name, url: url, date: parsed.date,
                                   label: parsed.label,
                                   isAutomatic: parsed.automatic,
                                   sizeBytes: size)
        }
        .sorted { $0.date > $1.date }
    }

    /// Write a snapshot of the given project state. Validated before it
    /// counts — a snapshot that can't restore is worse than none.
    @discardableResult
    public func create(_ project: Project, forProjectAt projectURL: URL,
                       label: String, automatic: Bool = false,
                       date: Date = Date()) throws -> ProjectSnapshot {
        let dir = Self.snapshotsDirectory(forProjectAt: projectURL)
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        let name = Self.fileName(date: date, label: label, automatic: automatic)
        let url = dir.appendingPathComponent(name)
        let data = try encoder.encode(project)
        _ = try decoder.decode(Project.self, from: data)   // must restore
        try data.write(to: url, options: .atomic)
        if automatic { pruneDailies(forProjectAt: projectURL) }
        return ProjectSnapshot(id: name, url: url, date: date, label: label,
                               isAutomatic: automatic,
                               sizeBytes: Int64(data.count))
    }

    /// First open of the day gets a free restore point.
    @discardableResult
    public func createDailyIfDue(_ project: Project,
                                 forProjectAt projectURL: URL,
                                 now: Date = Date()) throws
        -> ProjectSnapshot? {
        let newestAuto = list(forProjectAt: projectURL)
            .first(where: \.isAutomatic)?.date
        guard Self.dailyIsDue(newestAutomatic: newestAuto, now: now) else {
            return nil
        }
        return try create(project, forProjectAt: projectURL,
                          label: "Daily", automatic: true, date: now)
    }

    public func restore(_ snapshot: ProjectSnapshot) throws -> Project {
        let data = try Data(contentsOf: snapshot.url)
        return try decoder.decode(Project.self, from: data)
    }

    public func delete(_ snapshot: ProjectSnapshot) throws {
        try FileManager.default.removeItem(at: snapshot.url)
    }

    /// Dailies beyond the cap age out; the user's own snapshots never do.
    private func pruneDailies(forProjectAt projectURL: URL) {
        let dailies = list(forProjectAt: projectURL).filter(\.isAutomatic)
        for stale in dailies.dropFirst(dailyCap) {
            try? FileManager.default.removeItem(at: stale.url)
        }
    }
}

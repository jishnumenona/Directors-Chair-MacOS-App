// DirectorsChairCore/Sources/DirectorsChairCore/DailiesWatcher.swift
//
// Watch-folder dailies ingest (backlog §2.18) — the watching half.
//
// A polling watcher, deliberately: footage lands over seconds-to-minutes
// (card offloads, sync services), so a 2-second scan is instant at
// human scale, and STABILITY is the hard requirement no directory-event
// API gives us — a file must stop growing before it's touched, or the
// ingest copies half a take. A file is delivered exactly once per
// session, only after its size and mtime hold still across two
// consecutive scans.

import Foundation

public final class DailiesWatcher: @unchecked Sendable {

    /// Called on the MAIN queue with a file that finished arriving.
    public var onFileReady: ((URL) -> Void)?

    private struct Snapshot: Equatable {
        var size: Int64
        var modified: Date
    }

    private let pollInterval: TimeInterval
    private let queue = DispatchQueue(label: "dailies-watcher",
                                      qos: .utility)
    private var timer: DispatchSourceTimer?
    private var folder: URL?
    private var pending: [String: Snapshot] = [:]
    private var delivered: Set<String> = []

    public init(pollInterval: TimeInterval = 2.0) {
        self.pollInterval = pollInterval
    }

    public var isWatching: Bool {
        queue.sync { timer != nil }
    }

    public func start(folder: URL) {
        stop()
        queue.sync {
            self.folder = folder
            self.pending = [:]
            self.delivered = []
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now(),
                           repeating: pollInterval)
            timer.setEventHandler { [weak self] in self?.scan() }
            timer.resume()
            self.timer = timer
        }
    }

    public func stop() {
        queue.sync {
            timer?.cancel()
            timer = nil
            folder = nil
        }
    }

    private func scan() {
        guard let folder else { return }
        let manager = FileManager.default
        guard let names = try? manager.contentsOfDirectory(atPath: folder.path)
        else { return }

        for name in names {
            guard !name.hasPrefix("."),
                  DailiesIngest.videoExtensions.contains(
                    (name as NSString).pathExtension.lowercased()),
                  !delivered.contains(name) else { continue }

            let url = folder.appendingPathComponent(name)
            guard let attributes = try? manager
                .attributesOfItem(atPath: url.path) else { continue }
            let snapshot = Snapshot(
                size: (attributes[.size] as? Int64) ?? -1,
                modified: (attributes[.modificationDate] as? Date)
                    ?? .distantPast)

            if pending[name] == snapshot {
                // Two scans, no growth: the copy is done.
                delivered.insert(name)
                pending[name] = nil
                DispatchQueue.main.async { [onFileReady] in
                    onFileReady?(url)
                }
            } else {
                pending[name] = snapshot
            }
        }
    }
}

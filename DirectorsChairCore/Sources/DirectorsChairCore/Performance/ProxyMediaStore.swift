//
//  ProxyMediaStore.swift
//  DirectorsChairCore
//
//  Proxy media pipeline (P1, backlog §2.17).
//
//  Original camera files play badly from a project: 4K dailies stutter
//  on scrub, and a laptop on set has neither the decode budget nor the
//  disk bandwidth for six of them in a compare grid. Every professional
//  NLE solves this the same way — a lightweight 720p proxy generated in
//  the background at import, played by default, with the original one
//  toggle away. This is that, sized to DirectorsChair: proxies live in
//  assets/proxies/ keyed by a hash of the source's project-relative path
//  (flat, collision-free, GC-able), freshness is source-mtime based, and
//  sources already at or under 720p are never proxied — a proxy of a
//  proxy-sized file wastes disk to gain nothing.
//

import Foundation
import AVFoundation
import CryptoKit

// MARK: - Transcoding seam

/// What the store needs from a transcoder — behind a protocol so the
/// pipeline's queueing, freshness, and skip logic are testable without
/// rendering video.
public protocol ProxyTranscoding: Sendable {
    /// True when the source is worth proxying (probe says it exceeds the
    /// proxy resolution). Throwing means "could not read the file".
    func needsProxy(source: URL) async throws -> Bool
    /// Produce the proxy at `destination` (overwrite allowed).
    func transcode(source: URL, to destination: URL) async throws
}

/// The real transcoder: AVAssetExportSession at 1280×720, MP4,
/// stream-optimized.
public struct AVProxyTranscoder: ProxyTranscoding {
    public init() {}

    public func needsProxy(source: URL) async throws -> Bool {
        let asset = AVURLAsset(url: source)
        guard let track = try await asset.loadTracks(withMediaType: .video)
            .first else {
            return false        // audio-only or unreadable: nothing to gain
        }
        let size = try await track.load(.naturalSize)
        return min(abs(size.width), abs(size.height)) > 720
    }

    public func transcode(source: URL, to destination: URL) async throws {
        let asset = AVURLAsset(url: source)
        guard let session = AVAssetExportSession(
            asset: asset, presetName: AVAssetExportPreset1280x720) else {
            throw ProxyMediaError.exportUnavailable
        }
        // Export beside the destination and move in only when complete: an
        // interrupted export used to leave a truncated proxy whose fresh
        // mtime made it look valid forever (audit 2026-08-28).
        let partial = destination.deletingLastPathComponent()
            .appendingPathComponent(".\(destination.lastPathComponent).part")
        try? FileManager.default.removeItem(at: partial)
        session.shouldOptimizeForNetworkUse = true
        do {
            if #available(macOS 15, iOS 18, *) {
                try await session.export(to: partial, as: .mp4)
            } else {
                session.outputURL = partial
                session.outputFileType = .mp4
                await session.export()
                if let error = session.error { throw error }
            }
        } catch {
            try? FileManager.default.removeItem(at: partial)
            throw error
        }
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: partial, to: destination)
    }
}

public enum ProxyMediaError: Error {
    case exportUnavailable
}

// MARK: - The store

public actor ProxyMediaStore {

    public static let shared = ProxyMediaStore()

    private let transcoder: ProxyTranscoding
    /// Two at a time: proxying is background QoS work that must never
    /// starve playback or the UI of I/O.
    private let maxConcurrent: Int
    private var running = 0
    private var waiting: [CheckedContinuation<Void, Never>] = []
    /// Sources that failed, keyed to the mtime that failed — retried only
    /// when the file changes, so one broken clip can't burn CPU forever.
    private var failed: [String: Date] = [:]
    /// In-flight work, so a sweep and a record-finish can't double-encode.
    private var inFlight: Set<String> = []

    public init(transcoder: ProxyTranscoding = AVProxyTranscoder(),
                maxConcurrent: Int = 2) {
        self.transcoder = transcoder
        self.maxConcurrent = maxConcurrent
    }

    // MARK: Layout (pure, testable)

    /// assets/proxies/<sha256(relPath)>-720.mp4 — flat and rename-proof.
    public nonisolated static func proxyURL(forRelativePath relPath: String,
                                            projectBase: URL) -> URL {
        let digest = SHA256.hash(data: Data(relPath.utf8))
            .map { String(format: "%02x", $0) }.joined().prefix(24)
        return projectBase
            .appendingPathComponent("assets/proxies", isDirectory: true)
            .appendingPathComponent("\(digest)-720.mp4")
    }

    /// The proxy if it exists and is at least as new as the source.
    public nonisolated static func freshProxy(forRelativePath relPath: String,
                                              projectBase: URL) -> URL? {
        let source = projectBase.appendingPathComponent(relPath)
        let proxy = proxyURL(forRelativePath: relPath, projectBase: projectBase)
        guard let proxyDate = modificationDate(of: proxy),
              let sourceDate = modificationDate(of: source),
              proxyDate >= sourceDate else { return nil }
        return proxy
    }

    private nonisolated static func modificationDate(of url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[
            .modificationDate] as? Date
    }

    // MARK: Ensuring

    /// Generate the proxy for one source if it's missing or stale.
    /// Silent, background, idempotent, and safe to call repeatedly.
    public func ensureProxy(forRelativePath relPath: String,
                            projectBase: URL) async {
        let source = projectBase.appendingPathComponent(relPath)
        guard let sourceDate = Self.modificationDate(of: source) else {
            return                          // source missing: nothing to do
        }
        if Self.freshProxy(forRelativePath: relPath,
                           projectBase: projectBase) != nil {
            return
        }
        if failed[relPath] == sourceDate { return }
        guard !inFlight.contains(relPath) else { return }
        inFlight.insert(relPath)
        defer { inFlight.remove(relPath) }

        await acquireSlot()
        defer { releaseSlot() }

        do {
            guard try await transcoder.needsProxy(source: source) else {
                // At or under proxy size already — remember via the
                // failure memo so the probe doesn't rerun every sweep.
                failed[relPath] = sourceDate
                return
            }
            let destination = Self.proxyURL(forRelativePath: relPath,
                                            projectBase: projectBase)
            // The store owns the layout, so the store makes the room —
            // a transcoder that had to remember this was a trap for the
            // next implementation (the test fake fell straight into it).
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            try await transcoder.transcode(source: source, to: destination)
            failed[relPath] = nil
        } catch {
            failed[relPath] = sourceDate
        }
    }

    /// Ensure proxies for a whole project's media, in the background.
    /// Returns when all work is DISPATCHED, not finished.
    public nonisolated func sweep(relativePaths: [String], projectBase: URL) {
        for relPath in relativePaths {
            Task(priority: .background) {
                await self.ensureProxy(forRelativePath: relPath,
                                       projectBase: projectBase)
            }
        }
    }

    private func acquireSlot() async {
        if running < maxConcurrent { running += 1; return }
        await withCheckedContinuation { waiting.append($0) }
        running += 1
    }

    private func releaseSlot() {
        running -= 1
        if !waiting.isEmpty { waiting.removeFirst().resume() }
    }
}

// MARK: - Playback resolution

/// The one question every player asks: which file do I actually play?
public enum ProxyPlayback {
    public static let preferenceKey = "useProxyMediaWhenAvailable"

    /// On unless the user turned it off — the professional default.
    public static var enabled: Bool {
        UserDefaults.standard.object(forKey: preferenceKey) as? Bool ?? true
    }

    /// The URL to hand AVPlayer: the fresh proxy when allowed and
    /// present, otherwise the original. Total function — never fails,
    /// never blocks beyond two stat calls.
    public static func url(forRelativePath relPath: String?,
                           projectBase: URL?) -> URL? {
        guard let relPath, let projectBase else { return nil }
        let original = projectBase.appendingPathComponent(relPath)
        guard enabled,
              let proxy = ProxyMediaStore.freshProxy(
                  forRelativePath: relPath, projectBase: projectBase) else {
            return original
        }
        return proxy
    }

    /// Every relative media path a project references — the sweep's
    /// work-list. Pure, so the collection rule is testable.
    public static func mediaRelativePaths(in project: Project) -> [String] {
        var paths: [String] = []
        for sequence in project.sequences {
            for scene in sequence.scenes {
                for shot in scene.shots {
                    if let path = shot.videoPath, !path.isEmpty {
                        paths.append(path)
                    }
                    for take in shot.takes {
                        if let path = take.capturedVideoPath, !path.isEmpty {
                            paths.append(path)
                        }
                    }
                }
            }
        }
        return paths
    }
}

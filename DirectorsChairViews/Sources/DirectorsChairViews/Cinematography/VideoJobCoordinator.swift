// VideoJobCoordinator.swift
//
// WS6.1 — app-scoped owner of the paid video-generation lifecycle (submit →
// poll → download → persist), keyed by shot id.
//
// Previously this lived in @State of ShotVideoGenerationSection, and the view
// is force-recreated on shot change and cancels polling on disappear — so
// switching shots or tabs mid-generation permanently orphaned the job: the
// video was generated and billed server-side but never downloaded or saved.
//
// This coordinator is created once at the app root and outlives all view
// navigation. It polls independently, downloads on completion, and reports the
// result via `onEvent` to an app-scoped store (ProjectViewModel), so a job
// completes and persists even if the user has navigated away. A job is also
// resumable from the persisted shot.videoGenerationJobId after relaunch.

import Foundation
import DirectorsChairCore
import DirectorsChairServices

// MARK: - Job State

public struct VideoJobState: Equatable {
    public enum Phase: Equatable { case submitting, active, downloading, completed, failed }
    public var jobId: String
    public var phase: Phase
    public var progress: Double
    public var message: String
    public var errorMessage: String?

    public var isActive: Bool { phase == .submitting || phase == .active || phase == .downloading }
}

// MARK: - Job Context

/// Everything the coordinator needs to run a job, resolved by the view so the
/// coordinator does not depend on view-layer provider types.
public struct VideoJobContext {
    public let shotId: String        // Shot.id (uuid) — key + persist target
    public let shotShotId: Int       // shot.shotId — used in the on-disk path
    public let aiProvider: AIProvider
    public let folderName: String
    public let providerRawValue: String
    public let providerDisplayName: String
    public let basePath: URL
    public let duration: Double
    public let quality: String

    public init(shotId: String, shotShotId: Int, aiProvider: AIProvider,
                folderName: String, providerRawValue: String, providerDisplayName: String,
                basePath: URL, duration: Double, quality: String) {
        self.shotId = shotId
        self.shotShotId = shotShotId
        self.aiProvider = aiProvider
        self.folderName = folderName
        self.providerRawValue = providerRawValue
        self.providerDisplayName = providerDisplayName
        self.basePath = basePath
        self.duration = duration
        self.quality = quality
    }
}

// MARK: - Job Event (persisted by the app-scoped store)

public enum VideoJobEvent {
    case started(shotId: String, jobId: String)          // set videoGenerationJobId
    case completed(shotId: String, videoRelativePath: String)  // set videoPath, clear jobId
    case cleared(shotId: String)                         // clear jobId (cancel/fail)
}

// MARK: - Coordinator

@MainActor
public final class VideoJobCoordinator: ObservableObject {

    /// Per-shot job state, observed by the generation UI.
    @Published public private(set) var jobs: [String: VideoJobState] = [:]

    /// Wired once at the app root to persist results into the project.
    public var onEvent: ((VideoJobEvent) -> Void)?

    private var tasks: [String: Task<Void, Never>] = [:]

    /// Poll failures tolerated before giving up (≈1 minute at 3s intervals).
    private let maxConsecutivePollFailures = 20

    public init() {}

    public func state(forShot shotId: String) -> VideoJobState? { jobs[shotId] }

    // MARK: Submit

    public func submit(_ request: VideoGenerationRequest, context: VideoJobContext) {
        cancelTask(shotId: context.shotId)
        jobs[context.shotId] = VideoJobState(jobId: "", phase: .submitting, progress: 0,
                                             message: "Submitting…", errorMessage: nil)
        tasks[context.shotId] = Task { [weak self] in
            guard let self else { return }
            do {
                let response = try await AIServiceClient.shared.submitVideoGeneration(request)
                self.jobs[context.shotId]?.jobId = response.jobId
                self.jobs[context.shotId]?.phase = .active
                self.jobs[context.shotId]?.message = "Processing…"
                // Persist the job id immediately so it survives navigation/relaunch.
                self.onEvent?(.started(shotId: context.shotId, jobId: response.jobId))
                await self.poll(jobId: response.jobId, context: context)
            } catch {
                self.fail(shotId: context.shotId, jobId: "", message: error.localizedDescription)
            }
        }
    }

    // MARK: Resume (existing job after navigation / relaunch)

    public func resume(jobId: String, context: VideoJobContext) {
        // Don't double-track a job already in flight.
        guard tasks[context.shotId] == nil, jobs[context.shotId]?.isActive != true else { return }
        jobs[context.shotId] = VideoJobState(jobId: jobId, phase: .active, progress: 0,
                                             message: "Resuming…", errorMessage: nil)
        tasks[context.shotId] = Task { [weak self] in
            await self?.poll(jobId: jobId, context: context)
        }
    }

    // MARK: Cancel

    public func cancel(shotId: String, aiProvider: AIProvider) {
        let jobId = jobs[shotId]?.jobId
        cancelTask(shotId: shotId)
        jobs[shotId] = nil
        if let jobId, !jobId.isEmpty {
            Task { _ = try? await AIServiceClient.shared.cancelVideoGeneration(jobId: jobId, provider: aiProvider) }
        }
        onEvent?(.cleared(shotId: shotId))
    }

    // MARK: - Internals

    private func poll(jobId: String, context: VideoJobContext) async {
        let shotId = context.shotId
        var failures = 0
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { break }
            do {
                let status = try await AIServiceClient.shared.checkVideoStatus(jobId: jobId, provider: context.aiProvider)
                failures = 0
                if let p = status.progress { jobs[shotId]?.progress = p }
                switch status.status {
                case .pending:
                    jobs[shotId]?.message = "Queued…"
                case .processing:
                    jobs[shotId]?.message = status.estimatedTimeSeconds.map { "Processing… ~\($0)s remaining" } ?? "Processing…"
                case .completed:
                    await download(jobId: jobId, context: context)
                    return
                case .failed:
                    fail(shotId: shotId, jobId: jobId, message: status.errorMessage ?? "Video generation failed")
                    return
                }
            } catch {
                failures += 1
                jobs[shotId]?.message = "Checking status…"
                if failures >= maxConsecutivePollFailures {
                    // Don't clear the persisted job id: the job may still finish
                    // server-side and can be resumed later.
                    jobs[shotId] = VideoJobState(jobId: jobId, phase: .failed, progress: 0,
                                                 message: "", errorMessage: "Lost connection to the video service. It may still be processing — reopen this shot to retry.")
                    return
                }
            }
        }
    }

    private func download(jobId: String, context: VideoJobContext) async {
        let shotId = context.shotId
        jobs[shotId]?.phase = .downloading
        jobs[shotId]?.message = "Downloading video…"

        let videoDir = context.basePath
            .appendingPathComponent("assets/shots/shot_\(context.shotShotId)/video/\(context.folderName)")
        try? FileManager.default.createDirectory(at: videoDir, withIntermediateDirectories: true)
        let filename = "take_\(nextTakeIndex(in: videoDir)).mp4"
        let localVideoPath = videoDir.appendingPathComponent(filename)
        let relativePath = "assets/shots/shot_\(context.shotShotId)/video/\(context.folderName)/\(filename)"

        do {
            try await AIServiceClient.shared.downloadVideo(jobId: jobId, provider: context.aiProvider, to: localVideoPath)
            jobs[shotId] = VideoJobState(jobId: jobId, phase: .completed, progress: 100,
                                         message: "Complete!", errorMessage: nil)
            onEvent?(.completed(shotId: shotId, videoRelativePath: relativePath))
            AIUsageTracker.shared.recordVideoUsage(
                provider: context.providerRawValue, model: context.providerDisplayName,
                durationSeconds: context.duration, quality: context.quality
            )
        } catch {
            fail(shotId: shotId, jobId: jobId, message: "Failed to download video: \(error.localizedDescription)")
        }
    }

    private func fail(shotId: String, jobId: String, message: String) {
        jobs[shotId] = VideoJobState(jobId: jobId, phase: .failed, progress: 0, message: "", errorMessage: message)
    }

    private func cancelTask(shotId: String) {
        tasks[shotId]?.cancel()
        tasks[shotId] = nil
    }

    /// Next `take_N.mp4` index in a provider directory.
    private func nextTakeIndex(in dir: URL) -> Int {
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return 1 }
        let indices = files.compactMap { url -> Int? in
            let name = url.lastPathComponent
            guard name.hasPrefix("take_"), name.hasSuffix(".mp4") else { return nil }
            return Int(name.dropFirst(5).dropLast(4))
        }
        return (indices.max() ?? 0) + 1
    }
}

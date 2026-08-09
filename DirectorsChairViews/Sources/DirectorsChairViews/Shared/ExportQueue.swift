// DirectorsChairViews/Sources/DirectorsChairViews/Shared/ExportQueue.swift
//
// The background export queue (backlog §2.18).
//
// An export is a value snapshot plus a pure generator, so nothing about
// it belongs on the main thread except the save panel. Jobs run one at
// a time off-main (exports contend for the same disk anyway), the panel
// shows what's queued/running/done/failed, and a failure explains
// itself and never blocks the jobs behind it.
//
// Package-side for the usual reason: new files don't compile in the app
// target's synchronized folder group, and the model wants unit tests.

import SwiftUI
import AppKit

// MARK: - Job

public struct ExportJob: Identifiable, Equatable {
    public enum State: Equatable {
        case queued
        case running
        case done
        case failed(String)

        public var isFinished: Bool {
            switch self {
            case .done, .failed: return true
            case .queued, .running: return false
            }
        }
    }

    public let id: UUID
    public let title: String
    public let destination: URL
    public var state: State
}

// MARK: - Queue

@MainActor
public final class ExportQueue: ObservableObject {
    public static let shared = ExportQueue()

    /// Two flavors because the PDF generators are deliberately
    /// @MainActor (they draw through NSGraphicsContext.current, global
    /// state their author confined to main): text generators run truly
    /// in the background; PDF runs as async main-actor work — same
    /// serial order, same reporting, honest about the renderer it has.
    private enum Work {
        case background(@Sendable () throws -> Void)
        case main(@MainActor () throws -> Void)
    }

    @Published public private(set) var jobs: [ExportJob] = []
    private var work: [UUID: Work] = [:]
    private var isRunning = false

    public init() {}

    /// `work` runs on a background task and is responsible for writing
    /// `destination` (atomically — every generator already writes with
    /// `atomically: true` or a single Data write).
    public func enqueue(title: String, destination: URL,
                        work: @escaping @Sendable () throws -> Void) {
        append(title: title, destination: destination,
               work: .background(work))
    }

    /// For generators that must render on the main actor (PDF).
    public func enqueueOnMain(title: String, destination: URL,
                              work: @escaping @MainActor () throws -> Void) {
        append(title: title, destination: destination, work: .main(work))
    }

    private func append(title: String, destination: URL, work: Work) {
        let job = ExportJob(id: UUID(), title: title,
                            destination: destination, state: .queued)
        jobs.append(job)
        self.work[job.id] = work
        pump()
    }

    public var hasUnfinished: Bool {
        jobs.contains { !$0.state.isFinished }
    }

    public func clearFinished() {
        jobs.removeAll { $0.state.isFinished }
    }

    private func pump() {
        guard !isRunning,
              let index = jobs.firstIndex(where: { $0.state == .queued }),
              let task = work[jobs[index].id] else { return }
        isRunning = true
        let id = jobs[index].id
        jobs[index].state = .running
        switch task {
        case .background(let body):
            Task.detached(priority: .userInitiated) {
                do {
                    try body()
                    await self.finish(id, .done)
                } catch {
                    await self.finish(id, .failed(error.localizedDescription))
                }
            }
        case .main(let body):
            Task { @MainActor in
                // Yield once so the panel paints the running row before a
                // render occupies the main thread.
                await Task.yield()
                do {
                    try body()
                    self.finish(id, .done)
                } catch {
                    self.finish(id, .failed(error.localizedDescription))
                }
            }
        }
    }

    private func finish(_ id: UUID, _ state: ExportJob.State) {
        if let index = jobs.firstIndex(where: { $0.id == id }) {
            jobs[index].state = state
        }
        work[id] = nil
        isRunning = false
        pump()
    }
}

// MARK: - Panel

/// The downloads-style card that appears while exports exist: one row a
/// job, spinner → checkmark/warning, Reveal for anything written, and a
/// message on failure. The host mounts it bottom-trailing whenever
/// `jobs` is non-empty.
public struct ExportQueuePanel: View {
    @ObservedObject var queue: ExportQueue

    public init(queue: ExportQueue) {
        self.queue = queue
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Exports")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                if queue.jobs.contains(where: { $0.state.isFinished }) {
                    Button("Clear") { queue.clearFinished() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider().opacity(0.4)

            VStack(alignment: .leading, spacing: 2) {
                ForEach(queue.jobs) { job in
                    row(job)
                }
            }
            .padding(6)
        }
        .frame(width: 320)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 18, y: 8)
        .accessibilityIdentifier("export-queue-panel")
    }

    @ViewBuilder
    private func row(_ job: ExportJob) -> some View {
        HStack(spacing: 9) {
            switch job.state {
            case .queued:
                Image(systemName: "clock")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
            case .running:
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 16)
            case .done:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.green)
                    .frame(width: 16)
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
                    .frame(width: 16)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(job.title)
                    .font(.system(size: 11.5))
                    .lineLimit(1)
                if case .failed(let message) = job.state {
                    Text(message)
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                } else {
                    Text(job.destination.lastPathComponent)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if job.state == .done {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting(
                        [job.destination])
                } label: {
                    Image(systemName: "magnifyingglass.circle")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Reveal in Finder")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
    }
}

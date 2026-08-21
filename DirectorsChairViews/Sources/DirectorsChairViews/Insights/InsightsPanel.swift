// DirectorsChairViews/Insights/InsightsPanel.swift
//
// On-device AI insights (DC-0055, Product-Versions §3.7 — Free on every
// plan). The panel renders whatever the engine's availability says,
// honestly: a clear unavailable reason, a CONSENTED download (size named,
// never silent), progress, and then the three insight families. Engine
// and context building live below the seam; this file is presentation
// and one small view model.

import SwiftUI
import DirectorsChairCore
import DirectorsChairServices

// MARK: - View model

@MainActor
public final class InsightsViewModel: ObservableObject {
    public enum RunState: Equatable {
        case idle
        case running
        case result(String)
        case failed(String)
    }

    @Published public private(set) var availability: InsightAvailability?
    @Published public private(set) var states: [InsightFamily: RunState] = [:]
    @Published public var selectedFamily: InsightFamily = .overviewDigest

    private let engine: InsightEngine

    public init(engine: InsightEngine) {
        self.engine = engine
    }

    public func state(for family: InsightFamily) -> RunState {
        states[family] ?? .idle
    }

    public func refreshAvailability() async {
        availability = await engine.availability()
    }

    /// One-time model download — only ever called from the consent button.
    public func download() async {
        do {
            availability = .downloading(progress: 0)
            // Poll progress while prepare() runs; prepare finishing wins.
            let poll = Task { [engine] in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    let state = await engine.availability()
                    await MainActor.run { [weak self] in
                        if case .downloading = state { self?.availability = state }
                    }
                }
            }
            defer { poll.cancel() }
            try await engine.prepare()
            await refreshAvailability()
        } catch {
            availability = await engine.availability()
            states[selectedFamily] = .failed(describe(error))
        }
    }

    public func run(family: InsightFamily, project: Project) async {
        guard state(for: family) != .running else { return }
        states[family] = .running
        let context = InsightContextBuilder.context(for: family, project: project)
        do {
            let text = try await engine.insight(for: family, context: context)
            states[family] = .result(text)
        } catch {
            states[family] = .failed(describe(error))
        }
    }

    private func describe(_ error: Error) -> String {
        switch error {
        case InsightEngineError.notReady(let state):
            if case .unavailable(let reason) = state { return reason }
            return "The on-device model isn't ready yet."
        case InsightEngineError.downloadFailed:
            return "The model download failed — check your connection and try again."
        case InsightEngineError.inferenceFailed:
            return "The model couldn't finish this insight — try again."
        default:
            return "Something went wrong — try again."
        }
    }
}

// MARK: - Panel

public struct InsightsPanel: View {
    @StateObject private var viewModel: InsightsViewModel
    private let project: Project

    public init(engine: InsightEngine, project: Project) {
        _viewModel = StateObject(wrappedValue: InsightsViewModel(engine: engine))
        self.project = project
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "brain")
                    .foregroundStyle(Color.accentColor)
                Text("AI Insights")
                    .font(.headline)
                Text("on-device · free on every plan")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            switch viewModel.availability {
            case nil:
                ProgressView().controlSize(.small)
            case .unavailable(let reason):
                Text(reason)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            case .needsDownload(let bytes):
                downloadConsent(bytes: bytes)
            case .downloading(let progress):
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: progress)
                    Text("Downloading the on-device model… \(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .ready:
                readyBody
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5)))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1))
        .accessibilityIdentifier("insights-panel")
        .task { await viewModel.refreshAvailability() }
    }

    private func downloadConsent(bytes: Int64) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Insights run entirely on this Mac — no cloud, no cost, "
                 + "works offline. The model is a one-time "
                 + "\(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)) download.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                Task { await viewModel.download() }
            } label: {
                Label("Download model", systemImage: "arrow.down.circle")
            }
            .accessibilityIdentifier("insights-download")
        }
    }

    private var readyBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("", selection: $viewModel.selectedFamily) {
                ForEach(InsightFamily.allCases) { family in
                    Label(family.title, systemImage: family.systemImage)
                        .tag(family)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch viewModel.state(for: viewModel.selectedFamily) {
            case .idle:
                runButton("Run \(viewModel.selectedFamily.title.lowercased()) insights")
            case .running:
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Reading the project…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .result(let text):
                VStack(alignment: .leading, spacing: 8) {
                    Text(text)
                        .font(.callout)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("insights-result")
                    runButton("Run again")
                }
            case .failed(let message):
                VStack(alignment: .leading, spacing: 8) {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    runButton("Try again")
                }
            }
        }
    }

    private func runButton(_ title: String) -> some View {
        Button {
            let family = viewModel.selectedFamily
            Task { await viewModel.run(family: family, project: project) }
        } label: {
            Label(title, systemImage: "sparkles")
        }
        .accessibilityIdentifier("insights-run")
    }
}

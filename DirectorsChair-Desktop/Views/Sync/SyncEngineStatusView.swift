// SyncEngineStatusView.swift
//
// Toolbar affordance for SyncEngine v1 (first-party sync API). Shows the
// engine state, offers "Sync Now" (flush → push → pull-if-behind → reload),
// and surfaces the keep-mine / use-theirs conflict choice. Replaces the
// retired Gitea-era SyncStatusView mount.

import DirectorsChairServices
import SwiftUI

struct SyncEngineStatusView: View {
    @ObservedObject var engine: SyncEngine
    @EnvironmentObject private var projectViewModel: ProjectViewModel
    @EnvironmentObject private var authManager: AuthManager
    @State private var showConflict = false

    var body: some View {
        Button(action: { Task { await syncNow() } }) {
            HStack(spacing: 5) {
                if isSyncing, let progress = engine.progress {
                    // Byte-weighted transfer progress: determinate ring +
                    // percent, replacing the static icon while blobs move.
                    ProgressView(value: progress)
                        .progressViewStyle(.circular)
                        .controlSize(.small)
                    Text("\(Int((progress * 100).rounded()))%")
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: iconName)
                        .foregroundStyle(iconColor)
                }
                // Org subtitle (Orgs §12B.7): whose cloud this project
                // lives in, plus the pull-only marker for viewers.
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .help(helpText)
        .disabled(isSyncing || !authManager.isAuthenticated)
        .task(id: projectDir) {
            guard let dir = projectDir else { return }
            engine.loadRemoteContext(projectDir: dir)     // instant, cached
            await engine.refreshRemoteContext(projectDir: dir)
        }
        .onChange(of: engine.state) { _, newState in
            if case .conflict = newState { showConflict = true }
        }
        .alert("Sync Conflict", isPresented: $showConflict) {
            Button("Keep My Version") {
                Task { await resolve(keepMine: true) }
            }
            Button("Use Server Version", role: .destructive) {
                Task { await resolve(keepMine: false) }
            }
            Button("Decide Later", role: .cancel) {}
        } message: {
            Text("This project changed on another device and here. Both versions "
                 + "are preserved — choose which becomes the latest. "
                 + "(A backup of your local version is kept either way.)")
        }
    }

    private var isSyncing: Bool {
        if case .syncing = engine.state { return true }
        return false
    }

    private var iconName: String {
        switch engine.state {
        case .idle: return "icloud"
        case .syncing: return "arrow.triangle.2.circlepath.icloud"
        case .conflict: return "exclamationmark.icloud"
        case .error: return "xmark.icloud"
        case .synced: return "checkmark.icloud"
        }
    }

    private var iconColor: Color {
        switch engine.state {
        case .conflict, .error: return .orange
        case .synced: return .green
        default: return .secondary
        }
    }

    private var subtitle: String? {
        guard let orgName = engine.orgName else { return nil }
        return engine.isViewer ? "\(orgName) · view-only" : orgName
    }

    private var helpText: String {
        let base: String
        switch engine.state {
        case .idle: base = "Sync project to DirectorsChair Cloud"
        case .syncing(let message): base = message
        case .conflict: base = "Sync conflict — click to resolve"
        case .error(let message): base = message
        case .synced(let date):
            base = "Synced \(date.formatted(date: .omitted, time: .shortened))"
        }
        return engine.isViewer
            ? base + " (view-only access — Sync pulls the latest version)"
            : base
    }

    private var projectDir: URL? {
        let path = projectViewModel.project.basePath
        guard !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path)
    }

    @MainActor
    private func syncNow() async {
        guard let dir = projectDir else { return }
        // Viewer role: the server would 404 our commits (IDOR posture), so
        // Sync means "get the latest version" — no push, no failed state.
        if engine.isViewer {
            if await engine.pull(projectDir: dir) {
                try? await projectViewModel.load(from: dir.appendingPathComponent("project.json"))
            }
            return
        }
        // Flush the editor to disk so the manifest sees the latest document.
        await projectViewModel.saveSilently()
        let project = projectViewModel.project
        let pushed = await engine.push(projectDir: dir, projectID: project.uuid,
                                       name: project.name)
        guard pushed else { return }   // conflict/error surfaced via state
        if await engine.pull(projectDir: dir) {
            try? await projectViewModel.load(from: dir.appendingPathComponent("project.json"))
        }
    }

    @MainActor
    private func resolve(keepMine: Bool) async {
        guard let dir = projectDir else { return }
        if keepMine {
            await engine.resolveKeepMine(projectDir: dir)
        } else {
            await engine.resolveUseTheirs(projectDir: dir)
            try? await projectViewModel.load(from: dir.appendingPathComponent("project.json"))
        }
    }
}

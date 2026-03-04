// DirectorsChair-Desktop/Views/Sync/SyncStatusView.swift
//
// Cloud sync status indicator for the toolbar

import SwiftUI
import DirectorsChairServices

struct SyncStatusView: View {
    @ObservedObject var syncManager: CloudSyncManager
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var projectViewModel: ProjectViewModel

    @State private var showDetails = false
    @State private var showDebugLogs = false

    var body: some View {
        Button {
            showDetails.toggle()
        } label: {
            HStack(spacing: 4) {
                syncIcon
                    .font(.system(size: 13))

                if syncManager.pendingChanges > 0 {
                    Text("\(syncManager.pendingChanges)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.accentColor.opacity(0.2), in: Capsule())
                }
            }
        }
        .buttonStyle(.plain)
        .help(syncTooltip)
        .popover(isPresented: $showDetails, arrowEdge: .bottom) {
            syncDetailsPopover
        }
    }

    @ViewBuilder
    private var syncIcon: some View {
        switch syncManager.syncState {
        case .idle:
            Image(systemName: "cloud")
                .foregroundStyle(.secondary)
        case .syncing:
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.rotate)
        case .error:
            Image(systemName: "exclamationmark.icloud")
                .foregroundStyle(.red)
        case .lastSynced:
            Image(systemName: "checkmark.icloud")
                .foregroundStyle(.green)
        }
    }

    private var syncTooltip: String {
        switch syncManager.syncState {
        case .idle:
            return "Cloud Sync"
        case .syncing(_, let message):
            return message
        case .error(let msg):
            return "Sync error: \(msg)"
        case .lastSynced(let date):
            let formatter = RelativeDateTimeFormatter()
            return "Last synced \(formatter.localizedString(for: date, relativeTo: Date()))"
        }
    }

    @ViewBuilder
    private var syncDetailsPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "icloud")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.accentColor)
                Text("CLOUD SYNC")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Divider()

            // Status
            switch syncManager.syncState {
            case .idle:
                Label("Ready to sync", systemImage: "checkmark.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

            case .syncing(let progress, let message):
                VStack(alignment: .leading, spacing: 6) {
                    Text(message)
                        .font(.system(size: 12))
                    ProgressView(value: progress)
                }

            case .error(let message):
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(message)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

            case .lastSynced(let date):
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Synced \(date, style: .relative) ago")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            if syncManager.pendingChanges > 0 {
                Text("\(syncManager.pendingChanges) unsaved change\(syncManager.pendingChanges == 1 ? "" : "s")")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
            }

            Divider()

            // Sync button
            Button {
                Task {
                    await performSync()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Sync Now")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(!canSync)

            // Debug logs (collapsible)
            if !syncManager.debugLogs.isEmpty {
                Divider()

                DisclosureGroup("Debug Logs (\(syncManager.debugLogs.count))", isExpanded: $showDebugLogs) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(syncManager.debugLogs.enumerated()), id: \.offset) { _, entry in
                                Text(entry)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 150)
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(width: showDebugLogs ? 400 : 280)
    }

    private var canSync: Bool {
        guard authManager.isAuthenticated,
              authManager.currentUser != nil else { return false }

        if case .syncing = syncManager.syncState { return false }
        return true
    }

    private func performSync() async {
        guard let user = authManager.currentUser,
              projectViewModel.hasProject else { return }
        let project = projectViewModel.project

        // Set the auth token
        if let token = authManager.currentAccessToken {
            await syncManager.setAuthToken(token)
        }

        do {
            try await syncManager.push(project: project, username: user.username)
        } catch {
            // Error is set on syncManager.syncState
        }
    }
}

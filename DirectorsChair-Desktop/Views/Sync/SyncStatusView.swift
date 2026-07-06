// DirectorsChair-Desktop/Views/Sync/SyncStatusView.swift
//
// Cloud sync status indicator for the toolbar

import SwiftUI
import DirectorsChairServices
import DirectorsChairCore

struct SyncStatusView: View {
    @ObservedObject var syncManager: CloudSyncManager
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var projectViewModel: ProjectViewModel

    @State private var showDetails = false
    @State private var showDebugLogs = false

    // Sharing state
    @State private var showShareSection = false
    @State private var collaborators: [RemoteUser] = []
    @State private var searchQuery = ""
    @State private var searchResults: [RemoteUser] = []
    @State private var isLoadingCollaborators = false
    @State private var sharingError: String?

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

            // Sharing section
            if projectViewModel.hasProject && authManager.isAuthenticated {
                Divider()
                sharingSection
            }

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
        .frame(width: (showDebugLogs || showShareSection) ? 400 : 280)
    }

    // MARK: - Sharing Section

    @ViewBuilder
    private var sharingSection: some View {
        DisclosureGroup("Sharing", isExpanded: $showShareSection) {
            VStack(alignment: .leading, spacing: 10) {
                // Current collaborators
                if isLoadingCollaborators {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading...")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                } else if collaborators.isEmpty {
                    Text("No collaborators yet")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                } else {
                    VStack(spacing: 4) {
                        ForEach(collaborators, id: \.id) { collab in
                            HStack(spacing: 6) {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                Text(collab.username)
                                    .font(.system(size: 11, weight: .medium))
                                Text("write")
                                    .font(.system(size: 8, weight: .semibold))
                                    .tracking(0.5)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.15), in: Capsule())
                                    .foregroundStyle(Color.accentColor)
                                Spacer()
                                Button {
                                    Task { await removeCollaborator(collab.username) }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.red.opacity(0.7))
                                }
                                .buttonStyle(.plain)
                                .help("Remove \(collab.username)")
                            }
                            .padding(.vertical, 3)
                            .padding(.horizontal, 6)
                            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }

                // Add collaborator
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        TextField("Search users...", text: $searchQuery)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11))
                            .padding(5)
                            .background(Color(nsColor: .quaternarySystemFill), in: RoundedRectangle(cornerRadius: 6))
                            .onChange(of: searchQuery) { _, newValue in
                                Task { await performUserSearch(newValue) }
                            }
                        Button {
                            Task { await addCollaboratorByQuery() }
                        } label: {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(searchQuery.trimmingCharacters(in: .whitespaces).isEmpty)
                    }

                    // Search results dropdown
                    if !searchResults.isEmpty && !searchQuery.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(searchResults, id: \.id) { user in
                                Button {
                                    Task { await addCollaborator(user.username) }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "person")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.secondary)
                                        Text(user.username)
                                            .font(.system(size: 11))
                                        if !user.fullName.isEmpty {
                                            Text("(\(user.fullName))")
                                                .font(.system(size: 10))
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "plus.circle")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color.accentColor)
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 6)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                Divider()
                            }
                        }
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor).opacity(0.3)))
                    }
                }

                if let error = sharingError {
                    Text(error)
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                }
            }
            .padding(.top, 4)
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.secondary)
        .onChange(of: showShareSection) { _, expanded in
            if expanded {
                Task { await loadCollaborators() }
            }
        }
    }

    // MARK: - Sharing Actions

    private func loadCollaborators() async {
        guard let user = authManager.currentUser, projectViewModel.hasProject else { return }
        isLoadingCollaborators = true
        sharingError = nil
        do {
            collaborators = try await syncManager.listCollaborators(
                projectName: projectViewModel.project.name,
                username: user.username
            )
            // Filter out the owner from the list
            collaborators = collaborators.filter { $0.username != user.username }
        } catch {
            sharingError = "Failed to load collaborators"
        }
        isLoadingCollaborators = false
    }

    private func addCollaborator(_ username: String) async {
        guard let user = authManager.currentUser, projectViewModel.hasProject else { return }
        sharingError = nil
        do {
            try await syncManager.addCollaborator(
                username: username,
                permission: .write,
                projectName: projectViewModel.project.name,
                owner: user.username
            )
            searchQuery = ""
            searchResults = []
            await loadCollaborators()
        } catch {
            sharingError = "Failed to add \(username)"
        }
    }

    private func addCollaboratorByQuery() async {
        let username = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !username.isEmpty else { return }
        await addCollaborator(username)
    }

    private func removeCollaborator(_ username: String) async {
        guard let user = authManager.currentUser, projectViewModel.hasProject else { return }
        sharingError = nil
        do {
            try await syncManager.removeCollaborator(
                username: username,
                projectName: projectViewModel.project.name,
                owner: user.username
            )
            await loadCollaborators()
        } catch {
            sharingError = "Failed to remove \(username)"
        }
    }

    private func performUserSearch(_ query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            searchResults = []
            return
        }
        do {
            let results = try await syncManager.searchUsers(query: trimmed)
            // Filter out current user and existing collaborators
            let currentUsername = authManager.currentUser?.username ?? ""
            let existingUsernames = Set(collaborators.map(\.username))
            searchResults = results.filter {
                $0.username != currentUsername && !existingUsernames.contains($0.username)
            }
        } catch {
            searchResults = []
        }
    }

    // MARK: - Sync Logic

    private var canSync: Bool {
        guard authManager.isAuthenticated,
              authManager.currentUser != nil else { return false }

        if case .syncing = syncManager.syncState { return false }
        return true
    }

    private func performSync() async {
        guard let user = authManager.currentUser else { return }

        // Refresh token if expired, then set it
        do {
            try await authManager.refreshTokenIfNeeded()
        } catch {
            // Try force refresh if normal refresh fails
            try? await authManager.forceRefreshToken()
        }

        if let token = authManager.currentAccessToken {
            await syncManager.setAuthToken(token)
        }

        // 1. Push current project if one is open
        if projectViewModel.hasProject {
            let project = projectViewModel.project
            do {
                try await syncManager.push(project: project, username: user.username)
            } catch {
                // Error is set on syncManager.syncState
            }
        }

        // 2. Pull: discover remote projects not present locally
        do {
            let remoteRepos = try await syncManager.listRemoteProjects()
            let localProjectDirs = ProjectDirectoryManager.listProjects()

            for repo in remoteRepos {
                let repoName = repo.name
                let repoOwner = repo.owner.username

                // Check if a local directory already matches this repo
                let alreadyLocal = localProjectDirs.contains { dir in
                    syncManager.sanitizeRepoName(dir.lastPathComponent) == repoName
                }

                if !alreadyLocal {
                    // Pull into a new local directory named after the repo
                    let basePath = ProjectDirectoryManager.directorsChairRoot
                        .appendingPathComponent(repoName)
                    do {
                        let _ = try await syncManager.pull(
                            username: repoOwner,
                            repoName: repoName,
                            basePath: basePath
                        )
                    } catch {
                        debugLog("CloudSync: Failed to pull '\(repoName)': \(error)")
                    }
                }
            }
        } catch {
            debugLog("CloudSync: Failed to list remote repos: \(error)")
        }
    }
}

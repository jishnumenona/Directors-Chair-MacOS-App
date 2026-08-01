// DirectorsChair-Desktop/Views/Auth/AccountMenuView.swift
//
// Toolbar account menu — avatar + username dropdown with login/logout

import SwiftUI
import DirectorsChairServices

struct AccountMenuView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showUsageStats = false
    @State private var loginError: String?

    var body: some View {
        if let user = authManager.currentUser {
            // Logged-in state — avatar + username menu
            Menu {
                // User info header
                Section {
                    Label(user.fullName.isEmpty ? user.username : user.fullName, systemImage: "person.circle.fill")
                    if !user.email.isEmpty {
                        Label(user.email, systemImage: "envelope")
                    }
                }

                Divider()

                Section {
                    Button {
                        Task { await openWebDashboard() }
                    } label: {
                        Label("Open Web Dashboard", systemImage: "globe")
                    }

                    Button {
                        showUsageStats = true
                    } label: {
                        Label("AI Usage", systemImage: "chart.bar.fill")
                    }
                }

                Divider()

                Section {
                    Button(role: .destructive) {
                        Task {
                            await authManager.logout()
                        }
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.accentColor)

                    Text(user.username)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .sheet(isPresented: $showUsageStats) {
                UsageStatsView()
                    .frame(minWidth: 480, minHeight: 400)
            }

        } else if authManager.isLoading {
            // Loading state
            ProgressView()
                .controlSize(.small)
                .padding(.horizontal, 8)

        } else if !authManager.isAuthenticated {
            // Not logged in — show Sign In button
            Button {
                loginError = nil
                Task {
                    do {
                        try await authManager.login()
                    } catch {
                        loginError = error.localizedDescription
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "person.badge.key.fill")
                        .font(.system(size: 12))
                    Text("Sign In")
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .help("Sign in to enable AI and cloud features")

        } else {
            // Offline mode — allow login from here too
            Menu {
                Button {
                    // Switch from offline to login
                    authManager.isAuthenticated = false
                } label: {
                    Label("Sign In", systemImage: "person.badge.key")
                }
            } label: {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 7, height: 7)
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text("Offline")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5), in: Capsule())
                .overlay(Capsule().stroke(Color(nsColor: .separatorColor).opacity(0.3)))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    /// Opens the web dashboard signed in: mint a one-time handoff ticket with
    /// the desktop's auth, then open the browser to the platform's handoff URL
    /// (which redeems it into a web session). Falls back to the hosted login
    /// if the mint fails (offline / expired session).
    @MainActor
    private func openWebDashboard() async {
        let webBase = "https://directorschair.app"
        var target = URL(string: "\(webBase)/app/")!   // fallback: hosted login
        if let ticket = try? await authManager.createWebHandoffTicket(),
           let encoded = ticket.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "\(webBase)/api/v1/session/handoff?ticket=\(encoded)") {
            target = url
        }
        NSWorkspace.shared.open(target)
    }
}

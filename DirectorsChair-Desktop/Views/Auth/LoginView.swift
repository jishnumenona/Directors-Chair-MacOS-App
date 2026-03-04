// DirectorsChair-Desktop/Views/Auth/LoginView.swift
//
// Full-screen login gate — shown when user is not authenticated

import SwiftUI
import DirectorsChairServices

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showError = false

    var body: some View {
        ZStack {
            // Solid opaque background — fully covers content behind
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            // Subtle top-to-bottom gradient overlay
            LinearGradient(
                colors: [
                    Color(nsColor: .controlBackgroundColor).opacity(0.3),
                    Color.clear,
                    Color(nsColor: .controlBackgroundColor).opacity(0.2),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // App icon + title
                VStack(spacing: 16) {
                    Image(systemName: "film.stack")
                        .font(.system(size: 72))
                        .foregroundStyle(Color.accentColor)

                    Text("DirectorsChair")
                        .font(.system(size: 40, weight: .bold))

                    Text("Professional Filmmaking Suite")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Login card
                VStack(spacing: 24) {
                    // Primary login button
                    if authManager.isLoading {
                        ProgressView("Signing in...")
                            .controlSize(.large)
                    } else {
                        Button {
                            Task {
                                do {
                                    try await authManager.login()
                                } catch {
                                    authManager.errorMessage = error.localizedDescription
                                    showError = true
                                }
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "person.badge.key.fill")
                                    .font(.system(size: 16))
                                Text("Login with Gitea")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .frame(maxWidth: 280)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        // Continue offline
                        Button {
                            authManager.isAuthenticated = true // Offline mode
                        } label: {
                            Text("Continue Offline")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Use DirectorsChair without cloud features. AI generation will not be available.")
                    }

                    // Error display
                    if showError, let error = authManager.errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                            Text(error)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .frame(maxWidth: 360)
                        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.15)))
                    }
                }
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.3))
                )

                Spacer()

                // Footer
                Text("Your projects are stored locally. Cloud sync and AI features require login.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 32)
            }
            .frame(maxWidth: 420)
        }
    }
}

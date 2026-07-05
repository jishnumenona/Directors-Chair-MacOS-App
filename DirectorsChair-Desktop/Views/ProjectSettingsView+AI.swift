//
// ProjectSettingsView+AI.swift
//
// Extracted from ProjectSettingsView.swift (WS9.1 tier decomposition).
//

import SwiftUI
import AppKit
import DirectorsChairCore
import DirectorsChairServices
import DirectorsChairViews

extension ProjectSettingsView {

    // MARK: - AI Server Section

    var aiServerSection: some View {
        SettingsCard(title: "AI SERVER", icon: "server.rack") {
            VStack(alignment: .leading, spacing: 16) {
                // Server URL
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("Proxy Server URL")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 8) {
                        Text(aiProxyURL)
                            .font(.system(size: 12, design: .monospaced))
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .quaternarySystemFill))
                            .cornerRadius(6)

                        // Connection status indicator
                        HStack(spacing: 5) {
                            Circle()
                                .fill(aiCheckingHealth ? Color.yellow : (aiServerHealthy ? Color.green : Color.red))
                                .frame(width: 8, height: 8)
                            Text(aiCheckingHealth ? "Checking..." : (aiServerHealthy ? "Connected" : "Offline"))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(aiCheckingHealth ? .yellow : (aiServerHealthy ? .green : .red))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(nsColor: .quaternarySystemFill))
                        )
                    }
                }

                // Check connection button
                Button {
                    checkAIHealth()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                        Text("Test Connection")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .quaternarySystemFill))
                    )
                }
                .buttonStyle(.plain)
                .disabled(aiCheckingHealth)

                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    Text("All AI operations (text, image, video generation) are routed through this proxy server.")
                        .font(.system(size: 10))
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                }
            }
        }
        .onAppear { checkAIHealth() }
    }

    // MARK: - AI Providers Section

    var aiProvidersSection: some View {
        SettingsCard(title: "PROVIDERS", icon: "cpu") {
            VStack(alignment: .leading, spacing: 16) {
                // Default providers info
                VStack(alignment: .leading, spacing: 10) {
                    aiProviderRow(
                        label: "Text Generation",
                        icon: "text.bubble",
                        provider: "Google Gemini",
                        detail: "gemini-2.5-flash-preview"
                    )
                    Divider().opacity(0.3)
                    aiProviderRow(
                        label: "Image Generation",
                        icon: "photo",
                        provider: "Google Imagen",
                        detail: "imagen-3.0-generate"
                    )
                    Divider().opacity(0.3)
                    aiProviderRow(
                        label: "Video Generation",
                        icon: "film",
                        provider: "Google Veo",
                        detail: "veo-3"
                    )
                    Divider().opacity(0.3)
                    aiProviderRow(
                        label: "AI Chat",
                        icon: "bubble.left.and.bubble.right",
                        provider: "Google Gemini",
                        detail: "4000 tokens, temp 0.7"
                    )
                    Divider().opacity(0.3)
                    aiProviderRow(
                        label: "Character Analysis",
                        icon: "person.text.rectangle",
                        provider: "Google Gemini",
                        detail: "8000 tokens, temp 0.3"
                    )
                    Divider().opacity(0.3)
                    aiProviderRow(
                        label: "Screenplay Import",
                        icon: "doc.text.magnifyingglass",
                        provider: "Google Gemini",
                        detail: "65000 tokens, 5 passes"
                    )
                }

                // Available providers from health check
                if !aiAvailableProviders.isEmpty {
                    Divider().opacity(0.5)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.shield")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text("Available Providers")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 6)], alignment: .leading, spacing: 6) {
                            ForEach(aiAvailableProviders.sorted(by: { $0.key < $1.key }), id: \.key) { provider, available in
                                HStack(spacing: 5) {
                                    Circle()
                                        .fill(available ? Color.green : Color.red.opacity(0.6))
                                        .frame(width: 6, height: 6)
                                    Text(provider)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(available ? .primary : .secondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(nsColor: .quaternarySystemFill))
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - AI Usage Section

    var aiUsageSection: some View {
        SettingsCard(title: "USAGE & COSTS", icon: "chart.line.uptrend.xyaxis") {
            VStack(alignment: .leading, spacing: 16) {
                // Session stats from AIUsageTracker
                let tracker = AIUsageTracker.shared
                let sessionStats = tracker.sessionStats

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    StatBadge(icon: "text.bubble", label: "Text Calls", value: "\(sessionStats.totalTextCalls)")
                    StatBadge(icon: "photo", label: "Images", value: "\(sessionStats.totalImages)")
                    StatBadge(icon: "film", label: "Videos", value: "\(sessionStats.totalVideos)")
                    StatBadge(icon: "dollarsign.circle", label: "Session Cost", value: String(format: "$%.2f", sessionStats.totalCostUSD))
                }

                Divider().opacity(0.5)

                // Token usage
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.doc")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text("Input Tokens")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        Text(formatNumber(sessionStats.totalPromptTokens))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.doc")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text("Output Tokens")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        Text(formatNumber(sessionStats.totalCompletionTokens))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "video")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text("Video Duration")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        Text(String(format: "%.1fs", sessionStats.totalVideoSeconds))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Cost breakdown
                Divider().opacity(0.5)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "dollarsign.circle")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("Pricing Reference")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 0) {
                        costInfoCell(label: "Text Input", value: "$0.30 / 1M tokens")
                        costInfoCell(label: "Text Output", value: "$2.50 / 1M tokens")
                        costInfoCell(label: "Image", value: "$0.04 / image")
                        costInfoCell(label: "Video", value: "$0.02 / second")
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    Text("Session stats reset when the app restarts. Costs are estimates based on Google Gemini Flash pricing.")
                        .font(.system(size: 10))
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                }
            }
        }
    }
}

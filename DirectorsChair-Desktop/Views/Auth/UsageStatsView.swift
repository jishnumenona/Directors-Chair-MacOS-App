// DirectorsChair-Desktop/Views/Auth/UsageStatsView.swift
//
// AI usage statistics panel — fetches from server API

import SwiftUI
import DirectorsChairServices

struct UsageStatsView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @State private var usageData: UsageData?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("AI Usage")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            if isLoading {
                Spacer()
                ProgressView("Loading usage data...")
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Button("Retry") {
                        Task { await loadUsage() }
                    }
                }
                Spacer()
            } else if let data = usageData {
                ScrollView {
                    VStack(spacing: 24) {
                        // Today's usage
                        usageSection(title: "Today", stats: data.today)

                        // This month
                        usageSection(title: "This Month", stats: data.month)

                        // Quota remaining
                        if let quota = data.quota {
                            quotaSection(quota: quota)
                        }
                    }
                    .padding()
                }
            }
        }
        .task {
            await loadUsage()
        }
    }

    @ViewBuilder
    private func usageSection(title: String, stats: UsagePeriod) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                statCard(icon: "text.justify.leading", label: "Text", value: "\(stats.textCount)")
                statCard(icon: "photo", label: "Images", value: "\(stats.imageCount)")
                statCard(icon: "film", label: "Videos", value: "\(stats.videoCount)")
                statCard(icon: "waveform", label: "Speech", value: "\(stats.speechCount)")
            }

            if stats.estimatedCost > 0 {
                HStack {
                    Text("Estimated cost")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "$%.2f", stats.estimatedCost))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                }
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(nsColor: .separatorColor).opacity(0.3)))
    }

    @ViewBuilder
    private func statCard(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.accentColor)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func quotaSection(quota: QuotaInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("QUOTA")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(quota.tier.capitalized)
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15), in: Capsule())
            }

            quotaRow(label: "Text", used: quota.textUsed, limit: quota.textLimit)
            quotaRow(label: "Images", used: quota.imageUsed, limit: quota.imageLimit)
            quotaRow(label: "Videos", used: quota.videoUsed, limit: quota.videoLimit)
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(nsColor: .separatorColor).opacity(0.3)))
    }

    @ViewBuilder
    private func quotaRow(label: String, used: Int, limit: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 12))
                Spacer()
                Text("\(used)/\(limit)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: Double(used), total: Double(max(limit, 1)))
                .tint(used >= limit ? .red : Color.accentColor)
        }
    }

    private func loadUsage() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let token = authManager.currentAccessToken else {
            errorMessage = "Not authenticated"
            return
        }

        // Fetch from API server
        let baseURL = "https://directorschair.app/ai"
        guard let url = URL(string: "\(baseURL)/api/usage/me") else {
            errorMessage = "Invalid server URL"
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                errorMessage = "Server returned an error"
                return
            }

            let decoded = try JSONDecoder().decode(UsageData.self, from: data)
            usageData = decoded
        } catch {
            errorMessage = "Failed to load usage: \(error.localizedDescription)"
        }
    }
}

// MARK: - Usage Data Models

private struct UsageData: Codable {
    let today: UsagePeriod
    let month: UsagePeriod
    let quota: QuotaInfo?
}

private struct UsagePeriod: Codable {
    let textCount: Int
    let imageCount: Int
    let videoCount: Int
    let speechCount: Int
    let estimatedCost: Double

    enum CodingKeys: String, CodingKey {
        case textCount = "text_count"
        case imageCount = "image_count"
        case videoCount = "video_count"
        case speechCount = "speech_count"
        case estimatedCost = "estimated_cost"
    }
}

private struct QuotaInfo: Codable {
    let tier: String
    let textUsed: Int
    let textLimit: Int
    let imageUsed: Int
    let imageLimit: Int
    let videoUsed: Int
    let videoLimit: Int

    enum CodingKeys: String, CodingKey {
        case tier
        case textUsed = "text_used"
        case textLimit = "text_limit"
        case imageUsed = "image_used"
        case imageLimit = "image_limit"
        case videoUsed = "video_used"
        case videoLimit = "video_limit"
    }
}

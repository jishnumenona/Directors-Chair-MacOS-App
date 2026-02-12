//
//  AIUsageWidget.swift
//  DirectorsChair-Desktop
//
//  Compact toolbar widget showing AI costs and project storage
//

import SwiftUI
import DirectorsChairServices

struct AIUsageWidget: View {
    let projectStorageSize: Int64

    @ObservedObject private var tracker = AIUsageTracker.shared
    @State private var showingPopover = false

    var body: some View {
        Button(action: { showingPopover.toggle() }) {
            HStack(spacing: 6) {
                // AI cost
                HStack(spacing: 3) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                        .foregroundColor(.accentColor)
                    Text(formattedCost(tracker.projectStats.totalCostUSD))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                }

                Rectangle()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(width: 1, height: 14)

                // Storage
                HStack(spacing: 3) {
                    Image(systemName: "internaldrive")
                        .font(.system(size: 10))
                        .foregroundColor(.accentColor)
                    Text(StorageSizeCalculator.formattedSize(projectStorageSize))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingPopover, arrowEdge: .bottom) {
            AIUsagePopover(projectStorageSize: projectStorageSize)
        }
    }

    private func formattedCost(_ cost: Double) -> String {
        if cost < 0.01 {
            return String(format: "$%.3f", cost)
        }
        return String(format: "$%.2f", cost)
    }
}

// MARK: - Expanded Popover

struct AIUsagePopover: View {
    let projectStorageSize: Int64

    @ObservedObject private var tracker = AIUsageTracker.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Session section
            usageSection(
                title: "AI USAGE THIS SESSION",
                icon: "sparkles",
                stats: tracker.sessionStats
            )

            Divider()
                .padding(.vertical, 8)

            // Project total section
            HStack(spacing: 6) {
                Image(systemName: "folder")
                    .font(.system(size: 10))
                    .foregroundColor(.accentColor)
                Text("PROJECT TOTAL")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(.secondary)
                Spacer()
                Text(formattedCost(tracker.projectStats.totalCostUSD))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
            }

            Divider()
                .padding(.vertical, 8)

            // Storage section
            HStack(spacing: 6) {
                Image(systemName: "internaldrive")
                    .font(.system(size: 10))
                    .foregroundColor(.accentColor)
                Text("PROJECT STORAGE")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(.secondary)
                Spacer()
                Text(StorageSizeCalculator.formattedSize(projectStorageSize))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
            }

            Divider()
                .padding(.vertical, 8)

            // Action buttons
            HStack {
                Button("Reset Session") {
                    tracker.resetSession()
                }
                .font(.system(size: 11))

                Spacer()

                Button("Reset Project Usage") {
                    tracker.resetLifetime()
                }
                .font(.system(size: 11))
                .foregroundColor(.red)
            }
        }
        .padding(16)
        .frame(width: 300)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    @ViewBuilder
    private func usageSection(title: String, icon: String, stats: AIUsageStats) -> some View {
        // Header
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(.accentColor)
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundColor(.secondary)
        }
        .padding(.bottom, 10)

        // Stats rows
        VStack(spacing: 6) {
            statRow(label: "Text Calls", value: "\(stats.totalTextCalls)")
            statRow(label: "Input Tokens", value: formatNumber(stats.totalPromptTokens), cost: stats.textInputCostUSD)
            statRow(label: "Output Tokens", value: formatNumber(stats.totalCompletionTokens), cost: stats.textOutputCostUSD)
            statRow(label: "Images", value: "\(stats.totalImages)", cost: stats.imageCostUSD)
            if stats.totalVideoCalls > 0 {
                statRow(label: "Videos", value: "\(stats.totalVideoCalls) (\(String(format: "%.0fs", stats.totalVideoSeconds)))", cost: stats.videoCostUSD)
            }

            Divider()
                .padding(.vertical, 2)

            HStack {
                Text("Session Total")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                Text(formattedCost(stats.totalCostUSD))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.accentColor)
            }
        }
    }

    private func statRow(label: String, value: String, cost: Double? = nil) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.primary)
            if let cost = cost {
                Text(formattedCost(cost))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .trailing)
            }
        }
    }

    private func formattedCost(_ cost: Double) -> String {
        if cost < 0.01 {
            return String(format: "$%.3f", cost)
        }
        return String(format: "$%.2f", cost)
    }

    private func formatNumber(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}

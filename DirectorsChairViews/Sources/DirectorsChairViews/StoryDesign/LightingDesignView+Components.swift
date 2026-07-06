//
// LightingDesignView+Components.swift
//
// Extracted from LightingDesignView.swift (WS9.1 tier decomposition).
//

import SwiftUI
import DirectorsChairCore


// MARK: - Light Attribute Card

struct LightAttributeCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(1.2)
            }
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Light Chip

struct LightChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor : Color(nsColor: .quaternarySystemFill))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Lighting Tab Chip

struct LightingTabChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(label)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor : Color(nsColor: .quaternarySystemFill))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Color hex helper

extension Color {
    var lightCueHexString: String {
        let nsColor = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        let r = Int(nsColor.redComponent * 255)
        let g = Int(nsColor.greenComponent * 255)
        let b = Int(nsColor.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - MM:SS Time Field

struct TimeFieldMMSS: View {
    let label: String
    @Binding var seconds: Double
    var isReadOnly: Bool = false

    @State private var minText: String = ""
    @State private var secText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                .tracking(0.5)
            if isReadOnly {
                Text(DurationEstimator.formatTime(CGFloat(seconds)))
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .padding(6)
                    .background(Color(nsColor: .quaternarySystemFill))
                    .cornerRadius(6)
                    .frame(minWidth: 70)
            } else {
                HStack(spacing: 2) {
                    TextField("00", text: $minText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .padding(6)
                        .background(Color(nsColor: .quaternarySystemFill))
                        .cornerRadius(6)
                        .frame(width: 36)
                        .multilineTextAlignment(.trailing)
                        .onSubmit { commitTime() }
                        .onChange(of: minText) { _ in commitTime() }
                    Text(":")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                    TextField("00", text: $secText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .padding(6)
                        .background(Color(nsColor: .quaternarySystemFill))
                        .cornerRadius(6)
                        .frame(width: 36)
                        .multilineTextAlignment(.leading)
                        .onSubmit { commitTime() }
                        .onChange(of: secText) { _ in commitTime() }
                }
            }
        }
        .onAppear { syncFromSeconds() }
        .onChange(of: seconds) { _ in syncFromSeconds() }
    }

    private func syncFromSeconds() {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        let newMin = String(format: "%02d", m)
        let newSec = String(format: "%02d", s)
        if minText != newMin { minText = newMin }
        if secText != newSec { secText = newSec }
    }

    private func commitTime() {
        let m = Int(minText) ?? 0
        let s = Int(secText) ?? 0
        let total = Double(max(0, m * 60 + s))
        if seconds != total {
            seconds = total
        }
    }
}

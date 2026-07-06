//
// LightingGanttView+Components.swift
//
// Extracted from LightingGanttView.swift (WS9.1 tier decomposition).
//

import SwiftUI
import UniformTypeIdentifiers
import DirectorsChairCore


// MARK: - Gantt Bar Shape (Lighting)

struct GanttBarShape: View {
    let cue: LightCue
    let barWidth: CGFloat
    let barHeight: CGFloat
    let pxPerSec: CGFloat
    var isSelected: Bool = false

    var barColor: Color { Color(hex: cue.markerColor) }
    var barOpacity: CGFloat { cue.intensity * 0.6 + 0.15 }
    var fadeInWidth: CGFloat { CGFloat(cue.fadeInDuration) * pxPerSec }
    var fadeOutWidth: CGFloat { CGFloat(cue.fadeOutDuration) * pxPerSec }

    var body: some View {
        ZStack(alignment: .leading) {
            // Main bar
            RoundedRectangle(cornerRadius: 4)
                .fill(barColor.opacity(barOpacity))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(barColor.opacity(isSelected ? 1.0 : 0.8), lineWidth: isSelected ? 2.5 : 1)
                )

            // Fade-in gradient
            if fadeInWidth > 2 {
                LinearGradient(
                    colors: [barColor.opacity(0), barColor.opacity(barOpacity)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: min(fadeInWidth, barWidth * 0.4))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            // Fade-out gradient
            if fadeOutWidth > 2 {
                HStack {
                    Spacer()
                    LinearGradient(
                        colors: [barColor.opacity(barOpacity), barColor.opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: min(fadeOutWidth, barWidth * 0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }

            // Label inside bar (icon + cue number + name)
            if barWidth > 40 {
                HStack(spacing: 3) {
                    Image(systemName: cue.fixtureType.icon)
                        .font(.system(size: 8))
                    Text(cue.cueNumber)
                        .font(.system(size: 9, weight: .semibold))
                    if barWidth > 80 {
                        Text(cue.name)
                            .font(.system(size: 9))
                            .lineLimit(1)
                    }
                }
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 0.5)
                .padding(.leading, 6)
            }

            // Intensity line at bottom
            VStack {
                Spacer()
                Rectangle()
                    .fill(barColor)
                    .frame(width: barWidth * cue.intensity, height: 2)
                    .padding(.bottom, 2)
                    .padding(.leading, 2)
            }
        }
    }
}

// MARK: - SFX Gantt Bar Shape

struct SFXGanttBarShape: View {
    let cue: SFXCue
    let barWidth: CGFloat
    let barHeight: CGFloat
    let pxPerSec: CGFloat
    var isSelected: Bool = false

    var barColor: Color { Color(hex: cue.markerColor) }
    var barOpacity: CGFloat { cue.intensity * 0.6 + 0.15 }
    var fadeInWidth: CGFloat { CGFloat(cue.fadeInDuration) * pxPerSec }
    var fadeOutWidth: CGFloat { CGFloat(cue.fadeOutDuration) * pxPerSec }

    var body: some View {
        ZStack(alignment: .leading) {
            // Main bar
            RoundedRectangle(cornerRadius: 4)
                .fill(barColor.opacity(barOpacity))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(barColor.opacity(isSelected ? 1.0 : 0.8), lineWidth: isSelected ? 2.5 : 1)
                )

            // Fade-in gradient
            if fadeInWidth > 2 {
                LinearGradient(
                    colors: [barColor.opacity(0), barColor.opacity(barOpacity)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: min(fadeInWidth, barWidth * 0.4))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            // Fade-out gradient
            if fadeOutWidth > 2 {
                HStack {
                    Spacer()
                    LinearGradient(
                        colors: [barColor.opacity(barOpacity), barColor.opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: min(fadeOutWidth, barWidth * 0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }

            // Label inside bar (icon + cue number + name)
            if barWidth > 40 {
                HStack(spacing: 3) {
                    Image(systemName: cue.effectType.icon)
                        .font(.system(size: 8))
                    Text(cue.cueNumber)
                        .font(.system(size: 9, weight: .semibold))
                    if barWidth > 80 {
                        Text(cue.name)
                            .font(.system(size: 9))
                            .lineLimit(1)
                    }
                }
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 0.5)
                .padding(.leading, 6)
            }

            // Intensity line at bottom
            VStack {
                Spacer()
                Rectangle()
                    .fill(barColor)
                    .frame(width: barWidth * cue.intensity, height: 2)
                    .padding(.bottom, 2)
                    .padding(.leading, 2)
            }
        }
    }
}

// MARK: - Support Gantt Bar Shape

struct SupportGanttBarShape: View {
    let cue: SupportCue
    let barWidth: CGFloat
    let barHeight: CGFloat
    var isSelected: Bool = false

    var barColor: Color { Color(hex: cue.markerColor) }

    var body: some View {
        ZStack(alignment: .leading) {
            // Main bar (no fade gradients for support actions)
            RoundedRectangle(cornerRadius: 4)
                .fill(barColor.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(barColor.opacity(isSelected ? 1.0 : 0.8), lineWidth: isSelected ? 2.5 : 1)
                )

            // Label inside bar (icon + cue number)
            if barWidth > 40 {
                HStack(spacing: 3) {
                    Image(systemName: cue.actionType.icon)
                        .font(.system(size: 8))
                    Text(cue.cueNumber)
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 0.5)
                .padding(.leading, 6)
            }
        }
    }
}

// MARK: - Filter Chip

struct GanttFilterChip: View {
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

// MARK: - Scroll Offset Preference Key

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

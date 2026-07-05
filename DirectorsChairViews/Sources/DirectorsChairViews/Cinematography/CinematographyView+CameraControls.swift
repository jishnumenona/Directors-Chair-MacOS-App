//
// CinematographyView+CameraControls.swift
//
// Extracted from CinematographyView.swift (WS9.1 god-file decomposition).
// Behaviour unchanged; these were file-private helpers, now module-internal.
//

import SwiftUI
import AVFoundation
import DirectorsChairCore
import DirectorsChairServices


// MARK: - Shot Info Pill

struct ShotInfoPill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(text)
                .font(.system(size: 10))
        }
        .foregroundColor(.gray)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(hex: "#2A2A2A"))
        .cornerRadius(4)
    }
}

// MARK: - Camera Setting Card (Read-only, kept for reference)

struct CameraSettingCard: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Text(value)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(hex: "#2A2A2A"))
        .cornerRadius(8)
    }
}

// MARK: - Shot Attribute Descriptions

/// Descriptions for camera angles to help users choose
let cameraAngleDescriptions: [String: String] = [
    "Eye Level": "Natural, neutral perspective at subject's eye height. Creates relatability and connection.",
    "Low": "Camera looks up at subject. Conveys power, dominance, or heroism.",
    "High": "Camera looks down on subject. Suggests vulnerability, weakness, or insignificance.",
    "Dutch": "Tilted camera angle. Creates unease, tension, or psychological disturbance.",
    "Bird's Eye": "Directly overhead view. Provides god-like perspective, shows spatial relationships.",
    "Worm's Eye": "Extreme low angle from ground. Dramatic effect, makes subjects appear monumental.",
    "POV": "Point of view shot. Shows exactly what character sees, creates immersion."
]

/// Descriptions for shot types to help users choose
let shotTypeDescriptions: [String: String] = [
    "ECU": "Extreme Close-Up — Single feature (eyes, hands). Intense focus, heightens emotion.",
    "CU": "Close-Up — Face fills frame. Shows emotion and reaction, creates intimacy.",
    "MCU": "Medium Close-Up — Chest up. Intimate but not too personal, great for dialogue.",
    "MS": "Medium Shot — Waist up. Standard conversational framing, shows body language.",
    "MWS": "Medium Wide Shot — Subject from knees up. Balances character and environment.",
    "WS": "Wide Shot — Shows full body with environment. Establishes setting and character's place in it.",
    "EWS": "Extreme Wide Shot — Establishes vast environment, subject appears tiny. Great for landscapes.",
    "OTS": "Over The Shoulder — Shows subject from behind another character. Creates intimacy in dialogue.",
    "2S": "Two Shot — Two subjects in frame. Shows relationship and interaction between characters.",
    "3S": "Three Shot — Three subjects in frame. Shows group dynamics while maintaining focus.",
    "Group": "Group Shot — Multiple subjects. Establishes group dynamics and relationships.",
    "Insert": "Insert Shot — Detail shot of object or action. Draws attention to important story elements.",
    "Cutaway": "Cutaway — Shot of something outside main action. Provides context or parallel action.",
    "POV": "Point of View — Shows exactly what character sees. Creates immersion and subjectivity.",
    "Reaction": "Reaction Shot — Character's response to events. Essential for emotional impact."
]

/// Descriptions for camera movements to help users choose
let movementDescriptions: [String: String] = [
    "Static": "No camera movement. Stable, observational, lets action unfold naturally.",
    "Pan Left": "Horizontal rotation left. Follows action or reveals environment to the left.",
    "Pan Right": "Horizontal rotation right. Follows action or reveals environment to the right.",
    "Tilt Up": "Vertical rotation upward. Reveals height, follows upward movement, shows scale.",
    "Tilt Down": "Vertical rotation downward. Focuses attention, moves down to subject.",
    "Dolly In": "Camera moves toward subject. Increases intensity, draws viewer in emotionally.",
    "Dolly Out": "Camera moves away from subject. Creates distance, reveals context.",
    "Dolly Left": "Camera slides left. Reveals new elements, follows lateral action.",
    "Dolly Right": "Camera slides right. Reveals new elements, follows lateral action.",
    "Tracking": "Camera follows alongside subject. Creates energy, keeps pace with action.",
    "Crane Up": "Camera rises vertically. Reveals scope, often used for dramatic endings.",
    "Crane Down": "Camera descends vertically. Focuses attention, moves into scene.",
    "Handheld": "Deliberate camera shake. Creates urgency, documentary feel, tension.",
    "Steadicam": "Smooth handheld movement. Fluid following shots, dreamlike quality.",
    "Zoom In": "Lens zooms closer. Quick focus shift, can feel voyeuristic or dramatic.",
    "Zoom Out": "Lens zooms wider. Reveals context, can create isolation effect.",
    "Push In": "Slow move toward subject. Builds tension, focuses attention gradually.",
    "Pull Out": "Slow move away from subject. Reveals surprise, shows isolation.",
    "Arc Left": "Camera moves in curved path left around subject. Dynamic reveal, adds dimension.",
    "Arc Right": "Camera moves in curved path right around subject. Dynamic reveal, adds dimension.",
    "Whip Pan": "Very fast pan. Creates energy, shows passage of time, transitions scenes."
]

/// Descriptions for lens focal lengths
let lensDescriptions: [Int: String] = [
    16: "Ultra wide — Dramatic distortion, vast environments, claustrophobic interiors",
    24: "Wide angle — Expansive view, slight distortion, great for landscapes and interiors",
    28: "Moderate wide — Natural wide view, minimal distortion, versatile storytelling lens",
    35: "Classic cinema — Natural perspective, slight width, the 'director's lens'",
    50: "Standard — Closest to human vision, neutral and natural look",
    85: "Portrait — Flattering compression, beautiful bokeh, ideal for close-ups",
    100: "Short telephoto — Compressed perspective, intimate feel, great for dialogue",
    135: "Telephoto — Strong compression, isolates subject, cinematic depth",
    200: "Long telephoto — Extreme compression, voyeuristic feel, dramatic isolation"
]

/// Descriptions for aperture values
let apertureDescriptions: [String: String] = [
    "f/1.2": "Extremely shallow depth — Dreamy, romantic, razor-thin focus plane",
    "f/1.4": "Very shallow depth — Beautiful bokeh, subject isolation, low light capable",
    "f/1.8": "Shallow depth — Soft backgrounds, subject emphasis, intimate feel",
    "f/2": "Moderately shallow — Good separation, natural look, versatile",
    "f/2.8": "Standard cinema — Classic look, manageable focus, professional standard",
    "f/4": "Moderate depth — More in focus, easier to shoot, good for movement",
    "f/5.6": "Medium depth — Balanced sharpness, good for group shots",
    "f/8": "Deep focus — Most of frame sharp, documentary style, landscape work",
    "f/11": "Very deep focus — Nearly everything sharp, detailed environments",
    "f/16": "Maximum depth — Everything in focus, architectural, maximum detail"
]

// MARK: - Chip Selector (Modern pill-style selector)

struct ChipSelector: View {
    let icon: String
    let title: String
    let options: [String]
    let selectedValue: String
    let onSelect: (String) -> Void
    var descriptions: [String: String] = [:]

    @State private var hoveredOption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header with tooltip
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)

                // Tooltip appears here, next to title
                if let hovered = hoveredOption, let desc = descriptions[hovered] {
                    Text("— \(desc)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            // Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        ChipButton(
                            label: option,
                            isSelected: option == selectedValue,
                            isHoveredBinding: Binding(
                                get: { hoveredOption == option },
                                set: { if $0 { hoveredOption = option } else if hoveredOption == option { hoveredOption = nil } }
                            ),
                            onTap: { onSelect(option) }
                        )
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }
}

struct ChipButton: View {
    let label: String
    let isSelected: Bool
    @Binding var isHoveredBinding: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color(hex: "#3A3A3A"))
                        .overlay(
                            Capsule()
                                .stroke(isHovered && !isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                )
                .foregroundColor(isSelected ? .white : .gray)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
            isHoveredBinding = hovering
        }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .animation(.easeInOut(duration: 0.1), value: isHovered)
    }
}

// MARK: - Lens Selector (Compact number chips)

struct LensSelector: View {
    let icon: String
    let title: String
    let options: [Int]
    let selectedValue: Int?
    let onSelect: (Int) -> Void
    var descriptions: [Int: String] = [:]

    @State private var hoveredLens: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header with tooltip
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)

                if let hovered = hoveredLens, let desc = descriptions[hovered] {
                    Text("— \(desc)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            // Lens chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(options, id: \.self) { lens in
                        LensChip(
                            value: lens,
                            isSelected: lens == selectedValue,
                            isHoveredBinding: Binding(
                                get: { hoveredLens == lens },
                                set: { if $0 { hoveredLens = lens } else if hoveredLens == lens { hoveredLens = nil } }
                            ),
                            onTap: { onSelect(lens) }
                        )
                    }
                }
            }
        }
        .frame(minWidth: 180)
    }
}

struct LensChip: View {
    let value: Int
    let isSelected: Bool
    @Binding var isHoveredBinding: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            Text("\(value)")
                .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .rounded))
                .frame(width: 36, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.accentColor : Color(hex: "#3A3A3A"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isHovered && !isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                )
                .foregroundColor(isSelected ? .white : .gray)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
            isHoveredBinding = hovering
        }
    }
}

// MARK: - Aperture Selector (f-stop chips)

struct ApertureSelector: View {
    let icon: String
    let title: String
    let options: [String]
    let selectedValue: String
    let onSelect: (String) -> Void
    var descriptions: [String: String] = [:]

    @State private var hoveredAperture: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header with tooltip
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)

                if let hovered = hoveredAperture, let desc = descriptions[hovered] {
                    Text("— \(desc)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            // Aperture chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(options, id: \.self) { aperture in
                        ApertureChip(
                            value: aperture,
                            isSelected: aperture == selectedValue,
                            isHoveredBinding: Binding(
                                get: { hoveredAperture == aperture },
                                set: { if $0 { hoveredAperture = aperture } else if hoveredAperture == aperture { hoveredAperture = nil } }
                            ),
                            onTap: { onSelect(aperture) }
                        )
                    }
                }
            }
        }
        .frame(minWidth: 200)
    }
}

struct ApertureChip: View {
    let value: String
    let isSelected: Bool
    @Binding var isHoveredBinding: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            Text(value)
                .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .monospaced))
                .frame(minWidth: 36, minHeight: 28, maxHeight: 28)
                .padding(.horizontal, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.accentColor : Color(hex: "#3A3A3A"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isHovered && !isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                )
                .foregroundColor(isSelected ? .white : .gray)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
            isHoveredBinding = hovering
        }
    }
}

// MARK: - Duration Editor (Stepper style)

struct DurationEditor: View {
    let icon: String
    let title: String
    let value: Double?
    let onValueChange: (Double?) -> Void

    @State private var displayValue: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            }

            // Duration control
            HStack(spacing: 0) {
                // Decrease button
                Button {
                    let newValue = max(0.5, displayValue - 0.5)
                    displayValue = newValue
                    onValueChange(newValue)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 28, height: 28)
                        .background(Color(hex: "#3A3A3A"))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
                .cornerRadius(6, corners: [.topLeft, .bottomLeft])

                // Value display
                Text(String(format: "%.1fs", displayValue))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .frame(width: 50, height: 28)
                    .background(Color(hex: "#2A2A2A"))
                    .foregroundColor(.white)

                // Increase button
                Button {
                    let newValue = displayValue + 0.5
                    displayValue = newValue
                    onValueChange(newValue)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 28, height: 28)
                        .background(Color(hex: "#3A3A3A"))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
                .cornerRadius(6, corners: [.topRight, .bottomRight])
            }
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(hex: "#4A4A4A"), lineWidth: 1)
            )
        }
        .onAppear {
            displayValue = value ?? 2.0
        }
        .onChange(of: value) { _, newValue in
            displayValue = newValue ?? 2.0
        }
    }
}

// MARK: - Corner Radius Helper
//
// File-private to this file: the camera-setting chips (above) are the only
// users of the partial-corner rounding. Other files in the package (e.g.
// TakesSectionView) intentionally keep their own private RectCorner/RoundedCorner
// with different shapes, so these must not be widened to internal.

private extension View {
    func cornerRadius(_ radius: CGFloat, corners: RectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

private struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: RectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let tl = corners.contains(.topLeft) ? radius : 0
        let tr = corners.contains(.topRight) ? radius : 0
        let bl = corners.contains(.bottomLeft) ? radius : 0
        let br = corners.contains(.bottomRight) ? radius : 0

        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr), radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br), radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl), radius: bl, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl), radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)

        return path
    }
}

private struct RectCorner: OptionSet {
    let rawValue: Int

    static let topLeft = RectCorner(rawValue: 1 << 0)
    static let topRight = RectCorner(rawValue: 1 << 1)
    static let bottomLeft = RectCorner(rawValue: 1 << 2)
    static let bottomRight = RectCorner(rawValue: 1 << 3)
    static let allCorners: RectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

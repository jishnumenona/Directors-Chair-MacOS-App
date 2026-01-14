// DirectorsChairViews/Sources/DirectorsChairViews/StoryDesign/PersonalityTraitsTab.swift
//
// Personality traits editor with radar chart visualization

import SwiftUI
import DirectorsChairCore

/// Personality traits tab - shows 25 traits organized by 5 categories
///
/// Categories:
/// - Openness: Creativity, Curiosity, Imagination, Open-mindedness, Artistic interest
/// - Conscientiousness: Organization, Diligence, Reliability, Self-discipline, Ambition
/// - Extraversion: Sociability, Energy, Assertiveness, Enthusiasm, Talkativeness
/// - Agreeableness: Empathy, Cooperation, Trust, Kindness, Politeness
/// - Neuroticism: Anxiety, Moodiness, Sensitivity, Irritability, Self-consciousness
public struct PersonalityTraitsTab: View {
    @Binding var character: Character
    @State private var selectedCategory: TraitCategory = .openness

    // Callbacks
    var onAnalyzeFromScript: (() -> Void)?
    var onResetToDefaults: (() -> Void)?

    public init(
        character: Binding<Character>,
        onAnalyzeFromScript: (() -> Void)? = nil,
        onResetToDefaults: (() -> Void)? = nil
    ) {
        self._character = character
        self.onAnalyzeFromScript = onAnalyzeFromScript
        self.onResetToDefaults = onResetToDefaults
    }

    public var body: some View {
        HSplitView {
            // Left: Radar chart visualization
            VStack {
                Text("Personality Profile")
                    .font(.headline)
                    .padding(.top)

                TraitsRadarChart(traits: character.traits)
                    .frame(minWidth: 300, minHeight: 300)
                    .padding()

                // AI Calibration info
                if let confidence = character.traitsConfidenceScore {
                    HStack {
                        Text("AI Confidence:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(Int(confidence))%")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(confidence >= 70 ? .green : .orange)
                    }
                }

                // Action buttons
                HStack {
                    Button("Analyze from Script") {
                        onAnalyzeFromScript?()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Reset to Defaults") {
                        onResetToDefaults?()
                    }
                }
                .padding()

                Spacer()
            }
            .frame(minWidth: 350)
            .background(Color(NSColor.controlBackgroundColor))

            // Right: Trait sliders
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Category picker
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(TraitCategory.allCases, id: \.self) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.bottom)

                    // Traits for selected category
                    ForEach(selectedCategory.traits, id: \.self) { traitName in
                        TraitSliderRow(
                            traitName: traitName,
                            value: traitBinding(for: traitName)
                        )
                    }

                    // AI reasoning (if available)
                    if let reasoning = character.traitsAiReasoning, !reasoning.isEmpty {
                        GroupBox("AI Analysis") {
                            Text(reasoning)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
            }
        }
    }

    private func traitBinding(for name: String) -> Binding<Double> {
        Binding(
            get: { character.traits[name] ?? 50.0 },
            set: { character.traits[name] = $0 }
        )
    }
}

// MARK: - Trait Category Enum

enum TraitCategory: String, CaseIterable {
    case openness
    case conscientiousness
    case extraversion
    case agreeableness
    case neuroticism

    var displayName: String {
        rawValue.capitalized
    }

    var traits: [String] {
        switch self {
        case .openness:
            return ["Creativity", "Curiosity", "Imagination", "Open-mindedness", "Artistic Interest"]
        case .conscientiousness:
            return ["Organization", "Diligence", "Reliability", "Self-discipline", "Ambition"]
        case .extraversion:
            return ["Sociability", "Energy", "Assertiveness", "Enthusiasm", "Talkativeness"]
        case .agreeableness:
            return ["Empathy", "Cooperation", "Trust", "Kindness", "Politeness"]
        case .neuroticism:
            return ["Anxiety", "Moodiness", "Sensitivity", "Irritability", "Self-consciousness"]
        }
    }

    var color: Color {
        switch self {
        case .openness: return .purple
        case .conscientiousness: return .blue
        case .extraversion: return .orange
        case .agreeableness: return .green
        case .neuroticism: return .red
        }
    }
}

// MARK: - Trait Slider Row

private struct TraitSliderRow: View {
    let traitName: String
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(traitName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(Int(value))")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .frame(width: 30)
            }

            HStack {
                Text("Low")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Slider(value: $value, in: 0...100, step: 1)

                Text("High")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Radar Chart

/// Radar chart visualization for personality traits
public struct TraitsRadarChart: View {
    let traits: [String: Double]

    // All 25 traits for the full radar
    private let allTraits = [
        "Creativity", "Curiosity", "Imagination", "Open-mindedness", "Artistic Interest",
        "Organization", "Diligence", "Reliability", "Self-discipline", "Ambition",
        "Sociability", "Energy", "Assertiveness", "Enthusiasm", "Talkativeness",
        "Empathy", "Cooperation", "Trust", "Kindness", "Politeness",
        "Anxiety", "Moodiness", "Sensitivity", "Irritability", "Self-consciousness"
    ]

    public init(traits: [String: Double]) {
        self.traits = traits
    }

    public var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = size / 2 - 40

            ZStack {
                // Background rings
                ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { scale in
                    RadarPolygon(
                        sides: allTraits.count,
                        radius: radius * scale,
                        center: center
                    )
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                }

                // Axis lines
                ForEach(0..<allTraits.count, id: \.self) { index in
                    let angle = angleFor(index: index, total: allTraits.count)
                    Path { path in
                        path.move(to: center)
                        path.addLine(to: pointAt(angle: angle, radius: radius, center: center))
                    }
                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                }

                // Data polygon
                RadarDataPolygon(
                    values: allTraits.map { traits[$0] ?? 50.0 },
                    maxValue: 100,
                    radius: radius,
                    center: center
                )
                .fill(Color.blue.opacity(0.3))
                .overlay(
                    RadarDataPolygon(
                        values: allTraits.map { traits[$0] ?? 50.0 },
                        maxValue: 100,
                        radius: radius,
                        center: center
                    )
                    .stroke(Color.blue, lineWidth: 2)
                )

                // Data points
                ForEach(0..<allTraits.count, id: \.self) { index in
                    let value = traits[allTraits[index]] ?? 50.0
                    let angle = angleFor(index: index, total: allTraits.count)
                    let pointRadius = radius * (value / 100)
                    let point = pointAt(angle: angle, radius: pointRadius, center: center)

                    Circle()
                        .fill(Color.blue)
                        .frame(width: 6, height: 6)
                        .position(point)
                }

                // Labels (only show abbreviated for clarity)
                ForEach(0..<5, id: \.self) { categoryIndex in
                    let index = categoryIndex * 5
                    let angle = angleFor(index: index, total: allTraits.count)
                    let labelRadius = radius + 25
                    let point = pointAt(angle: angle, radius: labelRadius, center: center)

                    Text(TraitCategory.allCases[categoryIndex].displayName.prefix(3).uppercased())
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(TraitCategory.allCases[categoryIndex].color)
                        .position(point)
                }
            }
        }
    }

    private func angleFor(index: Int, total: Int) -> Double {
        let angle = (Double(index) / Double(total)) * 2 * .pi - .pi / 2
        return angle
    }

    private func pointAt(angle: Double, radius: Double, center: CGPoint) -> CGPoint {
        CGPoint(
            x: center.x + radius * cos(angle),
            y: center.y + radius * sin(angle)
        )
    }
}

// MARK: - Radar Polygon Shape

private struct RadarPolygon: Shape {
    let sides: Int
    let radius: Double
    let center: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()

        for i in 0..<sides {
            let angle = (Double(i) / Double(sides)) * 2 * .pi - .pi / 2
            let point = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )

            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()

        return path
    }
}

// MARK: - Radar Data Polygon Shape

private struct RadarDataPolygon: Shape {
    let values: [Double]
    let maxValue: Double
    let radius: Double
    let center: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()

        for (index, value) in values.enumerated() {
            let angle = (Double(index) / Double(values.count)) * 2 * .pi - .pi / 2
            let pointRadius = radius * (value / maxValue)
            let point = CGPoint(
                x: center.x + pointRadius * cos(angle),
                y: center.y + pointRadius * sin(angle)
            )

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()

        return path
    }
}

#Preview {
    PersonalityTraitsTab(
        character: .constant(Character(
            name: "John",
            role: "Protagonist",
            traits: [
                "Creativity": 75,
                "Curiosity": 80,
                "Imagination": 65,
                "Organization": 45,
                "Sociability": 70,
                "Empathy": 85,
                "Anxiety": 30
            ],
            traitsConfidenceScore: 78,
            traitsAiReasoning: "Based on dialogue analysis, John shows high empathy and creativity with moderate social energy."
        ))
    )
    .frame(width: 900, height: 600)
}

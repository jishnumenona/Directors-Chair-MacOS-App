// DirectorsChairViews/Sources/DirectorsChairViews/StoryDesign/PersonalityTraitsTab.swift
//
// Personality traits editor with category ring gauges + pentagon overview

import SwiftUI
import DirectorsChairCore

/// Personality traits tab - shows 25 traits organized by 5 OCEAN categories
///
/// Left panel: Pentagon overview chart + category ring gauges
/// Right panel: Trait editor with colored bar sliders per category
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
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left: Overview visualization
                ScrollView {
                    VStack(spacing: 20) {
                        pentagonChartSection
                        categoryRingsSection
                        aiConfidenceSection
                        actionButtons
                    }
                    .padding(20)
                }
                .frame(width: min(420, geometry.size.width * 0.42))
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                // Right: Trait editor
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        categoryChips
                        traitEditorsSection
                        aiReasoningSection
                    }
                    .padding(24)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Category Averages

    private func categoryAverage(_ category: TraitCategory) -> Double {
        let values = category.traits.map { character.traits[$0] ?? 50.0 }
        return values.reduce(0, +) / Double(values.count)
    }

    // MARK: - Pentagon Chart

    private var pentagonChartSection: some View {
        TraitsCard(title: "PERSONALITY PROFILE", icon: "brain.head.profile") {
            ZStack {
                PentagonChart(
                    values: TraitCategory.allCases.map { categoryAverage($0) },
                    colors: TraitCategory.allCases.map { $0.color },
                    labels: TraitCategory.allCases.map { $0.displayName },
                    icons: TraitCategory.allCases.map { $0.icon }
                )
            }
            .frame(height: 280)
        }
    }

    // MARK: - Category Rings

    private var categoryRingsSection: some View {
        TraitsCard(title: "CATEGORY SCORES", icon: "chart.bar") {
            VStack(spacing: 10) {
                ForEach(TraitCategory.allCases, id: \.self) { category in
                    CategoryScoreBar(
                        category: category,
                        average: categoryAverage(category),
                        isSelected: selectedCategory == category,
                        onTap: { selectedCategory = category }
                    )
                }
            }
        }
    }

    // MARK: - AI Confidence

    @ViewBuilder
    private var aiConfidenceSection: some View {
        if let confidence = character.traitsConfidenceScore {
            TraitsCard(title: "AI CONFIDENCE", icon: "cpu") {
                HStack(spacing: 12) {
                    // Ring gauge
                    ZStack {
                        Circle()
                            .stroke(Color(nsColor: .quaternarySystemFill), lineWidth: 5)
                            .frame(width: 44, height: 44)
                        Circle()
                            .trim(from: 0, to: confidence / 100)
                            .stroke(
                                confidence >= 70 ? Color.green : (confidence >= 40 ? Color.orange : Color.red),
                                style: StrokeStyle(lineWidth: 5, lineCap: .round)
                            )
                            .frame(width: 44, height: 44)
                            .rotationEffect(.degrees(-90))
                        Text("\(Int(confidence))")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Analysis Score")
                            .font(.system(size: 12, weight: .medium))
                        Text(confidence >= 70 ? "High confidence" : confidence >= 40 ? "Moderate confidence" : "Low confidence")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if let date = character.traitsLastCalibrated {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 10))
                            .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    }
                }
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button {
                onAnalyzeFromScript?()
            } label: {
                Label("Analyze from Script", systemImage: "wand.and.stars")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                onResetToDefaults?()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Category Chips

    private var categoryChips: some View {
        HStack(spacing: 6) {
            ForEach(TraitCategory.allCases, id: \.self) { category in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = category
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: category.icon)
                            .font(.system(size: 11))
                        Text(category.displayName)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedCategory == category ? category.color : Color(nsColor: .quaternarySystemFill))
                    )
                    .foregroundColor(selectedCategory == category ? .white : .primary)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    // MARK: - Trait Editors

    private var traitEditorsSection: some View {
        TraitsCard(title: selectedCategory.displayName.uppercased(), icon: selectedCategory.icon) {
            VStack(spacing: 16) {
                ForEach(selectedCategory.traits, id: \.self) { traitName in
                    TraitBarEditor(
                        name: traitName,
                        value: traitBinding(for: traitName),
                        color: selectedCategory.color
                    )
                }
            }
        }
    }

    // MARK: - AI Reasoning

    @ViewBuilder
    private var aiReasoningSection: some View {
        if let reasoning = character.traitsAiReasoning, !reasoning.isEmpty {
            TraitsCard(title: "AI ANALYSIS", icon: "sparkles") {
                Text(reasoning)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
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

    var icon: String {
        switch self {
        case .openness: return "lightbulb"
        case .conscientiousness: return "checkmark.seal"
        case .extraversion: return "person.wave.2"
        case .agreeableness: return "heart"
        case .neuroticism: return "bolt.heart"
        }
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

// MARK: - Card Container

private struct TraitsCard<Content: View>: View {
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

// MARK: - Pentagon Chart

private struct PentagonChart: View {
    let values: [Double]      // 5 category averages (0-100)
    let colors: [Color]        // 5 category colors
    let labels: [String]       // 5 category names
    let icons: [String]        // 5 SF Symbol icons

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = size / 2 - 50

            ZStack {
                // Background grid rings
                ForEach([20.0, 40.0, 60.0, 80.0, 100.0], id: \.self) { level in
                    PentagonShape(radius: radius * (level / 100), center: center)
                        .stroke(Color(nsColor: .separatorColor).opacity(level == 100 ? 0.3 : 0.15), lineWidth: 1)
                }

                // Grid level labels (on one axis)
                ForEach([20, 40, 60, 80], id: \.self) { level in
                    let y = center.y - radius * (Double(level) / 100)
                    Text("\(level)")
                        .font(.system(size: 8))
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                        .position(x: center.x + 10, y: y)
                }

                // Axis lines
                ForEach(0..<5, id: \.self) { i in
                    let angle = angleFor(index: i)
                    Path { path in
                        path.move(to: center)
                        path.addLine(to: pointAt(angle: angle, radius: radius, center: center))
                    }
                    .stroke(Color(nsColor: .separatorColor).opacity(0.2), lineWidth: 1)
                }

                // Data fill — gradient mesh
                PentagonDataShape(values: values, maxValue: 100, radius: radius, center: center)
                    .fill(
                        LinearGradient(
                            colors: [colors[0].opacity(0.25), colors[2].opacity(0.2), colors[4].opacity(0.15)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // Data stroke
                PentagonDataShape(values: values, maxValue: 100, radius: radius, center: center)
                    .stroke(
                        LinearGradient(
                            colors: colors.map { $0.opacity(0.8) },
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 2.5
                    )

                // Data points + value badges
                ForEach(0..<5, id: \.self) { i in
                    let value = values[i]
                    let angle = angleFor(index: i)
                    let pointRadius = radius * (value / 100)
                    let point = pointAt(angle: angle, radius: pointRadius, center: center)

                    // Glowing dot
                    Circle()
                        .fill(colors[i])
                        .frame(width: 10, height: 10)
                        .shadow(color: colors[i].opacity(0.5), radius: 4)
                        .position(point)

                    // Value badge near the dot
                    let badgeRadius = radius * (value / 100) + 14
                    let badgePoint = pointAt(angle: angle, radius: badgeRadius, center: center)
                    Text("\(Int(value))")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(colors[i])
                        .position(badgePoint)
                }

                // Category labels with icons
                ForEach(0..<5, id: \.self) { i in
                    let angle = angleFor(index: i)
                    let labelRadius = radius + 36
                    let point = pointAt(angle: angle, radius: labelRadius, center: center)

                    VStack(spacing: 2) {
                        Image(systemName: icons[i])
                            .font(.system(size: 12))
                            .foregroundColor(colors[i])
                        Text(labels[i])
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(colors[i])
                    }
                    .position(point)
                }
            }
        }
    }

    private func angleFor(index: Int) -> Double {
        (Double(index) / 5.0) * 2 * .pi - .pi / 2
    }

    private func pointAt(angle: Double, radius: Double, center: CGPoint) -> CGPoint {
        CGPoint(
            x: center.x + radius * cos(angle),
            y: center.y + radius * sin(angle)
        )
    }
}

// MARK: - Pentagon Shapes

private struct PentagonShape: Shape {
    let radius: Double
    let center: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for i in 0..<5 {
            let angle = (Double(i) / 5.0) * 2 * .pi - .pi / 2
            let point = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
            if i == 0 { path.move(to: point) }
            else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

private struct PentagonDataShape: Shape {
    let values: [Double]
    let maxValue: Double
    let radius: Double
    let center: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for (i, value) in values.enumerated() {
            let angle = (Double(i) / Double(values.count)) * 2 * .pi - .pi / 2
            let r = radius * (value / maxValue)
            let point = CGPoint(
                x: center.x + r * cos(angle),
                y: center.y + r * sin(angle)
            )
            if i == 0 { path.move(to: point) }
            else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Category Score Bar

private struct CategoryScoreBar: View {
    let category: TraitCategory
    let average: Double
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Icon
                Image(systemName: category.icon)
                    .font(.system(size: 12))
                    .foregroundColor(category.color)
                    .frame(width: 20)

                // Name
                Text(category.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 110, alignment: .leading)

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(nsColor: .quaternarySystemFill))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [category.color.opacity(0.7), category.color],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * (average / 100), height: 8)
                    }
                }
                .frame(height: 8)

                // Value
                Text("\(Int(average))")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(category.color)
                    .frame(width: 32, alignment: .trailing)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? category.color.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? category.color.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Trait Bar Editor

private struct TraitBarEditor: View {
    let name: String
    @Binding var value: Double
    let color: Color

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 8) {
            // Header: name + value badge
            HStack {
                Text(name)
                    .font(.system(size: 12, weight: .medium))

                Spacer()

                // Value badge
                Text("\(Int(value))")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                    .frame(width: 36)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(color.opacity(0.12))
                    )
            }

            // Progress bar + slider
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(nsColor: .quaternarySystemFill))
                    .frame(height: 6)

                // Filled track
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.5), color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * (value / 100), height: 6)
                }
                .frame(height: 6)
            }

            // Slider (subtle, shown on hover or always)
            HStack(spacing: 6) {
                Text("Low")
                    .font(.system(size: 9))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))

                Slider(value: $value, in: 0...100, step: 1)
                    .controlSize(.mini)
                    .tint(color)

                Text("High")
                    .font(.system(size: 9))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color(nsColor: .quaternarySystemFill).opacity(0.5) : Color.clear)
        )
        .onHover { isHovered = $0 }
    }
}

// MARK: - Legacy Public Radar Chart (kept for backward compatibility)

public struct TraitsRadarChart: View {
    let traits: [String: Double]

    public init(traits: [String: Double]) {
        self.traits = traits
    }

    private var averages: [Double] {
        TraitCategory.allCases.map { cat -> Double in
            let vals = cat.traits.map { traits[$0] ?? 50.0 }
            return vals.reduce(0, +) / Double(vals.count)
        }
    }

    public var body: some View {
        PentagonChart(
            values: averages,
            colors: TraitCategory.allCases.map { $0.color },
            labels: TraitCategory.allCases.map { $0.displayName },
            icons: TraitCategory.allCases.map { $0.icon }
        )
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
                "Open-mindedness": 70,
                "Artistic Interest": 60,
                "Organization": 45,
                "Diligence": 55,
                "Reliability": 60,
                "Self-discipline": 40,
                "Ambition": 65,
                "Sociability": 70,
                "Energy": 75,
                "Assertiveness": 60,
                "Enthusiasm": 80,
                "Talkativeness": 65,
                "Empathy": 85,
                "Cooperation": 70,
                "Trust": 60,
                "Kindness": 80,
                "Politeness": 75,
                "Anxiety": 30,
                "Moodiness": 25,
                "Sensitivity": 45,
                "Irritability": 20,
                "Self-consciousness": 35
            ],
            traitsConfidenceScore: 78,
            traitsAiReasoning: "Based on dialogue analysis, John shows high empathy and creativity with moderate social energy. His low neuroticism scores suggest emotional stability under pressure."
        ))
    )
    .frame(width: 900, height: 600)
}

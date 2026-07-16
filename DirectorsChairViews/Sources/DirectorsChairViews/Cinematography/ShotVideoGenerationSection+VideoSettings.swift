//
// ShotVideoGenerationSection+VideoSettings.swift
//
// Extracted from ShotVideoGenerationSection.swift (WS9.1 god-file decomposition).
// Behaviour unchanged.
//

import SwiftUI
import AVKit
import AppKit
import UniformTypeIdentifiers
import DirectorsChairCore
import DirectorsChairServices


// MARK: - Flow Layout

struct VideoContextFlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: ProposedViewSize(width: bounds.width, height: bounds.height), subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0; var y: CGFloat = 0; var rowHeight: CGFloat = 0; var maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height); x += size.width + spacing; maxX = max(maxX, x)
        }
        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}

// MARK: - Video Settings Card

struct VideoSettingsCard: View {
    @Binding var selectedProvider: VideoProvider
    @Binding var duration: Double
    @Binding var quality: String
    @Binding var aspectRatio: String
    @Binding var resolution: String
    @Binding var cameraMotion: String
    @Binding var motionSpeed: String
    @Binding var subjectMotion: String
    @Binding var negativePrompt: String
    @Binding var lightingStyle: String
    @Binding var syncDuration: Bool
    /// End keyframe has an image → the provider bridges start→end and fixes
    /// the clip length itself; the duration slider would be a lie.
    let interpolatesEndFrame: Bool
    let shot: Shot
    /// Look bible: project styles + built-in presets, the shot's explicit
    /// override id, and the style that actually resolves (incl. inherited).
    let lookStyles: [FilmStyle]
    let activeStyleId: String?
    let resolvedStyle: FilmStyle?
    let onStyleSelected: (String?) -> Void
    /// Scene atmosphere (slug-line facts) — owned by the scene, edited here.
    let timeOfDay: String?
    let weather: String?
    let onTimeOfDayChanged: (String?) -> Void
    let onWeatherChanged: (String?) -> Void
    let onDurationChanged: (Double) -> Void

    @State private var showMoreSettings: Bool = false

    private let qualities = ["Standard", "High", "Ultra"]
    // One movement vocabulary across the app — same list as the shot editor.
    private var cameraMotions: [String] { CameraAngleOptions.movements }
    private let motionSpeeds = ["Slow", "Normal", "Fast", "Whip"]
    private let subjectMotions = ["Static", "Subtle", "Walking", "Running", "Dynamic"]
    private let timesOfDay = ["Day", "Night", "Golden Hour", "Blue Hour", "Dawn", "Dusk", "Overcast"]
    private let weathers = ["Clear", "Rain", "Fog", "Snow", "Storm", "Haze"]
    private let lightingMoods = ["Soft key", "Hard key", "Low-key", "High-key", "Backlit rim",
                                 "Silhouette", "Practical sources", "Candlelight", "Neon glow"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                Text("VIDEO SETTINGS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(.gray)
            }

            // Look (film style — the shot's look bible entry)
            VStack(alignment: .leading, spacing: 6) {
                Text("Look")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.gray)
                    .textCase(.uppercase)
                Menu {
                    Button("Project default") { onStyleSelected(nil) }
                    Divider()
                    ForEach(lookStyles) { style in
                        Button(action: { onStyleSelected(style.id) }) {
                            if style.id == activeStyleId {
                                Label(style.name, systemImage: "checkmark")
                            } else {
                                Text(style.name)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 10))
                            .foregroundColor(resolvedStyle != nil ? .accentColor : .gray)
                        Text(resolvedStyle?.name ?? "No look set")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(resolvedStyle != nil ? .white : .gray)
                        if activeStyleId == nil && resolvedStyle != nil {
                            Text("inherited")
                                .font(.system(size: 8))
                                .foregroundColor(.gray.opacity(0.6))
                        }
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color(hex: "#3A3A3A"))
                    .cornerRadius(6)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                if let style = resolvedStyle, !style.description.isEmpty {
                    Text(style.description)
                        .font(.system(size: 9))
                        .foregroundColor(.gray.opacity(0.7))
                        .lineLimit(1)
                }
            }

            // Provider
            VStack(alignment: .leading, spacing: 6) {
                Text("Provider")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.gray)
                    .textCase(.uppercase)
                HStack(spacing: 6) {
                    ForEach(VideoProvider.allCases, id: \.rawValue) { provider in
                        chipButton(icon: provider.icon, label: provider.displayName, isSelected: selectedProvider == provider) {
                            selectedProvider = provider
                            if duration > provider.maxDuration { duration = provider.maxDuration; onDurationChanged(duration) }
                            if duration < provider.minDuration { duration = provider.minDuration; onDurationChanged(duration) }
                            if !provider.supportedAspectRatios.contains(aspectRatio) {
                                aspectRatio = provider.supportedAspectRatios.first ?? "16:9"
                            }
                            if !provider.supportedResolutions.contains(resolution) {
                                resolution = provider.supportedResolutions.first ?? "720p"
                            }
                        }
                    }
                }
            }

            // Duration — hidden while interpolating (the provider sets the length)
            if interpolatesEndFrame {
                HStack(spacing: 8) {
                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.system(size: 11))
                        .foregroundColor(.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Start → end frame bridging")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Duration is set by \(selectedProvider.displayName) when an end frame is present (~\(Int(VideoProvider.interpolationDurationSeconds))s). Remove the End keyframe image to control duration manually.")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.accentColor.opacity(0.08))
                .cornerRadius(8)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Duration").font(.system(size: 9, weight: .medium)).foregroundColor(.gray).textCase(.uppercase)
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: syncDuration ? "link" : "link.badge.plus").font(.system(size: 9)).foregroundColor(syncDuration ? .accentColor : .gray)
                            Text("Sync timeline").font(.system(size: 9)).foregroundColor(.gray)
                            Toggle("", isOn: $syncDuration).toggleStyle(.switch).scaleEffect(0.6).frame(width: 30)
                        }
                    }
                    if let options = selectedProvider.discreteDurations {
                        // Veo renders fixed clip lengths — offer exactly those,
                        // instead of a slider whose value would be snapped anyway.
                        HStack(spacing: 6) {
                            ForEach(options, id: \.self) { option in
                                chipButton(icon: "timer", label: "\(Int(option))s",
                                           isSelected: duration == option) {
                                    duration = option
                                    onDurationChanged(option)
                                }
                            }
                        }
                    } else {
                        HStack(spacing: 12) {
                            Text(String(format: "%.1f", duration))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("sec").font(.system(size: 11)).foregroundColor(.gray)
                            Slider(value: $duration, in: selectedProvider.minDuration...selectedProvider.maxDuration, step: 0.5)
                                .onChange(of: duration) { _, newValue in onDurationChanged(newValue) }
                        }
                    }
                }
            }

            // Quality & Aspect & Resolution
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Quality").font(.system(size: 9, weight: .medium)).foregroundColor(.gray).textCase(.uppercase)
                    HStack(spacing: 6) {
                        ForEach(qualities, id: \.self) { q in
                            chipButton(icon: q == "Ultra" ? "star.fill" : q == "High" ? "sparkles" : "circle", label: q, isSelected: quality == q) { quality = q }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Aspect Ratio").font(.system(size: 9, weight: .medium)).foregroundColor(.gray).textCase(.uppercase)
                    HStack(spacing: 6) {
                        ForEach(selectedProvider.supportedAspectRatios, id: \.self) { ar in
                            chipButton(icon: ar == "16:9" ? "rectangle" : ar == "9:16" ? "rectangle.portrait" : "square", label: ar, isSelected: aspectRatio == ar) { aspectRatio = ar }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Resolution").font(.system(size: 9, weight: .medium)).foregroundColor(.gray).textCase(.uppercase)
                    HStack(spacing: 6) {
                        ForEach(selectedProvider.supportedResolutions, id: \.self) { res in
                            chipButton(icon: res == "1080p" ? "sparkles.tv" : "tv", label: res, isSelected: resolution == res) { resolution = res }
                        }
                    }
                }
            }

            // Camera Motion (same vocabulary as the shot editor) + speed
            VStack(alignment: .leading, spacing: 6) {
                Text("Camera Motion").font(.system(size: 9, weight: .medium)).foregroundColor(.gray).textCase(.uppercase)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 6)], spacing: 6) {
                    ForEach(cameraMotions, id: \.self) { motion in
                        chipButton(icon: motionIcon(motion), label: motion, isSelected: cameraMotion == motion) { cameraMotion = motion }
                    }
                }
                if cameraMotion != "Static" {
                    HStack(spacing: 6) {
                        Text("Speed").font(.system(size: 9, weight: .medium)).foregroundColor(.gray).textCase(.uppercase)
                        ForEach(motionSpeeds, id: \.self) { speed in
                            chipButton(icon: speed == "Slow" ? "tortoise" : speed == "Whip" ? "bolt" : speed == "Fast" ? "hare" : "metronome",
                                       label: speed, isSelected: motionSpeed == speed) { motionSpeed = speed }
                        }
                    }
                }
            }

            // Lighting (scene atmosphere + this shot's key mood)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.yellow.opacity(0.8))
                    Text("LIGHTING")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.0)
                        .foregroundColor(.gray)
                    Spacer()
                    Text("time & weather apply to the whole scene")
                        .font(.system(size: 8))
                        .foregroundColor(.gray.opacity(0.5))
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Time of Day").font(.system(size: 9, weight: .medium)).foregroundColor(.gray).textCase(.uppercase)
                    VideoContextFlowLayout(spacing: 6) {
                        ForEach(timesOfDay, id: \.self) { tod in
                            chipButton(icon: tod == "Night" ? "moon.fill" : tod == "Golden Hour" ? "sun.horizon.fill" : "sun.max",
                                       label: tod, isSelected: timeOfDay == tod) {
                                onTimeOfDayChanged(timeOfDay == tod ? nil : tod)
                            }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Weather / Atmosphere").font(.system(size: 9, weight: .medium)).foregroundColor(.gray).textCase(.uppercase)
                    VideoContextFlowLayout(spacing: 6) {
                        ForEach(weathers, id: \.self) { condition in
                            chipButton(icon: condition == "Rain" ? "cloud.rain" : condition == "Fog" || condition == "Haze" ? "cloud.fog" : condition == "Snow" ? "snowflake" : condition == "Storm" ? "cloud.bolt" : "sun.min",
                                       label: condition, isSelected: weather == condition) {
                                onWeatherChanged(weather == condition ? nil : condition)
                            }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Key Mood").font(.system(size: 9, weight: .medium)).foregroundColor(.gray).textCase(.uppercase)
                    VideoContextFlowLayout(spacing: 6) {
                        ForEach(lightingMoods, id: \.self) { mood in
                            chipButton(icon: "lightbulb", label: mood, isSelected: lightingStyle == mood) {
                                lightingStyle = (lightingStyle == mood) ? "" : mood
                            }
                        }
                    }
                }
            }

            // More settings (advanced, provider support varies)
            VStack(alignment: .leading, spacing: 8) {
                Button(action: { withAnimation(.easeInOut(duration: 0.15)) { showMoreSettings.toggle() } }) {
                    HStack(spacing: 6) {
                        Image(systemName: showMoreSettings ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                        Text("More settings")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.gray)
                }
                .buttonStyle(.plain)

                if showMoreSettings {
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Subject Motion").font(.system(size: 9, weight: .medium)).foregroundColor(.gray).textCase(.uppercase)
                            HStack(spacing: 6) {
                                ForEach(subjectMotions, id: \.self) { motion in
                                    chipButton(icon: motion == "Static" ? "figure.stand" : "figure.walk.motion", label: motion, isSelected: subjectMotion == motion) { subjectMotion = motion }
                                }
                            }
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Negative Prompt").font(.system(size: 9, weight: .medium)).foregroundColor(.gray).textCase(.uppercase)
                            TextField("What to avoid (e.g. text overlays, blur)…", text: $negativePrompt)
                                .textFieldStyle(.plain)
                                .font(.system(size: 11))
                                .padding(8)
                                .background(Color(hex: "#1A1A1A"))
                                .cornerRadius(6)
                        }
                        Text("Provider support varies — Veo currently ignores subject motion and negative prompts.")
                            .font(.system(size: 9))
                            .foregroundColor(.gray.opacity(0.7))
                    }
                    .padding(.leading, 2)
                }
            }
        }
        .padding(14)
        .background(Color(hex: "#252525"))
        .cornerRadius(10)
    }

    private func motionIcon(_ motion: String) -> String {
        switch motion {
        case "Static": return "viewfinder"
        case "Pan Left": return "arrow.left"
        case "Pan Right": return "arrow.right"
        case "Tilt Up": return "arrow.up"
        case "Tilt Down": return "arrow.down"
        case "Zoom In", "Push In": return "plus.magnifyingglass"
        case "Zoom Out", "Pull Out": return "minus.magnifyingglass"
        case "Dolly In": return "arrow.up.forward.circle"
        case "Dolly Out": return "arrow.down.backward.circle"
        case "Dolly Left", "Arc Left": return "arrow.turn.up.left"
        case "Dolly Right", "Arc Right": return "arrow.turn.up.right"
        case "Crane Up": return "arrow.up.to.line"
        case "Crane Down": return "arrow.down.to.line"
        case "Handheld": return "hand.raised"
        case "Steadicam": return "figure.walk.motion"
        case "Tracking": return "figure.walk"
        case "Whip Pan": return "bolt.horizontal"
        default: return "arrow.left.and.right"
        }
    }

    @ViewBuilder
    private func chipButton(icon: String, label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 9))
                Text(label).font(.system(size: 10, weight: .medium))
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color(hex: "#3A3A3A"))
            .foregroundColor(isSelected ? .white : .gray)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Cost Estimate Bar

struct CostEstimateBar: View {
    let provider: VideoProvider
    let duration: Double
    let quality: String

    private var estimatedCost: Double {
        duration * provider.costPerSecond
    }

    var body: some View {
        HStack {
            Image(systemName: "dollarsign.circle").font(.system(size: 11)).foregroundColor(.accentColor)
            Text(provider.displayName).font(.system(size: 10, weight: .medium)).foregroundColor(.gray)
            Text("·").foregroundColor(.gray.opacity(0.5))
            Text(String(format: "%.1fs", duration)).font(.system(size: 10)).foregroundColor(.gray)
            Text("·").foregroundColor(.gray.opacity(0.5))
            Text(quality).font(.system(size: 10)).foregroundColor(.gray)
            Spacer()
            Text("Estimated:").font(.system(size: 10)).foregroundColor(.gray)
            Text(String(format: "$%.2f", estimatedCost))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.accentColor)
        }
        .padding(10)
        .background(Color(hex: "#252525"))
        .cornerRadius(8)
    }
}

// MARK: - Generation Progress View

struct GenerationProgressView: View {
    let progress: Double
    let status: String
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "waveform").font(.system(size: 10)).foregroundColor(.accentColor)
                Text("GENERATING").font(.system(size: 9, weight: .bold)).tracking(1.2).foregroundColor(.gray)
                Spacer()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color(hex: "#2A2A2A")).frame(height: 8)
                    RoundedRectangle(cornerRadius: 4).fill(Color.accentColor)
                        .frame(width: geo.size.width * (progress / 100), height: 8)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 8)
            HStack {
                Text(String(format: "%.0f%%", progress)).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(.white)
                Text(status).font(.system(size: 11)).foregroundColor(.gray)
                Spacer()
                Button(action: onCancel) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark").font(.system(size: 9))
                        Text("Cancel").font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.red).padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.red.opacity(0.15)).cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12).background(Color(hex: "#252525")).cornerRadius(8)
    }
}

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
    @Binding var cameraMotion: String
    @Binding var syncDuration: Bool
    let shot: Shot
    let onDurationChanged: (Double) -> Void

    private let qualities = ["Standard", "High", "Ultra"]
    private let aspectRatios = ["16:9", "9:16", "1:1"]
    private let cameraMotions = ["Static", "Pan Left", "Pan Right", "Zoom In", "Zoom Out", "Dolly", "Crane", "Tracking"]

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
                        }
                    }
                }
            }

            // Duration
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
                HStack(spacing: 12) {
                    Text(String(format: "%.1f", duration))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("sec").font(.system(size: 11)).foregroundColor(.gray)
                    Slider(value: $duration, in: selectedProvider.minDuration...selectedProvider.maxDuration, step: 0.5)
                        .onChange(of: duration) { _, newValue in onDurationChanged(newValue) }
                }
            }

            // Quality & Aspect
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
                        ForEach(aspectRatios, id: \.self) { ar in
                            chipButton(icon: ar == "16:9" ? "rectangle" : ar == "9:16" ? "rectangle.portrait" : "square", label: ar, isSelected: aspectRatio == ar) { aspectRatio = ar }
                        }
                    }
                }
            }

            // Camera Motion
            VStack(alignment: .leading, spacing: 6) {
                Text("Camera Motion").font(.system(size: 9, weight: .medium)).foregroundColor(.gray).textCase(.uppercase)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 6)], spacing: 6) {
                    ForEach(cameraMotions, id: \.self) { motion in
                        chipButton(icon: motionIcon(motion), label: motion, isSelected: cameraMotion == motion) { cameraMotion = motion }
                    }
                }
            }
        }
        .padding(14)
        .background(Color(hex: "#252525"))
        .cornerRadius(10)
    }

    private func motionIcon(_ motion: String) -> String {
        switch motion {
        case "Static": return "viewfinder"; case "Pan Left": return "arrow.left"; case "Pan Right": return "arrow.right"
        case "Zoom In": return "plus.magnifyingglass"; case "Zoom Out": return "minus.magnifyingglass"
        case "Dolly": return "arrow.up.and.down"; case "Crane": return "arrow.up.forward"; case "Tracking": return "figure.walk"
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

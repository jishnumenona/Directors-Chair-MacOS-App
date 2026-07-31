// AIUsageView.swift
//
// Accounting › AI Usage: tallies real AI API spend per capability (image,
// video, speech, text, assistant chat) for this project and this session,
// plus an estimate calculator — including "videos for every shot via Veo"
// computed from the project's actual shot durations. The package depends
// only on Core, so the tracker's numbers arrive as injected AIUsagePanelData
// built at the app layer.

import SwiftUI

// MARK: - Injected data

public struct AIUsagePanelData {
    public struct CapabilityLine: Identifiable {
        public let id: String            // capability name
        public let icon: String          // SF Symbol
        public let calls: Int
        public let unitsLabel: String    // "564 images", "12.4k tokens"
        public let costUSD: Double

        public init(id: String, icon: String, calls: Int,
                    unitsLabel: String, costUSD: Double) {
            self.id = id
            self.icon = icon
            self.calls = calls
            self.unitsLabel = unitsLabel
            self.costUSD = costUSD
        }
    }

    public var projectLines: [CapabilityLine]
    public var sessionLines: [CapabilityLine]
    public var projectTotalUSD: Double
    public var sessionTotalUSD: Double
    /// Rate card (gateway cost model): $/image, $/video-second,
    /// $/1k speech chars, $/1M input tokens, $/1M output tokens.
    public var imageRate: Double
    public var videoRatePerSecond: Double
    public var speechRatePer1kChars: Double
    public var textInRatePerMTokens: Double
    public var textOutRatePerMTokens: Double
    /// This project's shots, for the Veo estimate.
    public var shotCount: Int
    public var shotSecondsSpecified: Double
    public var shotsWithoutDuration: Int

    public init(projectLines: [CapabilityLine], sessionLines: [CapabilityLine],
                projectTotalUSD: Double, sessionTotalUSD: Double,
                imageRate: Double, videoRatePerSecond: Double,
                speechRatePer1kChars: Double, textInRatePerMTokens: Double,
                textOutRatePerMTokens: Double, shotCount: Int,
                shotSecondsSpecified: Double, shotsWithoutDuration: Int) {
        self.projectLines = projectLines
        self.sessionLines = sessionLines
        self.projectTotalUSD = projectTotalUSD
        self.sessionTotalUSD = sessionTotalUSD
        self.imageRate = imageRate
        self.videoRatePerSecond = videoRatePerSecond
        self.speechRatePer1kChars = speechRatePer1kChars
        self.textInRatePerMTokens = textInRatePerMTokens
        self.textOutRatePerMTokens = textOutRatePerMTokens
        self.shotCount = shotCount
        self.shotSecondsSpecified = shotSecondsSpecified
        self.shotsWithoutDuration = shotsWithoutDuration
    }
}

// MARK: - Estimator (pure, tested)

public enum AIEstimator {
    /// Videos for every shot: shots with a set duration bill their real
    /// length; shots without one assume the fallback clip length. Veo
    /// generates 4/6/8s clips, so seconds are billed as generated, and
    /// shots longer than 8s need multiple clips (already captured by
    /// billing their full duration).
    public static func allShotsVideoCost(shotSecondsSpecified: Double,
                                         shotsWithoutDuration: Int,
                                         fallbackClipSeconds: Double,
                                         ratePerSecond: Double) -> Double {
        (shotSecondsSpecified + Double(shotsWithoutDuration) * fallbackClipSeconds)
            * ratePerSecond
    }

    public static func imagesCost(count: Int, rate: Double) -> Double {
        Double(count) * rate
    }

    public static func videoCost(seconds: Double, ratePerSecond: Double) -> Double {
        seconds * ratePerSecond
    }

    public static func speechCost(characters: Int, ratePer1k: Double) -> Double {
        Double(characters) / 1000.0 * ratePer1k
    }

    public static func chatCost(turns: Int, promptTokensPerTurn: Int,
                                outputTokensPerTurn: Int,
                                inRatePerM: Double, outRatePerM: Double) -> Double {
        let inputCost = Double(turns * promptTokensPerTurn) / 1_000_000 * inRatePerM
        let outputCost = Double(turns * outputTokensPerTurn) / 1_000_000 * outRatePerM
        return inputCost + outputCost
    }
}

// MARK: - View

struct AIUsageView: View {
    let data: AIUsagePanelData

    @State private var scope = "Project"
    // Calculator inputs
    @State private var calcImages = 25
    @State private var calcVideoSeconds = 60.0
    @State private var calcSpeechChars = 5_000
    @State private var calcChatTurns = 50
    @State private var fallbackClipSeconds = 8.0

    private var lines: [AIUsagePanelData.CapabilityLine] {
        scope == "Project" ? data.projectLines : data.sessionLines
    }

    private var scopeTotal: Double {
        scope == "Project" ? data.projectTotalUSD : data.sessionTotalUSD
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                tallySection
                Divider()
                allShotsVideoSection
                Divider()
                calculatorSection
            }
            .padding(20)
        }
    }

    // MARK: Tally

    private var tallySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("AI API usage", systemImage: "brain")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Picker("", selection: $scope) {
                    Text("This Project").tag("Project")
                    Text("This Session").tag("Session")
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
            }
            if lines.allSatisfy({ $0.calls == 0 }) {
                Text("No AI usage recorded \(scope == "Project" ? "for this project" : "this session") yet.")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                    .padding(.vertical, 8)
            } else {
                ForEach(lines) { line in
                    HStack(spacing: 10) {
                        Image(systemName: line.icon)
                            .frame(width: 18)
                            .foregroundColor(.accentColor)
                        Text(line.id)
                            .frame(width: 110, alignment: .leading)
                        Text("\(line.calls) call\(line.calls == 1 ? "" : "s")")
                            .foregroundColor(.secondary)
                            .frame(width: 80, alignment: .leading)
                        Text(line.unitsLabel)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(Self.money(line.costUSD))
                            .fontWeight(.medium)
                            .monospacedDigit()
                    }
                    .font(.system(size: 12))
                }
                HStack {
                    Spacer()
                    Text("Total \(Self.money(scopeTotal))")
                        .font(.system(size: 13, weight: .semibold))
                        .monospacedDigit()
                }
                .padding(.top, 2)
            }
        }
    }

    // MARK: All-shots Veo estimate

    private var allShotsVideoCost: Double {
        AIEstimator.allShotsVideoCost(
            shotSecondsSpecified: data.shotSecondsSpecified,
            shotsWithoutDuration: data.shotsWithoutDuration,
            fallbackClipSeconds: fallbackClipSeconds,
            ratePerSecond: data.videoRatePerSecond)
    }

    private var allShotsVideoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Generate video for every shot (Veo)", systemImage: "video.badge.waveform")
                .font(.system(size: 13, weight: .semibold))
            if data.shotCount == 0 {
                Text("This project has no shots yet.")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
            } else {
                Text("\(data.shotCount) shots · \(Int(data.shotSecondsSpecified))s specified"
                     + (data.shotsWithoutDuration > 0
                        ? " · \(data.shotsWithoutDuration) without a duration (assume "
                          + "\(Int(fallbackClipSeconds))s clips)"
                        : ""))
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                if data.shotsWithoutDuration > 0 {
                    HStack {
                        Text("Clip length for unspecified shots")
                            .font(.system(size: 12))
                        Picker("", selection: $fallbackClipSeconds) {
                            Text("4s").tag(4.0)
                            Text("6s").tag(6.0)
                            Text("8s").tag(8.0)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 150)
                    }
                }
                HStack {
                    Text("At \(Self.money(data.videoRatePerSecond))/second:")
                        .font(.system(size: 12))
                    Text(Self.money(allShotsVideoCost))
                        .font(.system(size: 16, weight: .bold))
                        .monospacedDigit()
                        .foregroundColor(.accentColor)
                }
            }
        }
        .accessibilityIdentifier("ai-usage-all-shots-estimate")
    }

    // MARK: Calculator

    private var calculatorSection: some View {
        let imagesCost = AIEstimator.imagesCost(count: calcImages, rate: data.imageRate)
        let videoCost = AIEstimator.videoCost(seconds: calcVideoSeconds,
                                              ratePerSecond: data.videoRatePerSecond)
        let speechCost = AIEstimator.speechCost(characters: calcSpeechChars,
                                                ratePer1k: data.speechRatePer1kChars)
        let chatCost = AIEstimator.chatCost(
            turns: calcChatTurns, promptTokensPerTurn: 6_000, outputTokensPerTurn: 400,
            inRatePerM: data.textInRatePerMTokens, outRatePerM: data.textOutRatePerMTokens)
        let videoLabel = "\(Int(calcVideoSeconds))s"

        return VStack(alignment: .leading, spacing: 10) {
            Label("Estimate calculator", systemImage: "plus.forwardslash.minus")
                .font(.system(size: 13, weight: .semibold))
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                calcRow(label: "Images", value: $calcImages, range: 0...2000, step: 5,
                        unit: "images", cost: imagesCost)
                GridRow {
                    Text("Video").font(.system(size: 12))
                    HStack(spacing: 6) {
                        Slider(value: $calcVideoSeconds, in: 0...1800, step: 10)
                            .frame(width: 180)
                        Text(videoLabel).font(.system(size: 12)).monospacedDigit()
                    }
                    Text(Self.money(videoCost))
                        .font(.system(size: 12, weight: .medium)).monospacedDigit()
                }
                calcRow(label: "Speech (TTS)", value: $calcSpeechChars, range: 0...500_000,
                        step: 1000, unit: "chars", cost: speechCost)
                calcRow(label: "Assistant", value: $calcChatTurns, range: 0...2000, step: 10,
                        unit: "turns", cost: chatCost)
            }
            rateFootnote
        }
    }

    private var rateFootnote: some View {
        let inRate = String(format: "%.2f", data.textInRatePerMTokens)
        let outRate = String(format: "%.2f", data.textOutRatePerMTokens)
        let text = "Rates: " + Self.money(data.imageRate) + "/image · "
            + Self.money(data.videoRatePerSecond) + "/video-second · "
            + Self.money(data.speechRatePer1kChars) + "/1k TTS chars · "
            + "assistant turns assume ~6k in / 400 out tokens at $"
            + inRate + "/$" + outRate + " per 1M tokens."
        return Text(text)
            .font(.system(size: 10))
            .foregroundColor(.secondary)
    }

    private func calcRow(label: String, value: Binding<Int>,
                         range: ClosedRange<Int>, step: Int, unit: String,
                         cost: Double) -> some View {
        GridRow {
            Text(label).font(.system(size: 12))
            HStack(spacing: 6) {
                Stepper("", value: value, in: range, step: step)
                    .labelsHidden()
                Text("\(value.wrappedValue) \(unit)")
                    .font(.system(size: 12)).monospacedDigit()
            }
            Text(Self.money(cost))
                .font(.system(size: 12, weight: .medium)).monospacedDigit()
        }
    }

    static func money(_ value: Double) -> String {
        value < 0.01 && value > 0
            ? String(format: "$%.4f", value)
            : String(format: "$%.2f", value)
    }
}

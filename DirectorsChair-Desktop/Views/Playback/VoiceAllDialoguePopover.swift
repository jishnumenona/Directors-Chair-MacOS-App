//
//  VoiceAllDialoguePopover.swift
//  DirectorsChair-Desktop
//
//  The Playback transport's "Voice all dialogue" control (DC-0081): what
//  will be voiced and what it costs before anything runs, progress and a
//  cancel while it runs, the tally when it is done.
//

import SwiftUI
import DirectorsChairServices

/// What the transport bar needs from Playback to offer the batch.
struct VoiceAllDialogueControl {
    let batch: DialogueVoicingBatch
    let provider: AIProvider
    let plan: (_ onlyUnvoiced: Bool) -> DialogueVoicingPlan
    let start: (_ plan: DialogueVoicingPlan) -> Void
    /// Called when the user dismisses a finished run (the playlist rebuilds).
    let finished: () -> Void

    var providerLabel: String {
        switch provider {
        case .google, .googleGemini: return "Google"
        case .elevenlabs: return "ElevenLabs"
        case .openai: return "OpenAI"
        case .onDevice: return "this Mac"
        default: return provider.rawValue.capitalized
        }
    }

    var isMetered: Bool { provider != .onDevice }
}

struct VoiceAllDialoguePopover: View {
    let control: VoiceAllDialogueControl
    @ObservedObject var batch: DialogueVoicingBatch
    @State private var onlyUnvoiced = true

    init(control: VoiceAllDialogueControl) {
        self.control = control
        self.batch = control.batch
    }

    private var plan: DialogueVoicingPlan { control.plan(onlyUnvoiced) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Voice all dialogue")
                .font(.headline)
                .accessibilityIdentifier("voice-all-title")
            Text("Every line in the timeline, in order, in each character's cast voice.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            switch batch.state {
            case .idle:
                idleBody
            case .running(let done, let total, let character):
                runningBody(done: done, total: total, character: character)
            case .finished(let summary):
                finishedBody(summary)
            }
        }
        .padding(14)
        .frame(width: 300)
    }

    private var idleBody: some View {
        let plan = self.plan
        return VStack(alignment: .leading, spacing: 8) {
            Toggle("Only lines without a voice", isOn: $onlyUnvoiced)
                .toggleStyle(.checkbox)
                .font(.caption)
                .accessibilityIdentifier("voice-all-only-unvoiced")
            if plan.lines.isEmpty {
                Text(onlyUnvoiced && plan.alreadyVoiced > 0
                     ? "Every line already has a voice."
                     : "There is no dialogue in the timeline yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(summaryLine(for: plan))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("voice-all-summary")
                if onlyUnvoiced && plan.alreadyVoiced > 0 {
                    Text("\(plan.alreadyVoiced) line\(plan.alreadyVoiced == 1 ? "" : "s") already voiced — kept as is.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            HStack {
                Spacer()
                Button("Voice \(plan.lines.count) line\(plan.lines.count == 1 ? "" : "s")") {
                    control.start(plan)
                }
                .accessibilityIdentifier("voice-all-start")
                .keyboardShortcut(.defaultAction)
                .disabled(plan.lines.isEmpty)
            }
        }
    }

    private func summaryLine(for plan: DialogueVoicingPlan) -> String {
        let lines = "\(plan.lines.count) line\(plan.lines.count == 1 ? "" : "s")"
        let people = "\(plan.characterCount) character\(plan.characterCount == 1 ? "" : "s")"
        if control.isMetered {
            return "\(lines) · \(people) · about $\(String(format: "%.2f", max(plan.estimatedCost, 0.01))) with \(control.providerLabel)"
        }
        return "\(lines) · \(people) · on \(control.providerLabel)"
    }

    private func runningBody(done: Int, total: Int, character: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: Double(done), total: Double(max(total, 1)))
            Text("Voicing \(done + 1) of \(total) — \(character)")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancel") { batch.cancel() }
                    .accessibilityIdentifier("voice-all-cancel")
                    .keyboardShortcut(.cancelAction)
            }
        }
    }

    private func finishedBody(_ summary: DialogueVoicingBatch.Summary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tally(summary))
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            if let error = summary.firstError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                Button("Done") {
                    batch.reset()
                    control.finished()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func tally(_ summary: DialogueVoicingBatch.Summary) -> String {
        var parts = ["Voiced \(summary.generated)"]
        if summary.failed > 0 { parts.append("failed \(summary.failed)") }
        if summary.skipped > 0 { parts.append("not attempted \(summary.skipped)") }
        let text = parts.joined(separator: " · ")
        return summary.cancelled ? "Cancelled — " + text.prefix(1).lowercased() + text.dropFirst() : text
    }
}

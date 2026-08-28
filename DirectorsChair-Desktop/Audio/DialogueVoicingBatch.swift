//
//  DialogueVoicingBatch.swift
//  DirectorsChair-Desktop
//
//  "Voice all dialogue" from Playback (DC-0081, owner request): a plan of
//  every line in the timeline that still needs a voice, and a cancellable
//  runner that voices them one after another through DialogueVoicer,
//  saving each take as it lands so a cancel or a crash keeps what was done.
//

import Foundation
import DirectorsChairCore
import DirectorsChairServices

/// One line the batch will voice, resolved from the live project by uuid
/// when its turn comes (an edit meanwhile must not misfile a take).
struct DialogueVoicingLine: Identifiable, Equatable {
    let uuid: String
    let character: String
    /// Plain spoken text.
    let text: String
    let hasAudio: Bool
    var id: String { uuid }
}

struct DialogueVoicingPlan: Equatable {
    var lines: [DialogueVoicingLine]
    /// Lines left out because they already have a take.
    var alreadyVoiced: Int

    var estimatedCost: Double {
        lines.reduce(0) { $0 + DialogueVoicer.estimate(characters: $1.text.count) }
    }

    var characterCount: Int { Set(lines.map(\.character)).count }

    /// Every dialogue line in timeline order — sequences, then scenes, then
    /// the scene's chronology — skipping lines with nothing to say and, when
    /// `onlyUnvoiced`, lines that already have a take.
    static func timeline(in project: Project, onlyUnvoiced: Bool) -> DialogueVoicingPlan {
        var lines: [DialogueVoicingLine] = []
        var alreadyVoiced = 0
        for sequence in project.sequences {
            for scene in sequence.scenes {
                let ordered = scene.dialogues.enumerated()
                    .sorted { ($0.element.chronologyNumber, $0.offset) < ($1.element.chronologyNumber, $1.offset) }
                    .map(\.element)
                for dialogue in ordered {
                    let text = DialogueVoicer.plainText(dialogue.text)
                    guard !text.isEmpty else { continue }
                    let hasAudio = !(dialogue.audioFilePath ?? "").isEmpty
                    if onlyUnvoiced && hasAudio { alreadyVoiced += 1; continue }
                    lines.append(DialogueVoicingLine(uuid: dialogue.uuid, character: dialogue.character,
                                                     text: text, hasAudio: hasAudio))
                }
            }
        }
        return DialogueVoicingPlan(lines: lines, alreadyVoiced: alreadyVoiced)
    }
}

@MainActor
final class DialogueVoicingBatch: ObservableObject {

    struct Summary: Equatable {
        var generated = 0
        var failed = 0
        /// Lines never attempted (cancelled, or the run stopped).
        var skipped = 0
        var cancelled = false
        var firstError: String?
    }

    enum State: Equatable {
        case idle
        case running(done: Int, total: Int, character: String)
        case finished(Summary)
    }

    @Published private(set) var state: State = .idle

    /// A provider that fails this many lines in a row is not going to
    /// succeed on the next one (auth, quota, network) — stop burning time.
    static let consecutiveFailureLimit = 3

    private var cancelRequested = false

    var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    /// Stops after the line in flight; what landed stays.
    func cancel() { cancelRequested = true }

    func reset() { state = .idle }

    @discardableResult
    func run(plan: DialogueVoicingPlan, projectViewModel pvm: ProjectViewModel,
             provider: AIProvider, generate: @escaping DialogueVoicer.Generate) async -> Summary {
        var summary = Summary()
        guard let projectFile = pvm.projectPath else {
            summary.firstError = "The project has not been saved yet."
            summary.skipped = plan.lines.count
            state = .finished(summary)
            return summary
        }
        let directory: URL
        do {
            directory = try DialogueVoicer.directory(besides: projectFile)
        } catch {
            summary.firstError = error.localizedDescription
            summary.skipped = plan.lines.count
            state = .finished(summary)
            return summary
        }
        cancelRequested = false
        var consecutiveFailures = 0
        for (index, line) in plan.lines.enumerated() {
            if cancelRequested || Task.isCancelled {
                summary.cancelled = true
                summary.skipped += plan.lines.count - index
                break
            }
            state = .running(done: index, total: plan.lines.count, character: line.character)
            guard let at = Self.locate(uuid: line.uuid, in: pvm.project) else {
                summary.skipped += 1
                continue
            }
            let dialogue = pvm.project.sequences[at.sequence].scenes[at.scene].dialogues[at.dialogue]
            let request = DialogueVoicer.request(
                text: DialogueVoicer.plainText(dialogue.text), characterName: dialogue.character,
                tags: dialogue.tags,
                character: DialogueVoicer.character(named: dialogue.character, in: pvm.project),
                provider: provider)
            do {
                let audio = try await generate(request)
                try audio.write(to: directory.appendingPathComponent("\(line.uuid).wav"))
                // Re-locate: the line may have moved while the take rendered.
                if let now = Self.locate(uuid: line.uuid, in: pvm.project) {
                    pvm.project.sequences[now.sequence].scenes[now.scene].dialogues[now.dialogue].audioFilePath =
                        DialogueVoicer.relativePath(for: line.uuid)
                }
                summary.generated += 1
                consecutiveFailures = 0
            } catch {
                summary.failed += 1
                consecutiveFailures += 1
                if summary.firstError == nil { summary.firstError = error.localizedDescription }
                if consecutiveFailures >= Self.consecutiveFailureLimit {
                    summary.skipped += plan.lines.count - index - 1
                    break
                }
            }
        }
        state = .finished(summary)
        return summary
    }

    static func locate(uuid: String, in project: Project) -> (sequence: Int, scene: Int, dialogue: Int)? {
        for (s, sequence) in project.sequences.enumerated() {
            for (c, scene) in sequence.scenes.enumerated() {
                if let d = scene.dialogues.firstIndex(where: { $0.uuid == uuid }) { return (s, c, d) }
            }
        }
        return nil
    }
}

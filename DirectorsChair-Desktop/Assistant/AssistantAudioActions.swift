//
//  AssistantAudioActions.swift
//  DirectorsChair-Desktop
//
//  AI Assistant program, Phase A5.3: TTS from chat (F-E4) — "read this
//  scene aloud". Mirrors the Timeline TTS seam exactly: character voice
//  casting (custom voice or gender default), voiceStyle+tags as the
//  emotion direction, HTML-stripped text, audio at
//  assets/audio/dialogues/<uuid>.wav with Dialogue.audioFilePath set so
//  the timeline's play buttons light up. Spending-risk: per-line cost
//  previews computed from the gateway's real formula ($0.30/1k chars),
//  nothing renders without approval (AD5). Provider call injected for
//  offline tests.
//

import Foundation
import DirectorsChairCore
import DirectorsChairServices

private let stringProp = JSONValue.object(["type": .string("string")])
private let integerProp = JSONValue.object(["type": .string("integer")])
private let boolProp = JSONValue.object(["type": .string("boolean")])

private func objectSchema(_ properties: [String: JSONValue],
                          required: [String]) -> JSONValue {
    .object(["type": .string("object"),
             "properties": .object(properties),
             "required": .array(required.map(JSONValue.string))])
}

// MARK: - generate_dialogue_audio

final class GenerateDialogueAudioAction: ProjectAssistantAction, AssistantAction {
    /// Gateway parity (services/cost.py): $0.30 per 1k characters — the
    /// one estimate every voicing surface shows (DialogueVoicer).
    static func estimate(characters: Int) -> Double {
        DialogueVoicer.estimate(characters: characters)
    }

    typealias Generate = DialogueVoicer.Generate

    let name = "generate_dialogue_audio"
    let summary = """
    Voice a scene's dialogue with each character's cast voice (text-to-\
    speech). By default renders every line that has no audio yet; pass \
    "index" for one [n] line, or regenerate=true to redo existing audio. \
    SPENDS ~$0.30 per 1k characters; runs only after the user approves.
    """
    let risk = ActionRisk.spending
    let minimumTier = ProductTier.creator  // §3.7: generation actions are Creator+
    var parameterSchema: JSONValue {
        objectSchema([
            "scene": stringProp, "index": integerProp, "regenerate": boolProp,
        ], required: ["scene"])
    }

    private let makeGenerate: @MainActor () -> Generate

    init(projectViewModel: ProjectViewModel?, coordinator: AppCoordinator?,
         makeGenerate: @escaping @MainActor () -> Generate) {
        self.makeGenerate = makeGenerate
        super.init(projectViewModel: projectViewModel, coordinator: coordinator)
    }

    private struct Arguments: Decodable {
        let scene: String
        let index: Int?
        let regenerate: Bool?
    }

    @MainActor private func selectedIndices(_ args: Arguments,
                                            in pvm: ProjectViewModel) throws
    -> (seq: Int, sc: Int, lines: [Int]) {
        let (seq, sc) = try sceneIndices(named: args.scene, in: pvm)
        let dialogues = pvm.project.sequences[seq].scenes[sc].dialogues
        if let index = args.index {
            guard dialogues.indices.contains(index) else {
                throw ActionError("dialogue index \(index) out of range "
                                  + "(scene has \(dialogues.count) dialogues)")
            }
            return (seq, sc, [index])
        }
        let lines = dialogues.indices.filter {
            args.regenerate == true || dialogues[$0].audioFilePath == nil
        }
        guard !lines.isEmpty else {
            throw ActionError(dialogues.isEmpty
                ? "“\(args.scene)” has no dialogue lines"
                : "every line in “\(args.scene)” already has audio — pass regenerate=true to redo them")
        }
        return (seq, sc, lines)
    }

    private static func plainText(_ text: String) -> String {
        DialogueVoicer.plainText(text)
    }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let pvm = try requireProject()
        let (seq, sc, lines) = try selectedIndices(args, in: pvm)
        let dialogues = pvm.project.sequences[seq].scenes[sc].dialogues
        let total = lines.reduce(0.0) { sum, i in
            sum + Self.estimate(characters: Self.plainText(dialogues[i].text).count)
        }
        return ActionPlan(
            summary: "Voice \(lines.count) line\(lines.count == 1 ? "" : "s") "
                + "in “\(args.scene)” (~$\(String(format: "%.2f", max(total, 0.01))))",
            previews: lines.map { i in
                let line = dialogues[i]
                return ActionPreview(
                    title: "\(line.character) · [\(i)]",
                    oldValue: line.audioFilePath == nil ? "no audio" : "existing audio",
                    newValue: "\(String(Self.plainText(line.text).prefix(60)))…"
                        + " (~$\(String(format: "%.3f", Self.estimate(characters: Self.plainText(line.text).count))))")
            },
            estimatedCost: total)
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let pvm = try requireProject()
        guard let projectFile = pvm.projectPath else {
            throw ActionError("the project has not been saved yet")
        }
        let (seq, sc, lines) = try selectedIndices(args, in: pvm)
        let directory = try DialogueVoicer.directory(besides: projectFile)
        let generate = makeGenerate()

        var voiced = 0
        for i in lines {
            let line = pvm.project.sequences[seq].scenes[sc].dialogues[i]
            // Voice casting through the one voicer (DC-0081) — identical to
            // the Timeline seam and the Playback batch.
            let request = DialogueVoicer.request(
                text: Self.plainText(line.text), characterName: line.character, tags: line.tags,
                character: DialogueVoicer.character(named: line.character, in: pvm.project),
                provider: AIProviderSelection.shared.provider(for: .speech))
            let audioData = try await generate(request)

            try audioData.write(to: directory.appendingPathComponent("\(line.uuid).wav"))
            pvm.project.sequences[seq].scenes[sc].dialogues[i].audioFilePath =
                DialogueVoicer.relativePath(for: line.uuid)
            voiced += 1
        }
        didMutate(.script)
        return ActionOutcome(
            resultForModel: #"{"status": "applied", "voiced": \#(voiced)}"#,
            userSummary: "Voiced \(voiced) line\(voiced == 1 ? "" : "s") in “\(args.scene)”")
    }
}

// MARK: - Factory extension

extension AssistantActionFactory {
    @MainActor static func audioActions(projectViewModel: ProjectViewModel?,
                                        coordinator: AppCoordinator?) -> [any AssistantAction] {
        [
            GenerateDialogueAudioAction(
                projectViewModel: projectViewModel, coordinator: coordinator,
                makeGenerate: {
                    { request in
                        try await AIServiceClient.shared.generateSpeech(request).audioData
                    }
                }),
        ]
    }
}

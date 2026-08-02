//
//  AssistantVideoActions.swift
//  DirectorsChair-Desktop
//
//  AI Assistant program, Phase A5.4: video generation from chat (F-E3).
//  The action submits through the SAME app-scoped VideoJobCoordinator the
//  Cinematography view uses (submit → poll → download → persist as a new
//  take, surviving navigation), so a chat-started job is indistinguishable
//  from a UI-started one. Spending-risk with duration-based cost previews
//  (Veo $0.40/second — the wallet modality); the chat view model follows
//  the job and posts progress into the conversation. Submission is
//  injected for offline tests.
//

import Foundation
import DirectorsChairCore
import DirectorsChairServices
import DirectorsChairViews

private let stringProp = JSONValue.object(["type": .string("string")])
private let integerProp = JSONValue.object(["type": .string("integer")])
private let numberProp = JSONValue.object(["type": .string("number")])

private func objectSchema(_ properties: [String: JSONValue],
                          required: [String]) -> JSONValue {
    .object(["type": .string("object"),
             "properties": .object(properties),
             "required": .array(required.map(JSONValue.string))])
}

// MARK: - generate_shot_video

final class GenerateShotVideoAction: ProjectAssistantAction, AssistantAction {
    /// Veo constants — parity with the Cinematography provider row and the
    /// gateway's cost.py ($0.40/s). Veo's honest lengths are 4/6/8 seconds.
    static let costPerSecond = 0.40
    static let validDurations: [Double] = [4, 6, 8]
    static let veoFolderName = "veo3"
    static let veoRawValue = "google_veo"
    static let veoDisplayName = "Veo 3"

    /// (request, context) — the factory routes this into the app-scoped
    /// VideoJobCoordinator; tests record it.
    typealias Submit = @MainActor (VideoGenerationRequest, VideoJobContext) throws -> Void
    /// Is a job already running for this shot uuid?
    typealias ActiveCheck = @MainActor (String) -> Bool

    let name = "generate_shot_video"
    let summary = """
    Generate a video clip for a shot (by its shot number) with Veo. \
    duration is 4, 6, or 8 seconds (default 4). SPENDS $0.40 per second \
    ($1.60–$3.20 per clip); runs only after the user approves. The clip \
    renders in the background as a new take — progress appears in the chat \
    and in the Cinematography tab.
    """
    let risk = ActionRisk.spending
    let minimumTier = ProductTier.creator  // §3.7: generation actions are Creator+
    var parameterSchema: JSONValue {
        objectSchema([
            "shot": integerProp,
            "duration": numberProp,
            "camera_motion": stringProp,
            "custom_prompt": stringProp,
        ], required: ["shot"])
    }

    private let submit: Submit
    private let isJobActive: ActiveCheck

    init(projectViewModel: ProjectViewModel?, coordinator: AppCoordinator?,
         submit: @escaping Submit, isJobActive: @escaping ActiveCheck) {
        self.submit = submit
        self.isJobActive = isJobActive
        super.init(projectViewModel: projectViewModel, coordinator: coordinator)
    }

    private struct Arguments: Decodable {
        let shot: Int
        let duration: Double?
        let cameraMotion: String?
        let customPrompt: String?
        enum CodingKeys: String, CodingKey {
            case shot, duration
            case cameraMotion = "camera_motion"
            case customPrompt = "custom_prompt"
        }
    }

    @MainActor private func locate(_ number: Int, in pvm: ProjectViewModel)
    throws -> (seq: Int, sc: Int, shot: Int) {
        for seq in pvm.project.sequences.indices {
            for sc in pvm.project.sequences[seq].scenes.indices {
                if let s = pvm.project.sequences[seq].scenes[sc].shots
                    .firstIndex(where: { $0.shotId == number }) {
                    return (seq, sc, s)
                }
            }
        }
        throw ActionError("no shot #\(number) — use get_scene to find shot numbers")
    }

    @MainActor private func resolvedDuration(_ args: Arguments) throws -> Double {
        let duration = args.duration ?? 4
        guard Self.validDurations.contains(duration) else {
            throw ActionError("duration must be 4, 6, or 8 seconds")
        }
        return duration
    }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let pvm = try requireProject()
        let (seq, sc, s) = try locate(args.shot, in: pvm)
        let shot = pvm.project.sequences[seq].scenes[sc].shots[s]
        let duration = try resolvedDuration(args)
        if isJobActive(shot.id) {
            throw ActionError("shot #\(args.shot) is already rendering — wait for the current take to finish")
        }
        let cost = duration * Self.costPerSecond
        var warnings: [String] = []
        warnings.append("video is the most expensive generation — this clip is ~$\(String(format: "%.2f", cost))")
        return ActionPlan(
            summary: "Render shot #\(args.shot) with \(Self.veoDisplayName) "
                + "(\(Int(duration))s ≈ $\(String(format: "%.2f", cost)))",
            previews: [ActionPreview(
                title: "shot #\(args.shot) · \(shot.shotType) / \(shot.cameraAngle)",
                oldValue: shot.videoPath == nil ? "no video" : "existing take kept",
                newValue: "new \(Int(duration))s take (~$\(String(format: "%.2f", cost)))")],
            warnings: warnings,
            estimatedCost: cost)
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let pvm = try requireProject()
        guard let projectFile = pvm.projectPath else {
            throw ActionError("the project has not been saved yet")
        }
        let (seq, sc, s) = try locate(args.shot, in: pvm)
        let shot = pvm.project.sequences[seq].scenes[sc].shots[s]
        let scene = pvm.project.sequences[seq].scenes[sc]
        let duration = try resolvedDuration(args)
        if isJobActive(shot.id) {
            throw ActionError("shot #\(args.shot) is already rendering")
        }

        let cameraMotion = args.cameraMotion ?? "Static"
        let prompt = args.customPrompt ?? ShotPromptBuilder.videoPrompt(
            shot: shot, scene: scene,
            characters: pvm.project.characters,
            locations: pvm.project.locations,
            cameraMotion: cameraMotion,
            duration: duration,
            filmStyle: nil,
            lightingStyle: shot.lightingStyle)

        let request = VideoGenerationRequest(
            prompt: prompt,
            provider: .google,
            durationSeconds: duration,
            quality: shot.videoQuality ?? "Standard",
            aspectRatio: "16:9",
            fps: 24,
            cameraMotion: cameraMotion,
            subjectMotion: "Static",
            negativePrompt: nil,
            startFrameBase64: nil,
            endFrameBase64: nil,
            referenceFrames: nil,
            resolution: shot.videoResolution ?? "720p",
            shotId: shot.id,
            projectId: nil)
        let context = VideoJobContext(
            shotId: shot.id,
            shotShotId: shot.shotId,
            aiProvider: .google,
            folderName: Self.veoFolderName,
            providerRawValue: Self.veoRawValue,
            providerDisplayName: Self.veoDisplayName,
            basePath: projectFile.deletingLastPathComponent(),
            duration: duration,
            quality: shot.videoQuality ?? "Standard")
        try submit(request, context)
        didMutate(.shots)
        return ActionOutcome(
            resultForModel: #"{"status": "applied", "note": "video job submitted — it renders in the background over several minutes; progress is shown to the user automatically"}"#,
            userSummary: "Rendering shot #\(args.shot) (\(Int(duration))s) — progress will appear here")
    }
}

// MARK: - Factory extension

extension AssistantActionFactory {
    @MainActor static func videoActions(projectViewModel: ProjectViewModel?,
                                        coordinator: AppCoordinator?) -> [any AssistantAction] {
        [
            GenerateShotVideoAction(
                projectViewModel: projectViewModel, coordinator: coordinator,
                submit: { request, context in
                    guard let jobs = AssistantRuntime.shared.videoJobs else {
                        throw ActionError("the video engine isn't ready yet — open the project window first")
                    }
                    jobs.submit(request, context: context)
                },
                isJobActive: { shotUUID in
                    AssistantRuntime.shared.videoJobs?.state(forShot: shotUUID)?.isActive ?? false
                }),
        ]
    }
}

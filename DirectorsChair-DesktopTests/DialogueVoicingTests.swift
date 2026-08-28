// DirectorsChair-DesktopTests/DialogueVoicingTests.swift
//
// DC-0081: "voice all dialogue" from Playback — the timeline plan (order,
// skip rules, cost), the batch (takes saved as they land, cancel, failure
// accounting) and the one voicer's casting rule shared with the Timeline
// and the assistant.

import XCTest
@testable import DirectorsChair_Desktop
@testable import DirectorsChairCore
@testable import DirectorsChairServices

@MainActor
final class DialogueVoicingTests: XCTestCase {

    private var projectVM: ProjectViewModel!
    private var tempDir: URL!
    private let requests = Requests()

    private final class Requests: @unchecked Sendable {
        private let lock = NSLock()
        private var items: [SpeechGenerationRequest] = []
        func record(_ request: SpeechGenerationRequest) { lock.lock(); items.append(request); lock.unlock() }
        var all: [SpeechGenerationRequest] { lock.lock(); defer { lock.unlock() }; return items }
    }

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dc-voicing-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        var mara = Character(name: "Mara")
        mara.gender = "female"
        mara.voiceStyle = "calm and low"
        var ilya = Character(name: "Ilya")
        ilya.gender = "male"
        ilya.voice = "Puck"

        var voiced = Dialogue(uuid: "d3", character: "Mara", text: "Already voiced", chronologyNumber: 3)
        voiced.audioFilePath = "assets/audio/dialogues/d3.wav"

        var project = Project(name: "Fixture Film")
        project.characters = [mara, ilya]
        project.sequences = [
            Sequence(name: "Act 1", scenes: [
                Scene(name: "Opening", description: "d", dialogues: [
                    // Stored out of order on purpose: the plan follows chronology.
                    Dialogue(uuid: "d1", character: "Mara", text: "<p>Run. <b>Now.</b></p>",
                             tags: ["urgent"], chronologyNumber: 2),
                    Dialogue(uuid: "d2", character: "Ilya", text: "Where?", chronologyNumber: 1),
                    voiced,
                    Dialogue(uuid: "d4", character: "Ilya", text: "<p></p>", chronologyNumber: 4),
                ]),
            ]),
            Sequence(name: "Act 2", scenes: [
                Scene(name: "Later", description: "d", dialogues: [
                    Dialogue(uuid: "d5", character: "Mara", text: "Later line", chronologyNumber: 1),
                ]),
            ]),
        ]
        projectVM = ProjectViewModel(project: project)
        projectVM.projectPath = tempDir.appendingPathComponent("project.json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        projectVM = nil
        super.tearDown()
    }

    private func generator(failing: @escaping @Sendable (SpeechGenerationRequest) -> Bool = { _ in false },
                           afterEach: (@Sendable () async -> Void)? = nil) -> DialogueVoicer.Generate {
        let requests = self.requests
        return { request in
            requests.record(request)
            if failing(request) { throw AIClientError.invalidResponse("provider said no") }
            await afterEach?()
            return Data("RIFF".utf8)
        }
    }

    // MARK: - Plan

    func testPlanFollowsTheTimelineAndSkipsVoicedAndEmptyLines() {
        let plan = DialogueVoicingPlan.timeline(in: projectVM.project, onlyUnvoiced: true)
        XCTAssertEqual(plan.lines.map(\.uuid), ["d2", "d1", "d5"],
                       "sequence, scene, then chronology — not storage order")
        XCTAssertEqual(plan.lines.map(\.text), ["Where?", "Run. Now.", "Later line"], "spoken text is plain")
        XCTAssertEqual(plan.alreadyVoiced, 1)
        XCTAssertEqual(plan.characterCount, 2)
        XCTAssertEqual(plan.estimatedCost,
                       DialogueVoicer.estimate(characters: 6) + DialogueVoicer.estimate(characters: 9)
                       + DialogueVoicer.estimate(characters: 10), accuracy: 0.000001)

        let everything = DialogueVoicingPlan.timeline(in: projectVM.project, onlyUnvoiced: false)
        XCTAssertEqual(everything.lines.map(\.uuid), ["d2", "d1", "d3", "d5"], "regenerating includes voiced lines")
        XCTAssertEqual(everything.alreadyVoiced, 0)
        XCTAssertTrue(everything.lines[2].hasAudio)
    }

    // MARK: - Batch

    func testBatchSavesEachTakeAndSetsThePath() async throws {
        let batch = DialogueVoicingBatch()
        let plan = DialogueVoicingPlan.timeline(in: projectVM.project, onlyUnvoiced: true)
        let summary = await batch.run(plan: plan, projectViewModel: projectVM, provider: .google,
                                      generate: generator())
        XCTAssertEqual(summary, DialogueVoicingBatch.Summary(generated: 3, failed: 0, skipped: 0,
                                                             cancelled: false, firstError: nil))
        XCTAssertEqual(batch.state, .finished(summary))
        for uuid in ["d1", "d2", "d5"] {
            XCTAssertTrue(FileManager.default.fileExists(
                atPath: tempDir.appendingPathComponent("assets/audio/dialogues/\(uuid).wav").path), uuid)
            let at = try XCTUnwrap(DialogueVoicingBatch.locate(uuid: uuid, in: projectVM.project))
            XCTAssertEqual(projectVM.project.sequences[at.sequence].scenes[at.scene].dialogues[at.dialogue].audioFilePath,
                           "assets/audio/dialogues/\(uuid).wav")
        }
        XCTAssertEqual(requests.all.map(\.characterName), ["Ilya", "Mara", "Mara"], "voiced in timeline order")
        XCTAssertEqual(requests.all.map(\.provider), [.google, .google, .google])
    }

    func testCancelStopsAfterTheLineInFlightAndKeepsWhatLanded() async throws {
        let batch = DialogueVoicingBatch()
        let plan = DialogueVoicingPlan.timeline(in: projectVM.project, onlyUnvoiced: true)
        let summary = await batch.run(plan: plan, projectViewModel: projectVM, provider: .google,
                                      generate: generator(afterEach: { await MainActor.run { batch.cancel() } }))
        XCTAssertTrue(summary.cancelled)
        XCTAssertEqual(summary.generated, 1)
        XCTAssertEqual(summary.skipped, 2)
        XCTAssertEqual(requests.all.count, 1)
        XCTAssertNotNil(projectVM.project.sequences[0].scenes[0].dialogues[1].audioFilePath, "the first take stays")
        XCTAssertNil(projectVM.project.sequences[0].scenes[0].dialogues[0].audioFilePath)
    }

    func testAFailedLineIsCountedAndTheRunGoesOn() async throws {
        let batch = DialogueVoicingBatch()
        let plan = DialogueVoicingPlan.timeline(in: projectVM.project, onlyUnvoiced: true)
        let summary = await batch.run(plan: plan, projectViewModel: projectVM, provider: .google,
                                      generate: generator(failing: { $0.characterName == "Ilya" }))
        XCTAssertEqual(summary.generated, 2)
        XCTAssertEqual(summary.failed, 1)
        XCTAssertEqual(summary.skipped, 0)
        XCTAssertFalse(summary.cancelled)
        XCTAssertTrue(summary.firstError?.contains("provider said no") == true)
        XCTAssertNil(projectVM.project.sequences[0].scenes[0].dialogues[1].audioFilePath, "Ilya's line stays unvoiced")
    }

    func testThreeFailuresInARowStopTheRun() async throws {
        let batch = DialogueVoicingBatch()
        let plan = DialogueVoicingPlan.timeline(in: projectVM.project, onlyUnvoiced: false)   // 4 lines
        let summary = await batch.run(plan: plan, projectViewModel: projectVM, provider: .google,
                                      generate: generator(failing: { _ in true }))
        XCTAssertEqual(summary.failed, DialogueVoicingBatch.consecutiveFailureLimit)
        XCTAssertEqual(summary.skipped, 1, "the fourth line is never attempted")
        XCTAssertEqual(summary.generated, 0)
        XCTAssertEqual(requests.all.count, 3)
    }

    func testAnUnsavedProjectVoicesNothing() async {
        projectVM.projectPath = nil
        let batch = DialogueVoicingBatch()
        let plan = DialogueVoicingPlan.timeline(in: projectVM.project, onlyUnvoiced: true)
        let summary = await batch.run(plan: plan, projectViewModel: projectVM, provider: .google,
                                      generate: generator())
        XCTAssertEqual(summary.generated, 0)
        XCTAssertEqual(summary.skipped, 3)
        XCTAssertTrue(summary.firstError?.contains("saved") == true)
        XCTAssertTrue(requests.all.isEmpty)
    }

    // MARK: - The shared voicer

    func testVoicerCastsLikeTheTimelineSeam() {
        let project = projectVM.project
        let mara = DialogueVoicer.request(
            text: DialogueVoicer.plainText("<p>Run. <b>Now.</b></p>"), characterName: "Mara", tags: ["urgent"],
            character: DialogueVoicer.character(named: "mara", in: project), provider: .google)
        XCTAssertEqual(mara.text, "Run. Now.")
        XCTAssertEqual(mara.voiceName, "Kore", "no cast voice → the gender default")
        XCTAssertEqual(mara.emotion, "Say calm and low, urgent")
        XCTAssertEqual(mara.characterName, "Mara")

        let ilya = DialogueVoicer.request(text: "Where?", characterName: "Ilya", tags: [],
                                          character: DialogueVoicer.character(named: "Ilya", in: project),
                                          provider: .elevenlabs)
        XCTAssertEqual(ilya.voiceName, "Puck", "the cast voice wins")
        XCTAssertNil(ilya.emotion)
        XCTAssertEqual(ilya.provider, .elevenlabs)

        let stranger = DialogueVoicer.request(text: "Hello.", characterName: "Stranger", tags: [],
                                              character: nil, provider: .google)
        XCTAssertEqual(stranger.voiceName, "Charon")
        XCTAssertEqual(DialogueVoicer.relativePath(for: "abc"), "assets/audio/dialogues/abc.wav")
        XCTAssertEqual(DialogueVoicer.estimate(characters: 1000), 0.30, accuracy: 0.000001)
    }
}

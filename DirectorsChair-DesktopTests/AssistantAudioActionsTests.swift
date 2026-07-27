// DirectorsChair-DesktopTests/AssistantAudioActionsTests.swift
//
// AI Assistant program, Phase A5.3: generate_dialogue_audio — voice
// casting parity with the Timeline seam, per-line cost previews from the
// gateway formula, missing-audio selection, and file+field persistence
// through an offline stub.

import XCTest
@testable import DirectorsChair_Desktop
@testable import DirectorsChairCore
@testable import DirectorsChairServices

@MainActor
final class AssistantAudioActionsTests: XCTestCase {

    private var projectVM: ProjectViewModel!
    private var tempDir: URL!
    private var requests: [SpeechGenerationRequest] = []

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dc-audio-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir,
                                                 withIntermediateDirectories: true)
        var mara = Character(name: "Mara")
        mara.gender = "female"
        mara.voiceStyle = "calm and low"
        var ilya = Character(name: "Ilya")
        ilya.gender = "male"
        ilya.voice = "Puck"

        var voiced = Dialogue(character: "Mara", text: "Already voiced")
        voiced.audioFilePath = "assets/audio/dialogues/existing.wav"

        var project = Project(name: "Fixture Film")
        project.characters = [mara, ilya]
        project.sequences = [Sequence(name: "Act 1", scenes: [
            Scene(name: "Opening", description: "d", dialogues: [
                Dialogue(character: "Mara", text: "<p>Run. <b>Now.</b></p>",
                         tags: ["urgent"]),
                Dialogue(character: "Ilya", text: "Where?"),
                voiced,
            ]),
        ])]
        projectVM = ProjectViewModel(project: project)
        projectVM.projectPath = tempDir.appendingPathComponent("project.json")
        requests = []
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        projectVM = nil
        super.tearDown()
    }

    private func makeAction() -> GenerateDialogueAudioAction {
        GenerateDialogueAudioAction(
            projectViewModel: projectVM, coordinator: nil,
            makeGenerate: { [weak self] in
                { request in
                    await MainActor.run { self?.requests.append(request) }
                    return Data("fake-wav".utf8)
                }
            })
    }

    private func args(_ json: String) -> Data { Data(json.utf8) }

    func testValidateSelectsOnlyUnvoicedLinesWithCostPreviews() throws {
        let action = makeAction()
        XCTAssertEqual(action.risk, .spending)

        let plan = try action.validate(argumentsData: args(#"{"scene": "Opening"}"#))
        XCTAssertEqual(plan.previews.count, 2, "the already-voiced line is skipped")
        XCTAssertTrue(plan.previews.allSatisfy { $0.oldValue == "no audio" })
        XCTAssertTrue(plan.previews[0].newValue?.contains("$0.0") == true,
                      "per-line cost from the $0.30/1k-chars formula")

        // regenerate=true includes the voiced line too
        let all = try action.validate(argumentsData:
            args(#"{"scene": "Opening", "regenerate": true}"#))
        XCTAssertEqual(all.previews.count, 3)

        XCTAssertThrowsError(try action.validate(argumentsData:
            args(#"{"scene": "Opening", "index": 9}"#)))
        XCTAssertThrowsError(try action.validate(argumentsData:
            args(#"{"scene": "Ghost"}"#)))
    }

    func testExecuteCastsVoicesStripsHTMLAndPersists() async throws {
        let action = makeAction()
        _ = try await action.execute(argumentsData: args(#"{"scene": "Opening"}"#))

        XCTAssertEqual(requests.count, 2)
        // Mara: no custom voice, female → Kore; style + tags as emotion; HTML stripped.
        XCTAssertEqual(requests[0].voiceName, "Kore")
        XCTAssertEqual(requests[0].text, "Run. Now.")
        XCTAssertEqual(requests[0].emotion, "Say calm and low, urgent")
        // Ilya: custom cast voice wins.
        XCTAssertEqual(requests[1].voiceName, "Puck")
        XCTAssertNil(requests[1].emotion)

        let dialogues = projectVM.project.sequences[0].scenes[0].dialogues
        for i in [0, 1] {
            let path = dialogues[i].audioFilePath
            XCTAssertNotNil(path)
            XCTAssertTrue(path!.hasPrefix("assets/audio/dialogues/"))
            XCTAssertTrue(FileManager.default.fileExists(
                atPath: tempDir.appendingPathComponent(path!).path), path!)
        }
        XCTAssertEqual(dialogues[2].audioFilePath,
                       "assets/audio/dialogues/existing.wav", "untouched")
        XCTAssertTrue(projectVM.isDirty)
    }

    func testSingleIndexModeAndFullyVoicedSceneError() async throws {
        let action = makeAction()
        _ = try await action.execute(argumentsData:
            args(#"{"scene": "Opening", "index": 1}"#))
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests[0].characterName, "Ilya")

        // Voice the rest, then a plain call must error with guidance.
        _ = try await action.execute(argumentsData: args(#"{"scene": "Opening"}"#))
        XCTAssertThrowsError(try action.validate(argumentsData:
            args(#"{"scene": "Opening"}"#))) { error in
            XCTAssertTrue("\(error)".contains("regenerate"))
        }
    }
}

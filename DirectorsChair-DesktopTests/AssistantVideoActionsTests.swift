// DirectorsChair-DesktopTests/AssistantVideoActionsTests.swift
//
// AI Assistant program, Phase A5.4: generate_shot_video — duration-based
// cost previews, prompt/context parity with the Cinematography seam,
// active-job blocking, and the in-chat progress monitor — all offline via
// injected submit/state closures.

import XCTest
@testable import DirectorsChair_Desktop
@testable import DirectorsChairCore
@testable import DirectorsChairServices
@testable import DirectorsChairViews

@MainActor
final class AssistantVideoActionsTests: XCTestCase {

    private var projectVM: ProjectViewModel!
    private var submissions: [(request: VideoGenerationRequest, context: VideoJobContext)] = []
    private var activeShotUUIDs: Set<String> = []

    override func setUp() {
        super.setUp()
        var shot = Shot(shotId: 12, description: "Wide establishing")
        shot.lightingStyle = "Low-key"
        var project = Project(name: "Fixture Film")
        project.sequences = [Sequence(name: "Act 1", scenes: [
            Scene(name: "Opening", description: "Night. Rain.", shots: [shot]),
        ])]
        projectVM = ProjectViewModel(project: project)
        projectVM.projectPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("dc-video-\(UUID().uuidString)/project.json")
        submissions = []
        activeShotUUIDs = []
    }

    override func tearDown() {
        projectVM = nil
        super.tearDown()
    }

    private func makeAction() -> GenerateShotVideoAction {
        GenerateShotVideoAction(
            projectViewModel: projectVM, coordinator: nil,
            submit: { [weak self] request, context in
                self?.submissions.append((request, context))
            },
            isJobActive: { [weak self] uuid in
                self?.activeShotUUIDs.contains(uuid) ?? false
            })
    }

    private func args(_ json: String) -> Data { Data(json.utf8) }

    func testValidatePreviewsDurationCostAndBlocksActiveJobs() throws {
        let action = makeAction()
        XCTAssertEqual(action.risk, .spending)

        let plan = try action.validate(argumentsData: args(#"{"shot": 12, "duration": 8}"#))
        XCTAssertTrue(plan.summary.contains("$3.20"), plan.summary)
        XCTAssertTrue(plan.warnings.first?.contains("most expensive") == true)
        XCTAssertTrue(plan.previews[0].title.contains("#12"))

        let cheap = try action.validate(argumentsData: args(#"{"shot": 12}"#))
        XCTAssertTrue(cheap.summary.contains("$1.60"), "default 4s ≈ $1.60")

        XCTAssertThrowsError(try action.validate(argumentsData:
            args(#"{"shot": 12, "duration": 5}"#)), "duration must be 4/6/8")
        XCTAssertThrowsError(try action.validate(argumentsData:
            args(#"{"shot": 99}"#)))

        activeShotUUIDs.insert(projectVM.project.sequences[0].scenes[0].shots[0].id)
        XCTAssertThrowsError(try action.validate(argumentsData:
            args(#"{"shot": 12}"#))) { error in
            XCTAssertTrue("\(error)".contains("already rendering"))
        }
    }

    func testExecuteSubmitsWithSeamParityRequestAndContext() async throws {
        let action = makeAction()
        _ = try await action.execute(argumentsData:
            args(#"{"shot": 12, "duration": 6, "camera_motion": "Slow push-in"}"#))

        XCTAssertEqual(submissions.count, 1)
        let (request, context) = submissions[0]
        XCTAssertEqual(request.durationSeconds, 6)
        XCTAssertEqual(request.aspectRatio, "16:9")
        XCTAssertEqual(request.cameraMotion, "Slow push-in")
        XCTAssertTrue(request.prompt.contains("Cinematic video shot"),
                      "ShotPromptBuilder prompt used")
        XCTAssertEqual(request.shotId,
                       projectVM.project.sequences[0].scenes[0].shots[0].id)

        XCTAssertEqual(context.folderName, "veo3")
        XCTAssertEqual(context.providerRawValue, "google_veo")
        XCTAssertEqual(context.duration, 6)
        XCTAssertEqual(context.shotShotId, 12)
        XCTAssertTrue(projectVM.isDirty)
    }

    func testExecuteCustomPromptOverrides() async throws {
        let action = makeAction()
        _ = try await action.execute(argumentsData:
            args(#"{"shot": 12, "custom_prompt": "storm rolls over the skyline"}"#))
        XCTAssertEqual(submissions[0].request.prompt, "storm rolls over the skyline")
    }

    func testVideoJobMonitorNarratesPhasesIntoChat() async throws {
        let viewModel = AIChatViewModel()
        viewModel.projectViewModel = projectVM
        defer {
            for conversation in viewModel.conversations {
                viewModel.deleteConversation(conversation)
            }
        }
        viewModel.videoMonitorInterval = 0.01
        // Scripted phase sequence the poller will observe.
        var feed: [(String, String)] = [
            ("active", "Rendering — 40%"),
            ("active", "Rendering — 40%"),          // no duplicate message
            ("downloading", "Downloading take"),
            ("completed", "Saved take 1"),
        ]
        viewModel.videoJobStateLookup = { _ in
            feed.isEmpty ? nil : feed.removeFirst()
        }

        let before = viewModel.messages.count
        viewModel.startVideoJobMonitor(shotNumber: 12)
        try await Task.sleep(nanoseconds: 300_000_000)

        let added = viewModel.messages.suffix(from: before).map(\.content)
        XCTAssertEqual(added.filter { $0.contains("Rendering — 40%") }.count, 1,
                       "phase repeats must not spam")
        XCTAssertTrue(added.contains { $0.contains("Downloading take") })
        XCTAssertTrue(added.contains { $0.contains("video is ready") },
                      "completion posts the final message: \(added)")
    }
}

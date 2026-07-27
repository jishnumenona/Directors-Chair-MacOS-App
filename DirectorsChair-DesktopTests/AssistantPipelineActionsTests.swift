// DirectorsChair-DesktopTests/AssistantPipelineActionsTests.swift
//
// AI Assistant program, Phase A5.6 slice 1: import_screenplay — path
// validation, replace-structure warning, and the graft of the imported
// project into the current one, through an injected offline runner.

import XCTest
@testable import DirectorsChair_Desktop
@testable import DirectorsChairCore
@testable import DirectorsChairServices

@MainActor
final class AssistantPipelineActionsTests: XCTestCase {

    private var projectVM: ProjectViewModel!
    private var tempDir: URL!
    private var pdfURL: URL!
    private var importedNames: [String] = []

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dc-pipeline-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir,
                                                 withIntermediateDirectories: true)
        pdfURL = tempDir.appendingPathComponent("script.pdf")
        try? Data("fake-pdf".utf8).write(to: pdfURL)

        var project = Project(name: "My Film")
        project.sequences = [Sequence(name: "Old Act", scenes: [
            Scene(name: "Old Scene", description: "stale"),
        ])]
        project.characters = [Character(name: "Old Hero")]
        projectVM = ProjectViewModel(project: project)
        projectVM.projectPath = tempDir.appendingPathComponent("project.json")
        importedNames = []
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        projectVM = nil
        super.tearDown()
    }

    private func makeAction() -> ImportScreenplayAction {
        ImportScreenplayAction(
            projectViewModel: projectVM, coordinator: nil,
            runImport: { [weak self] url, name in
                await MainActor.run { self?.importedNames.append(name) }
                var imported = Project(name: name)
                imported.genre = "Neo-Noir"
                imported.sequences = [Sequence(name: "Act 1", scenes: [
                    Scene(name: "Opening", description: "Night. Rain.",
                          dialogues: [Dialogue(character: "Mara", text: "Run.")]),
                    Scene(name: "Finale", description: "Dawn."),
                ])]
                imported.characters = [Character(name: "Mara")]
                imported.locations = [Location(name: "Rooftop")]
                return ScreenplayImporter.ImportResult(
                    project: imported,
                    stats: ScreenplayImporter.ImportStats(
                        sceneCount: 2, shotCount: 0, dialogueCount: 1,
                        actionCount: 0, characterCount: 1, soundNoteCount: 0,
                        propCount: 0, locationCount: 1))
            })
    }

    private func args(_ json: String) -> Data { Data(json.utf8) }

    func testValidateChecksPathAndWarnsAboutReplacement() throws {
        let action = makeAction()
        XCTAssertEqual(action.risk, .spending)

        let plan = try action.validate(argumentsData:
            args(#"{"path": "\#(pdfURL.path)"}"#))
        XCTAssertEqual(plan.warnings.count, 1, "non-empty project → replace warning")
        XCTAssertTrue(plan.warnings[0].contains("1 scenes"))
        XCTAssertTrue(plan.summary.contains("script.pdf"))
        XCTAssertEqual(plan.estimatedCost,
                       ImportScreenplayAction.estimatedImportCost)

        XCTAssertThrowsError(try action.validate(argumentsData:
            args(#"{"path": "/nonexistent/script.pdf"}"#)))
        let textFile = tempDir.appendingPathComponent("script.txt")
        try Data("text".utf8).write(to: textFile)
        XCTAssertThrowsError(try action.validate(argumentsData:
            args(#"{"path": "\#(textFile.path)"}"#))) { error in
            XCTAssertTrue("\(error)".contains("PDF"))
        }
    }

    func testExecuteGraftsImportedStructureIntoCurrentProject() async throws {
        let action = makeAction()
        let outcome = try await action.execute(argumentsData:
            args(#"{"path": "\#(pdfURL.path)"}"#))

        // Identity kept; structure replaced.
        XCTAssertEqual(projectVM.project.name, "My Film")
        XCTAssertEqual(importedNames, ["My Film"], "pipeline ran under the project's name")
        XCTAssertEqual(projectVM.project.sequences.map(\.name), ["Act 1"])
        XCTAssertEqual(projectVM.project.sequences[0].scenes.map(\.name),
                       ["Opening", "Finale"])
        XCTAssertEqual(projectVM.project.characters.map(\.name), ["Mara"])
        XCTAssertEqual(projectVM.project.locations.map(\.name), ["Rooftop"])
        XCTAssertEqual(projectVM.project.genre, "Neo-Noir")
        XCTAssertTrue(projectVM.isDirty)
        XCTAssertTrue(outcome.userSummary.contains("2 scenes"), outcome.userSummary)
        XCTAssertTrue(outcome.userSummary.contains("1 characters"))
    }
}

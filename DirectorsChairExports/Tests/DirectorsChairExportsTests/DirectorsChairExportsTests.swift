// DirectorsChairExports/Tests/DirectorsChairExportsTests/DirectorsChairExportsTests.swift

import XCTest
@testable import DirectorsChairExports
@testable import DirectorsChairCore

final class DirectorsChairExportsTests: XCTestCase {
    
    // MARK: - Test Data
    
    private var testProject: Project {
        var project = Project(name: "Test Movie")
        project.director = "Test Author"
        project.genre = "Drama"
        project.overviewLogline = "A test logline for the movie."
        
        // Add a character
        var character = Character(name: "John Doe")
        character.role = "Protagonist"
        character.about = "A brave hero"
        character.age = 35
        character.gender = "male"
        project.characters.append(character)
        
        // Add a sequence with a scene
        var sequence = Sequence(name: "Act 1")
        var scene = Scene(name: "Opening")
        scene.description = "The story begins."
        scene.location = "Coffee Shop"
        
        let dialogue = Dialogue(
            character: "John Doe",
            text: "Hello, world!",
            chronologyNumber: 1
        )
        scene.dialogues.append(dialogue)
        
        let action = Action(
            description: "John walks through the door.",
            chronologyNumber: 0
        )
        scene.actions.append(action)
        
        sequence.scenes.append(scene)
        project.sequences.append(sequence)
        
        return project
    }
    
    // MARK: - Export Format Tests
    
    func testExportFormatProperties() {
        XCTAssertEqual(ExportFormat.fountain.fileExtension, "fountain")
        XCTAssertEqual(ExportFormat.fdx.fileExtension, "fdx")
        XCTAssertEqual(ExportFormat.pdf.fileExtension, "pdf")
        XCTAssertEqual(ExportFormat.html.fileExtension, "html")
        
        XCTAssertEqual(ExportFormat.fountain.displayName, "Fountain")
        XCTAssertEqual(ExportFormat.fdx.displayName, "Final Draft")
    }
    
    // MARK: - Fountain Export Tests
    
    func testFountainExportProject() {
        let project = testProject
        let fountain = FountainExportService.exportProject(project)
        
        // Check title page
        XCTAssertTrue(fountain.contains("Title: Test Movie"))
        XCTAssertTrue(fountain.contains("Author: Test Author"))
        
        // Check scene content
        XCTAssertTrue(fountain.contains("INT."))
        XCTAssertTrue(fountain.contains("JOHN DOE"))
        XCTAssertTrue(fountain.contains("Hello, world!"))
    }
    
    func testFountainExportScene() {
        let project = testProject
        let scene = project.sequences.first!.scenes.first!
        let fountain = FountainExportService.exportScene(scene)
        
        XCTAssertTrue(fountain.contains("INT."))
        XCTAssertTrue(fountain.contains("JOHN DOE"))
    }
    
    // MARK: - HTML Export Tests
    
    func testHTMLExportCharacterOverview() {
        let project = testProject
        let character = project.characters.first!
        let html = HTMLExportService.exportCharacterOverview(character, project: project)
        
        XCTAssertTrue(html.contains("<!DOCTYPE html>"))
        XCTAssertTrue(html.contains("John Doe"))
        XCTAssertTrue(html.contains("Protagonist"))
    }
    
    func testHTMLExportProjectOverview() {
        let project = testProject
        let html = HTMLExportService.exportProjectOverview(project)
        
        XCTAssertTrue(html.contains("<!DOCTYPE html>"))
        XCTAssertTrue(html.contains("Test Movie"))
        XCTAssertTrue(html.contains("Drama"))
    }
    
    func testHTMLExportScreenplay() {
        let project = testProject
        let html = HTMLExportService.exportScreenplay(project)
        
        XCTAssertTrue(html.contains("<!DOCTYPE html>"))
        XCTAssertTrue(html.contains("screenplay"))
        XCTAssertTrue(html.contains("Test Movie"))
    }
    
    // MARK: - FDX Export Tests
    
    func testFDXExportProject() {
        let project = testProject
        let fdx = FDXExportService.exportProject(project)
        
        XCTAssertTrue(fdx.contains("<?xml version=\"1.0\""))
        XCTAssertTrue(fdx.contains("<FinalDraft"))
        XCTAssertTrue(fdx.contains("Test Movie"))
        XCTAssertTrue(fdx.contains("Scene Heading"))
        XCTAssertTrue(fdx.contains("JOHN DOE"))
    }
    
    func testFDXElementTypes() {
        XCTAssertEqual(FDXExportService.FDXElementTypes.sceneHeading, "Scene Heading")
        XCTAssertEqual(FDXExportService.FDXElementTypes.dialogue, "Dialogue")
        XCTAssertEqual(FDXExportService.FDXElementTypes.character, "Character")
        XCTAssertEqual(FDXExportService.FDXElementTypes.action, "Action")
    }
    
    // MARK: - PDF Export Tests
    
    @MainActor
    func testPDFPageSettings() {
        let usLetter = PDFExportService.PageSettings.usLetter
        XCTAssertEqual(usLetter.pageSize.width, 612)
        XCTAssertEqual(usLetter.pageSize.height, 792)
        
        let a4 = PDFExportService.PageSettings.a4
        XCTAssertEqual(a4.pageSize.width, 595)
        XCTAssertEqual(a4.pageSize.height, 842)
    }
    
    // MARK: - Export Error Tests
    
    func testExportErrorDescriptions() {
        let invalidProject = ExportError.invalidProject("No sequences")
        XCTAssertNotNil(invalidProject.errorDescription)
        XCTAssertTrue(invalidProject.errorDescription!.contains("Invalid project"))
        
        let writeError = ExportError.fileWriteError("Permission denied")
        XCTAssertNotNil(writeError.errorDescription)
        XCTAssertTrue(writeError.errorDescription!.contains("Failed to write"))
    }
}

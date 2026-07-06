// DirectorsChairExports/Tests/DirectorsChairExportsTests/FountainSpecComplianceTests.swift
//
// WS8.4 — validate exported output against Fountain's parsing rules using a
// minimal reference classifier (scoped to the elements we emit). Guards the
// class of bug where narration exported as a TRANSITION (any all-caps line
// ending in ':' is a transition to a Fountain parser).

import XCTest
@testable import DirectorsChairExports
@testable import DirectorsChairCore

final class FountainSpecComplianceTests: XCTestCase {

    /// Minimal Fountain line classifier following the spec's disambiguation
    /// rules for the element kinds this app emits.
    enum FountainLine: Equatable {
        case blank, titlePage, sceneHeading, transition, centered, parenthetical, characterCue, actionOrDialogue
    }

    static func classify(_ line: String, previousBlank: Bool) -> FountainLine {
        let t = line.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return .blank }
        if t.contains(":") && (t.hasPrefix("Title:") || t.hasPrefix("Author:") || t.hasPrefix("Credit:") || t.hasPrefix("Draft date:") || t.hasPrefix("Genre:") || t.hasPrefix("Contact:")) {
            return .titlePage
        }
        if t.hasPrefix(">") && t.hasSuffix("<") { return .centered }
        if t.hasPrefix("(") && t.hasSuffix(")") { return .parenthetical }
        if t.hasPrefix("INT") || t.hasPrefix("EXT") || t.hasPrefix("I/E") || t.hasPrefix(".") { return .sceneHeading }
        // Fountain: an all-caps line ENDING IN ':' (or forced with '>') is a transition.
        if t == t.uppercased() && t.hasSuffix(":") { return .transition }
        if t.hasPrefix(">") { return .transition }
        // An all-caps line after a blank line is a character cue.
        if previousBlank && t == t.uppercased() && t.rangeOfCharacter(from: .letters) != nil { return .characterCue }
        return .actionOrDialogue
    }

    private func makeProject() -> Project {
        var project = Project(name: "Spec Test")
        project.director = "Author"
        var scene = Scene(name: "S1")
        scene.location = "EXT. DOCKS - NIGHT"
        scene.dialogues = [Dialogue(character: "Alex", text: "It's over.", chronologyNumber: 1)]
        scene.actions = [Action(description: "Rain hammers the pier.", chronologyNumber: 0)]
        scene.narrations = [Narration(text: "TEN YEARS EARLIER", chronologyNumber: 2)]
        var seq = Sequence(name: "Act 1")
        seq.scenes = [scene]
        project.sequences = [seq]
        return project
    }

    func testNarrationNeverClassifiesAsTransition() {
        let fountain = FountainExportService.exportProject(makeProject())
        let lines = fountain.components(separatedBy: "\n")
        var prevBlank = true
        for line in lines {
            let kind = Self.classify(line, previousBlank: prevBlank)
            if line.contains("TEN YEARS EARLIER") {
                XCTAssertEqual(kind, .centered,
                               "narration must export as centered text, not \(kind): '\(line)'")
            }
            prevBlank = (kind == .blank)
        }
    }

    func testEveryLineClassifiesAsIntendedElement() {
        let fountain = FountainExportService.exportProject(makeProject())
        let lines = fountain.components(separatedBy: "\n")
        var prevBlank = true
        var sawHeading = false, sawCue = false, sawDialogue = false
        var unexpectedTransitions: [String] = []

        for line in lines {
            let kind = Self.classify(line, previousBlank: prevBlank)
            switch kind {
            case .sceneHeading: sawHeading = true
            case .characterCue: sawCue = true
            case .actionOrDialogue where !prevBlank: sawDialogue = true
            case .transition: unexpectedTransitions.append(line)
            default: break
            }
            prevBlank = (kind == .blank)
        }

        XCTAssertTrue(sawHeading, "scene heading present and classified")
        XCTAssertTrue(sawCue, "character cue present and classified")
        XCTAssertTrue(sawDialogue, "dialogue follows its cue")
        XCTAssertTrue(unexpectedTransitions.isEmpty,
                      "no content accidentally classifies as a transition: \(unexpectedTransitions)")
    }

    func testSceneHeadingSurvivesClassification() {
        let fountain = FountainExportService.exportProject(makeProject())
        XCTAssertTrue(fountain.contains("EXT. DOCKS - NIGHT"))
        XCTAssertEqual(Self.classify("EXT. DOCKS - NIGHT", previousBlank: true), .sceneHeading)
        XCTAssertEqual(Self.classify("ALEX", previousBlank: true), .characterCue)
        XCTAssertEqual(Self.classify(">TEN YEARS EARLIER<", previousBlank: true), .centered)
        XCTAssertEqual(Self.classify("CUT TO:", previousBlank: true), .transition)
    }
}

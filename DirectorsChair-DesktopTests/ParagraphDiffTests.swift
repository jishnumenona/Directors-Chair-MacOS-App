// ParagraphDiffTests.swift
//
// The splice math behind the editor's incremental sync (perf Tier 1.3).
// The document model: paragraphs joined by "\n", no trailing newline.
// Every case here verifies the splice by APPLYING it to the old document
// string and asserting the result equals the new document string — the same
// operation the coordinator performs on the text storage.

import XCTest
@testable import DirectorsChair_Desktop

final class ParagraphDiffTests: XCTestCase {

    private func para(_ texts: [String], styles: [Int]? = nil) -> [ParagraphDiff.Paragraph] {
        texts.enumerated().map { i, t in
            ParagraphDiff.Paragraph(text: t, style: styles?[i] ?? 0)
        }
    }

    /// Apply a splice the way the coordinator does and return the result.
    private func apply(_ splice: ParagraphDiff.Splice,
                       to old: [ParagraphDiff.Paragraph],
                       new: [ParagraphDiff.Paragraph]) -> String {
        let oldDoc = old.map(\.text).joined(separator: "\n")
        var replacement = ""
        if splice.leadingSeparator { replacement += "\n" }
        replacement += splice.newParagraphs.map { new[$0].text }.joined(separator: "\n")
        if splice.trailingSeparator { replacement += "\n" }
        let ns = NSMutableString(string: oldDoc)
        ns.replaceCharacters(in: splice.range, with: replacement)
        return ns as String
    }

    /// One assertion for every case: the splice transforms old → new exactly.
    private func assertSplice(_ old: [String], _ new: [String],
                              oldStyles: [Int]? = nil, newStyles: [Int]? = nil,
                              file: StaticString = #filePath, line: UInt = #line) {
        let o = para(old, styles: oldStyles)
        let n = para(new, styles: newStyles)
        guard let splice = ParagraphDiff.splice(old: o, new: n) else {
            XCTAssertEqual(old, new, "nil splice must mean identical documents", file: file, line: line)
            XCTAssertEqual(oldStyles ?? [], newStyles ?? oldStyles ?? [], file: file, line: line)
            return
        }
        XCTAssertEqual(apply(splice, to: o, new: n),
                       new.joined(separator: "\n"),
                       "splice must transform old doc into new doc", file: file, line: line)
    }

    func testIdenticalDocumentsProduceNoSplice() {
        XCTAssertNil(ParagraphDiff.splice(old: para(["A", "B"]), new: para(["A", "B"])))
    }

    func testSingleParagraphTextChange() {
        assertSplice(["A", "B", "C"], ["A", "X", "C"])
    }

    func testFirstAndLastParagraphChanges() {
        assertSplice(["A", "B", "C"], ["X", "B", "C"])
        assertSplice(["A", "B", "C"], ["A", "B", "X"])
    }

    func testInsertInMiddle() {
        assertSplice(["A", "C"], ["A", "B", "C"])
    }

    func testInsertAtStart() {
        assertSplice(["B", "C"], ["A", "B", "C"])
    }

    func testAppendAtEnd() {
        assertSplice(["A", "B"], ["A", "B", "C"])
        assertSplice(["A"], ["A", "B", "C", "D"])
    }

    func testDeleteFromMiddle() {
        assertSplice(["A", "B", "C"], ["A", "C"])
    }

    func testDeleteFirstParagraph() {
        assertSplice(["A", "B", "C"], ["B", "C"])
    }

    func testDeleteLastParagraph() {
        assertSplice(["A", "B", "C"], ["A", "B"])
    }

    func testDeleteMultiple() {
        assertSplice(["A", "B", "C", "D", "E"], ["A", "E"])
    }

    func testReplaceEverything() {
        assertSplice(["A", "B"], ["X", "Y", "Z"])
    }

    func testEmptyParagraphs() {
        // Blank lines are empty paragraphs — heavily present in screenplays.
        assertSplice(["A", "", "B"], ["A", "", "X", "", "B"])
        assertSplice(["", "", ""], ["", ""])
        assertSplice([""], ["A"])
        assertSplice(["A"], [""])
    }

    func testAmbiguousRepeatedParagraphs() {
        // Repeated identical paragraphs: any valid splice must still
        // transform old→new even when prefix/suffix overlap is ambiguous.
        assertSplice(["A", "A", "A"], ["A", "A"])
        assertSplice(["A", "A"], ["A", "A", "A"])
        assertSplice(["", "A", ""], ["", "A", "", "A", ""])
    }

    func testStyleOnlyChangeProducesSplice() {
        // ⌃1–6: same text, different element type → must NOT be nil.
        let old = para(["ALICE", "Hello"], styles: [3, 5])
        let new = para(["ALICE", "Hello"], styles: [1, 5])
        let splice = ParagraphDiff.splice(old: old, new: new)
        XCTAssertNotNil(splice, "Type-only changes must re-render the paragraph")
        XCTAssertEqual(splice?.newParagraphs, 0..<1, "Only the retyped paragraph is spliced")
        XCTAssertEqual(apply(splice!, to: old, new: new), "ALICE\nHello")
    }

    func testUTF16OffsetsWithNonASCII() {
        // Emoji and Malayalam text: ranges are UTF-16, not character counts.
        assertSplice(["നമസ്കാരം 🎬", "B", "C"], ["നമസ്കാരം 🎬", "X", "C"])
        assertSplice(["A🎥B", "C"], ["A🎥B", "🎞", "C"])
    }

    func testReturnKeySplitShape() {
        // What handleReturn actually does: paragraph i splits into two.
        assertSplice(["INT. OFFICE - DAY", "Alice enters and waves.", ""],
                     ["INT. OFFICE - DAY", "Alice enters", "and waves.", ""])
    }

    func testBackspaceMergeShape() {
        // What handleBackspace does: two paragraphs merge into one.
        assertSplice(["A", "Bee", "cee", "D"], ["A", "Beecee", "D"])
    }
}

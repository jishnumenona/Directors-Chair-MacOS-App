//
//  ParagraphDiff.swift
//  DirectorsChair-Desktop
//
//  Perf Tier 1.3 (audit B1): minimal-splice diff between the paragraphs the
//  NSTextView currently shows and the paragraphs the model wants. The editor
//  document is paragraphs joined by "\n" (no trailing newline); any single
//  structural edit touches a small contiguous window, so common-prefix /
//  common-suffix trimming reduces a full O(document) setAttributedString +
//  relayout to one targeted replaceCharacters call.
//
//  Pure and unit-tested: all range math lives here; the coordinator only
//  applies the result.
//

import Foundation

enum ParagraphDiff {

    /// One paragraph as the diff sees it: display text plus a style key —
    /// type-only changes (⌃1–6) alter attributes with identical text, so
    /// equality must include styling.
    struct Paragraph: Equatable {
        let text: String
        let style: Int

        init(text: String, style: Int = 0) {
            self.text = text
            self.style = style
        }
    }

    /// The splice to apply: replace `range` (UTF-16, in the old document)
    /// with the new paragraphs at `newParagraphs` (indices into the new
    /// array), joined by "\n", with optional boundary separators.
    struct Splice: Equatable {
        let range: NSRange
        let newParagraphs: Range<Int>
        let leadingSeparator: Bool
        let trailingSeparator: Bool
    }

    /// nil means the documents are identical (text AND style).
    static func splice(old: [Paragraph], new: [Paragraph]) -> Splice? {
        guard !old.isEmpty, !new.isEmpty else {
            // A document always has ≥1 paragraph (empty doc == [""]).
            // Degenerate inputs → treat as full replacement.
            return Splice(range: NSRange(location: 0, length: totalLength(old)),
                          newParagraphs: 0..<new.count,
                          leadingSeparator: false, trailingSeparator: false)
        }

        var p = 0
        let maxCommon = min(old.count, new.count)
        while p < maxCommon, old[p] == new[p] { p += 1 }

        var s = 0
        while s < maxCommon - p, old[old.count - 1 - s] == new[new.count - 1 - s] { s += 1 }

        let oldMid = p..<(old.count - s)
        let newMid = p..<(new.count - s)

        if oldMid.isEmpty && newMid.isEmpty { return nil }

        // Paragraph start offsets in the old document (UTF-16).
        var starts: [Int] = []
        starts.reserveCapacity(old.count)
        var acc = 0
        for para in old {
            starts.append(acc)
            acc += para.text.utf16.count + 1  // +1 for the "\n" separator
        }
        let docLength = acc - 1  // no trailing newline

        if !oldMid.isEmpty {
            // Replace the old middle block (excluding its trailing "\n").
            var rStart = starts[oldMid.lowerBound]
            let lastOld = oldMid.upperBound - 1
            var rEnd = starts[lastOld] + old[lastOld].text.utf16.count

            if newMid.isEmpty {
                // Pure deletion — one adjacent separator goes with it.
                if s > 0 {
                    rEnd += 1          // eat the "\n" after the block
                } else if p > 0 {
                    rStart -= 1        // eat the "\n" before the block
                }
            }
            return Splice(range: NSRange(location: rStart, length: rEnd - rStart),
                          newParagraphs: newMid,
                          leadingSeparator: false, trailingSeparator: false)
        }

        // Pure insertion at a paragraph boundary.
        if s == 0 {
            // Append after the last paragraph (p == old.count).
            return Splice(range: NSRange(location: docLength, length: 0),
                          newParagraphs: newMid,
                          leadingSeparator: true,   // separate from the prefix
                          trailingSeparator: false)
        }
        // Insert before the first suffix paragraph.
        return Splice(range: NSRange(location: starts[p], length: 0),
                      newParagraphs: newMid,
                      leadingSeparator: false,
                      trailingSeparator: true)
    }

    private static func totalLength(_ paras: [Paragraph]) -> Int {
        guard !paras.isEmpty else { return 0 }
        return paras.reduce(0) { $0 + $1.text.utf16.count } + paras.count - 1
    }
}

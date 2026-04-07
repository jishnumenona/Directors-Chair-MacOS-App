// TagPillViewSnapshotTests.swift

import XCTest
import SwiftUI
import SnapshotTesting
@testable import DirectorsChairViews

@available(macOS 14.0, *)
final class TagPillViewSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // isRecording = true  // Uncomment to record/update reference images
    }

    func testDefaultBluePill() {
        let view = TagPillView(text: "Action")
        assertCompactSnapshot(view)
    }

    func testCustomColorPill() {
        let view = TagPillView(
            text: "Drama",
            color: .red.opacity(0.2),
            textColor: .red
        )
        assertCompactSnapshot(view)
    }

    func testTagsStackViewMultipleTags() {
        let view = TagsStackView(tags: ["Action", "Drama", "Thriller", "Sci-Fi"])
        assertCompactSnapshot(view, size: CGSize(width: 400, height: 60))
    }

    func testTagsStackViewOverflow() {
        let view = TagsStackView(
            tags: ["Action", "Drama", "Thriller", "Sci-Fi", "Horror", "Comedy", "Romance"],
            maxVisible: 5
        )
        assertCompactSnapshot(view, size: CGSize(width: 400, height: 60))
    }

    func testEmptyTagsStack() {
        let view = TagsStackView(tags: [])
        assertCompactSnapshot(view, size: CGSize(width: 200, height: 40))
    }
}

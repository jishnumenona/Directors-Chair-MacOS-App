// AIGenerateButtonSnapshotTests.swift

import XCTest
import SwiftUI
import SnapshotTesting
@testable import DirectorsChairViews

@available(macOS 14.0, *)
final class AIGenerateButtonSnapshotTests: LocalOnlySnapshotTestCase {

    func testIdle() {
        let view = AIGenerateButton(
            title: "Generate",
            icon: "sparkles",
            loadingText: "Generating...",
            isLoading: false,
            action: {}
        )
        assertCompactSnapshot(view, size: CGSize(width: 250, height: 60))
    }

    func testLoadingSpinner() {
        let view = AIGenerateButton(
            title: "Generate",
            icon: "sparkles",
            loadingText: "Generating...",
            isLoading: true,
            action: {}
        )
        assertCompactSnapshot(view, size: CGSize(width: 250, height: 60))
    }

    func testLoadingWithProgress() {
        let view = AIGenerateButton(
            title: "Generate",
            icon: "sparkles",
            loadingText: "Generating...",
            isLoading: true,
            progress: 60,
            action: {}
        )
        assertCompactSnapshot(view, size: CGSize(width: 250, height: 60))
    }
}

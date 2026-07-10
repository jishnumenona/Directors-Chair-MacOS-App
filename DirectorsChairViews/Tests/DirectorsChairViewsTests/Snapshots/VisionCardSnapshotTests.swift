// VisionCardSnapshotTests.swift

import XCTest
import SwiftUI
import SnapshotTesting
@testable import DirectorsChairViews
@testable import DirectorsChairCore

@available(macOS 14.0, *)
final class VisionCardSnapshotTests: LocalOnlySnapshotTestCase {

    func testTextCard() {
        let card = TestFixtures.textVisionCard()
        let view = VisionCardItem(card: card, isSelected: false)
        assertViewSnapshot(view, size: CGSize(width: 300, height: 250))
    }

    func testImagePlaceholder() {
        // No imagePath = placeholder
        let card = TestFixtures.visionCard(title: "Reference Photo", cardType: "image")
        let view = VisionCardItem(card: card, isSelected: false)
        assertViewSnapshot(view, size: CGSize(width: 300, height: 250))
    }

    func testSelectedCard() {
        let card = TestFixtures.textVisionCard()
        let view = VisionCardItem(card: card, isSelected: true)
        assertViewSnapshot(view, size: CGSize(width: 300, height: 250))
    }

    func testColorPaletteCard() {
        var card = VisionCard(
            id: "test-palette",
            title: "Warm Tones",
            cardType: "color_palette",
            colorPalette: ["#FF6B35", "#F7C59F", "#EFEFD0", "#004E89", "#1A659E"],
            size: "medium"
        )
        let view = VisionCardItem(card: card, isSelected: false)
        assertViewSnapshot(view, size: CGSize(width: 300, height: 250))
    }

    func testSmallVsLargeZoom() {
        let card = TestFixtures.textVisionCard()
        let view = HStack(spacing: 20) {
            VisionCardItem(card: card, isSelected: false, zoomLevel: 0.5, showLabel: true)
                .frame(width: 150, height: 120)
            VisionCardItem(card: card, isSelected: false, zoomLevel: 1.5, showLabel: true)
                .frame(width: 150, height: 120)
        }
        assertViewSnapshot(view, size: CGSize(width: 400, height: 200))
    }
}

// VisionBoardFilterSnapshotTests.swift

import XCTest
import SwiftUI
import SnapshotTesting
@testable import DirectorsChairViews
@testable import DirectorsChairCore

@available(macOS 14.0, *)
final class VisionBoardFilterSnapshotTests: XCTestCase {

    func testTypeChips() {
        let types = VisionCardType.allCases
        let view = HStack(spacing: 6) {
            ForEach(Array(types.enumerated()), id: \.offset) { _, type in
                HStack(spacing: 4) {
                    Image(systemName: type.systemImage)
                        .font(.system(size: 10))
                    Text(type.displayName)
                        .font(.system(size: 10))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(nsColor: .quaternarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding()
        assertViewSnapshot(view, size: CGSize(width: 600, height: 50))
    }

    func testSelectedTypeChip() {
        let types = VisionCardType.allCases
        let selectedType = VisionCardType.image
        let view = HStack(spacing: 6) {
            ForEach(Array(types.enumerated()), id: \.offset) { _, type in
                HStack(spacing: 4) {
                    Image(systemName: type.systemImage)
                        .font(.system(size: 10))
                    Text(type.displayName)
                        .font(.system(size: 10))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(type == selectedType ? Color.accentColor : Color(nsColor: .quaternarySystemFill))
                .foregroundStyle(type == selectedType ? .white : Color(nsColor: .labelColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding()
        assertViewSnapshot(view, size: CGSize(width: 600, height: 50))
    }

    func testEmptyBoardPlaceholder() {
        let view = VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Vision Cards")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Add images, color palettes, or text cards to build your vision board.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        assertViewSnapshot(view, size: CGSize(width: 400, height: 300))
    }

    func testVisionBoardEmptyState() {
        let view = VisionBoardView(cards: [])
        assertViewSnapshot(view, size: CGSize(width: 800, height: 500))
    }

    func testVisionBoardWithCards() {
        let cards = [
            TestFixtures.textVisionCard(title: "Theme", text: "Isolation and redemption", id: "vb-1"),
            TestFixtures.visionCard(title: "Ref Image", cardType: "image", id: "vb-2"),
        ]
        let view = VisionBoardView(cards: cards)
        assertViewSnapshot(view, size: CGSize(width: 800, height: 500))
    }
}

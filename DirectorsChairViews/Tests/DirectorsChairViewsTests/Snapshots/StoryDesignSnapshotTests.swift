// StoryDesignSnapshotTests.swift

import XCTest
import SwiftUI
import SnapshotTesting
@testable import DirectorsChairViews
@testable import DirectorsChairCore

@available(macOS 14.0, *)
final class StoryDesignSnapshotTests: XCTestCase {

    func testModePickerCharacters() {
        // Test mode picker in isolation via the StoryDesignMode enum display
        let view = HStack(spacing: 8) {
            ForEach(StoryDesignMode.allCases, id: \.rawValue) { mode in
                HStack(spacing: 4) {
                    Image(systemName: mode.icon)
                    Text(mode.displayName)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(mode == .characters ? Color.accentColor : Color(nsColor: .quaternarySystemFill))
                .foregroundStyle(mode == .characters ? .white : Color(nsColor: .labelColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        assertCompactSnapshot(view, size: CGSize(width: 350, height: 60))
    }

    func testModePickerLocations() {
        let view = HStack(spacing: 8) {
            ForEach(StoryDesignMode.allCases, id: \.rawValue) { mode in
                HStack(spacing: 4) {
                    Image(systemName: mode.icon)
                    Text(mode.displayName)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(mode == .locations ? Color.accentColor : Color(nsColor: .quaternarySystemFill))
                .foregroundStyle(mode == .locations ? .white : Color(nsColor: .labelColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        assertCompactSnapshot(view, size: CGSize(width: 350, height: 60))
    }

    func testDesignTabBar() {
        let view = HStack(spacing: 4) {
            ForEach(DesignTab.allCases, id: \.self) { tab in
                VStack(spacing: 2) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 12))
                    Text(tab.displayName)
                        .font(.system(size: 9))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(tab == .physical ? Color.accentColor : Color(nsColor: .quaternarySystemFill))
                .foregroundStyle(tab == .physical ? .white : Color(nsColor: .labelColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding()
        assertViewSnapshot(view, size: CGSize(width: 500, height: 70))
    }

    func testTraitCategoryColorGrid() {
        let view = VStack(alignment: .leading, spacing: 8) {
            ForEach(TraitCategory.allCases, id: \.displayName) { category in
                HStack {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 10, height: 10)
                    Text(category.displayName)
                        .font(.system(size: 11, weight: .medium))
                    Spacer()
                    Text("\(category.traits.count) traits")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(width: 250)
        assertViewSnapshot(view, size: CGSize(width: 280, height: 200))
    }

    func testStoryDesignFullView() {
        var project = TestFixtures.project()
        let view = StoryDesignView(project: .constant(project))
        assertViewSnapshot(view, size: CGSize(width: 800, height: 600))
    }
}

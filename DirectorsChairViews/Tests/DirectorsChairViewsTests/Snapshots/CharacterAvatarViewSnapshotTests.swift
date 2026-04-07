// CharacterAvatarViewSnapshotTests.swift

import XCTest
import SwiftUI
import SnapshotTesting
@testable import DirectorsChairViews
@testable import DirectorsChairCore

@available(macOS 14.0, *)
final class CharacterAvatarViewSnapshotTests: XCTestCase {

    func testFullNameInitials() {
        let view = CharacterAvatarView(
            character: nil,
            characterName: "Jane Doe",
            size: 40
        )
        assertCompactSnapshot(view, size: CGSize(width: 80, height: 80))
    }

    func testSingleInitial() {
        let view = CharacterAvatarView(
            character: nil,
            characterName: "Jane",
            size: 40
        )
        assertCompactSnapshot(view, size: CGSize(width: 80, height: 80))
    }

    func testSmallSize() {
        let view = CharacterAvatarView(
            character: nil,
            characterName: "JD",
            size: 24
        )
        assertCompactSnapshot(view, size: CGSize(width: 60, height: 60))
    }

    func testLargeSize() {
        let view = CharacterAvatarView(
            character: nil,
            characterName: "Mark Smith",
            size: 80
        )
        assertCompactSnapshot(view, size: CGSize(width: 120, height: 120))
    }
}

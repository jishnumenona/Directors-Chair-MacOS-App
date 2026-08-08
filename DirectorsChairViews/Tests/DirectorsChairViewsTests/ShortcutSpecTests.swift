// DirectorsChairViewsTests/ShortcutSpecTests.swift
//
// The remappable-shortcut value type (§2.18). What must stay true: the
// storage form round-trips exactly (it lives in UserDefaults across app
// versions), malformed storage is nil rather than a broken menu, and the
// display string renders modifiers in macOS's canonical ⌃⌥⇧⌘ order.

import XCTest
import SwiftUI
@testable import DirectorsChairViews

final class ShortcutSpecTests: XCTestCase {

    func testStorageRoundTripsEveryModifierCombination() {
        for command in [false, true] {
            for shift in [false, true] {
                for option in [false, true] {
                    for control in [false, true] {
                        let spec = ShortcutSpec(key: "e", command: command,
                                                shift: shift, option: option,
                                                control: control)
                        XCTAssertEqual(ShortcutSpec.parse(spec.storage), spec,
                                       "storage must round-trip \(spec.storage)")
                    }
                }
            }
        }
    }

    func testMalformedStorageIsNilNotACrashOrAGuess() {
        for bad in ["", "e", ":", "cs:", "cs:ee", "q:e", "cs", "🎬:e"] {
            XCTAssertNil(ShortcutSpec.parse(bad),
                         "'\(bad)' must fall back to the shipped binding")
        }
    }

    func testDisplayUsesCanonicalModifierOrder() {
        let spec = ShortcutSpec(key: "e", command: true, shift: true,
                                option: true, control: true)
        XCTAssertEqual(spec.display, "⌃⌥⇧⌘E",
                       "macOS renders modifiers control-option-shift-command")
        XCTAssertEqual(ShortcutSpec(key: "k", command: true).display, "⌘K")
    }

    func testKeysStoreLowercasedButDisplayUppercased() {
        let spec = ShortcutSpec(key: "E", command: true)
        XCTAssertEqual(spec.key, "e")
        XCTAssertEqual(spec.display, "⌘E")
    }

    func testChordingRequiresARealModifier() {
        XCTAssertFalse(ShortcutSpec(key: "e").isChorded,
                       "a bare key is typing")
        XCTAssertFalse(ShortcutSpec(key: "e", shift: true).isChorded,
                       "shift alone is still typing — capital E")
        XCTAssertTrue(ShortcutSpec(key: "e", command: true).isChorded)
        XCTAssertTrue(ShortcutSpec(key: "e", option: true).isChorded)
        XCTAssertTrue(ShortcutSpec(key: "e", control: true).isChorded)
    }

    func testEventModifiersMapOneToOne() {
        let spec = ShortcutSpec(key: "e", command: true, option: true)
        XCTAssertTrue(spec.modifiers.contains(.command))
        XCTAssertTrue(spec.modifiers.contains(.option))
        XCTAssertFalse(spec.modifiers.contains(.shift))
        XCTAssertFalse(spec.modifiers.contains(.control))
        XCTAssertNotNil(spec.keyboardShortcut)
    }
}

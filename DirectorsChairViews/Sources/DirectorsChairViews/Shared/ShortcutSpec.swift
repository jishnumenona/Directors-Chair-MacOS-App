// DirectorsChairViews/Sources/DirectorsChairViews/Shared/ShortcutSpec.swift
//
// User-remappable shortcuts (backlog §2.18) — the value type.
//
// A shortcut is a character key plus modifiers, storable in UserDefaults,
// printable the way macOS prints it (⌃⌥⇧⌘E, in that canonical order),
// and convertible to SwiftUI's KeyboardShortcut for the Commands tree.
// The app-side ShortcutStore owns WHICH commands are rebindable and what
// their defaults are; this file owns what a shortcut IS — kept in the
// package where new files compile and unit tests live close.

import SwiftUI

public struct ShortcutSpec: Equatable, Sendable {
    /// Single lowercase character ("e", "1"). Function and arrow keys are
    /// deliberately out of scope for v1 — character keys cover every
    /// binding the app ships.
    public var key: String
    public var command: Bool
    public var shift: Bool
    public var option: Bool
    public var control: Bool

    public init(key: String, command: Bool = false, shift: Bool = false,
                option: Bool = false, control: Bool = false) {
        self.key = key.lowercased()
        self.command = command
        self.shift = shift
        self.option = option
        self.control = control
    }

    // MARK: - Storage ("cso:e" — modifier letters, colon, key)

    /// Compact, human-auditable defaults-file form. Letters appear in
    /// canonical order: t (control), o (option), s (shift), c (command).
    public var storage: String {
        var letters = ""
        if control { letters += "t" }
        if option { letters += "o" }
        if shift { letters += "s" }
        if command { letters += "c" }
        return letters + ":" + key
    }

    /// nil for anything malformed — a corrupted default falls back to the
    /// shipped binding rather than producing a broken menu.
    public static func parse(_ stored: String) -> ShortcutSpec? {
        let parts = stored.split(separator: ":", maxSplits: 1,
                                 omittingEmptySubsequences: false)
        guard parts.count == 2, parts[1].count == 1 else { return nil }
        let letters = Set(parts[0])
        guard letters.isSubset(of: ["t", "o", "s", "c"]) else { return nil }
        return ShortcutSpec(key: String(parts[1]),
                            command: letters.contains("c"),
                            shift: letters.contains("s"),
                            option: letters.contains("o"),
                            control: letters.contains("t"))
    }

    // MARK: - Presentation

    /// The way macOS renders it in menus: ⌃⌥⇧⌘ then the key, uppercased.
    public var display: String {
        var text = ""
        if control { text += "⌃" }
        if option { text += "⌥" }
        if shift { text += "⇧" }
        if command { text += "⌘" }
        return text + key.uppercased()
    }

    // MARK: - SwiftUI

    public var modifiers: EventModifiers {
        var mods: EventModifiers = []
        if command { mods.insert(.command) }
        if shift { mods.insert(.shift) }
        if option { mods.insert(.option) }
        if control { mods.insert(.control) }
        return mods
    }

    public var keyboardShortcut: KeyboardShortcut? {
        guard let character = key.first else { return nil }
        return KeyboardShortcut(KeyEquivalent(character),
                                modifiers: modifiers)
    }

    /// A bare key or shift-key is typing, not a command — every binding
    /// must carry at least one chording modifier.
    public var isChorded: Bool {
        command || option || control
    }
}

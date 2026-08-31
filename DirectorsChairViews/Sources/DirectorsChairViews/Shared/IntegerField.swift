//
//  IntegerField.swift
//  DirectorsChairViews
//
//  A text field for a whole number that behaves like a text field. Binding a
//  TextField straight to an Int with `format: .number` re-renders the parent
//  on every keystroke and pushes the stored value back into the field, so
//  "30" could not be cleared and stuck at "3" (owner report, 2026-08-29).
//  Here the text is the user's; the number is committed whenever the text is
//  a whole number in range, an empty or partial entry stays as typed while
//  editing, and the field re-syncs from the model when the value changes
//  elsewhere or when editing ends.
//

import SwiftUI

public struct IntegerField: View {
    @Binding private var value: Int
    private let range: ClosedRange<Int>
    private let placeholder: String

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    public init(_ placeholder: String = "", value: Binding<Int>, in range: ClosedRange<Int> = 0...9_999) {
        self.placeholder = placeholder
        self._value = value
        self.range = range
    }

    /// Digits only — what the field lets through.
    static func sanitized(_ text: String) -> String {
        String(text.filter(\.isNumber))
    }

    /// The number the text commits, or nil while it is empty, partial or out
    /// of range (the field keeps showing it; the model keeps its value).
    static func accepted(_ text: String, in range: ClosedRange<Int>) -> Int? {
        guard let number = Int(text), range.contains(number) else { return nil }
        return number
    }

    public var body: some View {
        TextField(placeholder, text: $text)
            .focused($isFocused)
            .onAppear { text = String(value) }
            .onChange(of: text) { _, typed in
                let clean = Self.sanitized(typed)
                if clean != typed { text = clean; return }
                if let number = Self.accepted(clean, in: range), number != value { value = number }
            }
            .onChange(of: value) { _, changed in
                // Changed elsewhere (another tab, undo, the assistant): show it —
                // unless it is exactly what this field already says.
                if Int(text) != changed { text = String(changed) }
            }
            .onChange(of: isFocused) { _, focused in
                // Editing ended on an empty or unaccepted entry: show the model's value.
                if !focused { text = String(value) }
            }
    }
}

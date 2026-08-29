//
//  DecimalField.swift
//  DirectorsChairViews
//
//  The decimal sibling of IntegerField (see there for the why): a text field
//  for a number with a fractional part that never snaps back while editing.
//  Digits and one decimal point get through; a number in range commits as
//  typed; an empty entry commits "not set" when the value is optional and
//  nothing otherwise; the field re-syncs from the model when the value
//  changes elsewhere or when editing ends.
//

import SwiftUI

public struct DecimalField: View {
    @Binding private var value: Double?
    private let range: ClosedRange<Double>
    private let placeholder: String
    private let allowsEmpty: Bool

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    /// An optional number: clearing the field sets it to nil.
    public init(_ placeholder: String = "", optionalValue: Binding<Double?>, in range: ClosedRange<Double>) {
        self.placeholder = placeholder
        self._value = optionalValue
        self.range = range
        self.allowsEmpty = true
    }

    /// A required number: clearing the field leaves the value as it was.
    public init(_ placeholder: String = "", value: Binding<Double>, in range: ClosedRange<Double>) {
        self.placeholder = placeholder
        self._value = Binding(get: { value.wrappedValue },
                              set: { if let number = $0 { value.wrappedValue = number } })
        self.range = range
        self.allowsEmpty = false
    }

    /// Digits and at most one decimal point (a comma counts as a point).
    static func sanitized(_ text: String) -> String {
        var out = ""
        var sawPoint = false
        for ch in text {
            if ch.isNumber { out.append(ch) }
            else if (ch == "." || ch == ","), !sawPoint { out.append("."); sawPoint = true }
        }
        return out
    }

    /// The number the text commits, or nil while empty, partial or out of range.
    static func accepted(_ text: String, in range: ClosedRange<Double>) -> Double? {
        guard !text.isEmpty, text != ".", let number = Double(text), range.contains(number) else { return nil }
        return number
    }

    /// How a model value is shown: no trailing ".0", nothing for "not set".
    static func display(_ value: Double?) -> String {
        guard let value else { return "" }
        if value == value.rounded(), abs(value) < 1e15 { return String(Int(value)) }
        var s = String(format: "%.3f", value)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }

    public var body: some View {
        TextField(placeholder, text: $text)
            .focused($isFocused)
            .onAppear { text = Self.display(value) }
            .onChange(of: text) { _, typed in
                let clean = Self.sanitized(typed)
                if clean != typed { text = clean; return }
                if clean.isEmpty {
                    if allowsEmpty, value != nil { value = nil }
                    return
                }
                if let number = Self.accepted(clean, in: range), number != value { value = number }
            }
            .onChange(of: value) { _, changed in
                let shown = Self.accepted(text, in: range)
                if shown != changed && !(text.isEmpty && changed == nil) { text = Self.display(changed) }
            }
            .onChange(of: isFocused) { _, focused in
                if !focused { text = Self.display(value) }
            }
    }
}

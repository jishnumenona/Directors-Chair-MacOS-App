//
// OutlineTab+Reorder.swift
//
// Right-click reordering for the navigator (PR 1). Shared UI: a context-menu
// section (Move Up/Down/Top/Bottom + Move to Position…) and the position-entry
// alert. The actual mutation goes through ProjectViewModel's move* methods
// (backed by the pure Project+Reorder model), and the caller fires the
// `.structure`/`.shots` event so screenplay, timeline and bubble reflect it.
//
// Drag-and-drop is PR 2; the model already supports it.
//

import SwiftUI

/// The reusable "reorder" block for a row's context menu. `position` is 1-based.
@ViewBuilder
func reorderMenuSection(
    position: Int,
    count: Int,
    moveUp: @escaping () -> Void,
    moveDown: @escaping () -> Void,
    moveToTop: @escaping () -> Void,
    moveToBottom: @escaping () -> Void,
    moveToPosition: @escaping () -> Void
) -> some View {
    let canMoveUp = position > 1
    let canMoveDown = position < count

    Button(action: moveUp) { Label("Move Up", systemImage: "arrow.up") }
        .disabled(!canMoveUp)
    Button(action: moveDown) { Label("Move Down", systemImage: "arrow.down") }
        .disabled(!canMoveDown)
    Button(action: moveToTop) { Label("Move to Top", systemImage: "arrow.up.to.line") }
        .disabled(!canMoveUp)
    Button(action: moveToBottom) { Label("Move to Bottom", systemImage: "arrow.down.to.line") }
        .disabled(!canMoveDown)
    if count > 1 {
        Button(action: moveToPosition) { Label("Move to Position…", systemImage: "number") }
    }
}

/// A number-entry alert that renumbers an item to a specific 1-based position.
/// `onMove` receives the resulting 0-based target index.
struct MoveToPositionAlert: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var text: String
    let count: Int
    let noun: String            // "sequence" / "scene" / "shot"
    let onMove: (Int) -> Void

    func body(content: Content) -> some View {
        content.alert("Move \(noun) to position", isPresented: $isPresented) {
            TextField("Position (1–\(count))", text: $text)
            Button("Move") {
                if let n = Int(text.trimmingCharacters(in: .whitespaces)), n >= 1, n <= count {
                    onMove(n - 1)
                }
                text = ""
            }
            Button("Cancel", role: .cancel) { text = "" }
        } message: {
            Text("Enter a number from 1 to \(count).")
        }
    }
}

extension View {
    func moveToPositionAlert(
        isPresented: Binding<Bool>,
        text: Binding<String>,
        count: Int,
        noun: String,
        onMove: @escaping (Int) -> Void
    ) -> some View {
        modifier(MoveToPositionAlert(isPresented: isPresented, text: text,
                                     count: count, noun: noun, onMove: onMove))
    }
}

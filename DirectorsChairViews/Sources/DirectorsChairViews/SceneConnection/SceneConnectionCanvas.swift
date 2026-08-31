// DirectorsChairViews/Sources/DirectorsChairViews/SceneConnection/SceneConnectionCanvas.swift
//
// Canvas center area: grid background, tap-to-deselect, and the per-connection
// hit bands (hover, click-to-select, × at the midpoint, right-click, ⌫).
// Visual connection lines and the × glyph are drawn as a full-width overlay
// in SceneConnectionView; this layer only decides what the pointer is on.

import SwiftUI

// MARK: - Scene Connection Canvas

public struct SceneConnectionCanvas: View {
    // MARK: - Properties

    @ObservedObject var viewModel: SceneConnectionViewModel

    // MARK: - State

    @State private var canvasOrigin: CGPoint = .zero

    /// The canvas must hold focus or ⌫ never reaches it — .focusable() alone
    /// doesn't make a view first responder (same pattern as the Vision wall).
    @FocusState private var canvasFocused: Bool

    // MARK: - Body

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                SceneConnectionColors.canvasBackground
                    .ignoresSafeArea()

                // Grid pattern (subtle)
                gridPattern(in: geometry.size)

                // Invisible hit bands for connection selection / removal
                // (center column only — a band stops short of the port dots)
                ForEach(viewModel.connections) { connection in
                    connectionHitArea(for: connection, in: geometry.size)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.clearSelection()
                canvasFocused = true
            }
            .focusable()
            .focusEffectDisabled()
            .focused($canvasFocused)
            .onKeyPress(.delete) { deleteSelectedConnection() }
            .onKeyPress(.deleteForward) { deleteSelectedConnection() }
            .accessibilityIdentifier("connections-canvas")
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            canvasOrigin = geo.frame(in: .named("sceneConnections")).origin
                        }
                        .onChange(of: geo.frame(in: .named("sceneConnections")).origin) { _, newOrigin in
                            canvasOrigin = newOrigin
                        }
                }
            )
        }
    }

    // MARK: - Coordinate Conversion

    /// Convert global coordinates to canvas-local coordinates
    private func toLocal(_ globalPoint: CGPoint) -> CGPoint {
        CGPoint(
            x: globalPoint.x - canvasOrigin.x,
            y: globalPoint.y - canvasOrigin.y
        )
    }

    // MARK: - Grid Pattern

    @ViewBuilder
    private func gridPattern(in size: CGSize) -> some View {
        Canvas { context, canvasSize in
            let gridSpacing: CGFloat = 40
            let lineColor = Color.white.opacity(0.03)

            // Vertical lines
            var x: CGFloat = 0
            while x < canvasSize.width {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: canvasSize.height))
                context.stroke(path, with: .color(lineColor), lineWidth: 1)
                x += gridSpacing
            }

            // Horizontal lines
            var y: CGFloat = 0
            while y < canvasSize.height {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: canvasSize.width, y: y))
                context.stroke(path, with: .color(lineColor), lineWidth: 1)
                y += gridSpacing
            }
        }
    }

    // MARK: - Connection Hit Area

    /// One invisible, interactive band per connection: hovering lights the
    /// line up and shows its ×, a click selects it, a click on the × removes
    /// it, right-click offers removal. The band is clipped to the canvas so
    /// the port dots in the side columns stay draggable.
    @ViewBuilder
    private func connectionHitArea(for connection: ScriptConnection, in size: CGSize) -> some View {
        let sourceKey = "script-\(connection.scriptItemId)"
        let targetKey = "shot-\(connection.itemType.rawValue.lowercased())-\(connection.shotId)"

        if let sourceGlobal = viewModel.portPositions[sourceKey],
           let targetGlobal = viewModel.portPositions[targetKey] {

            let sourcePoint = toLocal(sourceGlobal)
            let targetPoint = toLocal(targetGlobal)
            let bounds = CGRect(origin: .zero, size: size)
            let midpoint = ConnectionGeometry.midpoint(from: sourcePoint, to: targetPoint)
            let hitPath = ConnectionGeometry.hitPath(from: sourcePoint, to: targetPoint, within: bounds)
            let isSelected = viewModel.selectedConnection?.id == connection.id
            let isHovered = viewModel.hoveredConnectionId == connection.id
            let showsGlyph = (isSelected || isHovered) && bounds.contains(midpoint)

            Color.clear
                .contentShape(hitPath)
                .onContinuousHover(coordinateSpace: .local) { phase in
                    switch phase {
                    case .active(let location):
                        // Publish only on enter and on crossing the × edge —
                        // never per pointer tick.
                        if viewModel.hoveredConnectionId != connection.id {
                            viewModel.hoveredConnectionId = connection.id
                        }
                        let onGlyph = ConnectionGeometry.isOnRemoveGlyph(location, midpoint: midpoint)
                        if viewModel.isPointerOnRemoveGlyph != onGlyph {
                            viewModel.isPointerOnRemoveGlyph = onGlyph
                        }
                    case .ended:
                        if viewModel.hoveredConnectionId == connection.id {
                            viewModel.hoveredConnectionId = nil
                            viewModel.isPointerOnRemoveGlyph = false
                        }
                    }
                }
                .onTapGesture(coordinateSpace: .local) { location in
                    if ConnectionGeometry.isOnRemoveGlyph(location, midpoint: midpoint) {
                        viewModel.removeConnection(connection)
                    } else {
                        viewModel.selectConnection(connection)
                        canvasFocused = true
                    }
                }
                .contextMenu {
                    Text(connectionTitle(connection))
                    Divider()
                    Button {
                        viewModel.removeConnection(connection)
                    } label: {
                        Label("Remove Connection", systemImage: "xmark")
                    }
                    .accessibilityIdentifier("connection-remove-menu-\(connection.id)")
                }
                .overlay(alignment: .topLeading) {
                    if showsGlyph {
                        // Assistive anchor for the × the overlay draws here —
                        // pointer events fall through to the band's tap handler.
                        Color.clear
                            .frame(width: SceneConnectionConstants.connectionRemoveHitSize,
                                   height: SceneConnectionConstants.connectionRemoveHitSize)
                            .position(midpoint)
                            .allowsHitTesting(false)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Remove connection")
                            .accessibilityAddTraits(.isButton)
                            .accessibilityIdentifier("connection-remove-\(connection.id)")
                            .accessibilityAction { viewModel.removeConnection(connection) }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(connectionTitle(connection))
                .accessibilityIdentifier("connection-line-\(connection.id)")
                .accessibilityAction(named: "Remove connection") {
                    viewModel.removeConnection(connection)
                }
        }
    }

    /// "Dialogue #2 → Shot 3" — context-menu header and accessibility label.
    private func connectionTitle(_ connection: ScriptConnection) -> String {
        let itemLabel: String
        if let item = viewModel.scriptItem(withId: connection.scriptItemId) {
            itemLabel = "\(item.itemType.label) #\(item.chronologyNumber)"
        } else {
            itemLabel = connection.itemType.label
        }
        let shotLabel = viewModel.shot(withId: connection.shotId).map { "Shot \($0.shotId)" } ?? "Shot"
        return "\(itemLabel) → \(shotLabel)"
    }

    // MARK: - Keyboard

    /// ⌫ / ⌦ on the focused canvas removes the selected connection; with
    /// nothing selected the key falls through to whoever else wants it.
    private func deleteSelectedConnection() -> KeyPress.Result {
        guard viewModel.selectedConnection != nil else { return .ignored }
        viewModel.deleteSelectedConnection()
        return .handled
    }
}

// MARK: - Preview

#if DEBUG
struct SceneConnectionCanvas_Previews: PreviewProvider {
    static var previews: some View {
        SceneConnectionCanvas(viewModel: SceneConnectionViewModel())
            .frame(width: 600, height: 400)
            .previewLayout(.sizeThatFits)
    }
}
#endif

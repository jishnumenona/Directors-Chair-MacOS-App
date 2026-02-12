// DirectorsChairViews/Sources/DirectorsChairViews/SceneConnection/SceneConnectionCanvas.swift
//
// Canvas center area: grid background, tap-to-deselect, and connection hit areas
// Visual connection lines are drawn as a full-width overlay in SceneConnectionView

import SwiftUI

// MARK: - Scene Connection Canvas

public struct SceneConnectionCanvas: View {
    // MARK: - Properties

    @ObservedObject var viewModel: SceneConnectionViewModel

    // MARK: - State

    @State private var hoveredConnectionId: String?
    @State private var canvasOrigin: CGPoint = .zero

    // MARK: - Body

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                SceneConnectionColors.canvasBackground
                    .ignoresSafeArea()

                // Grid pattern (subtle)
                gridPattern(in: geometry.size)

                // Invisible hit areas for connection selection (center column only)
                ForEach(viewModel.connections) { connection in
                    connectionHitArea(for: connection)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.clearSelection()
            }
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            canvasOrigin = geo.frame(in: .named("sceneConnections")).origin
                        }
                        .onChange(of: geo.frame(in: .named("sceneConnections")).origin) { newOrigin in
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

    // MARK: - Bezier Path

    private func bezierPath(from start: CGPoint, to end: CGPoint) -> Path {
        Path { path in
            path.move(to: start)

            let distance = abs(end.x - start.x)
            let controlOffset = min(SceneConnectionConstants.maxControlOffset,
                                    max(50, distance * SceneConnectionConstants.bezierControlFactor))

            let control1 = CGPoint(x: start.x + controlOffset, y: start.y)
            let control2 = CGPoint(x: end.x - controlOffset, y: end.y)

            path.addCurve(to: end, control1: control1, control2: control2)
        }
    }

    // MARK: - Connection Hit Area

    @ViewBuilder
    private func connectionHitArea(for connection: ScriptConnection) -> some View {
        let sourceKey = "script-\(connection.scriptItemId)"
        let targetKey = "shot-\(connection.itemType.rawValue.lowercased())-\(connection.shotId)"

        if let sourceGlobal = viewModel.portPositions[sourceKey],
           let targetGlobal = viewModel.portPositions[targetKey] {

            let sourcePoint = toLocal(sourceGlobal)
            let targetPoint = toLocal(targetGlobal)
            let path = bezierPath(from: sourcePoint, to: targetPoint)

            path
                .stroke(Color.clear, lineWidth: 20)  // Wide hit area
                .contentShape(path.strokedPath(StrokeStyle(lineWidth: 20)))
                .onHover { isHovered in
                    hoveredConnectionId = isHovered ? connection.id : nil
                }
                .onTapGesture {
                    viewModel.selectConnection(connection)
                }
                .contextMenu {
                    Button(role: .destructive) {
                        viewModel.removeConnection(connection)
                    } label: {
                        Label("Remove Connection", systemImage: "trash")
                    }
                }
        }
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

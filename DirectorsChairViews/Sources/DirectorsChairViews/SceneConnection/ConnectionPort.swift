// DirectorsChairViews/Sources/DirectorsChairViews/SceneConnection/ConnectionPort.swift
//
// Reusable circular port component for connection endpoints

import SwiftUI

// MARK: - Connection Port

public struct ConnectionPort: View {
    // MARK: - Properties

    let portId: String
    let itemType: ScriptItemType
    let isOutput: Bool  // true = output port (script item), false = input port (shot)
    let isConnected: Bool
    let isHighlighted: Bool

    var onDragStart: (() -> Void)?
    var onDragUpdate: ((CGPoint) -> Void)?
    var onDragEnd: ((CGPoint) -> Void)?

    // MARK: - State

    @State private var isHovered: Bool = false
    @State private var dragOffset: CGSize = .zero

    // MARK: - Body

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Hit area (invisible, larger for easier clicking)
                Circle()
                    .fill(Color.clear)
                    .frame(width: SceneConnectionConstants.portHitArea,
                           height: SceneConnectionConstants.portHitArea)

                // Visual port
                Circle()
                    .fill(portFillColor)
                    .frame(width: SceneConnectionConstants.portSize,
                           height: SceneConnectionConstants.portSize)
                    .overlay(
                        Circle()
                            .strokeBorder(portStrokeColor, lineWidth: isHovered || isHighlighted ? 2 : 1)
                    )
                    .scaleEffect(isHovered || isHighlighted ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: SceneConnectionConstants.portHoverDuration), value: isHovered)
                    .animation(.easeInOut(duration: SceneConnectionConstants.portHoverDuration), value: isHighlighted)
            }
            .frame(width: SceneConnectionConstants.portHitArea, height: SceneConnectionConstants.portHitArea)
            .contentShape(Circle().size(width: SceneConnectionConstants.portHitArea,
                                        height: SceneConnectionConstants.portHitArea))
            .onHover { hovering in
                isHovered = hovering
            }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .named("sceneConnections"))
                    .onChanged { value in
                        if dragOffset == .zero {
                            onDragStart?()
                        }
                        dragOffset = value.translation
                        onDragUpdate?(value.location)
                    }
                    .onEnded { value in
                        onDragEnd?(value.location)
                        dragOffset = .zero
                    }
            )
            .preference(key: PortPositionKey.self, value: [
                portId: CGPoint(
                    x: geometry.frame(in: .named("sceneConnections")).midX,
                    y: geometry.frame(in: .named("sceneConnections")).midY
                )
            ])
        }
        .frame(width: SceneConnectionConstants.portHitArea,
               height: SceneConnectionConstants.portHitArea)
    }

    // MARK: - Computed Properties

    private var portFillColor: Color {
        if isConnected || isHighlighted {
            return itemType.color
        } else if isHovered {
            return itemType.color.opacity(0.5)
        } else {
            return SceneConnectionColors.portDefault.opacity(0.3)
        }
    }

    private var portStrokeColor: Color {
        if isConnected || isHighlighted || isHovered {
            return itemType.color
        } else {
            return SceneConnectionColors.portDefault
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ConnectionPort_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 40) {
            VStack(spacing: 20) {
                Text("Dialogue").font(.caption)
                ConnectionPort(
                    portId: "test1",
                    itemType: .dialogue,
                    isOutput: true,
                    isConnected: false,
                    isHighlighted: false
                )
                ConnectionPort(
                    portId: "test2",
                    itemType: .dialogue,
                    isOutput: true,
                    isConnected: true,
                    isHighlighted: false
                )
            }

            VStack(spacing: 20) {
                Text("Action").font(.caption)
                ConnectionPort(
                    portId: "test3",
                    itemType: .action,
                    isOutput: true,
                    isConnected: false,
                    isHighlighted: false
                )
                ConnectionPort(
                    portId: "test4",
                    itemType: .action,
                    isOutput: true,
                    isConnected: true,
                    isHighlighted: false
                )
            }

            VStack(spacing: 20) {
                Text("Narration").font(.caption)
                ConnectionPort(
                    portId: "test5",
                    itemType: .narration,
                    isOutput: true,
                    isConnected: false,
                    isHighlighted: false
                )
                ConnectionPort(
                    portId: "test6",
                    itemType: .narration,
                    isOutput: true,
                    isConnected: true,
                    isHighlighted: false
                )
            }
        }
        .padding(40)
        .background(SceneConnectionColors.canvasBackground)
        .previewLayout(.sizeThatFits)
    }
}
#endif

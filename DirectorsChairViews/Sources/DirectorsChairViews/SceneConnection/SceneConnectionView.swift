// DirectorsChairViews/Sources/DirectorsChairViews/SceneConnection/SceneConnectionView.swift
//
// Main view for the Scene Connection interface
// Allows users to connect Shots to Dialogues, Actions, and Narrations

import SwiftUI
import AppKit
import DirectorsChairCore

// MARK: - Scene Connection View

public struct SceneConnectionView: View {
    // MARK: - Properties

    @StateObject private var viewModel: SceneConnectionViewModel

    /// Callback when shots change (for persistence)
    public var onShotsChanged: (([Shot]) -> Void)?

    /// Callback when a shot is double-clicked (for navigation)
    public var onShotDoubleClicked: ((Shot) -> Void)?

    /// Callback when a script item is double-clicked (for navigation to bubble view)
    public var onScriptItemDoubleClicked: ((ScriptItem) -> Void)?

    /// Characters for avatar display
    public var characters: [Character]

    /// Project base path for loading avatar images
    public var projectBasePath: URL?

    // MARK: - State

    @State private var showingDeleteAlert: Bool = false
    @State private var connectionToDelete: ScriptConnection?
    @State private var previewModeDefault: Bool = false
    @State private var isCmdHeld: Bool = false
    @State private var cmdKeyMonitor: Any? = nil

    /// Whether to show preview images on shot cards (XOR of toggle and Cmd key)
    private var showShotPreview: Bool {
        previewModeDefault != isCmdHeld
    }

    // MARK: - Initialization

    public init(
        dialogues: [Dialogue] = [],
        actions: [Action] = [],
        narrations: [Narration] = [],
        shots: [Shot] = [],
        characters: [Character] = [],
        projectBasePath: URL? = nil,
        onShotsChanged: (([Shot]) -> Void)? = nil,
        onShotDoubleClicked: ((Shot) -> Void)? = nil,
        onScriptItemDoubleClicked: ((ScriptItem) -> Void)? = nil
    ) {
        self._viewModel = StateObject(wrappedValue: SceneConnectionViewModel(
            dialogues: dialogues,
            actions: actions,
            narrations: narrations,
            shots: shots
        ))
        self.characters = characters
        self.projectBasePath = projectBasePath
        self.onShotsChanged = onShotsChanged
        self.onShotDoubleClicked = onShotDoubleClicked
        self.onScriptItemDoubleClicked = onScriptItemDoubleClicked
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbar

            Divider()

            // Main content - three column layout with connection lines overlay
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Left column - Script items
                    scriptItemsColumn
                        .frame(width: SceneConnectionConstants.scriptColumnWidth)

                    Divider()

                    // Center - Grid background
                    SceneConnectionCanvas(viewModel: viewModel)
                        .frame(minWidth: SceneConnectionConstants.canvasMinWidth)

                    Divider()

                    // Right column - Shots
                    shotsColumn
                        .frame(width: SceneConnectionConstants.shotsColumnWidth)
                }
                .coordinateSpace(name: "sceneConnections")
                .overlay {
                    // Connection lines drawn on top of everything (full-width)
                    connectionLinesOverlay
                }
            }
        }
        .background(SceneConnectionColors.canvasBackground)
        .onPreferenceChange(PortPositionKey.self) { positions in
            viewModel.updatePortPositions(positions)
        }
        .onAppear {
            viewModel.onShotsChanged = onShotsChanged
            cmdKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
                isCmdHeld = event.modifierFlags.contains(.command)
                return event
            }
        }
        .onDisappear {
            if let monitor = cmdKeyMonitor {
                NSEvent.removeMonitor(monitor)
                cmdKeyMonitor = nil
            }
        }
        .alert("Delete Connection", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let connection = connectionToDelete {
                    viewModel.removeConnection(connection)
                }
                connectionToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                connectionToDelete = nil
            }
        } message: {
            Text("Are you sure you want to remove this connection?")
        }
        .onDeleteCommand {
            viewModel.deleteSelectedConnection()
        }
    }

    // MARK: - Toolbar

    @ViewBuilder
    private var toolbar: some View {
        HStack(spacing: 16) {
            // Title
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundColor(.accentColor)
                Text("Scene Connections")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            Divider()
                .frame(height: 20)

            // Filter toggles
            filterToggles

            Spacer()

            // Connection count
            HStack(spacing: 8) {
                Image(systemName: "link")
                    .foregroundColor(.gray)
                Text("\(viewModel.connections.count) connections")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            // Shot preview toggle
            Button {
                previewModeDefault.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: previewModeDefault ? "photo.fill" : "photo")
                        .font(.caption)
                    Text("Preview")
                        .font(.caption)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(previewModeDefault ? Color.accentColor.opacity(0.2) : Color.clear)
                .foregroundColor(previewModeDefault ? .accentColor : .gray)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(previewModeDefault ? Color.accentColor.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help(previewModeDefault ? "Showing previews by default (hold ⌘ for details)" : "Hold ⌘ to show shot previews")

            // Help button
            Button {
                // Show help
            } label: {
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
            .help("Drag from script items to shots to create connections")
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(SceneConnectionColors.sidebarBackground)
    }

    // MARK: - Filter Toggles

    @ViewBuilder
    private var filterToggles: some View {
        HStack(spacing: 8) {
            filterToggle(
                label: "Dialogues",
                icon: ScriptItemType.dialogue.icon,
                color: ScriptItemType.dialogue.color,
                isOn: $viewModel.showDialogues
            )

            filterToggle(
                label: "Actions",
                icon: ScriptItemType.action.icon,
                color: ScriptItemType.action.color,
                isOn: $viewModel.showActions
            )

            filterToggle(
                label: "Narrations",
                icon: ScriptItemType.narration.icon,
                color: ScriptItemType.narration.color,
                isOn: $viewModel.showNarrations
            )
        }
    }

    @ViewBuilder
    private func filterToggle(label: String, icon: String, color: Color, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(label)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(isOn.wrappedValue ? color.opacity(0.2) : Color.clear)
            .foregroundColor(isOn.wrappedValue ? color : .gray)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isOn.wrappedValue ? color.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Script Items Column

    @ViewBuilder
    private var scriptItemsColumn: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Script Items")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)

                Spacer()

                Text("\(viewModel.groupedScriptEntries.count)")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(4)
            }
            .padding(.horizontal, SceneConnectionConstants.cardPadding)
            .padding(.vertical, 10)

            Divider()

            // Script items list (grouped)
            if viewModel.groupedScriptEntries.isEmpty {
                emptyScriptItemsState
            } else {
                ScrollView {
                    VStack(spacing: SceneConnectionConstants.cardSpacing) {
                        ForEach(viewModel.groupedScriptEntries) { entry in
                            switch entry {
                            case .group(let group):
                                ScriptItemGroupCard(
                                    group: group,
                                    isSelected: viewModel.selectedScriptItemId == group.dialogue.id,
                                    connectedShotIds: viewModel.connectedShotIds(for: group.dialogue.id),
                                    character: group.dialogue.subtitle.flatMap { character(forName: $0) },
                                    projectBasePath: projectBasePath,
                                    onSelect: {
                                        viewModel.selectScriptItem(group.dialogue.id)
                                    },
                                    onDoubleClick: {
                                        onScriptItemDoubleClicked?(group.dialogue)
                                    },
                                    onDragStart: {
                                        viewModel.startDrag(fromScriptItem: group.dialogue.id, itemType: .dialogue)
                                    },
                                    onDragUpdate: { position in
                                        viewModel.updateDragPosition(position)
                                    },
                                    onDragEnd: { position in
                                        viewModel.endDrag(at: position)
                                    }
                                )

                            case .standalone(let item):
                                ScriptItemCard(
                                    item: item,
                                    isSelected: viewModel.selectedScriptItemId == item.id,
                                    connectedShotIds: viewModel.connectedShotIds(for: item.id),
                                    character: item.subtitle.flatMap { character(forName: $0) },
                                    projectBasePath: projectBasePath,
                                    onSelect: {
                                        viewModel.selectScriptItem(item.id)
                                    },
                                    onDoubleClick: {
                                        onScriptItemDoubleClicked?(item)
                                    },
                                    onDragStart: {
                                        viewModel.startDrag(fromScriptItem: item.id, itemType: item.itemType)
                                    },
                                    onDragUpdate: { position in
                                        viewModel.updateDragPosition(position)
                                    },
                                    onDragEnd: { position in
                                        viewModel.endDrag(at: position)
                                    }
                                )
                            }
                        }
                    }
                    .padding(SceneConnectionConstants.cardPadding)
                }
            }
        }
        .background(SceneConnectionColors.sidebarBackground)
    }

    @ViewBuilder
    private var emptyScriptItemsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 32))
                .foregroundColor(.gray)

            Text("No script items")
                .font(.caption)
                .foregroundColor(.gray)

            Text("Add dialogues, actions, or narrations to your scene")
                .font(.caption2)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Shots Column

    @ViewBuilder
    private var shotsColumn: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Shots")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)

                Spacer()

                Text("\(viewModel.shots.count)")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(4)
            }
            .padding(.horizontal, SceneConnectionConstants.cardPadding)
            .padding(.vertical, 10)

            Divider()

            // Shots list
            if viewModel.shots.isEmpty {
                emptyShotsState
            } else {
                ScrollView {
                    VStack(spacing: SceneConnectionConstants.cardSpacing) {
                        ForEach(viewModel.shots) { shot in
                            let counts = viewModel.connectionCounts(for: shot.id)

                            ShotConnectionCard(
                                shot: shot,
                                isSelected: viewModel.selectedShotId == shot.id,
                                isHighlighted: viewModel.isShotConnectedToSelectedItem(shot.id),
                                connectedDialogueCount: counts.dialogues,
                                connectedActionCount: counts.actions,
                                connectedNarrationCount: counts.narrations,
                                highlightedItemType: highlightedTypeForShot(shot.id),
                                showPreviewImage: showShotPreview,
                                projectBasePath: projectBasePath,
                                onSelect: {
                                    viewModel.selectShot(shot.id)
                                },
                                onDoubleClick: {
                                    onShotDoubleClicked?(shot)
                                }
                            )
                        }
                    }
                    .padding(SceneConnectionConstants.cardPadding)
                }
            }
        }
        .background(SceneConnectionColors.sidebarBackground)
    }

    @ViewBuilder
    private var emptyShotsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "film")
                .font(.system(size: 32))
                .foregroundColor(.gray)

            Text("No shots")
                .font(.caption)
                .foregroundColor(.gray)

            Text("Add shots in Shot List mode first")
                .font(.caption2)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Helpers

    /// Look up a Character by name from the characters array
    private func character(forName name: String) -> Character? {
        characters.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    private func highlightedTypeForShot(_ shotId: String) -> ScriptItemType? {
        // Highlight the port type when dragging
        if viewModel.isDragging {
            return viewModel.dragSourceType
        }

        // Highlight based on selected connection
        if let connection = viewModel.selectedConnection, connection.shotId == shotId {
            return connection.itemType
        }

        return nil
    }

    // MARK: - Connection Lines Overlay

    @ViewBuilder
    private var connectionLinesOverlay: some View {
        // Drawing canvas only — fully non-interactive so scrolling works in columns
        Canvas { context, size in
            // Draw existing connections
            for connection in viewModel.connections {
                drawConnection(connection, context: context)
            }

            // Draw drag preview line
            if viewModel.isDragging,
               let sourceId = viewModel.dragSourceId,
               let sourceType = viewModel.dragSourceType {
                drawDragPreview(sourceId: sourceId, sourceType: sourceType, context: context)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Connection Drawing

    private func isConnectionActive(_ connection: ScriptConnection) -> Bool {
        if let selectedScriptId = viewModel.selectedScriptItemId,
           connection.scriptItemId == selectedScriptId {
            return true
        }
        if let selectedShotId = viewModel.selectedShotId,
           connection.shotId == selectedShotId {
            return true
        }
        if viewModel.selectedConnection?.id == connection.id {
            return true
        }
        return false
    }

    private func drawConnection(_ connection: ScriptConnection, context: GraphicsContext) {
        let sourceKey = "script-\(connection.scriptItemId)"
        let targetKey = "shot-\(connection.itemType.rawValue.lowercased())-\(connection.shotId)"

        guard let sourcePoint = viewModel.portPositions[sourceKey],
              let targetPoint = viewModel.portPositions[targetKey] else {
            return
        }

        let isSelected = viewModel.selectedConnection?.id == connection.id
        let isActive = isConnectionActive(connection)

        let path = bezierPath(from: sourcePoint, to: targetPoint)

        let lineWidth: CGFloat = isSelected ? SceneConnectionConstants.connectionLineWidthSelected :
                                              SceneConnectionConstants.connectionLineWidth
        let opacity: Double = isActive ? SceneConnectionConstants.connectionOpacityHighlight :
                                                        SceneConnectionConstants.connectionOpacity * 0.6

        // Draw glow for selected connections
        if isSelected {
            context.stroke(
                path,
                with: .color(connection.itemType.color.opacity(0.3)),
                lineWidth: lineWidth + 4
            )
        }

        // Active connections (selected item/shot) are solid; all others are dotted
        if isActive {
            context.stroke(
                path,
                with: .color(connection.itemType.color.opacity(opacity)),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
        } else {
            context.stroke(
                path,
                with: .color(connection.itemType.color.opacity(opacity)),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: [6, 4])
            )
        }
    }

    private func drawDragPreview(sourceId: String, sourceType: ScriptItemType, context: GraphicsContext) {
        let sourceKey = "script-\(sourceId)"

        guard let sourcePoint = viewModel.portPositions[sourceKey] else { return }

        let targetPoint = viewModel.dragCurrentPosition

        let path = bezierPath(from: sourcePoint, to: targetPoint)

        // Draw dashed preview line
        context.stroke(
            path,
            with: .color(sourceType.color.opacity(0.8)),
            style: StrokeStyle(
                lineWidth: 2,
                lineCap: .round,
                dash: [8, 6]
            )
        )

        // Draw a small circle at the drag end point
        let endCircle = Path(ellipseIn: CGRect(
            x: targetPoint.x - 6,
            y: targetPoint.y - 6,
            width: 12,
            height: 12
        ))
        context.fill(endCircle, with: .color(sourceType.color.opacity(0.5)))
        context.stroke(endCircle, with: .color(sourceType.color), lineWidth: 2)
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

    // MARK: - Public Methods

    /// Update the view with new data
    public func update(
        dialogues: [Dialogue],
        actions: [Action],
        narrations: [Narration],
        shots: [Shot]
    ) {
        viewModel.updateScriptItems(dialogues: dialogues, actions: actions, narrations: narrations)
        viewModel.updateShots(shots)
    }
}

// MARK: - Preview

#if DEBUG
struct SceneConnectionView_Previews: PreviewProvider {
    static var previews: some View {
        SceneConnectionView(
            dialogues: [
                Dialogue(uuid: "d1", character: "HERO", text: "I've been waiting for this.", tags: [], costumes: [], effects: [], chronologyNumber: 1, globalChronologyNumber: 1),
                Dialogue(uuid: "d2", character: "VILLAIN", text: "Then wait no longer.", tags: [], costumes: [], effects: [], chronologyNumber: 3, globalChronologyNumber: 3)
            ],
            actions: [
                Action(uuid: "a1", description: "Hero draws sword slowly.", tags: [], costumes: [], effects: [], color: "", textColor: "", chronologyNumber: 2, globalChronologyNumber: 2, characters: [])
            ],
            narrations: [
                Narration(uuid: "n1", text: "The wind howled through the canyon.", tags: [], costumes: [], effects: [], color: "", textColor: "", chronologyNumber: 4, globalChronologyNumber: 4, characters: [])
            ],
            shots: [
                Shot(shotId: 1, description: "Close-up on Hero's face", cameraAngle: "Eye Level", lensMm: 85, shotType: "CU", linkedDialogueIds: ["d1"]),
                Shot(shotId: 2, description: "Wide establishing shot", cameraAngle: "High", lensMm: 24, shotType: "WS"),
                Shot(shotId: 3, description: "OTS of Villain", cameraAngle: "Eye Level", lensMm: 50, shotType: "OTS")
            ]
        )
        .frame(width: 1200, height: 600)
        .previewLayout(.sizeThatFits)
    }
}
#endif

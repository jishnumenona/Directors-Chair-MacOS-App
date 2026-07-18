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
    @Environment(\.undoManager) private var undoManager

    /// Scene content, stored so external edits (Bubble/Shots views) refresh an
    /// already-open canvas — the @StateObject only seeds once per identity.
    private let dialogues: [Dialogue]
    private let actions: [Action]
    private let narrations: [Narration]
    private let inputShots: [Shot]

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

    /// Deep-link highlights: when set on arrival (from Shots/Bubble/Scenes
    /// views), the canvas selects + scrolls to the target, then clears the
    /// binding (consumed). When both are set, the script item is selected so
    /// its connected shots light up, and both columns scroll into view.
    public var highlightShotId: Binding<String?>
    public var highlightScriptItemId: Binding<String?>

    // MARK: - State

    // Deletes are immediate + undoable (⌘Z) — no confirmation dialog needed.
    @State private var showingHelp: Bool = false
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
        highlightShotId: Binding<String?> = .constant(nil),
        highlightScriptItemId: Binding<String?> = .constant(nil),
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
        self.dialogues = dialogues
        self.actions = actions
        self.narrations = narrations
        self.inputShots = shots
        self.characters = characters
        self.projectBasePath = projectBasePath
        self.highlightShotId = highlightShotId
        self.highlightScriptItemId = highlightScriptItemId
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
        .onPreferenceChange(ShotCardFrameKey.self) { frames in
            viewModel.updateCardFrames(frames)
        }
        .onAppear {
            viewModel.onShotsChanged = onShotsChanged
            viewModel.undoManager = undoManager
            cmdKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
                isCmdHeld = event.modifierFlags.contains(.command)
                return event
            }
        }
        .onChange(of: undoManager) { _, newValue in
            viewModel.undoManager = newValue
        }
        // Freshness: edits made in the Bubble/Shots views propagate into an
        // already-open canvas (the @StateObject only seeds once per identity).
        .onChange(of: dialogues) { _, newValue in
            viewModel.refresh(dialogues: newValue, actions: actions,
                              narrations: narrations, shots: inputShots)
        }
        .onChange(of: actions) { _, newValue in
            viewModel.refresh(dialogues: dialogues, actions: newValue,
                              narrations: narrations, shots: inputShots)
        }
        .onChange(of: narrations) { _, newValue in
            viewModel.refresh(dialogues: dialogues, actions: actions,
                              narrations: newValue, shots: inputShots)
        }
        .onChange(of: inputShots) { _, newValue in
            // Skip round-trips of our own edits — the ViewModel is already
            // ahead of the host during in-canvas mutations.
            guard newValue != viewModel.shots.sorted(by: { $0.shotId < $1.shotId }) else { return }
            viewModel.refresh(dialogues: dialogues, actions: actions,
                              narrations: narrations, shots: newValue)
        }
        .onDisappear {
            if let monitor = cmdKeyMonitor {
                NSEvent.removeMonitor(monitor)
                cmdKeyMonitor = nil
            }
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
                showingHelp.toggle()
            } label: {
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
            .help("How linking works")
            .popover(isPresented: $showingHelp, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Linking script to shots")
                        .font(.system(size: 12, weight: .semibold))
                    Label("Drag from a port dot onto a shot — anywhere on the card works", systemImage: "hand.draw")
                    Label("Or right-click an item → Connect to Shot", systemImage: "contextualmenu.and.cursorarrow")
                    Label("Click a line to select it; ⌫ removes it", systemImage: "scissors")
                    Label("⌘Z undoes any link change", systemImage: "arrow.uturn.backward")
                    Label("Click an item to light up the shots covering it", systemImage: "rays")
                }
                .font(.system(size: 11))
                .padding(14)
                .frame(width: 320)
            }
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
                ScrollViewReader { proxy in
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
                                    },
                                    connectTargetsProvider: { shotConnectTargets(for: group.dialogue.id, itemType: .dialogue) },
                                    onToggleConnect: { target in
                                        viewModel.toggleConnection(scriptItemId: group.dialogue.id,
                                                                   shotId: target.id, itemType: .dialogue)
                                    }
                                )
                                .id("item-\(group.dialogue.id)")

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
                                    },
                                    connectTargetsProvider: { shotConnectTargets(for: item.id, itemType: item.itemType) },
                                    onToggleConnect: { target in
                                        viewModel.toggleConnection(scriptItemId: item.id,
                                                                   shotId: target.id, itemType: item.itemType)
                                    }
                                )
                                .id("item-\(item.id)")
                            }
                        }
                    }
                    .padding(SceneConnectionConstants.cardPadding)
                }
                .onAppear { applyScriptItemHighlight(proxy) }
                .onChange(of: highlightScriptItemId.wrappedValue) { _, _ in
                    applyScriptItemHighlight(proxy)
                }
                }
            }
        }
        .background(SceneConnectionColors.sidebarBackground)
    }

    /// Consume a script-item deep-link: select it (its connected shots light
    /// up), scroll it into view, then clear the binding.
    private func applyScriptItemHighlight(_ proxy: ScrollViewProxy) {
        guard let itemId = highlightScriptItemId.wrappedValue else { return }
        viewModel.selectScriptItem(itemId)
        withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo("item-\(itemId)", anchor: .center)
        }
        DispatchQueue.main.async { highlightScriptItemId.wrappedValue = nil }
    }

    /// Consume a shot deep-link: select it (unless a script item is the primary
    /// target), scroll it into view, then clear the binding.
    private func applyShotHighlight(_ proxy: ScrollViewProxy) {
        guard let shotId = highlightShotId.wrappedValue else { return }
        if highlightScriptItemId.wrappedValue == nil {
            viewModel.selectShot(shotId)
        }
        withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo("shot-\(shotId)", anchor: .center)
        }
        DispatchQueue.main.async { highlightShotId.wrappedValue = nil }
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
                ScrollViewReader { proxy in
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
                                },
                                connectTargetsProvider: { scriptConnectTargets(forShot: shot.id) },
                                onToggleConnect: { target in
                                    guard let itemType = target.itemType else { return }
                                    viewModel.toggleConnection(scriptItemId: target.id,
                                                               shotId: shot.id, itemType: itemType)
                                }
                            )
                            .id("shot-\(shot.id)")
                            .background(GeometryReader { proxy in
                                Color.clear.preference(
                                    key: ShotCardFrameKey.self,
                                    value: [shot.id: proxy.frame(in: .named("sceneConnections"))]
                                )
                            })
                        }
                    }
                    .padding(SceneConnectionConstants.cardPadding)
                }
                .onAppear { applyShotHighlight(proxy) }
                .onChange(of: highlightShotId.wrappedValue) { _, _ in
                    applyShotHighlight(proxy)
                }
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

    /// Menu targets for "Connect to Shot" on a script item — computed lazily
    /// when the context menu opens, not per render.
    private func shotConnectTargets(for scriptItemId: String, itemType: ScriptItemType) -> [ConnectionMenuTarget] {
        viewModel.shots.map { shot in
            ConnectionMenuTarget(
                id: shot.id,
                title: "Shot \(shot.shotId)" + (shot.description.isEmpty ? "" : " — \(shot.description.prefix(30))"),
                isConnected: viewModel.connectionExists(scriptItemId: scriptItemId,
                                                        shotId: shot.id, itemType: itemType)
            )
        }
    }

    /// Menu targets for "Connect Script Item" on a shot — lazy, menu-open only.
    private func scriptConnectTargets(forShot shotId: String) -> [ConnectionMenuTarget] {
        viewModel.scriptItems.map { item in
            let prefix = item.subtitle.map { "\($0): " } ?? ""
            return ConnectionMenuTarget(
                id: item.id,
                title: "#\(item.chronologyNumber) \(prefix)\(String(item.displayText.prefix(36)))",
                isConnected: viewModel.connectionExists(scriptItemId: item.id,
                                                        shotId: shotId, itemType: item.itemType),
                itemType: item.itemType
            )
        }
    }

    private func highlightedTypeForShot(_ shotId: String) -> ScriptItemType? {
        // Highlight only the hovered drop target while dragging — previously
        // every shot card lit up (and re-rendered) on each drag tick.
        if viewModel.isDragging {
            guard viewModel.dragHoverShotId == shotId else { return nil }
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

// MARK: - Shot Card Frame Preference

/// Shot CARD frames in canvas space — lets a drag drop anywhere on the card,
/// not just the 24pt port dot.
private struct ShotCardFrameKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

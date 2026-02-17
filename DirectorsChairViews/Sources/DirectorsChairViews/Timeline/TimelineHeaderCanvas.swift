// DirectorsChairViews/Sources/DirectorsChairViews/Timeline/TimelineHeaderCanvas.swift
//
// Fixed header canvas for the timeline — renders time ruler, shot labels lane,
// and scope marker labels. Stays pinned at top during vertical scrolling.

import SwiftUI
import AppKit

/// Fixed header canvas that renders the time ruler, shot labels lane, and scope marker labels.
/// This stays pinned at the top while character-lane tracks scroll vertically underneath.
public struct TimelineHeaderCanvas: View {
    // MARK: - Properties

    /// All segments (used only for computing totalWidth / totalSeconds)
    public let segments: [TimelineSegment]

    /// Scene boundaries (time, name)
    public let sceneBoundaries: [TimelineBoundary]

    /// Sequence boundaries (time, name)
    public let sequenceBoundaries: [TimelineBoundary]

    /// Shot labels for the shot lane
    public let shotLabels: [TimelineShotLabel]

    /// Whether to show shot labels lane
    public let showShotLabels: Bool

    /// Pixels per second (zoom level)
    public let pxPerSec: CGFloat

    /// Current timeline mode
    public let mode: TimelineMode

    /// Available viewport size
    public let viewportSize: CGSize

    /// Sub-lane assignment for each shot label
    public let shotSubLaneAssignments: [UUID: Int]

    /// Number of sub-lanes in the shots lane
    public let shotLaneSubLaneCount: Int

    /// Shot-dialogue connections (for drawing indicators on linked shot cards)
    public let shotDialogueConnections: [ShotDialogueConnection]

    /// Whether to show shot-dialogue connection lines
    public let showShotConnections: Bool

    /// Playhead time in seconds (nil = no playhead)
    public let playheadTime: CGFloat?

    /// Whether the playhead is active (following cursor)
    public let playheadActive: Bool

    /// User-created markers
    public let userMarkers: [TimelineMarker]

    /// Project base path for resolving preview image paths
    public let projectBasePath: URL?

    /// Callback when a shot label is double-clicked (shotId, sceneName)
    public var onShotLabelDoubleClicked: ((Int, String) -> Void)?

    /// Callback when a shot label is dragged to a new time position
    public var onShotLabelMoved: ((Int, String, CGFloat) -> Void)?

    /// Callback when a shot label is single-clicked (selected)
    public var onShotLabelSelected: ((UUID) -> Void)?

    /// Callback when a shot label is Option+clicked (jump to script) — (shotId, sceneName)
    public var onOptionClickShotLabel: ((Int, String) -> Void)?

    /// Callback when shot track eye toggle is clicked
    public var onShotTrackToggled: (() -> Void)?

    /// Callback when a shot label is resized to a new duration (shotId, sceneName, newDuration)
    public var onShotLabelResized: ((Int, String, CGFloat) -> Void)?

    /// Callback when a scene boundary marker is double-clicked (sceneName)
    public var onSceneMarkerDoubleClicked: ((String) -> Void)?

    /// Callback when a scene boundary marker is moved (sceneName, newTime)
    public var onSceneBoundaryMoved: ((String, CGFloat) -> Void)?

    /// Callback when a sequence boundary marker is moved (sequenceName, newTime)
    public var onSequenceBoundaryMoved: ((String, CGFloat) -> Void)?

    /// Callback when the ruler is clicked to set the playhead
    public var onRulerClicked: ((CGFloat) -> Void)?

    /// Callback when the playhead is dragged to a new X position
    public var onPlayheadDragged: ((CGFloat) -> Void)?

    /// Callback when a user marker is deleted (marker ID)
    public var onMarkerDeleted: ((UUID) -> Void)?

    /// Callback when a user marker is updated (id, label, icon, color)
    public var onMarkerUpdated: ((UUID, String, String, String) -> Void)?

    /// Callback when a new marker is added (time, label, icon, color)
    public var onMarkerAdded: ((CGFloat, String, String, String) -> Void)?

    /// ID of the shot currently being dragged
    @State private var draggingShotId: UUID?

    /// X position where drag started
    @State private var dragStartX: CGFloat = 0

    /// Current X position during drag
    @State private var dragCurrentX: CGFloat = 0

    /// ID of the shot currently being resized (right-edge drag)
    @State private var resizingShotId: UUID?

    /// X position where resize drag started
    @State private var resizeStartX: CGFloat = 0

    /// Original duration (seconds) when resize started
    @State private var resizeStartDuration: CGFloat = 0

    /// Shot label targeted by the right-click context menu
    @State private var contextMenuShot: TimelineShotLabel?

    /// Whether the duration popover is showing
    @State private var showDurationPopover: Bool = false

    /// Text field input for duration (seconds)
    @State private var durationInputText: String = ""

    /// ID of the boundary marker currently being dragged
    @State private var draggingBoundaryId: UUID?

    /// Whether the dragged boundary is a sequence boundary (true) or scene boundary (false)
    @State private var draggingBoundaryIsSequence: Bool = false

    /// X position where boundary drag started
    @State private var dragBoundaryStartX: CGFloat = 0

    /// Whether the playhead handle is being dragged
    @State private var isDraggingPlayhead: Bool = false

    /// Marker targeted by right-click context menu
    @State private var contextMenuMarker: TimelineMarker?

    /// Whether the marker edit popover is showing
    @State private var showMarkerEditPopover: Bool = false

    /// Marker edit fields
    @State private var markerEditLabel: String = ""
    @State private var markerEditIcon: String = "flag.fill"
    @State private var markerEditColor: String = "#FF5F5F"

    /// Time position for adding a new marker (nil = editing existing)
    @State private var addMarkerTime: CGFloat? = nil

    /// Anchor point for marker popover (local view coordinates of the right-click)
    @State private var markerPopoverAnchor: CGPoint = .zero

    /// Whether the Command key is currently held down (for showing shot previews)
    @State private var isCommandKeyDown: Bool = false

    /// Cache for loaded preview images (keyed by relative path)
    @State private var previewImageCache: [String: NSImage] = [:]

    // MARK: - Computed Properties

    /// Total timeline duration in seconds
    private var totalSeconds: CGFloat {
        guard let maxEnd = segments.map({ $0.end }).max() else { return 0 }
        return maxEnd
    }

    /// Total canvas width
    private var totalWidth: CGFloat {
        let contentWidth = TimelineLayoutConstants.leftMargin +
                           TimelineLayoutConstants.rowLabelWidth +
                           totalSeconds * pxPerSec + 160
        let viewportWidth = max(0, viewportSize.width - 16)
        return max(viewportWidth, max(TimelineLayoutConstants.minCanvasWidth, contentWidth))
    }

    /// Height of the shot labels lane (dynamic based on sub-lane count)
    private var shotLaneOffset: CGFloat {
        if showShotLabels {
            return CGFloat(shotLaneSubLaneCount) * TimelineLayoutConstants.shotLaneHeight
        } else {
            return 24 // Collapsed strip
        }
    }

    /// Height of this header canvas
    public var headerHeight: CGFloat {
        TimelineLayoutConstants.topMargin +
        TimelineLayoutConstants.rulerHeight +
        TimelineLayoutConstants.rulerGap +
        shotLaneOffset
    }

    /// Content origin X (where timeline content starts, after labels)
    private var originX: CGFloat {
        TimelineLayoutConstants.leftMargin + TimelineLayoutConstants.rowLabelWidth
    }

    // MARK: - Init

    public init(
        segments: [TimelineSegment],
        sceneBoundaries: [TimelineBoundary] = [],
        sequenceBoundaries: [TimelineBoundary] = [],
        shotLabels: [TimelineShotLabel] = [],
        showShotLabels: Bool = false,
        pxPerSec: CGFloat = TimelineLayoutConstants.defaultPxPerSec,
        mode: TimelineMode = .scene,
        viewportSize: CGSize = CGSize(width: 800, height: 300),
        shotSubLaneAssignments: [UUID: Int] = [:],
        shotLaneSubLaneCount: Int = 1,
        shotDialogueConnections: [ShotDialogueConnection] = [],
        showShotConnections: Bool = false,
        playheadTime: CGFloat? = nil,
        playheadActive: Bool = false,
        userMarkers: [TimelineMarker] = [],
        projectBasePath: URL? = nil,
        onShotLabelDoubleClicked: ((Int, String) -> Void)? = nil,
        onSceneMarkerDoubleClicked: ((String) -> Void)? = nil,
        onShotLabelMoved: ((Int, String, CGFloat) -> Void)? = nil,
        onShotLabelSelected: ((UUID) -> Void)? = nil,
        onOptionClickShotLabel: ((Int, String) -> Void)? = nil,
        onShotTrackToggled: (() -> Void)? = nil,
        onShotLabelResized: ((Int, String, CGFloat) -> Void)? = nil,
        onSceneBoundaryMoved: ((String, CGFloat) -> Void)? = nil,
        onSequenceBoundaryMoved: ((String, CGFloat) -> Void)? = nil,
        onRulerClicked: ((CGFloat) -> Void)? = nil,
        onPlayheadDragged: ((CGFloat) -> Void)? = nil,
        onMarkerDeleted: ((UUID) -> Void)? = nil,
        onMarkerUpdated: ((UUID, String, String, String) -> Void)? = nil,
        onMarkerAdded: ((CGFloat, String, String, String) -> Void)? = nil
    ) {
        self.segments = segments
        self.sceneBoundaries = sceneBoundaries
        self.sequenceBoundaries = sequenceBoundaries
        self.shotLabels = shotLabels
        self.showShotLabels = showShotLabels
        self.pxPerSec = pxPerSec
        self.mode = mode
        self.viewportSize = viewportSize
        self.shotSubLaneAssignments = shotSubLaneAssignments
        self.shotLaneSubLaneCount = shotLaneSubLaneCount
        self.shotDialogueConnections = shotDialogueConnections
        self.showShotConnections = showShotConnections
        self.playheadTime = playheadTime
        self.playheadActive = playheadActive
        self.userMarkers = userMarkers
        self.projectBasePath = projectBasePath
        self.onShotLabelDoubleClicked = onShotLabelDoubleClicked
        self.onSceneMarkerDoubleClicked = onSceneMarkerDoubleClicked
        self.onShotLabelMoved = onShotLabelMoved
        self.onShotLabelSelected = onShotLabelSelected
        self.onOptionClickShotLabel = onOptionClickShotLabel
        self.onShotTrackToggled = onShotTrackToggled
        self.onShotLabelResized = onShotLabelResized
        self.onSceneBoundaryMoved = onSceneBoundaryMoved
        self.onSequenceBoundaryMoved = onSequenceBoundaryMoved
        self.onRulerClicked = onRulerClicked
        self.onPlayheadDragged = onPlayheadDragged
        self.onMarkerDeleted = onMarkerDeleted
        self.onMarkerUpdated = onMarkerUpdated
        self.onMarkerAdded = onMarkerAdded
    }

    // MARK: - Body

    public var body: some View {
        Canvas { context, size in
            drawBackground(context: context, size: size)
            drawTimeRuler(context: context, size: size)

            // Always draw shot lane (expanded or collapsed strip)
            drawShotLabels(context: context, size: size)

            drawHeaderUserMarkers(context: context, size: size)
            drawScopeMarkers(context: context, size: size)
            drawPlayhead(context: context, size: size)
        }
        .frame(width: totalWidth, height: headerHeight)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { location in
            // Check for ruler double-click to toggle playhead
            let rulerTop = TimelineLayoutConstants.topMargin
            let rulerBottom = rulerTop + TimelineLayoutConstants.rulerHeight
            if location.y >= rulerTop && location.y <= rulerBottom && location.x >= originX {
                onRulerClicked?(location.x)
                return
            }
            // Check for scene marker double-click
            if let (boundary, isSequence) = findBoundaryMarker(at: location), !isSequence {
                onSceneMarkerDoubleClicked?(boundary.name)
                return
            }
            if showShotLabels, let shotLabel = findShotLabel(at: location) {
                onShotLabelDoubleClicked?(shotLabel.shotId, shotLabel.sceneName)
            }
        }
        .onTapGesture(count: 1) { location in
            // Check for shot track eye toggle first
            if isShotEyeToggleHit(at: location) {
                onShotTrackToggled?()
                return
            }
            // Option+Click on shot label → jump to script
            if showShotLabels, NSEvent.modifierFlags.contains(.option), let shotLabel = findShotLabel(at: location) {
                onOptionClickShotLabel?(shotLabel.shotId, shotLabel.sceneName)
                return
            }
            if showShotLabels, let shotLabel = findShotLabel(at: location) {
                onShotLabelSelected?(shotLabel.id)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    // First frame: decide what we're dragging
                    if draggingShotId == nil && resizingShotId == nil && draggingBoundaryId == nil && !isDraggingPlayhead {
                        // 0. Check playhead handle first
                        if findPlayheadHandle(at: value.startLocation) {
                            isDraggingPlayhead = true
                            onPlayheadDragged?(value.location.x)
                            return
                        }
                        // 1. Check boundary markers first (top margin area)
                        if let (boundary, isSequence) = findBoundaryMarker(at: value.startLocation) {
                            draggingBoundaryId = boundary.id
                            draggingBoundaryIsSequence = isSequence
                            dragBoundaryStartX = value.startLocation.x
                        }
                        // 2. Check shot right-edge (resize)
                        else if showShotLabels, let shotLabel = findShotLabelRightEdge(at: value.startLocation) {
                            resizingShotId = shotLabel.id
                            resizeStartX = value.startLocation.x
                            resizeStartDuration = shotLabel.duration > 0 ? shotLabel.duration : shotLabel.displayWidth(pxPerSec: pxPerSec) / pxPerSec
                        }
                        // 3. Check shot label body (move)
                        else if showShotLabels, let shotLabel = findShotLabel(at: value.startLocation) {
                            draggingShotId = shotLabel.id
                            dragStartX = value.startLocation.x
                        }
                    }
                    if isDraggingPlayhead {
                        onPlayheadDragged?(value.location.x)
                        return
                    }
                    if draggingShotId != nil || resizingShotId != nil || draggingBoundaryId != nil {
                        dragCurrentX = value.location.x
                    }
                }
                .onEnded { value in
                    // Handle playhead drag end
                    if isDraggingPlayhead {
                        onPlayheadDragged?(value.location.x)
                        isDraggingPlayhead = false
                        return
                    }
                    // Handle boundary move end
                    if let boundaryId = draggingBoundaryId {
                        let deltaX = value.location.x - dragBoundaryStartX
                        let deltaTime = deltaX / pxPerSec
                        if draggingBoundaryIsSequence {
                            if let boundary = sequenceBoundaries.first(where: { $0.id == boundaryId }) {
                                let newTime = max(0, boundary.time + deltaTime)
                                onSequenceBoundaryMoved?(boundary.name, newTime)
                            }
                        } else {
                            if let boundary = sceneBoundaries.first(where: { $0.id == boundaryId }) {
                                let newTime = max(0, boundary.time + deltaTime)
                                onSceneBoundaryMoved?(boundary.name, newTime)
                            }
                        }
                    }
                    // Handle resize end
                    else if let resizeId = resizingShotId,
                       let shotLabel = shotLabels.first(where: { $0.id == resizeId }) {
                        let deltaX = value.location.x - resizeStartX
                        let newDuration = max(0.5, resizeStartDuration + deltaX / pxPerSec)
                        onShotLabelResized?(shotLabel.shotId, shotLabel.sceneName, newDuration)
                    }
                    // Handle shot move end
                    else if let dragId = draggingShotId,
                       let shotLabel = shotLabels.first(where: { $0.id == dragId }) {
                        let deltaX = value.location.x - dragStartX
                        let deltaTime = deltaX / pxPerSec
                        let newTime = max(0, shotLabel.time + deltaTime)
                        onShotLabelMoved?(shotLabel.shotId, shotLabel.sceneName, newTime)
                    }
                    draggingShotId = nil
                    resizingShotId = nil
                    draggingBoundaryId = nil
                    draggingBoundaryIsSequence = false
                    dragCurrentX = 0
                    dragStartX = 0
                    dragBoundaryStartX = 0
                    resizeStartX = 0
                    resizeStartDuration = 0
                }
        )
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                // Update playhead position when active and cursor is in content area
                if playheadActive && location.x >= originX {
                    onPlayheadDragged?(location.x)
                }
                if showShotLabels, findShotLabelRightEdge(at: location) != nil {
                    NSCursor.resizeLeftRight.set()
                } else {
                    NSCursor.arrow.set()
                }
                // Marker tooltip
                if let marker = findUserMarker(at: location) {
                    let screenPoint = NSEvent.mouseLocation
                    MarkerTooltip.shared.show(text: marker.label, near: screenPoint)
                } else {
                    MarkerTooltip.shared.hide()
                }
            case .ended:
                NSCursor.arrow.set()
                MarkerTooltip.shared.hide()
            }
        }
        .overlay(
            RightClickOverlay { point, nsView in
                // Check user markers first
                if let marker = findUserMarker(at: point) {
                    let menu = NSMenu()
                    let editItem = NSMenuItem(title: "Edit Marker...", action: nil, keyEquivalent: "")
                    let deleteItem = NSMenuItem(title: "Delete Marker", action: nil, keyEquivalent: "")

                    let editHandler = MarkerMenuHandler {
                        contextMenuMarker = marker
                        addMarkerTime = nil
                        markerPopoverAnchor = point
                        markerEditLabel = marker.label
                        markerEditIcon = marker.icon
                        markerEditColor = marker.color
                        showMarkerEditPopover = true
                    }
                    editItem.target = editHandler
                    editItem.action = #selector(MarkerMenuHandler.execute)
                    objc_setAssociatedObject(editItem, "handler", editHandler, .OBJC_ASSOCIATION_RETAIN)

                    let deleteHandler = MarkerMenuHandler {
                        onMarkerDeleted?(marker.id)
                    }
                    deleteItem.target = deleteHandler
                    deleteItem.action = #selector(MarkerMenuHandler.execute)
                    objc_setAssociatedObject(deleteItem, "handler", deleteHandler, .OBJC_ASSOCIATION_RETAIN)

                    menu.addItem(editItem)
                    menu.addItem(deleteItem)

                    // Use unflipped coordinates relative to the NSView
                    let unflippedY = nsView.bounds.height - point.y
                    menu.popUp(positioning: nil, at: NSPoint(x: point.x, y: unflippedY), in: nsView)
                    return
                }
                // Right-click on ruler area → "Add Marker Here"
                let rulerTop = TimelineLayoutConstants.topMargin
                let rulerBottom = rulerTop + TimelineLayoutConstants.rulerHeight
                if point.y >= rulerTop && point.y <= rulerBottom && point.x >= originX {
                    let time = max(0, (point.x - originX) / pxPerSec)
                    let menu = NSMenu()
                    let addItem = NSMenuItem(title: "Add Marker Here", action: nil, keyEquivalent: "")

                    let addHandler = MarkerMenuHandler {
                        addMarkerTime = time
                        contextMenuMarker = nil
                        markerPopoverAnchor = point
                        markerEditLabel = "Marker"
                        markerEditIcon = "flag.fill"
                        markerEditColor = "#FF5F5F"
                        showMarkerEditPopover = true
                    }
                    addItem.target = addHandler
                    addItem.action = #selector(MarkerMenuHandler.execute)
                    objc_setAssociatedObject(addItem, "handler", addHandler, .OBJC_ASSOCIATION_RETAIN)

                    menu.addItem(addItem)

                    // Use unflipped coordinates relative to the NSView
                    let unflippedY = nsView.bounds.height - point.y
                    menu.popUp(positioning: nil, at: NSPoint(x: point.x, y: unflippedY), in: nsView)
                    return
                }
                if showShotLabels, let shotLabel = findShotLabel(at: point) {
                    contextMenuShot = shotLabel
                    let currentDuration = shotLabel.duration > 0 ? shotLabel.duration : shotLabel.displayWidth(pxPerSec: pxPerSec) / pxPerSec
                    durationInputText = String(format: "%.1f", currentDuration)
                    showDurationPopover = true
                }
            }
        )
        .popover(isPresented: $showDurationPopover, arrowEdge: .bottom) {
            if let shot = contextMenuShot {
                VStack(spacing: 12) {
                    Text("\(shot.shotName) \u{2022} \(shot.shotType)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)

                    HStack(spacing: 8) {
                        Text("Duration (sec):")
                            .font(.system(size: 11))
                            .foregroundColor(Color(nsColor: .secondaryLabelColor))
                        TextField("", text: $durationInputText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                            .onSubmit {
                                applyDurationInput()
                            }
                    }

                    HStack(spacing: 8) {
                        Button("Cancel") {
                            showDurationPopover = false
                            contextMenuShot = nil
                        }
                        .keyboardShortcut(.cancelAction)

                        Button("Set") {
                            applyDurationInput()
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                }
                .padding(16)
                .frame(width: 240)
            }
        }
        .overlay(
            Color.clear
                .frame(width: 1, height: 1)
                .position(markerPopoverAnchor)
                .popover(isPresented: $showMarkerEditPopover, arrowEdge: .bottom) {
                    if let marker = contextMenuMarker {
                        // Editing existing marker
                        MarkerConfigPopover(
                            markerLabel: $markerEditLabel,
                            markerIcon: $markerEditIcon,
                            markerColor: $markerEditColor,
                            isEditing: true,
                            onSave: {
                                onMarkerUpdated?(marker.id, markerEditLabel, markerEditIcon, markerEditColor)
                                showMarkerEditPopover = false
                                contextMenuMarker = nil
                            },
                            onCancel: {
                                showMarkerEditPopover = false
                                contextMenuMarker = nil
                            }
                        )
                    } else if let time = addMarkerTime {
                        // Adding new marker
                        MarkerConfigPopover(
                            markerLabel: $markerEditLabel,
                            markerIcon: $markerEditIcon,
                            markerColor: $markerEditColor,
                            isEditing: false,
                            onSave: {
                                onMarkerAdded?(time, markerEditLabel, markerEditIcon, markerEditColor)
                                showMarkerEditPopover = false
                                addMarkerTime = nil
                            },
                            onCancel: {
                                showMarkerEditPopover = false
                                addMarkerTime = nil
                            }
                        )
                    }
                }
        )
        .overlay(CommandKeyMonitor(isCommandKeyDown: $isCommandKeyDown))
    }

    // MARK: - Duration Input

    /// Apply the duration text field input to the context menu shot
    private func applyDurationInput() {
        guard let shot = contextMenuShot,
              let value = Double(durationInputText),
              value > 0 else {
            showDurationPopover = false
            contextMenuShot = nil
            return
        }
        let newDuration = max(0.5, CGFloat(value))
        onShotLabelResized?(shot.shotId, shot.sceneName, newDuration)
        showDurationPopover = false
        contextMenuShot = nil
    }

    // MARK: - Hit Testing

    /// Find a boundary marker (scene or sequence) at the given point.
    /// Returns the boundary and a bool indicating whether it's a sequence boundary.
    private func findBoundaryMarker(at point: CGPoint) -> (TimelineBoundary, Bool)? {
        let labelHeight: CGFloat = 18

        // Check sequence boundaries first (stackLevel 0 in global mode)
        if mode == .global {
            for boundary in sequenceBoundaries {
                let x = originX + boundary.time * pxPerSec
                let labelWidth = max(50, CGFloat(boundary.name.count) * 7 + 16)
                let labelY: CGFloat = 4
                let labelRect = CGRect(x: x - labelWidth / 2, y: labelY, width: labelWidth, height: labelHeight)
                if labelRect.contains(point) {
                    return (boundary, true)
                }
            }
        }

        // Check scene boundaries (stackLevel depends on mode)
        if mode == .sequence || mode == .global {
            let stackLevel = mode == .global ? 1 : 0
            for boundary in sceneBoundaries {
                let x = originX + boundary.time * pxPerSec
                let labelWidth = max(50, CGFloat(boundary.name.count) * 7 + 16)
                let labelY: CGFloat = 4 + CGFloat(stackLevel) * (labelHeight + 4)
                let labelRect = CGRect(x: x - labelWidth / 2, y: labelY, width: labelWidth, height: labelHeight)
                if labelRect.contains(point) {
                    return (boundary, false)
                }
            }
        }

        return nil
    }

    /// Find a shot label at the given point
    private func findShotLabel(at point: CGPoint) -> TimelineShotLabel? {
        guard showShotLabels else { return nil }

        let laneY = TimelineLayoutConstants.topMargin +
                    TimelineLayoutConstants.rulerHeight +
                    TimelineLayoutConstants.rulerGap
        let totalLaneHeight = shotLaneOffset
        let singleLaneHeight = TimelineLayoutConstants.shotLaneHeight
        let perfSize = TimelineLayoutConstants.filmPerforationSize

        guard point.y >= laneY && point.y <= laneY + totalLaneHeight else { return nil }

        let cardInset = perfSize + 6
        let cardHeight = singleLaneHeight - cardInset * 2

        for shotLabel in shotLabels {
            let x = originX + shotLabel.time * pxPerSec
            let cardWidth = shotLabel.displayWidth(pxPerSec: pxPerSec)

            let subLane = shotSubLaneAssignments[shotLabel.id] ?? 0
            let subLaneY = laneY + CGFloat(subLane) * singleLaneHeight
            let cardTopY = subLaneY + cardInset

            let shotRect = CGRect(
                x: x + 2,
                y: cardTopY,
                width: cardWidth - 4,
                height: cardHeight
            )

            if shotRect.contains(point) {
                return shotLabel
            }
        }

        return nil
    }

    /// Find a shot label whose right edge is within 8px of the given point
    private func findShotLabelRightEdge(at point: CGPoint) -> TimelineShotLabel? {
        guard showShotLabels else { return nil }

        let laneY = TimelineLayoutConstants.topMargin +
                    TimelineLayoutConstants.rulerHeight +
                    TimelineLayoutConstants.rulerGap
        let totalLaneHeight = shotLaneOffset
        let singleLaneHeight = TimelineLayoutConstants.shotLaneHeight
        let perfSize = TimelineLayoutConstants.filmPerforationSize

        guard point.y >= laneY && point.y <= laneY + totalLaneHeight else { return nil }

        let cardInset = perfSize + 6
        let cardHeight = singleLaneHeight - cardInset * 2
        let edgeThreshold: CGFloat = 8

        for shotLabel in shotLabels {
            let x = originX + shotLabel.time * pxPerSec
            let cardWidth = shotLabel.displayWidth(pxPerSec: pxPerSec)

            let subLane = shotSubLaneAssignments[shotLabel.id] ?? 0
            let subLaneY = laneY + CGFloat(subLane) * singleLaneHeight
            let cardTopY = subLaneY + cardInset

            let cardRight = x + cardWidth - 2  // right edge of card (accounting for 2px inset)

            // Check if point is within edgeThreshold of the right edge and within card height
            if point.y >= cardTopY && point.y <= cardTopY + cardHeight &&
               abs(point.x - cardRight) <= edgeThreshold {
                return shotLabel
            }
        }

        return nil
    }

    /// Check if a point hits the shot track eye toggle area
    private func isShotEyeToggleHit(at point: CGPoint) -> Bool {
        let laneY = TimelineLayoutConstants.topMargin +
                    TimelineLayoutConstants.rulerHeight +
                    TimelineLayoutConstants.rulerGap
        let totalLaneHeight = shotLaneOffset

        if showShotLabels {
            // Expanded: eye icon area within the label rect
            let labelRect = CGRect(x: 4, y: laneY + 4, width: TimelineLayoutConstants.rowLabelWidth - 12, height: totalLaneHeight - 8)
            let eyeRect = CGRect(x: labelRect.minX, y: labelRect.minY, width: 28, height: labelRect.height)
            return eyeRect.contains(point)
        } else {
            // Collapsed: entire label strip is clickable to re-expand
            let labelRect = CGRect(x: 4, y: laneY + 2, width: TimelineLayoutConstants.rowLabelWidth - 12, height: 20)
            return labelRect.contains(point)
        }
    }

    // MARK: - Playhead Hit Testing

    /// Check if a point is within the playhead triangle handle
    private func findPlayheadHandle(at point: CGPoint) -> Bool {
        guard let time = playheadTime else { return false }
        let x = originX + time * pxPerSec
        let handleY = TimelineLayoutConstants.topMargin
        let radius = TimelineLayoutConstants.playheadHitRadius
        return abs(point.x - x) <= radius && abs(point.y - handleY) <= radius
    }

    // MARK: - User Marker Hit Testing

    /// Find a user marker at the given point
    private func findUserMarker(at point: CGPoint) -> TimelineMarker? {
        let rulerBaselineY = TimelineLayoutConstants.topMargin + TimelineLayoutConstants.rulerHeight - 1
        let diamondSize = TimelineLayoutConstants.userMarkerDiamondSize
        let hitRadius: CGFloat = 12

        for marker in userMarkers {
            let x = originX + marker.time * pxPerSec
            if abs(point.x - x) <= hitRadius && abs(point.y - rulerBaselineY) <= (diamondSize + hitRadius) {
                return marker
            }
        }
        return nil
    }

    // MARK: - Drawing Methods

    /// Draw the header background
    private func drawBackground(context: GraphicsContext, size: CGSize) {
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(Color(hex: "#262626"))
        )
    }

    /// Draw time ruler at top
    private func drawTimeRuler(context: GraphicsContext, size: CGSize) {
        let rulerY = TimelineLayoutConstants.topMargin
        let baselineY = rulerY + TimelineLayoutConstants.rulerHeight - 1

        // Ruler background
        let rulerRect = CGRect(
            x: 0,
            y: rulerY,
            width: size.width,
            height: TimelineLayoutConstants.rulerHeight
        )
        context.fill(Path(rulerRect), with: .color(Color(hex: "#262626")))

        // Baseline
        context.stroke(
            Path { path in
                path.move(to: CGPoint(x: originX, y: baselineY))
                path.addLine(to: CGPoint(x: size.width - 20, y: baselineY))
            },
            with: .color(Color(hex: "#3A3A3A")),
            lineWidth: 1
        )

        let canvasSecondsCapacity = (size.width - originX - 20) / pxPerSec
        let totalSecs = Int(max(totalSeconds, canvasSecondsCapacity))

        let tickInterval: Int
        let labelInterval: Int

        if pxPerSec < 25 {
            tickInterval = 10
            labelInterval = 10
        } else if pxPerSec < 40 {
            tickInterval = 5
            labelInterval = 10
        } else if pxPerSec < 80 {
            tickInterval = 1
            labelInterval = 5
        } else {
            tickInterval = 1
            labelInterval = 5
        }

        for sec in stride(from: 0, through: totalSecs, by: tickInterval) {
            let px = originX + CGFloat(sec) * pxPerSec

            if px > size.width { break }

            let tickHeight: CGFloat
            if sec % 60 == 0 {
                tickHeight = TimelineLayoutConstants.minuteTickHeight
            } else if sec % 10 == 0 {
                tickHeight = TimelineLayoutConstants.majorTickHeight
            } else if sec % 5 == 0 {
                tickHeight = TimelineLayoutConstants.mediumTickHeight
            } else {
                tickHeight = TimelineLayoutConstants.minorTickHeight
            }

            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: px, y: baselineY))
                    path.addLine(to: CGPoint(x: px, y: baselineY - tickHeight))
                },
                with: .color(Color(hex: "#3A3A3A")),
                lineWidth: 1
            )

            if sec % labelInterval == 0 {
                let label = DurationEstimator.formatTime(CGFloat(sec))
                let textPoint = CGPoint(x: px, y: rulerY + 4)

                context.draw(
                    Text(label)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundColor(Color(hex: "#CCCCCC")),
                    at: textPoint,
                    anchor: .top
                )
            }
        }
    }

    /// Draw shot labels lane (film-strip style) or collapsed strip
    private func drawShotLabels(context: GraphicsContext, size: CGSize) {
        let laneY = TimelineLayoutConstants.topMargin +
                    TimelineLayoutConstants.rulerHeight +
                    TimelineLayoutConstants.rulerGap
        let totalLaneHeight = shotLaneOffset

        // --- Collapsed strip (showShotLabels == false) ---
        if !showShotLabels {
            let collapsedRect = CGRect(x: 0, y: laneY, width: size.width, height: totalLaneHeight)
            context.fill(Path(collapsedRect), with: .color(Color(hex: "#1A1A1A").opacity(0.7)))

            // Separator lines
            context.stroke(
                Path { p in p.move(to: CGPoint(x: 0, y: laneY)); p.addLine(to: CGPoint(x: size.width, y: laneY)) },
                with: .color(Color(hex: "#444444")), lineWidth: 1
            )
            context.stroke(
                Path { p in p.move(to: CGPoint(x: 0, y: laneY + totalLaneHeight)); p.addLine(to: CGPoint(x: size.width, y: laneY + totalLaneHeight)) },
                with: .color(Color(hex: "#444444")), lineWidth: 1
            )

            // Collapsed label
            let labelRect = CGRect(x: 4, y: laneY + 2, width: TimelineLayoutConstants.rowLabelWidth - 12, height: 20)
            context.fill(Path(roundedRect: labelRect, cornerRadius: 3), with: .color(Color(hex: "#333333").opacity(0.7)))
            context.stroke(Path(roundedRect: labelRect, cornerRadius: 3), with: .color(Color(hex: "#555555")), lineWidth: 1)

            let centerY = laneY + totalLaneHeight / 2

            // Eye.slash icon
            context.draw(
                Text(Image(systemName: "eye.slash")).font(.system(size: 9)).foregroundColor(Color(hex: "#888888")),
                at: CGPoint(x: labelRect.minX + 14, y: centerY), anchor: .center
            )
            // Film icon
            context.draw(
                Text(Image(systemName: "film")).font(.system(size: 9)).foregroundColor(Color(hex: "#666666")),
                at: CGPoint(x: labelRect.minX + 34, y: centerY), anchor: .center
            )
            // "Shots" text
            context.draw(
                Text("Shots").font(.system(size: 10, weight: .medium)).foregroundColor(Color(hex: "#666666")),
                at: CGPoint(x: labelRect.maxX - 8, y: centerY), anchor: .trailing
            )
            return
        }

        // --- Expanded shot lane ---
        let singleLaneHeight = TimelineLayoutConstants.shotLaneHeight
        let perfSize = TimelineLayoutConstants.filmPerforationSize
        let perfSpacing = TimelineLayoutConstants.filmPerforationSpacing

        // Film-strip background
        let laneRect = CGRect(x: 0, y: laneY, width: size.width, height: totalLaneHeight)
        context.fill(Path(laneRect), with: .color(Color(hex: "#1A1A1A").opacity(0.95)))

        // Top/bottom separator lines
        context.stroke(
            Path { p in p.move(to: CGPoint(x: 0, y: laneY)); p.addLine(to: CGPoint(x: size.width, y: laneY)) },
            with: .color(Color(hex: "#555555")), lineWidth: 1
        )
        context.stroke(
            Path { p in p.move(to: CGPoint(x: 0, y: laneY + totalLaneHeight)); p.addLine(to: CGPoint(x: size.width, y: laneY + totalLaneHeight)) },
            with: .color(Color(hex: "#555555")), lineWidth: 1
        )

        // Perforation holes
        let perfStartX = originX
        let perfTopY = laneY + 3
        let perfBottomY = laneY + totalLaneHeight - perfSize - 3
        let step = perfSize + perfSpacing

        var px = perfStartX
        while px < size.width {
            context.fill(Path(roundedRect: CGRect(x: px, y: perfTopY, width: perfSize, height: perfSize), cornerRadius: 1), with: .color(Color(hex: "#333333")))
            context.fill(Path(roundedRect: CGRect(x: px, y: perfBottomY, width: perfSize, height: perfSize), cornerRadius: 1), with: .color(Color(hex: "#333333")))
            px += step
        }

        // "Shots" row label with eye toggle
        let labelRect = CGRect(x: 4, y: laneY + 4, width: TimelineLayoutConstants.rowLabelWidth - 12, height: totalLaneHeight - 8)
        context.fill(Path(roundedRect: labelRect, cornerRadius: 4), with: .color(Color(hex: "#2A2A2A")))
        context.stroke(Path(roundedRect: labelRect, cornerRadius: 4), with: .color(Color(hex: "#444444")), lineWidth: 1)

        let centerY = laneY + totalLaneHeight / 2

        // Eye toggle icon (leftmost)
        context.draw(
            Text(Image(systemName: "eye.fill")).font(.system(size: 10)).foregroundColor(Color(hex: "#666666")),
            at: CGPoint(x: labelRect.minX + 14, y: centerY), anchor: .center
        )
        // Film icon (after eye)
        context.draw(
            Text(Image(systemName: "film")).font(.system(size: 10)).foregroundColor(Color(hex: "#999999")),
            at: CGPoint(x: labelRect.minX + 34, y: centerY), anchor: .center
        )
        context.draw(
            Text("Shots").font(.system(size: 11, weight: .medium)).foregroundColor(Color(hex: "#BBBBBB")),
            at: CGPoint(x: labelRect.maxX - 8, y: centerY), anchor: .trailing
        )

        // Shot cards with sub-lane offsets
        let cardInset = perfSize + 6
        let cardHeight = singleLaneHeight - cardInset * 2

        for shotLabel in shotLabels {
            var cardX = originX + shotLabel.time * pxPerSec
            var cardWidth = shotLabel.displayWidth(pxPerSec: pxPerSec)
            let isDragging = shotLabel.id == draggingShotId
            let isResizing = shotLabel.id == resizingShotId

            if isDragging && !isResizing {
                cardX += (dragCurrentX - dragStartX)
            }

            if isResizing {
                cardWidth += (dragCurrentX - resizeStartX)
                cardWidth = max(TimelineLayoutConstants.minShotCardWidth, cardWidth)
            }

            if cardX + cardWidth < 0 || cardX > size.width { continue }

            let subLane = shotSubLaneAssignments[shotLabel.id] ?? 0
            let subLaneY = laneY + CGFloat(subLane) * singleLaneHeight
            let cardTopY = subLaneY + cardInset

            let shotTypeColor = Color(hex: TimelineDefaultColors.colorForShotType(shotLabel.shotType))

            let cardRect = CGRect(x: cardX + 2, y: cardTopY, width: cardWidth - 4, height: cardHeight)

            // Check if we should show preview mode (Command key held)
            var previewNSImage: NSImage? = nil

            if isCommandKeyDown, let imgPath = shotLabel.previewImagePath, let basePath = projectBasePath {
                if let cached = previewImageCache[imgPath] {
                    previewNSImage = cached
                } else {
                    let fullPath = basePath.appendingPathComponent(imgPath)
                    if let img = NSImage(contentsOf: fullPath) {
                        DispatchQueue.main.async {
                            previewImageCache[imgPath] = img
                        }
                        previewNSImage = img
                    }
                }
            }

            if isCommandKeyDown, let nsImage = previewNSImage {
                // Snap preview to full shots track height (film strip style)
                let imageAspect = nsImage.size.width / max(nsImage.size.height, 1)
                let previewPad: CGFloat = 4
                let textBarHeight: CGFloat = 16
                let previewTop = laneY + perfSize + previewPad
                let previewBottom = laneY + totalLaneHeight - perfSize - previewPad
                let previewHeight = previewBottom - previewTop
                let imageAreaHeight = previewHeight - textBarHeight
                let previewWidth = max(cardWidth - 4, imageAreaHeight * imageAspect)
                let previewX = cardX + 2
                let previewRect = CGRect(x: previewX, y: previewTop, width: previewWidth, height: previewHeight)
                let imageRect = CGRect(x: previewX, y: previewTop, width: previewWidth, height: imageAreaHeight)

                // Black background
                context.fill(
                    Path(roundedRect: previewRect, cornerRadius: 3),
                    with: .color(Color.black)
                )

                // Draw the image aspect-fill (crop to fill) within the image area
                var imgCtx = context
                imgCtx.clip(to: Path(roundedRect: imageRect, cornerRadius: 3))

                let fillWidth: CGFloat
                let fillHeight: CGFloat
                if imageAspect > imageRect.width / imageRect.height {
                    fillHeight = imageRect.height
                    fillWidth = fillHeight * imageAspect
                } else {
                    fillWidth = imageRect.width
                    fillHeight = fillWidth / imageAspect
                }
                let fillX = imageRect.midX - fillWidth / 2
                let fillY = imageRect.midY - fillHeight / 2
                let fillRect = CGRect(x: fillX, y: fillY, width: fillWidth, height: fillHeight)

                let image = Image(nsImage: nsImage)
                let resolved = imgCtx.resolve(image)
                imgCtx.draw(resolved, in: fillRect)

                // Border
                context.stroke(
                    Path(roundedRect: previewRect, cornerRadius: 3),
                    with: .color(shotTypeColor),
                    lineWidth: 2
                )

                // Shot name in text bar at bottom
                let textBarRect = CGRect(x: previewRect.minX, y: previewRect.maxY - textBarHeight, width: previewRect.width, height: textBarHeight)
                context.fill(Path(textBarRect), with: .color(Color.black.opacity(0.7)))
                var textCtx = context
                textCtx.clip(to: Path(CGRect(x: textBarRect.minX + 4, y: textBarRect.minY, width: textBarRect.width - 8, height: textBarHeight)))
                let previewText = "\(shotLabel.shotName) \u{2022} \(shotLabel.shotType)"
                textCtx.draw(
                    Text(previewText).font(.system(size: 9, weight: .bold)).foregroundColor(.white),
                    at: CGPoint(x: textBarRect.minX + 6, y: textBarRect.midY), anchor: .leading
                )
            } else if isCommandKeyDown {
                // Command held but no preview image — show placeholder snapped to track
                let previewPad: CGFloat = 4
                let previewTop = laneY + perfSize + previewPad
                let previewBottom = laneY + totalLaneHeight - perfSize - previewPad
                let placeholderRect = CGRect(x: cardRect.minX, y: previewTop, width: cardRect.width, height: previewBottom - previewTop)
                context.fill(
                    Path(roundedRect: placeholderRect, cornerRadius: 3),
                    with: .color(shotTypeColor.opacity(0.15))
                )
                context.stroke(
                    Path(roundedRect: placeholderRect, cornerRadius: 3),
                    with: .color(shotTypeColor.opacity(0.9)),
                    lineWidth: 2
                )

                // Camera icon placeholder
                context.draw(
                    Text(Image(systemName: "camera.fill")).font(.system(size: 14)).foregroundColor(shotTypeColor.opacity(0.5)),
                    at: CGPoint(x: placeholderRect.midX, y: placeholderRect.midY - 8), anchor: .center
                )

                // Shot name below icon
                var textCtx = context
                textCtx.clip(to: Path(CGRect(x: placeholderRect.minX + 2, y: placeholderRect.minY, width: placeholderRect.width - 4, height: placeholderRect.height)))
                textCtx.draw(
                    Text("\(shotLabel.shotName)").font(.system(size: 8, weight: .medium)).foregroundColor(Color(hex: "#AAAAAA")),
                    at: CGPoint(x: placeholderRect.midX, y: placeholderRect.maxY - 8), anchor: .center
                )
            } else {
                // Normal card rendering (no preview)
                context.fill(
                    Path(roundedRect: cardRect, cornerRadius: 3),
                    with: .color(shotTypeColor.opacity(isDragging ? 0.40 : 0.25))
                )
                context.stroke(
                    Path(roundedRect: cardRect, cornerRadius: 3),
                    with: .color(shotTypeColor.opacity(isDragging ? 1.0 : 0.7)),
                    lineWidth: isDragging ? 2 : 1
                )

                // Left accent bar
                let accentRect = CGRect(x: cardRect.minX, y: cardRect.minY, width: TimelineLayoutConstants.shotAccentBarWidth, height: cardRect.height)
                context.fill(Path(roundedRect: accentRect, cornerRadius: 2), with: .color(shotTypeColor))

                // Clip text to card
                var clippedCtx = context
                let textClip = CGRect(
                    x: cardRect.minX + TimelineLayoutConstants.shotAccentBarWidth + 4,
                    y: cardRect.minY,
                    width: cardRect.width - TimelineLayoutConstants.shotAccentBarWidth - 8,
                    height: cardRect.height
                )
                clippedCtx.clip(to: Path(textClip))

                let textLeft = cardRect.minX + TimelineLayoutConstants.shotAccentBarWidth + 6

                let topText = "\(shotLabel.shotName) \u{2022} \(shotLabel.shotType)"
                clippedCtx.draw(
                    Text(topText).font(.system(size: 10, weight: .bold)).foregroundColor(.white),
                    at: CGPoint(x: textLeft, y: cardRect.minY + cardRect.height * 0.30), anchor: .leading
                )

                var bottomParts: [String] = [shotLabel.cameraAngle]
                if let lens = shotLabel.lensMm { bottomParts.append("\(lens)mm") }
                let bottomText = bottomParts.joined(separator: " \u{2022} ")
                clippedCtx.draw(
                    Text(bottomText).font(.system(size: 8.5)).foregroundColor(Color(hex: "#999999")),
                    at: CGPoint(x: textLeft, y: cardRect.minY + cardRect.height * 0.72), anchor: .leading
                )

                // Video indicator icon (bottom-right of card)
                if shotLabel.hasVideo {
                    context.draw(
                        Text(Image(systemName: "video.fill")).font(.system(size: 7.5, weight: .medium)).foregroundColor(.green.opacity(0.9)),
                        at: CGPoint(x: cardRect.maxX - 10, y: cardRect.maxY - 8), anchor: .center
                    )
                }

                if let movementIcon = TimelineDefaultColors.iconForMovement(shotLabel.movement) {
                    context.draw(
                        Text(Image(systemName: movementIcon)).font(.system(size: 9)).foregroundColor(shotTypeColor.opacity(0.8)),
                        at: CGPoint(x: cardRect.maxX - 10, y: cardRect.midY - (shotLabel.hasVideo ? 4 : 0)), anchor: .center
                    )
                }
            }

            // Connection indicator: small triangle at bottom of linked shot cards
            if showShotConnections {
                let hasConnection = shotDialogueConnections.contains { $0.shotLabelId == shotLabel.id }
                if hasConnection {
                    let triX = cardX + 4  // Align with connection line offset
                    let triY = cardRect.maxY
                    let triSize: CGFloat = 5

                    let trianglePath = Path { path in
                        path.move(to: CGPoint(x: triX - triSize, y: triY))
                        path.addLine(to: CGPoint(x: triX + triSize, y: triY))
                        path.addLine(to: CGPoint(x: triX, y: triY + triSize))
                        path.closeSubpath()
                    }

                    context.fill(trianglePath, with: .color(shotTypeColor.opacity(0.8)))
                }
            }
        }
    }

    /// Draw the playhead (red vertical line with triangle handle)
    private func drawPlayhead(context: GraphicsContext, size: CGSize) {
        guard let time = playheadTime else { return }
        let x = originX + time * pxPerSec
        let rulerTop = TimelineLayoutConstants.topMargin
        let handleW = TimelineLayoutConstants.playheadHandleWidth
        let handleH = TimelineLayoutConstants.playheadHandleHeight
        let playheadColor = Color(hex: TimelineDefaultColors.playheadColor)

        // Triangle handle at ruler top
        let trianglePath = Path { path in
            path.move(to: CGPoint(x: x - handleW / 2, y: rulerTop - 2))
            path.addLine(to: CGPoint(x: x + handleW / 2, y: rulerTop - 2))
            path.addLine(to: CGPoint(x: x, y: rulerTop + handleH - 2))
            path.closeSubpath()
        }
        context.fill(trianglePath, with: .color(playheadColor))
        context.stroke(trianglePath, with: .color(playheadColor.opacity(0.8)), lineWidth: 1)

        // Vertical line from triangle tip to bottom of canvas
        context.stroke(
            Path { path in
                path.move(to: CGPoint(x: x, y: rulerTop + handleH - 2))
                path.addLine(to: CGPoint(x: x, y: size.height))
            },
            with: .color(playheadColor.opacity(0.8)),
            lineWidth: 1.5
        )

        // Time label above triangle
        let label = formatPlayheadTime(time)
        context.draw(
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(playheadColor),
            at: CGPoint(x: x, y: rulerTop - 6),
            anchor: .bottom
        )
    }

    /// Format playhead time as MM:SS.f
    private func formatPlayheadTime(_ t: CGFloat) -> String {
        let totalSec = Int(t)
        let minutes = totalSec / 60
        let secs = totalSec % 60
        let frac = Int((t - CGFloat(totalSec)) * 10)
        return String(format: "%02d:%02d.%d", minutes, secs, frac)
    }

    /// Draw user markers on the ruler baseline
    private func drawHeaderUserMarkers(context: GraphicsContext, size: CGSize) {
        guard !userMarkers.isEmpty else { return }

        let rulerBaselineY = TimelineLayoutConstants.topMargin + TimelineLayoutConstants.rulerHeight - 1
        let diamondSize = TimelineLayoutConstants.userMarkerDiamondSize
        let iconSize = TimelineLayoutConstants.userMarkerIconSize

        for marker in userMarkers {
            let x = originX + marker.time * pxPerSec
            let markerColor = Color(hex: marker.color)

            // Diamond shape on ruler baseline
            let diamondPath = Path { path in
                path.move(to: CGPoint(x: x, y: rulerBaselineY - diamondSize))
                path.addLine(to: CGPoint(x: x + diamondSize, y: rulerBaselineY))
                path.addLine(to: CGPoint(x: x, y: rulerBaselineY + diamondSize))
                path.addLine(to: CGPoint(x: x - diamondSize, y: rulerBaselineY))
                path.closeSubpath()
            }
            context.fill(diamondPath, with: .color(markerColor))
            context.stroke(diamondPath, with: .color(markerColor.opacity(0.6)), lineWidth: 1)

            // SF Symbol icon above diamond
            context.draw(
                Text(Image(systemName: marker.icon))
                    .font(.system(size: iconSize))
                    .foregroundColor(markerColor),
                at: CGPoint(x: x, y: rulerBaselineY - diamondSize - iconSize / 2 - 2),
                anchor: .center
            )

            // Label below diamond (compact)
            let labelWidth = max(30, CGFloat(marker.label.count) * 6 + 8)
            let labelHeight: CGFloat = 14
            let labelY = rulerBaselineY + diamondSize + 2

            let labelRect = CGRect(
                x: x - labelWidth / 2,
                y: labelY,
                width: labelWidth,
                height: labelHeight
            )
            context.fill(
                Path(roundedRect: labelRect, cornerRadius: 2),
                with: .color(markerColor.opacity(0.25))
            )

            var clippedCtx = context
            clippedCtx.clip(to: Path(labelRect))
            clippedCtx.draw(
                Text(marker.label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(markerColor),
                at: CGPoint(x: x, y: labelY + labelHeight / 2),
                anchor: .center
            )
        }
    }

    /// Compute non-overlapping stack levels for a set of markers.
    /// Returns an array of stack levels (0-based) parallel to the input array.
    private func computeStackLevels(
        xPositions: [CGFloat],
        labelWidths: [CGFloat]
    ) -> [Int] {
        struct MarkerSpan {
            let index: Int
            let left: CGFloat
            let right: CGFloat
        }
        // Sort by x position for greedy placement
        var spans = xPositions.enumerated().map { i, x in
            MarkerSpan(index: i, left: x - labelWidths[i] / 2, right: x + labelWidths[i] / 2 + 4)
        }
        spans.sort { $0.left < $1.left }

        var levels = [Int](repeating: 0, count: xPositions.count)
        var levelEndX: [CGFloat] = [] // rightmost occupied X per level

        for span in spans {
            var assignedLevel = -1
            for (level, endX) in levelEndX.enumerated() {
                if span.left >= endX {
                    assignedLevel = level
                    break
                }
            }
            if assignedLevel == -1 {
                assignedLevel = levelEndX.count
                levelEndX.append(span.right)
            } else {
                levelEndX[assignedLevel] = span.right
            }
            levels[span.index] = assignedLevel
        }
        return levels
    }

    /// Draw scope markers (scene/sequence boundary labels + vertical lines through header)
    private func drawScopeMarkers(context: GraphicsContext, size: CGSize) {
        let lineTop = TimelineLayoutConstants.topMargin +
                      TimelineLayoutConstants.rulerHeight +
                      TimelineLayoutConstants.rulerGap +
                      shotLaneOffset - 6
        let lineBottom = size.height

        var sequenceLevelCount = 0

        // Sequence boundaries (only in global mode) — draw first (top rows)
        if mode == .global {
            var xPositions: [CGFloat] = []
            var labelWidths: [CGFloat] = []
            var isDraggingFlags: [Bool] = []

            for boundary in sequenceBoundaries {
                var x = originX + boundary.time * pxPerSec
                let isDragging = boundary.id == draggingBoundaryId && draggingBoundaryIsSequence
                if isDragging { x += (dragCurrentX - dragBoundaryStartX) }
                xPositions.append(x)
                labelWidths.append(max(50, CGFloat(boundary.name.count) * 7 + 16))
                isDraggingFlags.append(isDragging)
            }

            let levels = computeStackLevels(xPositions: xPositions, labelWidths: labelWidths)
            sequenceLevelCount = (levels.max() ?? -1) + 1

            for (i, boundary) in sequenceBoundaries.enumerated() {
                drawBoundaryMarker(
                    context: context,
                    x: xPositions[i],
                    lineTop: lineTop,
                    lineBottom: lineBottom,
                    label: boundary.name,
                    color: TimelineDefaultColors.sequenceBoundary,
                    thick: true,
                    stackLevel: levels[i],
                    isDragging: isDraggingFlags[i]
                )
            }
        }

        // Scene boundaries
        if mode == .sequence || mode == .global {
            let baseLevel = mode == .global ? sequenceLevelCount : 0
            var xPositions: [CGFloat] = []
            var labelWidths: [CGFloat] = []
            var isDraggingFlags: [Bool] = []

            for boundary in sceneBoundaries {
                var x = originX + boundary.time * pxPerSec
                let isDragging = boundary.id == draggingBoundaryId && !draggingBoundaryIsSequence
                if isDragging { x += (dragCurrentX - dragBoundaryStartX) }
                xPositions.append(x)
                labelWidths.append(max(50, CGFloat(boundary.name.count) * 7 + 16))
                isDraggingFlags.append(isDragging)
            }

            let levels = computeStackLevels(xPositions: xPositions, labelWidths: labelWidths)

            for (i, boundary) in sceneBoundaries.enumerated() {
                drawBoundaryMarker(
                    context: context,
                    x: xPositions[i],
                    lineTop: lineTop,
                    lineBottom: lineBottom,
                    label: boundary.name,
                    color: TimelineDefaultColors.sceneBoundary,
                    thick: false,
                    stackLevel: baseLevel + levels[i],
                    isDragging: isDraggingFlags[i]
                )
            }
        }
    }

    /// Draw a boundary marker with label in top margin area
    private func drawBoundaryMarker(
        context: GraphicsContext,
        x: CGFloat,
        lineTop: CGFloat,
        lineBottom: CGFloat,
        label: String,
        color: String,
        thick: Bool,
        stackLevel: Int,
        isDragging: Bool = false
    ) {
        let markerColor = Color(hex: color)

        // Vertical line through shot lane and tracks area
        context.stroke(
            Path { path in
                path.move(to: CGPoint(x: x, y: lineTop))
                path.addLine(to: CGPoint(x: x, y: lineBottom))
            },
            with: .color(markerColor.opacity(isDragging ? 0.5 : 1.0)),
            lineWidth: thick ? 2.2 : 1.4
        )

        // Label box in the top margin area
        let labelHeight: CGFloat = 18
        let labelWidth = max(50, CGFloat(label.count) * 7 + 16)
        let labelY: CGFloat = 4 + CGFloat(stackLevel) * (labelHeight + 4)
        let labelBottom = labelY + labelHeight

        // Connector line from label bottom down to the ruler baseline
        let rulerBaseline = TimelineLayoutConstants.topMargin + TimelineLayoutConstants.rulerHeight - 1
        if labelBottom < rulerBaseline {
            let connectorStyle = StrokeStyle(lineWidth: 1, dash: [3, 2])
            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: x, y: labelBottom + 2))
                    path.addLine(to: CGPoint(x: x, y: rulerBaseline))
                },
                with: .color(markerColor.opacity(isDragging ? 0.4 : 0.6)),
                style: connectorStyle
            )
            // Small tick mark at the ruler baseline
            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: x - 3, y: rulerBaseline))
                    path.addLine(to: CGPoint(x: x + 3, y: rulerBaseline))
                },
                with: .color(markerColor.opacity(isDragging ? 0.5 : 0.8)),
                lineWidth: 1.5
            )
        }

        let labelRect = CGRect(
            x: x - labelWidth / 2,
            y: labelY,
            width: labelWidth,
            height: labelHeight
        )

        context.fill(
            Path(roundedRect: labelRect, cornerRadius: 3),
            with: .color(markerColor.opacity(isDragging ? 0.7 : 0.9))
        )
        context.stroke(
            Path(roundedRect: labelRect, cornerRadius: 3),
            with: .color(markerColor),
            lineWidth: isDragging ? 2.5 : 1.5
        )

        context.draw(
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white),
            at: CGPoint(x: x, y: labelY + labelHeight / 2),
            anchor: .center
        )
    }
}

// MARK: - Right-Click Overlay

/// Transparent NSView overlay that intercepts only right-click events via a local event monitor.
/// Uses hitTest → nil so it never blocks left-click / drag events from reaching SwiftUI.
private struct RightClickOverlay: NSViewRepresentable {
    var onRightClick: (CGPoint, NSView) -> Void

    func makeNSView(context: Context) -> RightClickNSView {
        let view = RightClickNSView()
        view.onRightClick = onRightClick
        view.installMonitor()
        return view
    }

    func updateNSView(_ nsView: RightClickNSView, context: Context) {
        nsView.onRightClick = onRightClick
    }

    class RightClickNSView: NSView {
        var onRightClick: ((CGPoint, NSView) -> Void)?
        private var monitor: Any?

        // Never intercept hit-testing — all left-click/drag events pass through to SwiftUI
        override func hitTest(_ point: NSPoint) -> NSView? {
            return nil
        }

        func installMonitor() {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
                guard let self = self, let window = self.window, event.window === window else {
                    return event
                }
                let locationInView = self.convert(event.locationInWindow, from: nil)
                // Only handle if the click is within our bounds
                if self.bounds.contains(locationInView) {
                    let flippedY = self.bounds.height - locationInView.y
                    let point = CGPoint(x: locationInView.x, y: flippedY)
                    self.onRightClick?(point, self)
                }
                return event
            }
        }

        deinit {
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}

// MARK: - Command Key Monitor

/// Invisible overlay that monitors Command key press/release via flagsChanged events
private struct CommandKeyMonitor: NSViewRepresentable {
    @Binding var isCommandKeyDown: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isCommandKeyDown: $isCommandKeyDown)
    }

    func makeNSView(context: Context) -> CommandKeyNSView {
        let view = CommandKeyNSView()
        view.coordinator = context.coordinator
        view.installMonitor()
        return view
    }

    func updateNSView(_ nsView: CommandKeyNSView, context: Context) {
        nsView.coordinator = context.coordinator
    }

    class Coordinator {
        var isCommandKeyDown: Binding<Bool>
        init(isCommandKeyDown: Binding<Bool>) {
            self.isCommandKeyDown = isCommandKeyDown
        }
    }

    class CommandKeyNSView: NSView {
        weak var coordinator: Coordinator?
        private var monitor: Any?

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        func installMonitor() {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
                let isCommand = event.modifierFlags.contains(.command)
                DispatchQueue.main.async {
                    self?.coordinator?.isCommandKeyDown.wrappedValue = isCommand
                }
                return event
            }
        }

        deinit {
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}

// MARK: - Marker Menu Handler

/// NSObject target for NSMenu items — holds a closure for the menu action
private class MarkerMenuHandler: NSObject {
    let action: () -> Void
    init(_ action: @escaping () -> Void) {
        self.action = action
    }
    @objc func execute() {
        action()
    }
}

// MARK: - Marker Config Popover

/// Popover for creating or editing a user marker (name, icon, color)
struct MarkerConfigPopover: View {
    @Binding var markerLabel: String
    @Binding var markerIcon: String
    @Binding var markerColor: String

    var isEditing: Bool = false
    var onSave: () -> Void
    var onCancel: () -> Void

    private let iconOptions = [
        "flag.fill", "star.fill", "bolt.fill", "lightbulb.fill",
        "camera.fill", "music.note", "exclamationmark.triangle.fill", "bookmark.fill",
        "mappin", "heart.fill", "bell.fill", "tag.fill"
    ]

    private let colorOptions = [
        "#FF5F5F", "#FF9500", "#FFD60A", "#34C759",
        "#007AFF", "#AF52DE", "#FF2D55"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isEditing ? "Edit Marker" : "Add Marker")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)

            // Name field
            HStack {
                Text("Name:")
                    .font(.system(size: 11))
                    .foregroundColor(Color(nsColor: .secondaryLabelColor))
                    .frame(width: 40, alignment: .trailing)
                TextField("Marker", text: $markerLabel)
                    .textFieldStyle(.roundedBorder)
            }

            // Icon grid
            VStack(alignment: .leading, spacing: 4) {
                Text("Icon:")
                    .font(.system(size: 11))
                    .foregroundColor(Color(nsColor: .secondaryLabelColor))

                LazyVGrid(columns: Array(repeating: GridItem(.fixed(32), spacing: 4), count: 6), spacing: 4) {
                    ForEach(iconOptions, id: \.self) { icon in
                        Button(action: { markerIcon = icon }) {
                            Image(systemName: icon)
                                .font(.system(size: 13))
                                .foregroundColor(markerIcon == icon ? .white : Color(nsColor: .secondaryLabelColor))
                                .frame(width: 28, height: 28)
                                .background(markerIcon == icon ? Color(hex: markerColor).opacity(0.7) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(markerIcon == icon ? Color(hex: markerColor) : Color(nsColor: .separatorColor), lineWidth: markerIcon == icon ? 2 : 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Color swatches
            VStack(alignment: .leading, spacing: 4) {
                Text("Color:")
                    .font(.system(size: 11))
                    .foregroundColor(Color(nsColor: .secondaryLabelColor))

                HStack(spacing: 6) {
                    ForEach(colorOptions, id: \.self) { color in
                        Button(action: { markerColor = color }) {
                            Circle()
                                .fill(Color(hex: color))
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: markerColor == color ? 2.5 : 0)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Buttons
            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button(isEditing ? "Update" : "Add") { onSave() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 260)
    }
}

// MARK: - Instant Marker Tooltip

/// Floating tooltip window that appears instantly on marker hover
private class MarkerTooltip {
    static let shared = MarkerTooltip()

    private var window: NSWindow?
    private var currentText: String?

    private init() {}

    func show(text: String, near point: NSPoint) {
        // Skip if already showing the same text
        if currentText == text, window?.isVisible == true { return }
        hide()
        currentText = text

        let textField = NSTextField(labelWithString: text)
        textField.font = NSFont.systemFont(ofSize: 11)
        textField.textColor = NSColor.labelColor
        textField.backgroundColor = NSColor.windowBackgroundColor
        textField.isBordered = false
        textField.sizeToFit()

        let padding: CGFloat = 8
        let contentSize = NSSize(
            width: textField.frame.width + padding * 2,
            height: textField.frame.height + padding
        )
        textField.frame.origin = NSPoint(x: padding, y: padding / 2)

        let win = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        win.backgroundColor = NSColor.windowBackgroundColor
        win.isOpaque = false
        win.hasShadow = true
        win.level = .floating
        win.ignoresMouseEvents = true
        win.contentView?.wantsLayer = true
        win.contentView?.layer?.cornerRadius = 4
        win.contentView?.addSubview(textField)

        let screenPoint = NSPoint(
            x: point.x - contentSize.width / 2,
            y: point.y - contentSize.height - 20
        )
        win.setFrameOrigin(screenPoint)
        win.orderFront(nil)

        self.window = win
    }

    func hide() {
        window?.orderOut(nil)
        window = nil
        currentText = nil
    }
}

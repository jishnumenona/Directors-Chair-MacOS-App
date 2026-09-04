// DirectorsChairViews/Cinematography/ShotSketch.swift
//
// DC-0109/0110/0111 — the STUDIO: the one surface for authoring a shot
// preview. It unifies what used to be three tools (owner 2026-09-01:
// "combine annotate, edit prompt and sketch into one"):
//   • SKETCH — pen and a wide translucent MARKER for areas;
//   • NOTES — numbered spot instructions (the annotation pins), with
//     @ # $ & mentions;
//   • ELEMENTS — the story library, dragged onto shapes as numbered tags;
//   • PROMPT — the exact composed text lives in the right panel, always
//     visible, customizable before sending.
// One canvas, a left tool rail, a Library|Prompt panel, generate in place,
// iterate on the result. The prompt contract is probe-proven — see
// SketchStudioComposer and the sketch-studio-prompt-contract memory.

import DirectorsChairCore
import DirectorsChairServices
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Strokes

/// One drawn stroke, points normalised (0…1, top-left origin).
public struct SketchStroke: Equatable, Sendable, Codable {
    public enum Style: String, Codable, Sendable {
        /// Opaque ink — outlines and shapes.
        case pen
        /// Wide translucent ink — shading and highlighting whole areas.
        case marker
    }
    public var points: [CGPoint]
    /// Line width as a fraction of the canvas HEIGHT.
    public var width: CGFloat
    public var isEraser: Bool
    public var style: Style

    public init(points: [CGPoint] = [], width: CGFloat,
                isEraser: Bool = false, style: Style = .pen) {
        self.points = points
        self.width = width
        self.isEraser = isEraser
        self.style = style
    }

    enum CodingKeys: String, CodingKey { case points, width, isEraser, style }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        points = try container.decode([CGPoint].self, forKey: .points)
        width = try container.decode(CGFloat.self, forKey: .width)
        isEraser = (try? container.decodeIfPresent(Bool.self, forKey: .isEraser)) ?? false
        style = (try? container.decodeIfPresent(Style.self, forKey: .style)) ?? .pen
    }

    var inkAlpha: CGFloat { style == .marker ? 0.45 : 1.0 }
}

// MARK: - Placed tags, notes & library elements

/// A story element the user placed on (or attached to) the sketch.
public struct StudioElement: Equatable, Codable, Identifiable, Sendable {
    public var id: UUID
    /// "character" | "costume" | "prop" | "location" | "shot".
    public var kind: String
    public var name: String
    /// Project-relative picture path (resolved at generate time).
    public var imagePath: String
    /// Tag centre, normalised; nil = an untagged general reference.
    public var x: Double?
    public var y: Double?

    public init(id: UUID = UUID(), kind: String, name: String, imagePath: String,
                x: Double? = nil, y: Double? = nil) {
        self.id = id
        self.kind = kind
        self.name = name
        self.imagePath = imagePath
        self.x = x
        self.y = y
    }

    var isPlaced: Bool { x != nil && y != nil }
}

/// A written instruction pinned to a spot (the annotation pins, unified).
public struct StudioNote: Equatable, Codable, Identifiable, Sendable {
    public var id: UUID
    public var text: String
    public var x: Double
    public var y: Double

    public init(id: UUID = UUID(), text: String, x: Double, y: Double) {
        self.id = id
        self.text = text
        self.x = x
        self.y = y
    }
}

/// The studio's saved state — reopening the sketch restores everything.
struct SketchStudioDocument: Codable {
    var strokes: [SketchStroke] = []
    var elements: [StudioElement] = []
    var notes: [StudioNote] = []
    /// nil = blank canvas; "preview" = the shot's current preview;
    /// otherwise a project-relative picture path.
    var base: String?
    var prompt: String = ""

    enum CodingKeys: String, CodingKey { case strokes, elements, notes, base, prompt }
    init(strokes: [SketchStroke], elements: [StudioElement], notes: [StudioNote],
         base: String?, prompt: String) {
        self.strokes = strokes
        self.elements = elements
        self.notes = notes
        self.base = base
        self.prompt = prompt
    }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        strokes = (try? container.decodeIfPresent([SketchStroke].self, forKey: .strokes)) ?? []
        elements = (try? container.decodeIfPresent([StudioElement].self, forKey: .elements)) ?? []
        notes = (try? container.decodeIfPresent([StudioNote].self, forKey: .notes)) ?? []
        base = try? container.decodeIfPresent(String.self, forKey: .base)
        prompt = (try? container.decodeIfPresent(String.self, forKey: .prompt)) ?? ""
    }
}

// MARK: - Pure renderer (tested)

public enum SketchRender {
    /// Black-on-white strokes at `size` — kept for the simple sketch path.
    public static func png(strokes: [SketchStroke], size: CGSize) -> Data? {
        composedPNG(strokes: strokes, tags: [], size: size, base: nil, firstTagNumber: 2)
    }

    /// What the model sees: the base picture (edit mode) or paper, the
    /// strokes (marker strokes translucent), and a red numbered badge at
    /// every tag — numbering starts at `firstTagNumber` so TAG NUMBER ==
    /// ATTACHED IMAGE NUMBER (notes continue the same sequence).
    public static func composedPNG(strokes: [SketchStroke],
                                   tags: [(x: Double, y: Double)],
                                   size: CGSize,
                                   base: Data?,
                                   firstTagNumber: Int) -> Data? {
        let width = Int(size.width), height = Int(size.height)
        guard width > 0, height > 0,
              let context = CGContext(data: nil, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        if let base,
           let source = CGImageSourceCreateWithData(base as CFData, nil),
           let image = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        context.setLineCap(.round)
        context.setLineJoin(.round)
        for stroke in strokes where stroke.points.count > 1 {
            context.setStrokeColor(stroke.isEraser
                ? CGColor(red: 1, green: 1, blue: 1, alpha: 1)
                : CGColor(red: 0, green: 0, blue: 0, alpha: stroke.inkAlpha))
            context.setLineWidth(max(1, stroke.width * size.height))
            let mapped = stroke.points.map {
                CGPoint(x: $0.x * size.width, y: (1 - $0.y) * size.height)
            }
            context.beginPath()
            context.move(to: mapped[0])
            for point in mapped.dropFirst() { context.addLine(to: point) }
            context.strokePath()
        }
        let badgeRadius = max(14, size.height * 0.035)
        for (index, tag) in tags.enumerated() {
            let centre = CGPoint(x: tag.x * size.width, y: (1 - tag.y) * size.height)
            context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
            context.fillEllipse(in: CGRect(x: centre.x - badgeRadius, y: centre.y - badgeRadius,
                                           width: badgeRadius * 2, height: badgeRadius * 2))
            drawNumber(index + firstTagNumber, at: centre, size: badgeRadius * 1.2, in: context)
        }
        guard let image = context.makeImage() else { return nil }
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        return CGImageDestinationFinalize(dest) ? data as Data : nil
    }

    private static func drawNumber(_ number: Int, at point: CGPoint, size: CGFloat, in context: CGContext) {
        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, size, nil)
        let attributes: [CFString: Any] = [
            kCTFontAttributeName: font,
            kCTForegroundColorAttributeName: CGColor(red: 1, green: 1, blue: 1, alpha: 1),
        ]
        guard let string = CFAttributedStringCreate(nil, String(number) as CFString, attributes as CFDictionary) else { return }
        let line = CTLineCreateWithAttributedString(string)
        let bounds = CTLineGetBoundsWithOptions(line, [.useOpticalBounds])
        context.saveGState()
        context.textMatrix = .identity
        context.textPosition = CGPoint(x: point.x - bounds.midX, y: point.y - bounds.midY)
        CTLineDraw(line, context)
        context.restoreGState()
    }

    public static let referenceLabel = "sketch:Shot sketch"

    /// Kept for the reference-prefix path (other surfaces may attach a plain
    /// sketch); the studio composes its own complete prompt instead.
    public static func promptClause(imageNumber: Int) -> String {
        "- Image \(imageNumber) is a rough hand-drawn PLANNING sketch of this shot's composition — only a map: "
        + "each crude shape stands for a real thing (a stick figure is a person, a box is a vehicle or building, "
        + "a circle is the sun or a face). Place each real subject where its shape sits in the sketch and match "
        + "the sketched framing. Do NOT copy, trace or overlay the sketch's lines — none of its ink may appear "
        + "in the result."
    }
}

// MARK: - The studio

public struct ShotSketchStudio: View {
    enum Tool: String, CaseIterable {
        case pen, marker, note, eraser
        var symbol: String {
            switch self {
            case .pen: return "pencil"
            case .marker: return "highlighter"
            case .note: return "text.bubble"
            case .eraser: return "eraser"
            }
        }
        var title: String {
            switch self {
            case .pen: return "Pen — outlines and shapes"
            case .marker: return "Marker — shade or highlight a whole area"
            case .note: return "Note — click a spot and say what happens there"
            case .eraser: return "Eraser"
            }
        }
    }

    // Project data for the library.
    let characters: [DirectorsChairCore.Character]
    let locations: [Location]
    let props: [Prop]
    let shots: [Shot]
    let currentShotId: Int
    let projectDirectory: URL?
    let seedPrompt: String
    let currentPreviewPath: String?
    let documentURL: URL?
    let onKeep: (Data) -> Void
    let onSketchSaved: (Data) -> Void
    /// Double-click on a library element: (kind, id) — the shot page routes
    /// it to the element's Story Design page (⌘[ comes back).
    let onOpenElement: ((String, String) -> Void)?

    @Environment(\.dismiss) private var dismiss

    // Drawing state.
    @State private var strokes: [SketchStroke] = []
    @State private var current: SketchStroke?
    @State private var tool: Tool = .pen
    @State private var penWidth: CGFloat = 0.008
    @State private var showingSizePopover = false
    // Elements & notes.
    @State private var elements: [StudioElement] = []
    @State private var notes: [StudioNote] = []
    @State private var editingNoteId: UUID?
    @State private var dragOffsets: [UUID: CGSize] = [:]
    // Base.
    @State private var base: String?           // nil | "preview" | relative path
    @State private var baseImage: NSImage?
    @State private var dimBase = false
    // Prompt & generation.
    @State private var promptText: String = ""
    @State private var customPrompt: String = ""
    @State private var useCustomPrompt = false
    @State private var isGenerating = false
    @State private var resultData: Data?
    /// What the result is compared against: the untouched base (edit
    /// mode) or the marked sketch (create mode).
    @State private var beforeImage: NSImage?
    @State private var showingBefore = false
    @State private var beforePinned = false
    @State private var beforePressStart: Date?
    @State private var resultImage: NSImage?
    @State private var errorText: String?
    // Panels.
    @State private var rightTab = "library"
    @State private var librarySearch = ""
    @State private var studioSize: CGSize = ShotSketchStudio.hostSize()
    @State private var hoveredRow: LibraryRow?
    @State private var hoverTask: Task<Void, Never>?
    @State private var hoveredTool: Tool?
    @State private var hoveringBrushSize = false
    /// ⌘↩ generates from ANY focus — a focused NSTextView (scene field,
    /// note, custom prompt, search) swallows SwiftUI shortcuts, the same
    /// bug the annotation editor's Apply hit (owner 2026-08-30, 2026-09-04).
    @State private var commandReturnMonitor: Any?

    public init(characters: [DirectorsChairCore.Character], locations: [Location],
                props: [Prop], shots: [Shot], currentShotId: Int,
                projectDirectory: URL?, seedPrompt: String,
                currentPreviewPath: String?, documentURL: URL?,
                onKeep: @escaping (Data) -> Void,
                onSketchSaved: @escaping (Data) -> Void,
                onOpenElement: ((String, String) -> Void)? = nil) {
        self.characters = characters
        self.locations = locations
        self.props = props
        self.shots = shots
        self.currentShotId = currentShotId
        self.projectDirectory = projectDirectory
        self.seedPrompt = seedPrompt
        self.currentPreviewPath = currentPreviewPath
        self.documentURL = documentURL
        self.onKeep = onKeep
        self.onSketchSaved = onSketchSaved
        self.onOpenElement = onOpenElement
    }

    /// Nearly the host window — the studio is a workspace, not a dialog.
    static func hostSize() -> CGSize {
        let host = (NSApp.mainWindow ?? NSApp.windows.first { $0.isVisible && !$0.isSheet })?.frame.size
            ?? NSScreen.main?.visibleFrame.size
            ?? CGSize(width: 1500, height: 940)
        return CGSize(width: max(1120, host.width * 0.94), height: max(720, host.height * 0.92))
    }

    private var mode: SketchStudioInput.Mode { base == nil ? .create : .edit }
    private var placed: [StudioElement] { elements.filter(\.isPlaced) }
    private var generals: [StudioElement] { elements.filter { !$0.isPlaced } }
    /// Story elements the scene text or a note MENTIONS (@ character,
    /// # location, $ prop, & shot) that aren't placed or attached already —
    /// their pictures ride along as plain references, exactly like the shot
    /// description's mentions do (owner 2026-09-04).
    private var mentioned: [StudioElement] {
        var out: [StudioElement] = []
        for text in [promptText] + notes.map(\.text) {
            for mention in MentionParser.mentions(in: text, characters: characters,
                                                  locations: locations, props: props, shots: shots) {
                guard let path = mention.imagePath, !path.isEmpty else { continue }
                let kind: String
                switch mention.kind {
                case .character: kind = "character"
                case .location: kind = "location"
                case .prop: kind = "prop"
                case .shot: kind = "shot"
                }
                if kind == "shot", mention.name == "Shot #\(currentShotId)" { continue }
                if elements.contains(where: { $0.kind == kind && $0.name == mention.name }) { continue }
                if out.contains(where: { $0.kind == kind && $0.name == mention.name }) { continue }
                out.append(StudioElement(kind: kind, name: mention.name, imagePath: path))
            }
        }
        return out
    }
    static let mentionLegend = "@ character · # location · $ prop · & shot preview"
    private var firstTag: Int { SketchStudioComposer.firstTagNumber(for: mode) }
    /// Notes' badge numbers CONTINUE after the placed elements'.
    private var firstNoteTag: Int { firstTag + placed.count }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.3)
            HStack(spacing: 0) {
                toolRail
                Divider().opacity(0.3)
                canvasColumn
                Divider().opacity(0.3)
                rightPanel
                    .frame(width: 330)
            }
            Divider().opacity(0.3)
            footer
        }
        .frame(width: studioSize.width, height: studioSize.height)
        .background(Color(hex: "#232323"))
        .onAppear {
            restore()
            commandReturnMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                guard event.modifierFlags.contains(.command),
                      event.keyCode == 36 || event.keyCode == 76 else { return event }
                if canGenerate { generate() }
                return nil
            }
        }
        .onDisappear {
            persist()
            if let monitor = commandReturnMonitor {
                NSEvent.removeMonitor(monitor)
                commandReturnMonitor = nil
            }
        }
        .overlay(alignment: .topTrailing) { hoverPreviewPanel }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles.rectangle.stack").foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text("STUDIO").font(.system(size: 11, weight: .bold)).tracking(1.6)
                    .foregroundColor(.white.opacity(0.9))
                Text(mode == .create
                     ? "New picture — sketch it, note it, place your story elements, generate."
                     : "Editing the picture — everything you don't mark stays exactly as it is.")
                    .font(.system(size: 10)).foregroundColor(.gray)
            }
            Spacer()
            // What the work sits on.
            Picker("", selection: Binding(
                get: { base == nil ? 0 : 1 },
                set: { setBase($0 == 0 ? nil : (currentPreviewPath != nil ? "preview" : base)) }
            )) {
                Label("New picture", systemImage: "plus.square.on.square").tag(0)
                Label("Edit picture", systemImage: "photo").tag(1)
            }
            .pickerStyle(.segmented).labelsHidden().frame(width: 250)
            .disabled(currentPreviewPath == nil && base == nil)
            .help("New picture generates from scratch; Edit changes the base picture (right-click a shot or location in the library for other bases)")
            .accessibilityIdentifier("studio-base")
            Button { _ = strokes.popLast() } label: { Image(systemName: "arrow.uturn.backward") }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(strokes.isEmpty)
                .help("Undo the last stroke (⌘Z)")
            Button("Clear ink") { strokes.removeAll() }
                .disabled(strokes.isEmpty)
                .help("Remove every stroke (notes and elements stay)")
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(Color(hex: "#1C1C1C"))
    }

    // MARK: Tool rail

    private var toolRail: some View {
        VStack(spacing: 6) {
            ForEach(Tool.allCases, id: \.self) { candidate in
                Button { tool = candidate } label: {
                    Image(systemName: candidate.symbol)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(tool == candidate ? .white : .gray)
                        .frame(width: 40, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(tool == candidate ? Color.accentColor.opacity(0.85) : Color.white.opacity(0.04))
                        )
                }
                .buttonStyle(.plain)
                .onHover { hoveredTool = $0 ? candidate : nil }
                .help(candidate.title)
                .accessibilityIdentifier("studio-tool-\(candidate.rawValue)")
            }
            Divider().frame(width: 30).opacity(0.3).padding(.vertical, 4)
            // Brush size — a live dot plus a slider.
            Button { showingSizePopover = true } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04))
                    Circle().fill(Color.white.opacity(0.85))
                        .frame(width: min(26, max(4, penWidth * 700)),
                               height: min(26, max(4, penWidth * 700)))
                }
                .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .onHover { hoveringBrushSize = $0 }
            .help("Brush size")
            .popover(isPresented: $showingSizePopover, arrowEdge: .trailing) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Brush size").font(.system(size: 11, weight: .semibold))
                    Slider(value: $penWidth, in: 0.002...0.06)
                        .frame(width: 180)
                    HStack {
                        ForEach([0.004, 0.010, 0.024, 0.045], id: \.self) { preset in
                            Button { penWidth = preset } label: {
                                Circle().fill(Color.primary.opacity(0.8))
                                    .frame(width: max(4, preset * 500), height: max(4, preset * 500))
                                    .frame(width: 30, height: 30)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(12)
            }
            Spacer()
        }
        .padding(.vertical, 10)
        .frame(width: 56)
        .background(Color(hex: "#1C1C1C"))
        .overlay(alignment: .topLeading) { railHoverLabel }
    }

    /// The tool's name, instantly, beside whichever rail button the
    /// pointer is on (system tooltips take a second to appear).
    @ViewBuilder
    private var railHoverLabel: some View {
        let toolIndex = hoveredTool.flatMap { Tool.allCases.firstIndex(of: $0) }
        let title = hoveredTool?.title ?? (hoveringBrushSize ? "Brush size" : nil)
        if let title {
            // Rail geometry: 10pt top padding, 40pt buttons at a 6pt pitch,
            // then the divider block before the size button.
            let row = toolIndex.map(Double.init) ?? Double(Tool.allCases.count) + 0.4
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 9).padding(.vertical, 5)
                .background(Capsule().fill(Color(hex: "#111111").opacity(0.96)))
                .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                .fixedSize()
                .offset(x: 60, y: 10 + row * 46 + 8)
                .allowsHitTesting(false)
                .transition(.opacity)
        }
    }

    // MARK: Canvas

    private var canvasColumn: some View {
        VStack(spacing: 8) {
            ZStack {
                if let resultImage {
                    resultPane(resultImage)
                } else {
                    drawingCanvas
                }
            }
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 12).padding(.top, 12)
            promptRow
        }
    }

    private var drawingCanvas: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Color.white
                if let baseImage {
                    Image(nsImage: baseImage)
                        .resizable().scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .opacity(dimBase ? 0.35 : 1.0)
                }
                Canvas { context, size in
                    for stroke in strokes + (current.map { [$0] } ?? []) {
                        guard stroke.points.count > 1 else { continue }
                        var path = Path()
                        let pts = stroke.points.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
                        path.move(to: pts[0])
                        for point in pts.dropFirst() { path.addLine(to: point) }
                        context.stroke(path,
                                       with: .color(stroke.isEraser
                                                    ? .white
                                                    : .black.opacity(stroke.inkAlpha)),
                                       style: StrokeStyle(lineWidth: max(1, stroke.width * size.height),
                                                          lineCap: .round, lineJoin: .round))
                    }
                }
                ForEach(Array(placed.enumerated()), id: \.element.id) { index, element in
                    tagChip(element, number: index + firstTag)
                        .position(x: (element.x ?? 0) * geo.size.width
                                    + (dragOffsets[element.id]?.width ?? 0),
                                  y: (element.y ?? 0) * geo.size.height
                                    + (dragOffsets[element.id]?.height ?? 0))
                        .gesture(chipDrag(id: element.id, in: geo.size) { delta in
                            move(element, by: delta)
                        })
                }
                ForEach(Array(notes.enumerated()), id: \.element.id) { index, note in
                    noteChip(note, number: index + firstNoteTag)
                        .position(x: note.x * geo.size.width
                                    + (dragOffsets[note.id]?.width ?? 0),
                                  y: note.y * geo.size.height
                                    + (dragOffsets[note.id]?.height ?? 0))
                        .gesture(chipDrag(id: note.id, in: geo.size) { delta in
                            moveNote(note, by: delta)
                        })
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        guard tool != .note else { return }
                        let point = normalised(value.location, in: geo.size)
                        if current == nil {
                            current = SketchStroke(points: [point],
                                                   width: tool == .pen ? penWidth : penWidth * 3,
                                                   isEraser: tool == .eraser,
                                                   style: tool == .marker ? .marker : .pen)
                        } else {
                            current?.points.append(point)
                        }
                    }
                    .onEnded { _ in
                        if let stroke = current, stroke.points.count > 1 { strokes.append(stroke) }
                        current = nil
                    }
            )
            .onTapGesture(count: 1, coordinateSpace: .local) { location in
                guard tool == .note else { return }
                let point = normalised(location, in: geo.size)
                let note = StudioNote(text: "", x: point.x, y: point.y)
                notes.append(note)
                editingNoteId = note.id
            }
            .onDrop(of: [.plainText], isTargeted: nil) { providers, location in
                drop(providers: providers, at: normalised(location, in: geo.size))
            }
            .accessibilityIdentifier("studio-canvas")
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#3A3A3A"), lineWidth: 1))
        .overlay(alignment: .bottomLeading) {
            if baseImage != nil {
                Toggle("Dim picture while drawing", isOn: $dimBase)
                    .toggleStyle(.checkbox).font(.system(size: 10))
                    .padding(6)
                    .background(Color.black.opacity(0.5)).cornerRadius(5)
                    .padding(8)
            }
        }
    }

    private func chipDrag(id: UUID, in size: CGSize,
                          onEnd: @escaping (CGPoint) -> Void) -> some Gesture {
        DragGesture()
            .onChanged { dragOffsets[id] = $0.translation }
            .onEnded { value in
                onEnd(CGPoint(x: value.translation.width / size.width,
                              y: value.translation.height / size.height))
                dragOffsets[id] = nil
            }
    }

    /// A placed element: numbered badge + thumbnail + name.
    private func tagChip(_ element: StudioElement, number: Int) -> some View {
        HStack(spacing: 5) {
            ZStack {
                Circle().fill(Color.red)
                Text("\(number)").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
            }
            .frame(width: 18, height: 18)
            if let dir = projectDirectory {
                AsyncThumbnail(url: dir.appendingPathComponent(element.imagePath), displaySize: 22) {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 22, height: 22)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            Text(element.name).font(.system(size: 9, weight: .medium)).lineLimit(1)
            Button { remove(element) } label: {
                Image(systemName: "xmark").font(.system(size: 7, weight: .bold))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(Capsule().fill(Color(hex: "#1E1E1E").opacity(0.92)))
        .overlay(Capsule().stroke(Color.red.opacity(0.6), lineWidth: 1))
        .foregroundColor(.white)
        .contextMenu { Button("Remove", role: .destructive) { remove(element) } }
        .help("\(element.kind) “\(element.name)” goes where this tag sits — drag to move")
        .accessibilityIdentifier("studio-tag-\(element.name)")
    }

    /// A spot instruction: amber badge + the words; click to edit.
    private func noteChip(_ note: StudioNote, number: Int) -> some View {
        HStack(spacing: 5) {
            ZStack {
                Circle().fill(Color.orange)
                Text("\(number)").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
            }
            .frame(width: 18, height: 18)
            Text(note.text.isEmpty ? "say what happens here…" : note.text)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(note.text.isEmpty ? .gray : .white)
                .lineLimit(1)
                .frame(maxWidth: 170, alignment: .leading)
            Button { notes.removeAll { $0.id == note.id } } label: {
                Image(systemName: "xmark").font(.system(size: 7, weight: .bold))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(Capsule().fill(Color(hex: "#1E1E1E").opacity(0.92)))
        .overlay(Capsule().stroke(Color.orange.opacity(0.7), lineWidth: 1))
        .foregroundColor(.white)
        .onTapGesture { editingNoteId = note.id }
        .contextMenu { Button("Remove", role: .destructive) { notes.removeAll { $0.id == note.id } } }
        .popover(isPresented: Binding(get: { editingNoteId == note.id },
                                      set: { if !$0 { editingNoteId = nil } }),
                 arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text("What happens at this spot?").font(.system(size: 10, weight: .semibold))
                MentionTextView(text: Binding(
                        get: { notes.first(where: { $0.id == note.id })?.text ?? "" },
                        set: { text in
                            if let i = notes.firstIndex(where: { $0.id == note.id }) { notes[i].text = text }
                        }),
                    characters: characters, locations: locations, props: props,
                    continuityShots: shots, projectDirectory: projectDirectory,
                    placeholder: "What happens here? (\(Self.mentionLegend))",
                    onOpenMention: nil,
                    submitsOnReturn: true, onSubmit: { editingNoteId = nil })
                    .frame(width: 300, height: 54)
                HStack {
                    Spacer()
                    Button("Done") { editingNoteId = nil }.keyboardShortcut(.defaultAction)
                }
            }
            .padding(10)
        }
        .help("A numbered instruction for this exact spot — drag to move, click to edit")
        .accessibilityIdentifier("studio-note-\(number)")
    }

    private func resultPane(_ image: NSImage) -> some View {
        ZStack(alignment: .bottom) {
            Image(nsImage: (showingBefore ? beforeImage : nil) ?? image)
                .resizable().scaledToFit()
                .overlay(alignment: .topLeading) {
                    Text(showingBefore ? "BEFORE" : "AFTER")
                        .font(.system(size: 10, weight: .bold)).tracking(1.2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(showingBefore ? Color.orange.opacity(0.85)
                                                                 : Color.black.opacity(0.55)))
                        .padding(10)
                }
            HStack(spacing: 10) {
                beforeAfterControl
                Divider().frame(height: 18).opacity(0.4)
                Button {
                    if let data = resultData { onKeep(data) }
                    continueOnResult()
                } label: { Label("Keep as shot preview", systemImage: "checkmark.circle.fill") }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("studio-keep")
                Button { continueOnResult() } label: {
                    Label("Refine this", systemImage: "pencil.and.outline")
                }
                .help("Make this picture the base and mark the next round of changes on it")
                Button("Discard", role: .destructive) { clearResult() }
            }
            .padding(10)
            .background(Color.black.opacity(0.65)).cornerRadius(10)
            .padding(.bottom, 12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .background {
            // ⌘B toggles the comparison from the keyboard.
            Button("") { setBeforePinned(!beforePinned) }
                .keyboardShortcut("b", modifiers: .command)
                .opacity(0).frame(width: 0, height: 0)
        }
    }

    /// Hold to peek at the picture before this change, click to pin the
    /// comparison, click again (or ⌘B) to return.
    private var beforeAfterControl: some View {
        HStack(spacing: 6) {
            Image(systemName: showingBefore ? "eye.fill" : "eye")
                .font(.system(size: 11, weight: .semibold))
            Text(beforePinned ? "Showing before" : "Before")
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Capsule().fill(showingBefore ? Color.orange.opacity(0.7) : Color.white.opacity(0.14)))
        .contentShape(Capsule())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard beforePressStart == nil else { return }
                    beforePressStart = Date()
                    showingBefore = true
                }
                .onEnded { _ in
                    let held = Date().timeIntervalSince(beforePressStart ?? Date()) > 0.3
                    beforePressStart = nil
                    if held { showingBefore = beforePinned }       // a peek — snap back
                    else { setBeforePinned(!beforePinned) }        // a click — toggle
                }
        )
        .opacity(beforeImage == nil ? 0.4 : 1)
        .help("Hold to peek at the picture before this change; click to pin the comparison (⌘B)")
        .accessibilityIdentifier("studio-before")
    }

    private func setBeforePinned(_ pinned: Bool) {
        beforePinned = pinned
        showingBefore = pinned
    }

    private func clearResult() {
        resultData = nil
        resultImage = nil
        beforeImage = nil
        beforePinned = false
        showingBefore = false
    }

    private var promptRow: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                // The shot description's shortcuts work here too — a mention
                // attaches that element's picture automatically.
                MentionTextView(text: $promptText,
                                characters: characters, locations: locations, props: props,
                                continuityShots: shots, projectDirectory: projectDirectory,
                                placeholder: "What is this shot? (\(Self.mentionLegend))",
                                onOpenMention: nil,
                                onCommandReturn: { generate() })
                    .frame(height: 50)
                    .accessibilityIdentifier("studio-prompt")
                HStack(spacing: 6) {
                    Image(systemName: "at").font(.system(size: 8, weight: .bold))
                    Text("Mention story elements with \(Self.mentionLegend) — their pictures attach automatically")
                        .font(.system(size: 9))
                }
                .foregroundColor(.gray.opacity(0.85))
                .padding(.leading, 2)
            }
            Button { generate() } label: {
                HStack(spacing: 6) {
                    if isGenerating { ProgressView().controlSize(.small) }
                    else { Image(systemName: "wand.and.stars") }
                    Text(isGenerating ? "Generating…" : "Generate")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 14).padding(.vertical, 7)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canGenerate)
            .help("Generate (⌘↩ — from anywhere in the studio)")
            .accessibilityIdentifier("studio-generate")
        }
        .padding(.horizontal, 12)
        .overlay(alignment: .topLeading) {
            if let errorText {
                Text(errorText).font(.system(size: 10)).foregroundColor(.red)
                    .padding(.horizontal, 14).offset(y: -16)
            }
        }
    }

    // MARK: Right panel — Library | Prompt

    private var rightPanel: some View {
        VStack(spacing: 0) {
            Picker("", selection: $rightTab) {
                Text("Library").tag("library")
                Text("Prompt").tag("prompt")
            }
            .pickerStyle(.segmented).labelsHidden()
            .padding(.horizontal, 12).padding(.vertical, 8)
            Divider().opacity(0.3)
            if rightTab == "library" { libraryColumn } else { promptPanel }
        }
        .background(Color(hex: "#1F1F1F"))
    }

    /// The exact words that will be sent — live, and customizable
    /// (owner 2026-09-01: the prompt belongs IN the tool).
    private var promptPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Toggle("Customize before sending", isOn: $useCustomPrompt)
                .toggleStyle(.switch).controlSize(.small)
                .font(.system(size: 11))
                .padding(.horizontal, 12).padding(.vertical, 8)
                .onChange(of: useCustomPrompt) { _, on in
                    if on, customPrompt.isEmpty { customPrompt = livePrompt }
                }
                .accessibilityIdentifier("studio-custom-prompt")
            Divider().opacity(0.3)
            if useCustomPrompt {
                TextEditor(text: $customPrompt)
                    .font(.system(size: 11, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color(hex: "#141414"))
                Text("Sent exactly as written. Switch off to go back to the composed prompt.")
                    .font(.system(size: 9)).foregroundColor(.gray)
                    .padding(.horizontal, 12).padding(.vertical, 6)
            } else {
                ScrollView {
                    Text(livePrompt)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.85))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                Divider().opacity(0.3)
                Text("Updates as you work: pictures are numbered in the order they attach — tags carry the same numbers.")
                    .font(.system(size: 9)).foregroundColor(.gray)
                    .padding(.horizontal, 12).padding(.vertical, 6)
            }
        }
    }

    /// The composed prompt from the CURRENT state — picture bytes aren't
    /// needed to preview the words, so this stays cheap.
    private var livePrompt: String {
        let placements = placed.map {
            SketchPlacement(element: SketchElement(kind: $0.kind, name: $0.name, imageData: Data()),
                            x: $0.x ?? 0.5, y: $0.y ?? 0.5)
        }
        let references = (generals + mentioned).map {
            SketchElement(kind: $0.kind, name: $0.name, imageData: Data())
        }
        let input = SketchStudioInput(
            mode: mode, sceneText: SketchStudioComposer.stripMentions(promptText),
            taggedSketchPNG: Data(), cleanSketchPNG: nil, basePNG: nil,
            placements: placements,
            notes: notes.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
                        .map { SketchNote(text: $0.text, x: $0.x, y: $0.y) },
            generalReferences: references,
            aspectRatio: "16:9", targetSize: .projectPreview)
        return SketchStudioComposer.prompt(for: input)
    }

    struct LibraryRow: Identifiable, Equatable {
        let id: String
        let kind: String
        let name: String
        let imagePath: String
        let canBeBase: Bool
        /// Where a double-click goes (a costume opens its character).
        let navKind: String
        let navId: String
    }

    private var libraryRows: [(section: String, rows: [LibraryRow])] {
        let q = librarySearch.trimmingCharacters(in: .whitespaces).lowercased()
        func hit(_ name: String) -> Bool { q.isEmpty || name.lowercased().contains(q) }
        var sections: [(String, [LibraryRow])] = []
        let cast = characters.compactMap { c -> LibraryRow? in
            guard let img = c.representativeImage, hit(c.name) else { return nil }
            return LibraryRow(id: "character-\(c.name)", kind: "character", name: c.name,
                              imagePath: img, canBeBase: false, navKind: "character", navId: c.id)
        }
        if !cast.isEmpty { sections.append(("CHARACTERS", cast)) }
        let wardrobe = characters.flatMap { c in
            (c.costumes ?? []).compactMap { costume -> LibraryRow? in
                guard let img = costume.imageFront, hit("\(c.name) \(costume.name)") else { return nil }
                return LibraryRow(id: "costume-\(c.name)-\(costume.name)", kind: "costume",
                                  name: "\(c.name) — \(costume.name)", imagePath: img, canBeBase: false,
                                  navKind: "character", navId: c.id)
            }
        }
        if !wardrobe.isEmpty { sections.append(("COSTUMES", wardrobe)) }
        let places = locations.compactMap { l -> LibraryRow? in
            guard let img = l.primaryImage ?? l.images.first, !img.isEmpty, hit(l.name) else { return nil }
            return LibraryRow(id: "location-\(l.name)", kind: "location", name: l.name,
                              imagePath: img, canBeBase: true, navKind: "location", navId: l.id)
        }
        if !places.isEmpty { sections.append(("LOCATIONS", places)) }
        let objects = props.compactMap { p -> LibraryRow? in
            guard let img = p.thumbnail, !img.isEmpty, hit(p.name) else { return nil }
            return LibraryRow(id: "prop-\(p.name)", kind: "prop", name: p.name,
                              imagePath: img, canBeBase: false, navKind: "prop", navId: p.id)
        }
        if !objects.isEmpty { sections.append(("PROPS", objects)) }
        let frames = shots.compactMap { s -> LibraryRow? in
            guard let img = s.previewImage, !img.isEmpty, s.shotId != currentShotId,
                  hit("shot #\(s.shotId)") else { return nil }
            return LibraryRow(id: "shot-\(s.shotId)", kind: "shot", name: "Shot #\(s.shotId)",
                              imagePath: img, canBeBase: true, navKind: "shot", navId: s.id)
        }
        if !frames.isEmpty { sections.append(("SHOT PREVIEWS", frames)) }
        return sections
    }

    private var libraryColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Drag onto your sketch to say what a shape is. ＋ attaches it as a plain reference. Double-click opens its page.")
                .font(.system(size: 9)).foregroundColor(.gray.opacity(0.8))
                .padding(.horizontal, 12).padding(.top, 8)
            TextField("Search elements…", text: $librarySearch)
                .textFieldStyle(.roundedBorder).controlSize(.small)
                .padding(.horizontal, 12).padding(.vertical, 6)
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(libraryRows, id: \.section) { section in
                        Text(section.section)
                            .font(.system(size: 8, weight: .bold)).tracking(0.8)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 12).padding(.top, 8)
                        ForEach(section.rows) { row in libraryRow(row) }
                    }
                    if libraryRows.isEmpty {
                        Text("No elements with pictures yet — add pictures in Story Design.")
                            .font(.system(size: 10)).foregroundColor(.gray)
                            .padding(12)
                    }
                }
                .padding(.bottom, 8)
            }
            if !generals.isEmpty || !mentioned.isEmpty {
                Divider().opacity(0.3)
                Text("ATTACHED AS REFERENCES").font(.system(size: 8, weight: .bold)).tracking(0.8)
                    .foregroundColor(.gray).padding(.horizontal, 12).padding(.top, 6)
                ScrollView {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(mentioned, id: \.name) { element in
                            HStack(spacing: 6) {
                                Text(element.name).font(.system(size: 10)).lineLimit(1)
                                Text("mentioned").font(.system(size: 8)).foregroundColor(.gray)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .help("Attached because your words mention it — edit the words to remove it")
                        }
                        ForEach(generals) { element in
                            HStack(spacing: 6) {
                                Text(element.name).font(.system(size: 10)).lineLimit(1)
                                Spacer()
                                Button { remove(element) } label: {
                                    Image(systemName: "xmark").font(.system(size: 8))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 12)
                        }
                    }
                }
                .frame(maxHeight: 90)
                .padding(.bottom, 6)
            }
        }
    }

    private func libraryRow(_ row: LibraryRow) -> some View {
        HStack(spacing: 10) {
            if let dir = projectDirectory {
                AsyncThumbnail(url: dir.appendingPathComponent(row.imagePath), displaySize: 120) {
                    Color.gray.opacity(0.3)
                }
                .frame(width: row.kind == "character" ? 44 : 76, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: row.kind == "character" ? 22 : 5))
            }
            Text(row.name).font(.system(size: 12, weight: .medium)).lineLimit(2)
            Spacer()
            Button {
                elements.append(StudioElement(kind: row.kind, name: row.name, imagePath: row.imagePath))
            } label: {
                Image(systemName: "plus.circle").font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("Attach as a plain reference (no position)")
        }
        .padding(.horizontal, 12).padding(.vertical, 5)
        .contentShape(Rectangle())
        .background(hoveredRow == row ? Color.white.opacity(0.06) : Color.clear)
        .onHover { inside in
            hoverTask?.cancel()
            if inside {
                hoverTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    guard !Task.isCancelled else { return }
                    hoveredRow = row
                }
            } else if hoveredRow == row {
                hoveredRow = nil
            }
        }
        .onTapGesture(count: 2) {
            hoveredRow = nil
            dismiss()
            onOpenElement?(row.navKind, row.navId)
        }
        .onDrag {
            hoveredRow = nil
            return NSItemProvider(object: "\(row.kind)|\(row.name)|\(row.imagePath)" as NSString)
        }
        .contextMenu {
            if row.canBeBase {
                Button("Use as base — draw changes on it") { setBase(row.imagePath) }
            }
            Button("Attach as plain reference") {
                elements.append(StudioElement(kind: row.kind, name: row.name, imagePath: row.imagePath))
            }
            Button("Open in Story Design") {
                dismiss()
                onOpenElement?(row.navKind, row.navId)
            }
        }
        .accessibilityIdentifier("library-\(row.id)")
    }

    /// The big look at whatever library row the pointer rests on.
    @ViewBuilder
    private var hoverPreviewPanel: some View {
        if let row = hoveredRow, let dir = projectDirectory, rightTab == "library" {
            VStack(alignment: .leading, spacing: 6) {
                AsyncThumbnail(url: dir.appendingPathComponent(row.imagePath), displaySize: 560) {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 360, height: row.kind == "character" ? 360 : 202)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(row.name).font(.system(size: 12, weight: .semibold))
                Text(row.kind.capitalized).font(.system(size: 10)).foregroundColor(.gray)
            }
            .padding(10)
            .background(Color(hex: "#1A1A1A").opacity(0.97))
            .cornerRadius(10)
            .shadow(color: .black.opacity(0.5), radius: 10, y: 3)
            .padding(.top, 54)
            .padding(.trailing, 342)
            .transition(.opacity)
            .allowsHitTesting(false)
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 10) {
            Label(mode == .create
                  ? "New picture from your sketch, notes and elements"
                  : "Editing the base picture — everything you don't mark stays",
                  systemImage: mode == .create ? "sparkles" : "lock")
                .font(.system(size: 10)).foregroundColor(.gray)
            Spacer()
            Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(Color(hex: "#1C1C1C"))
    }

    // MARK: Actions

    private func normalised(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: min(max(point.x / size.width, 0), 1),
                y: min(max(point.y / size.height, 0), 1))
    }

    private func move(_ element: StudioElement, by delta: CGPoint) {
        guard let index = elements.firstIndex(where: { $0.id == element.id }) else { return }
        elements[index].x = min(max((element.x ?? 0) + delta.x, 0), 1)
        elements[index].y = min(max((element.y ?? 0) + delta.y, 0), 1)
    }

    private func moveNote(_ note: StudioNote, by delta: CGPoint) {
        guard let index = notes.firstIndex(where: { $0.id == note.id }) else { return }
        notes[index].x = min(max(note.x + delta.x, 0), 1)
        notes[index].y = min(max(note.y + delta.y, 0), 1)
    }

    private func remove(_ element: StudioElement) {
        elements.removeAll { $0.id == element.id }
    }

    private func drop(providers: [NSItemProvider], at point: CGPoint) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let token = object as? String else { return }
            let parts = token.split(separator: "|", maxSplits: 2).map(String.init)
            guard parts.count == 3 else { return }
            DispatchQueue.main.async {
                elements.append(StudioElement(kind: parts[0], name: parts[1], imagePath: parts[2],
                                              x: point.x, y: point.y))
            }
        }
        return true
    }

    private func setBase(_ newBase: String?) {
        base = newBase
        baseImage = loadBaseImage()
        clearResult()
    }

    private func loadBaseData() -> Data? {
        guard let dir = projectDirectory else { return nil }
        switch base {
        case nil: return nil
        case "preview":
            guard let path = currentPreviewPath else { return nil }
            return try? Data(contentsOf: dir.appendingPathComponent(path))
        case let path?:
            return try? Data(contentsOf: dir.appendingPathComponent(path))
        }
    }

    private func loadBaseImage() -> NSImage? {
        loadBaseData().flatMap(NSImage.init(data:))
    }

    private func elementData(_ element: StudioElement) -> Data? {
        guard let dir = projectDirectory else { return nil }
        return try? Data(contentsOf: dir.appendingPathComponent(element.imagePath))
    }

    /// Everything a generation needs, or nil with the reason on screen.
    private func prepareInput() -> SketchStudioInput? {
        errorText = nil
        let renderSize = CGSize(width: 1344, height: 756)
        let baseData = loadBaseData()
        let liveNotes = notes.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
        // Badge order MUST match the composer's numbering: placements, then notes.
        let tagPoints = placed.map { (x: $0.x ?? 0.5, y: $0.y ?? 0.5) }
                      + liveNotes.map { (x: $0.x, y: $0.y) }
        guard let sketchPNG = SketchRender.composedPNG(
            strokes: strokes, tags: tagPoints,
            size: renderSize, base: baseData, firstTagNumber: firstTag),
        let cleanPNG = SketchRender.composedPNG(
            strokes: strokes, tags: [], size: renderSize, base: baseData,
            firstTagNumber: firstTag) else {
            errorText = "Couldn't render the sketch."
            return nil
        }
        var placements: [SketchPlacement] = []
        for element in placed {
            guard let data = elementData(element) else {
                errorText = "Couldn't read the picture for \(element.name)."
                return nil
            }
            placements.append(SketchPlacement(
                element: SketchElement(kind: element.kind, name: element.name, imageData: data),
                x: element.x ?? 0.5, y: element.y ?? 0.5))
        }
        var references: [SketchElement] = []
        for element in generals + mentioned {
            guard let data = elementData(element) else {
                errorText = "Couldn't read the picture for \(element.name)."
                return nil
            }
            references.append(SketchElement(kind: element.kind, name: element.name, imageData: data))
        }
        return SketchStudioInput(
            mode: mode, sceneText: SketchStudioComposer.stripMentions(promptText),
            taggedSketchPNG: sketchPNG,
            cleanSketchPNG: mode == .create ? cleanPNG : nil,
            basePNG: baseData,
            placements: placements,
            notes: liveNotes.map { SketchNote(text: $0.text, x: $0.x, y: $0.y) },
            generalReferences: references,
            aspectRatio: "16:9", targetSize: .projectPreview)
    }

    private var canGenerate: Bool {
        !isGenerating && resultImage == nil
            && !(strokes.isEmpty && placed.isEmpty && notes.isEmpty
                 && promptText.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    private func generate() {
        guard canGenerate, let input = prepareInput() else { return }
        run(input, promptOverride: useCustomPrompt ? customPrompt : nil)
    }

    private func run(_ input: SketchStudioInput, promptOverride: String?) {
        isGenerating = true
        persist()
        onSketchSaved(input.taggedSketchPNG)
        Task { @MainActor in
            defer { isGenerating = false }
            do {
                var request = SketchStudioComposer.request(for: input)
                if let promptOverride, !promptOverride.trimmingCharacters(in: .whitespaces).isEmpty {
                    request.prompt = promptOverride
                }
                let response = try await AIServiceClient.shared.generateImage(request)
                guard let data = response.images.first else {
                    errorText = "No image came back."
                    return
                }
                resultData = data
                resultImage = NSImage(data: data)
                // Edit: compare against the untouched picture; create: the marked sketch.
                beforeImage = input.mode == .edit ? baseImage : NSImage(data: input.taggedSketchPNG)
                beforePinned = false
                showingBefore = false
            } catch let error as AIClientError where error.isCancellation {
                // The user cancelled in the prompt review — no error banner.
            } catch {
                errorText = error.localizedDescription
            }
        }
    }

    /// The result becomes the base for the next round of changes.
    private func continueOnResult() {
        guard let data = resultData, let dir = projectDirectory, let documentURL else {
            clearResult()
            return
        }
        // Keep the round on disk so "base" survives reopening.
        let roundURL = documentURL.deletingLastPathComponent()
            .appendingPathComponent("sketch_round_latest.png")
        try? data.write(to: roundURL)
        base = roundURL.path.replacingOccurrences(of: dir.path + "/", with: "")
        baseImage = NSImage(data: data)
        strokes.removeAll()
        notes.removeAll()
        elements.removeAll { $0.isPlaced }   // keep plain references for the next round
        clearResult()
    }

    // MARK: Persistence

    private func restore() {
        if let documentURL, let data = try? Data(contentsOf: documentURL),
           let doc = try? JSONDecoder().decode(SketchStudioDocument.self, from: data) {
            strokes = doc.strokes
            elements = doc.elements
            notes = doc.notes
            base = doc.base
            promptText = doc.prompt.isEmpty ? seedPrompt : doc.prompt
        } else {
            promptText = seedPrompt
            base = currentPreviewPath != nil ? "preview" : nil
        }
        baseImage = loadBaseImage()
    }

    private func persist() {
        guard let documentURL else { return }
        let doc = SketchStudioDocument(strokes: strokes, elements: elements,
                                       notes: notes, base: base, prompt: promptText)
        try? FileManager.default.createDirectory(at: documentURL.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(doc) {
            try? data.write(to: documentURL)
        }
    }
}

private extension AIClientError {
    var isCancellation: Bool {
        if case .cancelled = self { return true }
        return false
    }
}

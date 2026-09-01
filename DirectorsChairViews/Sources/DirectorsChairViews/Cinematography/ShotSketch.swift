// DirectorsChairViews/Cinematography/ShotSketch.swift
//
// DC-0109/DC-0110 — the SKETCH STUDIO (owner 2026-08-31): a self-contained
// authoring surface for shot previews. Draw the composition, drag story
// elements from the project's library onto the drawn shapes to say what
// they are, generate RIGHT HERE, then sketch corrections on the result and
// go again. The studio decides its own references — it never drags the
// shot page's reference bundle in (that inversion was the owner's core
// complaint about v1).
//
// Every prompt mechanism is live-proven (scratchpad/sketchprobe):
//  • planning-sketch wording → composition followed, zero ink in the result;
//  • red numbered tags where TAG NUMBER == ATTACHED IMAGE NUMBER → the
//    character portrait rendered at the tagged shape with exact likeness;
//  • edit mode = the marked-copy + edit-guard wording from annotation edits.
// The composition itself lives in Services (SketchStudioComposer, tested).

import DirectorsChairCore
import DirectorsChairServices
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Strokes

/// One drawn stroke, points normalised (0…1, top-left origin).
public struct SketchStroke: Equatable, Sendable, Codable {
    public var points: [CGPoint]
    /// Line width as a fraction of the canvas HEIGHT.
    public var width: CGFloat
    public var isEraser: Bool

    public init(points: [CGPoint] = [], width: CGFloat, isEraser: Bool = false) {
        self.points = points
        self.width = width
        self.isEraser = isEraser
    }
}

// MARK: - Placed tags & library elements

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

/// The studio's saved state — reopening the sketch restores everything.
struct SketchStudioDocument: Codable {
    var strokes: [SketchStroke] = []
    var elements: [StudioElement] = []
    /// nil = blank canvas; "preview" = the shot's current preview;
    /// otherwise a project-relative picture path.
    var base: String?
    var prompt: String = ""
}

// MARK: - Pure renderer (tested)

public enum SketchRender {
    /// Black-on-white strokes at `size` — kept for the simple sketch path.
    public static func png(strokes: [SketchStroke], size: CGSize) -> Data? {
        composedPNG(strokes: strokes, tags: [], size: size, base: nil, firstTagNumber: 2)
    }

    /// What the model sees: the base picture (edit mode) or paper, the
    /// strokes, and a red numbered badge at every tag — numbering starts
    /// at `firstTagNumber` so TAG NUMBER == ATTACHED IMAGE NUMBER.
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
                : CGColor(red: 0, green: 0, blue: 0, alpha: 1))
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
    @State private var isEraser = false
    @State private var penWidth: CGFloat = 0.008
    // Elements.
    @State private var elements: [StudioElement] = []
    @State private var dragOffsets: [UUID: CGSize] = [:]
    // Base.
    @State private var base: String?           // nil | "preview" | relative path
    @State private var baseImage: NSImage?
    @State private var dimBase = false
    // Prompt & generation.
    @State private var promptText: String = ""
    @State private var isGenerating = false
    @State private var resultData: Data?
    @State private var resultImage: NSImage?
    @State private var errorText: String?
    @State private var librarySearch = ""
    @State private var studioSize: CGSize = ShotSketchStudio.hostSize()
    @State private var hoveredRow: LibraryRow?
    @State private var hoverTask: Task<Void, Never>?
    // Owner 2026-08-31: see and edit the exact prompt before it is sent.
    @State private var showingPromptReview = false
    @State private var reviewInput: SketchStudioInput?
    @State private var reviewPrompt: String = ""

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
    private var firstTag: Int { SketchStudioComposer.firstTagNumber(for: mode) }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.3)
            HStack(spacing: 0) {
                canvasColumn
                Divider().opacity(0.3)
                libraryColumn
                    .frame(width: 320)
            }
            Divider().opacity(0.3)
            footer
        }
        // Owner 2026-08-31: use the screen — the studio is a workspace.
        .frame(width: studioSize.width, height: studioSize.height)
        .background(Color(hex: "#252525"))
        .onAppear(perform: restore)
        .onDisappear(perform: persist)
        .overlay(alignment: .topTrailing) { hoverPreviewPanel }
        .sheet(isPresented: $showingPromptReview) { promptReviewSheet }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "pencil.and.outline").foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text("SKETCH STUDIO").font(.system(size: 11, weight: .bold)).tracking(1.2)
                    .foregroundColor(.white.opacity(0.9))
                Text(mode == .create
                     ? "Draw the shot, drop story elements onto your shapes, generate — all right here."
                     : "Draw your changes on the picture, drop elements where they belong, generate.")
                    .font(.system(size: 10)).foregroundColor(.gray)
            }
            Spacer()
            Picker("", selection: $isEraser) {
                Label("Draw", systemImage: "pencil").tag(false)
                Label("Erase", systemImage: "eraser").tag(true)
            }
            .pickerStyle(.segmented).labelsHidden().frame(width: 140)
            Picker("", selection: $penWidth) {
                Text("Fine").tag(CGFloat(0.004))
                Text("Medium").tag(CGFloat(0.008))
                Text("Thick").tag(CGFloat(0.016))
            }
            .pickerStyle(.segmented).labelsHidden().frame(width: 160)
            baseMenu
            Button { _ = strokes.popLast() } label: { Image(systemName: "arrow.uturn.backward") }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(strokes.isEmpty)
                .help("Undo the last stroke (⌘Z)")
            Button("Clear") { strokes.removeAll() }
                .disabled(strokes.isEmpty)
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(Color(hex: "#1E1E1E"))
    }

    /// What the sketch sits on: a fresh frame, or a picture being changed.
    private var baseMenu: some View {
        Menu {
            Button("Blank canvas — new picture") { setBase(nil) }
            if currentPreviewPath != nil {
                Button("Current preview — change it") { setBase("preview") }
            }
            if !shots.filter({ $0.shotId != currentShotId && $0.previewImage != nil }).isEmpty
                || !locations.isEmpty {
                Divider()
                Text("Or right-click a shot or location in the library → “Use as base”.")
            }
        } label: {
            Label(mode == .create ? "Blank" : "Editing", systemImage: mode == .create ? "doc" : "photo")
                .font(.system(size: 11, weight: .medium))
        }
        .menuStyle(.borderlessButton).fixedSize()
        .help("Blank canvas generates a fresh picture; a base picture makes this an edit of it")
        .accessibilityIdentifier("studio-base")
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
                                       with: .color(stroke.isEraser ? .white : .black),
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
                        .gesture(
                            DragGesture()
                                .onChanged { dragOffsets[element.id] = $0.translation }
                                .onEnded { value in
                                    move(element,
                                         to: CGPoint(x: (element.x ?? 0) + value.translation.width / geo.size.width,
                                                     y: (element.y ?? 0) + value.translation.height / geo.size.height))
                                    dragOffsets[element.id] = nil
                                }
                        )
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        let point = normalised(value.location, in: geo.size)
                        if current == nil {
                            current = SketchStroke(points: [point],
                                                   width: isEraser ? penWidth * 3 : penWidth,
                                                   isEraser: isEraser)
                        } else {
                            current?.points.append(point)
                        }
                    }
                    .onEnded { _ in
                        if let stroke = current, stroke.points.count > 1 { strokes.append(stroke) }
                        current = nil
                    }
            )
            .onDrop(of: [.plainText], isTargeted: nil) { providers, location in
                drop(providers: providers, at: normalised(location, in: geo.size))
            }
            .accessibilityIdentifier("studio-canvas")
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "#3A3A3A"), lineWidth: 1))
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

    /// A placed element: numbered badge + thumbnail + name; drag to move,
    /// × or right-click to remove. Several can share a region.
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

    private func resultPane(_ image: NSImage) -> some View {
        ZStack(alignment: .bottom) {
            Image(nsImage: image).resizable().scaledToFit()
            HStack(spacing: 10) {
                Button {
                    if let data = resultData { onKeep(data) }
                    continueOnResult()
                } label: { Label("Keep as shot preview", systemImage: "checkmark.circle.fill") }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("studio-keep")
                Button { continueOnResult() } label: {
                    Label("Sketch on this", systemImage: "pencil.and.outline")
                }
                .help("Make this picture the base and draw the next round of changes on it")
                Button("Discard", role: .destructive) { resultData = nil; resultImage = nil }
            }
            .padding(10)
            .background(Color.black.opacity(0.65)).cornerRadius(10)
            .padding(.bottom, 12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var promptRow: some View {
        HStack(alignment: .top, spacing: 10) {
            TextField("What is this shot? (style, place, moment — your words)",
                      text: $promptText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...3)
                .font(.system(size: 12))
                .accessibilityIdentifier("studio-prompt")
            Button {
                guard let input = prepareInput() else { return }
                reviewInput = input
                reviewPrompt = SketchStudioComposer.prompt(for: input)
                showingPromptReview = true
            } label: {
                Label("Prompt", systemImage: "text.quote")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 8).padding(.vertical, 7)
            }
            .disabled(isGenerating)
            .help("See and edit the exact prompt before it is sent")
            .accessibilityIdentifier("studio-review-prompt")
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
            .disabled(isGenerating || (strokes.isEmpty && placed.isEmpty && promptText.trimmingCharacters(in: .whitespaces).isEmpty))
            .keyboardShortcut(.return, modifiers: .command)
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

    // MARK: Library

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
            HStack(spacing: 6) {
                Image(systemName: "books.vertical").font(.system(size: 11)).foregroundColor(.secondary)
                Text("STORY LIBRARY").font(.system(size: 9, weight: .bold)).tracking(1.0)
                    .foregroundColor(.gray)
                Spacer()
            }
            .padding(.horizontal, 12).padding(.top, 10)
            Text("Drag onto your sketch to say what a shape is. ＋ attaches it as a plain reference.")
                .font(.system(size: 9)).foregroundColor(.gray.opacity(0.8))
                .padding(.horizontal, 12).padding(.top, 2)
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
            if !generals.isEmpty {
                Divider().opacity(0.3)
                Text("ATTACHED AS REFERENCES").font(.system(size: 8, weight: .bold)).tracking(0.8)
                    .foregroundColor(.gray).padding(.horizontal, 12).padding(.top, 6)
                ScrollView {
                    VStack(alignment: .leading, spacing: 3) {
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
        .background(Color(hex: "#202020"))
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
        // Owner 2026-08-31: the small thumbnails are hard to read — hovering
        // shows the picture big (top-right panel), double-click opens the
        // element's Story Design page (⌘[ returns).
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
        }
        .accessibilityIdentifier("library-\(row.id)")
    }

    /// The big look at whatever library row the pointer rests on.
    @ViewBuilder
    private var hoverPreviewPanel: some View {
        if let row = hoveredRow, let dir = projectDirectory {
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
            .padding(.trailing, 332)
            .transition(.opacity)
            .allowsHitTesting(false)
        }
    }

    /// See and change the exact words before anything is sent (owner
    /// 2026-08-31 — same right as the shot page's prompt editor).
    private var promptReviewSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Label("THE PROMPT, AS IT WILL BE SENT", systemImage: "text.quote")
                    .font(.system(size: 11, weight: .bold)).tracking(1.0)
                Spacer()
                if let input = reviewInput {
                    Text("\(SketchStudioComposer.referenceImages(for: input).count) pictures attached")
                        .font(.system(size: 10)).foregroundColor(.gray)
                }
            }
            .padding(12)
            .background(Color(hex: "#1E1E1E"))
            Divider().opacity(0.3)
            TextEditor(text: $reviewPrompt)
                .font(.system(size: 12, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(hex: "#141414"))
            if let input = reviewInput {
                Divider().opacity(0.3)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(SketchStudioComposer.referenceImages(for: input).enumerated()),
                                id: \.offset) { index, ref in
                            VStack(spacing: 2) {
                                Text("Image \(index + 1)").font(.system(size: 9, weight: .bold))
                                Text(ref.label).font(.system(size: 9)).foregroundColor(.gray)
                            }
                            .padding(6).background(Color.white.opacity(0.06)).cornerRadius(5)
                        }
                    }
                    .padding(10)
                }
            }
            Divider().opacity(0.3)
            HStack {
                Button("Cancel") { showingPromptReview = false }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button {
                    showingPromptReview = false
                    if let input = reviewInput { run(input, promptOverride: reviewPrompt) }
                } label: {
                    Label("Generate with this prompt", systemImage: "wand.and.stars")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(12)
            .background(Color(hex: "#1E1E1E"))
        }
        .frame(width: 720, height: 560)
        .background(Color(hex: "#252525"))
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 10) {
            Label(mode == .create
                  ? "New picture from your sketch"
                  : "Editing the base picture — everything you don't mark stays",
                  systemImage: mode == .create ? "sparkles" : "lock")
                .font(.system(size: 10)).foregroundColor(.gray)
            Spacer()
            Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(Color(hex: "#1E1E1E"))
    }

    // MARK: Actions

    private func normalised(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: min(max(point.x / size.width, 0), 1),
                y: min(max(point.y / size.height, 0), 1))
    }

    private func move(_ element: StudioElement, to point: CGPoint) {
        guard let index = elements.firstIndex(where: { $0.id == element.id }) else { return }
        elements[index].x = min(max(point.x, 0), 1)
        elements[index].y = min(max(point.y, 0), 1)
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
        resultData = nil
        resultImage = nil
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
        guard let sketchPNG = SketchRender.composedPNG(
            strokes: strokes,
            tags: placed.map { (x: $0.x ?? 0.5, y: $0.y ?? 0.5) },
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
        for element in generals {
            guard let data = elementData(element) else {
                errorText = "Couldn't read the picture for \(element.name)."
                return nil
            }
            references.append(SketchElement(kind: element.kind, name: element.name, imageData: data))
        }
        return SketchStudioInput(
            mode: mode, sceneText: promptText,
            taggedSketchPNG: sketchPNG,
            cleanSketchPNG: mode == .create ? cleanPNG : nil,
            basePNG: baseData,
            placements: placements, generalReferences: references,
            aspectRatio: "16:9", targetSize: .projectPreview)
    }

    private func generate() {
        guard let input = prepareInput() else { return }
        run(input, promptOverride: nil)
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
            resultImage = nil; resultData = nil
            return
        }
        // Keep the round on disk so "base" survives reopening.
        let roundURL = documentURL.deletingLastPathComponent()
            .appendingPathComponent("sketch_round_latest.png")
        try? data.write(to: roundURL)
        base = roundURL.path.replacingOccurrences(of: dir.path + "/", with: "")
        baseImage = NSImage(data: data)
        strokes.removeAll()
        elements.removeAll { $0.isPlaced }   // keep plain references for the next round
        resultData = nil
        resultImage = nil
    }

    // MARK: Persistence

    private func restore() {
        if let documentURL, let data = try? Data(contentsOf: documentURL),
           let doc = try? JSONDecoder().decode(SketchStudioDocument.self, from: data) {
            strokes = doc.strokes
            elements = doc.elements
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
                                       base: base, prompt: promptText)
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

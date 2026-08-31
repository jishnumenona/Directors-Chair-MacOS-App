// DirectorsChairViews/Cinematography/ShotSketch.swift
//
// DC-0109 — sketch the shot (owner 2026-08-31: "hard to convey exactly how
// the shot preview should look… let the user draw a simple sketch and use
// it as a reference; make it intuitive").
//
// The user draws crude shapes on a 16:9 canvas; the strokes render to a
// clean black-on-white PNG that rides FIRST with the generation, labelled
// "sketch:". Proven on the live model 2026-08-31 (scratchpad/sketchprobe):
// a stick figure on the left third + a box on the right + a circle sun
// came back as a photoreal frame with the person, vehicle and sun exactly
// where they were drawn — but only with the "planning sketch, none of its
// ink may appear" wording; the naive wording pasted the black lines over
// the photograph.

import DirectorsChairCore
import ImageIO
import SwiftUI

// MARK: - Model

/// One drawn stroke, points normalised to the canvas (0…1 in both axes) so
/// the sketch is size-independent from gesture to render.
public struct SketchStroke: Equatable, Sendable {
    public var points: [CGPoint]
    /// Line width as a fraction of the canvas HEIGHT (so it scales with
    /// the render size).
    public var width: CGFloat
    /// An eraser stroke paints canvas-white over what is beneath it.
    public var isEraser: Bool

    public init(points: [CGPoint] = [], width: CGFloat, isEraser: Bool = false) {
        self.points = points
        self.width = width
        self.isEraser = isEraser
    }
}

// MARK: - Pure renderer (tested)

public enum SketchRender {
    /// The strokes as a black-on-white PNG at `size` — exactly what the
    /// model sees. Pure CoreGraphics so tests can pin it.
    public static func png(strokes: [SketchStroke], size: CGSize) -> Data? {
        let width = Int(size.width), height = Int(size.height)
        guard width > 0, height > 0,
              let context = CGContext(data: nil, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setLineCap(.round)
        context.setLineJoin(.round)
        for stroke in strokes where stroke.points.count > 1 {
            context.setStrokeColor(stroke.isEraser
                ? CGColor(red: 1, green: 1, blue: 1, alpha: 1)
                : CGColor(red: 0, green: 0, blue: 0, alpha: 1))
            context.setLineWidth(max(1, stroke.width * size.height))
            // Normalised points are top-left origin; CG draws bottom-left.
            let mapped = stroke.points.map {
                CGPoint(x: $0.x * size.width, y: (1 - $0.y) * size.height)
            }
            context.beginPath()
            context.move(to: mapped[0])
            for point in mapped.dropFirst() { context.addLine(to: point) }
            context.strokePath()
        }
        guard let image = context.makeImage() else { return nil }
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        return CGImageDestinationFinalize(dest) ? data as Data : nil
    }

    /// The reference label every sketch travels under.
    public static let referenceLabel = "sketch:Shot sketch"

    /// The proven prompt clause for a sketch reference (variant A of the
    /// 2026-08-31 live probe — composition followed, zero ink in the output).
    public static func promptClause(imageNumber: Int) -> String {
        "- Image \(imageNumber) is a rough hand-drawn PLANNING sketch of this shot's composition — only a map: "
        + "each crude shape stands for a real thing (a stick figure is a person, a box is a vehicle or building, "
        + "a circle is the sun or a face). Place each real subject where its shape sits in the sketch and match "
        + "the sketched framing. Do NOT copy, trace or overlay the sketch's lines — none of its ink may appear "
        + "in the result."
    }
}

// MARK: - The sheet

/// The drawing surface: pen/eraser, three widths, undo, clear, and an
/// optional faint underlay of the current preview to draw over.
public struct ShotSketchSheet: View {
    let currentPreview: NSImage?
    let onApply: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var strokes: [SketchStroke] = []
    @State private var current: SketchStroke?
    @State private var isEraser = false
    @State private var penWidth: CGFloat = 0.008
    @State private var showUnderlay = true

    public init(currentPreview: NSImage? = nil, onApply: @escaping (Data) -> Void) {
        self.currentPreview = currentPreview
        self.onApply = onApply
    }

    private static let widths: [(name: String, value: CGFloat)] =
        [("Fine", 0.004), ("Medium", 0.008), ("Thick", 0.016)]

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.3)
            canvas
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .frame(minWidth: 720, minHeight: 405)
                .padding(16)
            Divider().opacity(0.3)
            footer
        }
        .frame(width: 860)
        .background(Color(hex: "#252525"))
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "pencil.and.outline")
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text("SKETCH THE SHOT")
                    .font(.system(size: 11, weight: .bold)).tracking(1.2)
                    .foregroundColor(.white.opacity(0.9))
                Text("Crude is fine — a stick figure is a person, a box is a vehicle. The picture follows your layout.")
                    .font(.system(size: 10)).foregroundColor(.gray)
            }
            Spacer()
            Picker("", selection: $isEraser) {
                Label("Draw", systemImage: "pencil").tag(false)
                Label("Erase", systemImage: "eraser").tag(true)
            }
            .pickerStyle(.segmented).labelsHidden().frame(width: 150)
            .accessibilityIdentifier("sketch-tool")
            Picker("", selection: $penWidth) {
                ForEach(Self.widths, id: \.value) { Text($0.name).tag($0.value) }
            }
            .pickerStyle(.segmented).labelsHidden().frame(width: 170)
            .accessibilityIdentifier("sketch-width")
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color(hex: "#1E1E1E"))
    }

    private var canvas: some View {
        GeometryReader { geo in
            ZStack {
                Color.white
                if showUnderlay, let preview = currentPreview {
                    Image(nsImage: preview)
                        .resizable().scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .opacity(0.18)
                }
                Canvas { context, size in
                    for stroke in strokes + (current.map { [$0] } ?? []) {
                        guard stroke.points.count > 1 else { continue }
                        var path = Path()
                        let pts = stroke.points.map {
                            CGPoint(x: $0.x * size.width, y: $0.y * size.height)
                        }
                        path.move(to: pts[0])
                        for point in pts.dropFirst() { path.addLine(to: point) }
                        context.stroke(path,
                                       with: .color(stroke.isEraser ? .white : .black),
                                       style: StrokeStyle(lineWidth: max(1, stroke.width * size.height),
                                                          lineCap: .round, lineJoin: .round))
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let point = CGPoint(x: min(max(value.location.x / geo.size.width, 0), 1),
                                            y: min(max(value.location.y / geo.size.height, 0), 1))
                        if current == nil {
                            current = SketchStroke(points: [point], width: isEraser ? penWidth * 3 : penWidth,
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
            .accessibilityIdentifier("sketch-canvas")
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "#3A3A3A"), lineWidth: 1))
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button { _ = strokes.popLast() } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
                .disabled(strokes.isEmpty)
                .keyboardShortcut("z", modifiers: .command)
            Button("Clear") { strokes.removeAll() }
                .disabled(strokes.isEmpty)
            if currentPreview != nil {
                Toggle("Trace over current picture", isOn: $showUnderlay)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                    .help("Shows the current preview faintly under your pen — it is never part of the sketch")
            }
            Spacer()
            Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
            Button {
                if let png = SketchRender.png(strokes: strokes, size: CGSize(width: 1344, height: 756)) {
                    onApply(png)
                }
                dismiss()
            } label: {
                Label("Use sketch", systemImage: "wand.and.stars")
                    .padding(.horizontal, 12).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(strokes.isEmpty)
            .keyboardShortcut(.return, modifiers: .command)
            .accessibilityIdentifier("sketch-apply")
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color(hex: "#1E1E1E"))
    }
}

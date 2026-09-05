// DirectorsChairViews/StoryDesign/LocationCameraPlacementView.swift
//
// DC-0129 (owner 2026-09-05): "place the camera on a part of the image and
// then orient it towards a part of the image and then generate the image of
// what it would look like from that camera's vantage point."
//
// The camera goes down on one of the location's pictures — its photo, a
// variation, or the floor plan — and is aimed at a point of it. Generate
// asks the model for the view from that vantage (CameraVantage); Keep makes
// the result the angle's picture and remembers the placement so the angle
// can be adjusted and regenerated. Position and aim only, for now.

import AppKit
import DirectorsChairCore
import DirectorsChairServices
import SwiftUI

struct LocationCameraPlacementView: View {
    let location: Location
    let angle: LocationAngle
    let project: Project
    let projectBasePath: URL
    /// Kept: the generated picture and the placement that produced it.
    let onKeep: (Data, CameraPlacement) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var basePath: String
    @State private var placement: CameraPlacement?
    @State private var dragging: CameraPlacementGeometry.Handle?
    @State private var baseImage: NSImage?
    @State private var isGenerating = false
    @State private var resultData: Data?
    @State private var resultImage: NSImage?
    @State private var errorText: String?
    @State private var statusText = ""

    init(location: Location, angle: LocationAngle, project: Project, projectBasePath: URL,
         onKeep: @escaping (Data, CameraPlacement) -> Void) {
        self.location = location
        self.angle = angle
        self.project = project
        self.projectBasePath = projectBasePath
        self.onKeep = onKeep
        let saved = angle.camera
        _basePath = State(initialValue: saved?.basePicture ?? Self.candidates(of: location).first?.path ?? "")
        _placement = State(initialValue: saved)
    }

    // MARK: Candidates — the pictures a camera can stand on

    struct Candidate: Identifiable, Equatable {
        let path: String
        let label: String
        let isFloorPlan: Bool
        var id: String { path }
    }

    static func candidates(of location: Location) -> [Candidate] {
        var out: [Candidate] = []
        var seen = Set<String>()
        func add(_ path: String?, _ label: String, floorPlan: Bool = false) {
            guard let path, !path.isEmpty, !seen.contains(path) else { return }
            seen.insert(path)
            out.append(Candidate(path: path, label: label, isFloorPlan: floorPlan))
        }
        add(location.primaryImage, "Photo")
        for image in location.images {
            let stem = (image as NSString).lastPathComponent.replacingOccurrences(of: ".png", with: "")
                .replacingOccurrences(of: ".jpg", with: "").replacingOccurrences(of: "_", with: " ").capitalized
            add(image, stem)
        }
        add(location.floorPlanImage, "Floor plan", floorPlan: true)
        add(location.cinemaFloorPlanImage, "Generated floor plan", floorPlan: true)
        return out
    }

    private var candidates: [Candidate] { Self.candidates(of: location) }
    private var current: Candidate? { candidates.first { $0.path == basePath } }
    private var canGenerate: Bool { placement != nil && !isGenerating && baseImage != nil }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                VStack(spacing: 10) {
                    basePicker
                    canvas
                    Text(placement == nil
                         ? "Click to put the camera down, then drag to aim it. Drag either marker to adjust."
                         : "Drag the camera or its target to adjust. Generate renders what the camera sees.")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }
                .padding(16)
                Divider()
                resultColumn
                    .frame(width: 360)
            }
        }
        .frame(minWidth: 1040, minHeight: 640)
        .onAppear { loadBase() }
        .onChange(of: basePath) { _ in
            loadBase()
            if placement?.basePicture != basePath { placement = nil }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "camera.viewfinder").foregroundColor(.accentColor)
            Text("\(location.name) — \(angle.name)").font(.system(size: 14, weight: .semibold))
            Text("Place the camera").font(.system(size: 12)).foregroundColor(.secondary)
            Spacer()
            Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private var basePicker: some View {
        HStack(spacing: 8) {
            Text("Camera on").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
            Picker("", selection: $basePath) {
                ForEach(candidates) { candidate in
                    Text(candidate.isFloorPlan ? "\(candidate.label) (top-down)" : candidate.label).tag(candidate.path)
                }
            }
            .labelsHidden()
            .frame(maxWidth: 320)
            Spacer()
            if placement != nil {
                Button("Clear") { placement = nil }.controlSize(.small)
            }
        }
    }

    private var canvas: some View {
        GeometryReader { geometry in
            let bounds = geometry.size
            let rect = CameraPlacementGeometry.fittedRect(imageSize: baseImage?.size ?? CGSize(width: 16, height: 9), in: bounds)
            ZStack {
                Color.black.opacity(0.25)
                if let baseImage {
                    Image(nsImage: baseImage).resizable().aspectRatio(contentMode: .fit)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                } else {
                    Text("This picture could not be opened.").foregroundColor(.secondary)
                }
                if let placement {
                    markers(placement, in: rect)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let fraction = CameraPlacementGeometry.fraction(of: value.location, in: rect)
                        if dragging == nil {
                            let start = CameraPlacementGeometry.fraction(of: value.startLocation, in: rect)
                            if let handle = CameraPlacementGeometry.handle(at: value.startLocation, placement: placement, in: rect) {
                                dragging = handle
                            } else {
                                // A fresh press puts the camera down; the drag aims it.
                                placement = CameraPlacement(basePicture: basePath, isFloorPlan: current?.isFloorPlan ?? false,
                                                            x: start.x, y: start.y, targetX: fraction.x, targetY: fraction.y)
                                dragging = .target
                            }
                        }
                        guard var next = placement else { return }
                        switch dragging {
                        case .camera: next.x = fraction.x; next.y = fraction.y
                        case .target, .none: next.targetX = fraction.x; next.targetY = fraction.y
                        }
                        placement = next
                    }
                    .onEnded { _ in
                        dragging = nil
                        // A bare click leaves the target on the camera: aim it a little ahead.
                        if var next = placement, abs(next.targetX - next.x) < 0.005, abs(next.targetY - next.y) < 0.005 {
                            next.targetX = min(1, next.x + 0.2); next.targetY = max(0, next.y - 0.15)
                            placement = next
                        }
                    })
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityIdentifier("camera-placement-canvas")
    }

    private func markers(_ placement: CameraPlacement, in rect: CGRect) -> some View {
        let c = CameraPlacementGeometry.camera(placement, in: rect)
        let t = CameraPlacementGeometry.target(placement, in: rect)
        return ZStack {
            Path { path in path.move(to: c); path.addLine(to: t) }
                .stroke(Color.red, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            Circle().fill(Color.red).frame(width: 30, height: 30).position(c)
            Text("C").font(.system(size: 14, weight: .bold)).foregroundColor(.white).position(c)
            Circle().stroke(Color.red, lineWidth: 3).frame(width: 24, height: 24).position(t)
            Circle().fill(Color.red).frame(width: 18, height: 18).position(x: t.x + 12, y: t.y + 12)
            Text("T").font(.system(size: 11, weight: .bold)).foregroundColor(.white).position(x: t.x + 12, y: t.y + 12)
        }
        .allowsHitTesting(false)
    }

    private var resultColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("THE VIEW FROM THE CAMERA").font(.system(size: 10, weight: .bold)).tracking(1.2).foregroundColor(.secondary)
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.25))
                if let resultImage {
                    Image(nsImage: resultImage).resizable().aspectRatio(contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 8))
                } else if isGenerating {
                    ProgressView(statusText.isEmpty ? "Rendering the view…" : statusText).controlSize(.small)
                } else {
                    Text("Place the camera, then Generate.").font(.system(size: 11)).foregroundColor(.secondary)
                }
            }
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            if let errorText {
                Text(errorText).font(.system(size: 11)).foregroundColor(.red).fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                Button {
                    generate()
                } label: {
                    Label(resultImage == nil ? "Generate view" : "Try again", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canGenerate)
                .keyboardShortcut(.return, modifiers: .command)
                .requiresTier(.creator, feature: "AI location angles")
                .accessibilityIdentifier("camera-placement-generate")
                Spacer()
                Button {
                    if let resultData, let placement { onKeep(resultData, placement); dismiss() }
                } label: {
                    Label("Keep as the angle's picture", systemImage: "checkmark")
                }
                .disabled(resultData == nil || placement == nil)
                .accessibilityIdentifier("camera-placement-keep")
            }
            Text("Other pictures of this location ride along so the model knows what the camera cannot see in this one.")
                .font(.system(size: 10)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(16)
    }

    // MARK: Work

    private func loadBase() {
        guard !basePath.isEmpty else { baseImage = nil; return }
        baseImage = NSImage(contentsOf: projectBasePath.appendingPathComponent(basePath))
    }

    /// The location's other pictures and its other angles, as references (at most four).
    private func references(excluding base: String) -> [SketchElement] {
        var out: [SketchElement] = []
        func add(_ path: String?, kind: String, name: String) {
            guard out.count < 4, let path, !path.isEmpty, path != base,
                  let data = try? Data(contentsOf: projectBasePath.appendingPathComponent(path)),
                  let png = CameraMarkup.pngCopy(of: data) else { return }
            out.append(SketchElement(kind: kind, name: name, imageData: png))
        }
        add(location.primaryImage, kind: "location", name: location.name)
        for other in location.angles where other.id != angle.id {
            add(other.image, kind: "angle", name: LocationAngles.mention(location: location, angle: other))
        }
        for image in location.images where image != location.primaryImage {
            add(image, kind: "location", name: "\(location.name) — \((image as NSString).lastPathComponent)")
        }
        return out
    }

    /// Two calls (the probed contract): the text model names what is at C,
    /// at T and behind the camera from the marked copy; the image model
    /// renders from those words and the marked copy alone.
    private func generate() {
        guard let placement, canGenerate,
              let raw = try? Data(contentsOf: projectBasePath.appendingPathComponent(basePath)),
              let basePNG = CameraMarkup.pngCopy(of: raw),
              let marked = CameraMarkup.marked(source: basePNG, camera: placement) else {
            errorText = "The picture could not be prepared."
            return
        }
        let references = references(excluding: basePath)
        isGenerating = true
        errorText = nil
        statusText = "Reading the picture…"
        Task { @MainActor in
            defer { isGenerating = false; statusText = "" }
            do {
                let describe = TextGenerationRequest(
                    prompt: SketchStudioComposer.vantageDescribePrompt(for: placement),
                    provider: AIProviderSelection.shared.provider(for: .text),
                    maxTokens: SketchStudioComposer.vantageDescribeMaxTokens, temperature: 0.2,
                    imageBase64: marked.base64EncodedString(), imageMimeType: "image/png")
                let words = (try? await AIServiceClient.shared.generateText(describe))
                    .flatMap { CameraMarkerWords.parse($0.text) }
                statusText = words == nil ? "Rendering the view (the picture could not be read; using positions)…"
                                          : "Rendering the view…"
                let input = CameraVantageInput(
                    locationName: location.name, locationDescription: location.description,
                    angleName: angle.name, angleDescription: angle.description,
                    camera: placement, markedPNG: marked, words: words,
                    references: references, aspectRatio: "16:9", targetSize: .projectPreview)
                let response = try await AIServiceClient.shared.generateImage(SketchStudioComposer.vantageRequest(for: input))
                guard let data = response.images.first else { errorText = "No image came back."; return }
                resultData = data
                resultImage = NSImage(data: data)
            } catch is CancellationError {
            } catch {
                errorText = error.localizedDescription
            }
        }
    }
}

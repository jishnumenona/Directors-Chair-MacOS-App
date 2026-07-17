//
// ShotVideoGenerationSection+Keyframes.swift
//
// Extracted from ShotVideoGenerationSection.swift (WS9.1 god-file decomposition).
// Behaviour unchanged.
//

import SwiftUI
import AVKit
import AppKit
import UniformTypeIdentifiers
import DirectorsChairCore
import DirectorsChairServices


// MARK: - Keyframe Gallery (Redesigned — large cards)

struct KeyframeGallery: View {
    @Binding var keyframes: [VideoKeyframe]
    let duration: Double
    let shot: Shot
    let projectBasePath: URL?
    /// False when hosted inside a CollapsibleCard, which supplies the title.
    var showsHeader: Bool = true
    let isGeneratingKeyframe: Bool
    let activeKeyframeId: String?
    let onGenerateKeyframe: (String) -> Void
    let onRemoveKeyframe: (String) -> Void
    let onAddKeyframe: () -> Void
    let onAnnotationsApplied: (String, [KeyframeAnnotation]) -> Void
    /// View/edit a keyframe's generation prompt without generating.
    var onEditKeyframePrompt: ((String) -> Void)? = nil

    @State private var previewKeyframeImage: NSImage? = nil
    @State private var previewKeyframeLabel: String = ""
    @State private var showingKeyframePreview: Bool = false
    @State private var annotatingKeyframeId: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header (title omitted when the hosting card provides it)
            if showsHeader {
                HStack {
                    Image(systemName: "film")
                        .font(.system(size: 12))
                        .foregroundColor(.accentColor)
                    Text("KEYFRAMES")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.2)
                        .foregroundColor(.gray)

                    Spacer()

                    Text("\(keyframes.count) frame\(keyframes.count == 1 ? "" : "s")")
                        .font(.system(size: 10))
                        .foregroundColor(.gray.opacity(0.6))
                }
            }

            // Timeline track
            timelineTrack

            // Keyframe cards — horizontal scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(sortedKeyframes) { kf in
                        KeyframeCard(
                            keyframe: kf,
                            duration: duration,
                            projectBasePath: projectBasePath,
                            isGenerating: isGeneratingKeyframe && activeKeyframeId == kf.id,
                            isStartOrEnd: kf.position == 0.0 || kf.position == 1.0,
                            onGenerate: { onGenerateKeyframe(kf.id) },
                            onRemove: { onRemoveKeyframe(kf.id) },
                            onView: { image in
                                previewKeyframeImage = image
                                previewKeyframeLabel = kf.label.isEmpty ? String(format: "%.1fs", kf.position * duration) : kf.label
                                showingKeyframePreview = true
                            },
                            onDownload: { image in
                                downloadKeyframeImage(image: image, keyframe: kf)
                            },
                            onEdit: {
                                annotatingKeyframeId = kf.id
                            },
                            onEditPrompt: onEditKeyframePrompt.map { edit in
                                { edit(kf.id) }
                            }
                        )
                    }

                    // Add keyframe button
                    addKeyframeCard
                }
                .padding(.vertical, 2)
            }
        }
        .padding(14)
        .background(Color(hex: "#252525"))
        .cornerRadius(10)
        .sheet(isPresented: $showingKeyframePreview) {
            KeyframePreviewSheet(
                image: $previewKeyframeImage,
                label: previewKeyframeLabel,
                shotId: shot.shotId,
                isPresented: $showingKeyframePreview,
                onDownload: {
                    if let img = previewKeyframeImage {
                        downloadKeyframeImage(image: img, keyframe: nil)
                    }
                }
            )
        }
        .sheet(isPresented: Binding(
            get: { annotatingKeyframeId != nil },
            set: { if !$0 { annotatingKeyframeId = nil } }
        )) {
            if let kfId = annotatingKeyframeId,
               let kfIndex = keyframes.firstIndex(where: { $0.id == kfId }) {
                KeyframeAnnotationOverlay(
                    keyframe: $keyframes[kfIndex],
                    projectBasePath: projectBasePath,
                    shotId: shot.shotId,
                    isPresented: Binding(
                        get: { annotatingKeyframeId != nil },
                        set: { if !$0 { annotatingKeyframeId = nil } }
                    ),
                    onApplyEdits: { annotations in
                        onAnnotationsApplied(kfId, annotations)
                    }
                )
            }
        }
    }

    private var sortedKeyframes: [VideoKeyframe] {
        keyframes.sorted { $0.position < $1.position }
    }

    // Mini timeline track showing keyframe positions
    private var timelineTrack: some View {
        GeometryReader { geo in
            let w = geo.size.width

            ZStack(alignment: .leading) {
                // Track background
                Capsule()
                    .fill(Color(hex: "#3A3A3A"))
                    .frame(height: 4)

                // Filled portion (start to end)
                Capsule()
                    .fill(Color.accentColor.opacity(0.4))
                    .frame(height: 4)

                // Keyframe dots
                ForEach(sortedKeyframes) { kf in
                    Circle()
                        .fill(kf.imagePath != nil ? Color.accentColor : Color.gray)
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle()
                                .stroke(Color(hex: "#252525"), lineWidth: 2)
                        )
                        .position(x: max(5, min(kf.position * w, w - 5)), y: 5)
                }
            }
        }
        .frame(height: 10)
        .padding(.horizontal, 2)
    }

    private var addKeyframeCard: some View {
        Button(action: onAddKeyframe) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "#2A2A2A"))
                        .frame(width: 380, height: 240)

                    VStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 28))
                            .foregroundColor(.accentColor.opacity(0.7))
                        Text("Add Keyframe")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }

                Text("")
                    .font(.system(size: 9))
            }
        }
        .buttonStyle(.plain)
    }

    private func downloadKeyframeImage(image: NSImage, keyframe: VideoKeyframe?) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png, .jpeg]
        let label = keyframe?.label ?? "keyframe"
        let safeName = label.replacingOccurrences(of: " ", with: "_").lowercased()
        savePanel.nameFieldStringValue = "shot_\(shot.shotId)_\(safeName).png"
        savePanel.title = "Save Keyframe Image"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                let ext = url.pathExtension.lowercased()
                if let tiffData = image.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData) {
                    let imageData: Data?
                    if ext == "jpg" || ext == "jpeg" {
                        imageData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
                    } else {
                        imageData = bitmap.representation(using: .png, properties: [:])
                    }
                    if let data = imageData {
                        try? data.write(to: url)
                    }
                }
            }
        }
    }
}

// MARK: - Single Keyframe Card

struct KeyframeCard: View {
    let keyframe: VideoKeyframe
    let duration: Double
    let projectBasePath: URL?
    let isGenerating: Bool
    let isStartOrEnd: Bool
    let onGenerate: () -> Void
    let onRemove: () -> Void
    let onView: (NSImage) -> Void
    let onDownload: (NSImage) -> Void
    let onEdit: () -> Void
    /// View/edit the prompt this frame will generate with (persistable).
    var onEditPrompt: (() -> Void)? = nil

    @State private var isHovering: Bool = false

    private let cardWidth: CGFloat = 380
    private let cardHeight: CGFloat = 240

    private var loadedImage: NSImage? {
        guard let imagePath = keyframe.imagePath,
              let basePath = projectBasePath else { return nil }
        return NSImage(contentsOf: basePath.appendingPathComponent(imagePath))
    }

    var body: some View {
        VStack(spacing: 6) {
            // Image preview area
            ZStack {
                if let image = loadedImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: cardWidth, height: cardHeight)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    // Empty placeholder
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "#1E1E1E"))
                        .frame(width: cardWidth, height: cardHeight)
                        .overlay(
                            VStack(spacing: 6) {
                                if isGenerating {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                                    Text("Generating...")
                                        .font(.system(size: 10))
                                        .foregroundColor(.gray)
                                } else {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.system(size: 24))
                                        .foregroundColor(.gray.opacity(0.5))
                                    Text("No image")
                                        .font(.system(size: 10))
                                        .foregroundColor(.gray.opacity(0.5))
                                }
                            }
                        )
                }

                // Position badge (top-left)
                VStack {
                    HStack {
                        Text(keyframe.label.isEmpty ? String(format: "%.1fs", keyframe.position * duration) : keyframe.label)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)
                        Spacer()
                    }
                    Spacer()
                }
                .padding(8)

                // Regeneration overlay — unmissable while an existing image is
                // being replaced (e.g. after applying annotation edits).
                if isGenerating, loadedImage != nil {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.65))
                        .frame(width: cardWidth, height: cardHeight)
                    VStack(spacing: 10) {
                        ProgressView()
                            .scaleEffect(1.3)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text(keyframe.annotations?.isEmpty == false
                             ? "Applying annotation edits…"
                             : "Regenerating frame…")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        Text("The image updates here when it's ready")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.65))
                    }
                }

                // Hover action buttons (top-right) — only when image exists
                if let image = loadedImage, isHovering, !isGenerating {
                    VStack {
                        HStack {
                            Spacer()
                            HStack(spacing: 4) {
                                // View full size
                                Button(action: { onView(image) }) {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(6)
                                        .background(Color.black.opacity(0.7))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .help("View full size")

                                // Download
                                Button(action: { onDownload(image) }) {
                                    Image(systemName: "arrow.down.circle")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(6)
                                        .background(Color.black.opacity(0.7))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .help("Download image")

                                // Edit / Annotate
                                Button(action: onEdit) {
                                    Image(systemName: "pencil.and.outline")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(6)
                                        .background(Color.black.opacity(0.7))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .help("Edit with annotations")

                                // Regenerate
                                Button(action: onGenerate) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(6)
                                        .background(Color.black.opacity(0.7))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .help("Regenerate")
                                .disabled(isGenerating)
                            }
                        }
                        Spacer()
                    }
                    .padding(8)
                    .transition(.opacity)
                }
            }
            .frame(width: cardWidth, height: cardHeight)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        keyframe.imagePath != nil ? Color.accentColor.opacity(0.4) : Color(hex: "#3A3A3A"),
                        lineWidth: 1
                    )
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }

            // Time label + annotation badge
            HStack(spacing: 6) {
                Text(String(format: "%.1fs", keyframe.position * duration))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))

                if let annotations = keyframe.annotations, !annotations.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 9))
                        Text("\(annotations.count)")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(4)
                }

                if keyframe.customPrompt != nil {
                    HStack(spacing: 3) {
                        Image(systemName: "pencil")
                            .font(.system(size: 8))
                        Text("custom prompt")
                            .font(.system(size: 8, weight: .medium))
                    }
                    .foregroundColor(.accentColor.opacity(0.9))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.12))
                    .cornerRadius(4)
                }
            }

            // Actions row
            HStack(spacing: 6) {
                Button(action: onGenerate) {
                    HStack(spacing: 3) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 9))
                        Text("Generate")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.2))
                    .foregroundColor(.accentColor)
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .disabled(isGenerating)

                if let onEditPrompt {
                    Button(action: onEditPrompt) {
                        HStack(spacing: 3) {
                            Image(systemName: "text.quote")
                                .font(.system(size: 9))
                            Text("Prompt")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: "#3A3A3A"))
                        .foregroundColor(.white.opacity(0.85))
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .disabled(isGenerating)
                    .help("See and edit the prompt this frame will generate with")
                }

                if !isStartOrEnd {
                    Button(action: onRemove) {
                        Image(systemName: "trash")
                            .font(.system(size: 9))
                            .foregroundColor(.red.opacity(0.7))
                            .padding(4)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Keyframe Full-Size Preview Sheet

struct KeyframePreviewSheet: View {
    @Binding var image: NSImage?
    let label: String
    let shotId: Int
    @Binding var isPresented: Bool
    let onDownload: () -> Void

    private var imageSize: CGSize {
        guard let image = image else { return CGSize(width: 900, height: 506) }
        return image.size
    }

    private var sheetSize: (width: CGFloat, height: CGFloat) {
        let chromeHeight: CGFloat = 100
        let aspectRatio = imageSize.width / max(imageSize.height, 1)
        let displayWidth = min(imageSize.width, 1200)
        let displayHeight = displayWidth / aspectRatio
        return (displayWidth, displayHeight + chromeHeight)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Shot #\(shotId) — \(label) Keyframe")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(hex: "#1E1E1E"))

            Divider()

            // Image
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            } else {
                VStack {
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("No preview available")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(hex: "#1A1A1A"))
            }

            Divider()

            // Footer
            HStack {
                if let image = image {
                    Text("\(Int(image.size.width)) \u{00D7} \(Int(image.size.height))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                Button(action: onDownload) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle")
                        Text("Download")
                    }
                }

                Button("Done") {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(hex: "#1E1E1E"))
        }
        .frame(width: sheetSize.width, height: sheetSize.height)
        .background(Color(hex: "#252525"))
    }
}

// MARK: - Keyframe Annotation Overlay

struct KeyframeAnnotationOverlay: View {
    @Binding var keyframe: VideoKeyframe
    let projectBasePath: URL?
    let shotId: Int
    @Binding var isPresented: Bool
    let onApplyEdits: ([KeyframeAnnotation]) -> Void

    private var loadedImage: NSImage? {
        guard let imagePath = keyframe.imagePath,
              let basePath = projectBasePath else { return nil }
        return NSImage(contentsOf: basePath.appendingPathComponent(imagePath))
    }

    var body: some View {
        if let image = loadedImage {
            ImageAnnotationEditor(
                image: image,
                title: "EDIT KEYFRAME",
                subtitle: keyframe.label.isEmpty ? String(format: "%.1fs", keyframe.position) : keyframe.label,
                initialAnnotations: keyframe.annotations ?? [],
                isPresented: $isPresented,
                onApplyEdits: { annotations in
                    keyframe.annotations = annotations
                    onApplyEdits(annotations)
                }
            )
        } else {
            VStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.system(size: 32))
                    .foregroundColor(.gray.opacity(0.4))
                Text("No keyframe image")
                    .font(.system(size: 12))
                    .foregroundColor(.gray.opacity(0.5))
            }
            .frame(width: 900, height: 600)
            .background(Color(hex: "#252525"))
        }
    }
}

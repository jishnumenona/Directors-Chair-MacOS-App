//
// CinematographyView+ReferenceMedia.swift
//
// Extracted from CinematographyView.swift (WS9.1 god-file decomposition).
// Behaviour unchanged; these were file-private helpers, now module-internal.
//

import SwiftUI
import AVFoundation
import DirectorsChairCore
import DirectorsChairServices


// MARK: - Reference Media Section

struct ReferenceMediaSection: View {
    let media: [ReferenceMedia]
    let shotId: Int
    let projectBasePath: URL?
    let onMediaAdded: (ReferenceMedia) -> Void
    let onMediaRemoved: (String) -> Void
    let onUseAsPreview: (String) -> Void

    @State private var isDraggingOver = false
    @State private var showingFilePicker = false
    @State private var selectedMedia: ReferenceMedia?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                Text("Reference Images")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)

                if !media.isEmpty {
                    Text("·")
                        .foregroundColor(.gray.opacity(0.5))
                    Text("\(media.count)")
                        .font(.system(size: 11))
                        .foregroundColor(.gray.opacity(0.6))
                }

                Spacer()

                // Add button in header
                Button(action: { showingFilePicker = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .medium))
                        Text("Add")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }

            // Media grid or empty state
            if media.isEmpty {
                // Empty state with drop zone
                ReferenceDropZone(
                    isDraggingOver: $isDraggingOver,
                    onTap: { showingFilePicker = true },
                    onDrop: handleDrop
                )
            } else {
                // Scrollable grid of larger thumbnails
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(media) { item in
                            ReferenceMediaCard(
                                media: item,
                                onRemove: { onMediaRemoved(item.id) },
                                onTap: { selectedMedia = item },
                                onUseAsPreview: item.type == .image ? {
                                    useReferenceAsPreview(item)
                                } : nil
                            )
                        }

                        // Add more button
                        AddMoreButton(
                            isDraggingOver: $isDraggingOver,
                            onTap: { showingFilePicker = true },
                            onDrop: handleDrop
                        )
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.image, .movie, .video],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
        .sheet(item: $selectedMedia) { media in
            ReferenceMediaPreviewSheet(
                media: media,
                isPresented: Binding(
                    get: { selectedMedia != nil },
                    set: { if !$0 { selectedMedia = nil } }
                ),
                onUseAsPreview: media.type == .image ? {
                    useReferenceAsPreview(media)
                    selectedMedia = nil
                } : nil
            )
        }
    }

    /// Copy reference image to shot preview location and use it as the preview
    private func useReferenceAsPreview(_ media: ReferenceMedia) {
        guard let basePath = projectBasePath else { return }

        let projectDir = basePath.deletingLastPathComponent()
        let shotDir = projectDir
            .appendingPathComponent("assets")
            .appendingPathComponent("shots")
            .appendingPathComponent("shot_\(shotId)")

        do {
            // Create directory if needed
            if !FileManager.default.fileExists(atPath: shotDir.path) {
                try FileManager.default.createDirectory(at: shotDir, withIntermediateDirectories: true)
            }

            // Copy the reference image
            let sourceURL = URL(fileURLWithPath: media.path)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
            let timestamp = dateFormatter.string(from: Date())

            // Save with timestamp for history
            let ext = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension
            let historyFilename = "preview_\(timestamp)_ref.\(ext)"
            let historyPath = shotDir.appendingPathComponent(historyFilename)

            // Copy to history
            if FileManager.default.fileExists(atPath: historyPath.path) {
                try FileManager.default.removeItem(at: historyPath)
            }
            try FileManager.default.copyItem(at: sourceURL, to: historyPath)

            // Also copy as latest.png
            let latestPath = shotDir.appendingPathComponent("latest.png")
            if FileManager.default.fileExists(atPath: latestPath.path) {
                try FileManager.default.removeItem(at: latestPath)
            }

            // Load and save as PNG to ensure format consistency
            if let image = NSImage(contentsOf: sourceURL),
               let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                try pngData.write(to: latestPath)
            } else {
                // Fallback: just copy the file
                try FileManager.default.copyItem(at: sourceURL, to: latestPath)
            }

            // Save a note that this was from a reference
            let promptPath = shotDir.appendingPathComponent("prompt.txt")
            let note = "[Reference Image]\nUsed reference image: \(media.caption)\nOriginal path: \(media.path)\nDate: \(Date())"
            try note.write(to: promptPath, atomically: true, encoding: .utf8)

            let relativePath = "assets/shots/shot_\(shotId)/latest.png"
            onUseAsPreview(relativePath)

        } catch {
            print("Error copying reference to preview: \(error)")
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.image") {
                provider.loadItem(forTypeIdentifier: "public.image", options: nil) { item, _ in
                    if let url = item as? URL {
                        DispatchQueue.main.async {
                            addMedia(from: url, type: .image)
                        }
                    }
                }
                return true
            } else if provider.hasItemConformingToTypeIdentifier("public.movie") {
                provider.loadItem(forTypeIdentifier: "public.movie", options: nil) { item, _ in
                    if let url = item as? URL {
                        DispatchQueue.main.async {
                            addMedia(from: url, type: .video)
                        }
                    }
                }
                return true
            }
        }
        return false
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }

        for url in urls {
            let ext = url.pathExtension.lowercased()
            let type: ReferenceMedia.MediaType = ["mp4", "mov", "m4v", "avi"].contains(ext) ? .video : .image
            addMedia(from: url, type: type)
        }
    }

    private func addMedia(from url: URL, type: ReferenceMedia.MediaType) {
        let media = ReferenceMedia(
            type: type,
            path: url.path,
            caption: url.lastPathComponent
        )
        onMediaAdded(media)
    }
}

// MARK: - Reference Drop Zone (Empty State)

struct ReferenceDropZone: View {
    @Binding var isDraggingOver: Bool
    let onTap: () -> Void
    let onDrop: ([NSItemProvider]) -> Bool

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 24))
                    .foregroundColor(isDraggingOver ? .accentColor : .gray.opacity(0.5))

                Text("Drop images or click to add")
                    .font(.system(size: 11))
                    .foregroundColor(.gray.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: isDraggingOver ? "#2A2A2A" : "#1E1E1E"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isDraggingOver ? Color.accentColor : Color(hex: "#3A3A3A"),
                                style: StrokeStyle(lineWidth: 1, dash: [6, 3])
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .onDrop(of: [.image, .movie], isTargeted: $isDraggingOver, perform: onDrop)
    }
}

// MARK: - Reference Media Card (Larger Thumbnail)

struct ReferenceMediaCard: View {
    let media: ReferenceMedia
    let onRemove: () -> Void
    let onTap: () -> Void
    let onUseAsPreview: (() -> Void)?

    @State private var isHovered = false
    @State private var thumbnailImage: NSImage?

    private let cardWidth: CGFloat = 160
    private let cardHeight: CGFloat = 100

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Main content
            Button(action: onTap) {
                ZStack {
                    if let image = thumbnailImage {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Color(hex: "#2A2A2A")
                        VStack(spacing: 6) {
                            Image(systemName: media.type == .video ? "play.rectangle.fill" : "photo")
                                .font(.system(size: 28))
                                .foregroundColor(.gray.opacity(0.4))
                            Text(media.caption)
                                .font(.system(size: 9))
                                .foregroundColor(.gray.opacity(0.5))
                                .lineLimit(1)
                        }
                    }

                    // Video overlay
                    if media.type == .video && thumbnailImage != nil {
                        Color.black.opacity(0.3)
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.9))
                    }

                    // Hover overlay with action buttons
                    if isHovered && thumbnailImage != nil {
                        Color.black.opacity(0.4)

                        // Use as Preview button (for images only)
                        if onUseAsPreview != nil {
                            VStack(spacing: 8) {
                                Button(action: { onUseAsPreview?() }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "photo.badge.checkmark")
                                            .font(.system(size: 11))
                                        Text("Use as Preview")
                                            .font(.system(size: 10, weight: .medium))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.accentColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)

                                Text("Click to view")
                                    .font(.system(size: 9))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        } else {
                            Image(systemName: "eye")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
                .frame(width: cardWidth, height: cardHeight)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(isHovered ? 0.3 : 0.1), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            // Remove button
            if isHovered {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white, Color.black.opacity(0.6))
                }
                .buttonStyle(.plain)
                .offset(x: 6, y: -6)
            }
        }
        .onHover { isHovered = $0 }
        .onAppear { loadThumbnail() }
        .help("Click to view full size")
    }

    private func loadThumbnail() {
        guard media.type == .image else { return }
        let url = URL(fileURLWithPath: media.path)
        if let image = NSImage(contentsOf: url) {
            thumbnailImage = image
        }
    }
}

// MARK: - Add More Button

struct AddMoreButton: View {
    @Binding var isDraggingOver: Bool
    let onTap: () -> Void
    let onDrop: ([NSItemProvider]) -> Bool

    @State private var isHovered = false

    private let cardHeight: CGFloat = 100

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 24))
                Text("Add")
                    .font(.system(size: 10))
            }
            .foregroundColor(isHovered || isDraggingOver ? .white : .gray)
            .frame(width: 80, height: cardHeight)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: isHovered || isDraggingOver ? "#3A3A3A" : "#2A2A2A"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isDraggingOver ? Color.accentColor : Color.white.opacity(0.1),
                                style: StrokeStyle(lineWidth: 1, dash: [4, 2])
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .onDrop(of: [.image, .movie], isTargeted: $isDraggingOver, perform: onDrop)
    }
}

// MARK: - Reference Media Preview Sheet

struct ReferenceMediaPreviewSheet: View {
    let media: ReferenceMedia
    @Binding var isPresented: Bool
    let onUseAsPreview: (() -> Void)?

    @State private var image: NSImage?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reference Image")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(media.caption)
                        .font(.caption)
                        .foregroundColor(.gray)
                }

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

            // Image preview
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            } else {
                VStack(spacing: 12) {
                    if media.type == .video {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("Video preview not available")
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else {
                        ProgressView()
                        Text("Loading...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(hex: "#1A1A1A"))
            }

            Divider()

            // Footer with file info and actions
            HStack {
                if let image = image {
                    Text("\(Int(image.size.width)) × \(Int(image.size.height))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                // Use as Preview button (prominent)
                if let onUseAsPreview = onUseAsPreview {
                    Button(action: onUseAsPreview) {
                        HStack(spacing: 6) {
                            Image(systemName: "photo.badge.checkmark")
                                .font(.system(size: 12))
                            Text("Use as Shot Preview")
                                .font(.system(size: 12, weight: .medium))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button("Open in Finder") {
                    NSWorkspace.shared.selectFile(media.path, inFileViewerRootedAtPath: "")
                }
                .font(.caption)

                Button("Done") {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(hex: "#1E1E1E"))
        }
        .frame(width: 800, height: 600)
        .background(Color(hex: "#252525"))
        .onAppear {
            loadImage()
        }
    }

    private func loadImage() {
        guard media.type == .image else { return }
        let url = URL(fileURLWithPath: media.path)
        if let loadedImage = NSImage(contentsOf: url) {
            image = loadedImage
        }
    }
}

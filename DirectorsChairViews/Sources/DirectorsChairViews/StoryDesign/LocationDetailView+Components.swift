//
// LocationDetailView+Components.swift
//
// Extracted from LocationDetailView.swift (WS9.1 tier decomposition).
//

import SwiftUI
import DirectorsChairCore
import AppKit


// MARK: - Data Types

struct LocationDialogueSample: Hashable {
    let character: String
    let text: String
}

struct LocationSceneInfo: Identifiable, Equatable {
    let id = UUID()
    let sceneName: String
    let dialogueCount: Int
    let actionCount: Int
    let sampleDialogues: [LocationDialogueSample]
    let sampleActions: [String]

    static func == (lhs: LocationSceneInfo, rhs: LocationSceneInfo) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - AttributeCard (Location variant)

struct LocationAttributeCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(1.2)
            }

            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - LocationTypeChip

struct LocationTypeChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : Color(nsColor: .quaternarySystemFill))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - LocationCompactChip

struct LocationCompactChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.accentColor : Color(nsColor: .quaternarySystemFill))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - LocationGalleryButton

struct LocationGalleryButton: View {
    let label: String
    let icon: String
    let color: Color
    var isProminent: Bool = false
    let action: () -> Void

    @State var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(isProminent ? .white : color)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isProminent ? .white : (isHovered ? .primary : .secondary))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .frame(maxWidth: isProminent ? .infinity : nil)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isProminent
                        ? color.opacity(isHovered ? 0.9 : 0.8)
                        : (isHovered ? Color(nsColor: .quaternarySystemFill) : Color(nsColor: .quaternarySystemFill).opacity(0.5)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isProminent ? Color.clear : color.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - LocationVariationThumbnail

struct LocationVariationThumbnail: View {
    let label: String
    let imagePath: String?
    let projectBasePath: URL?
    var isSelected: Bool = false
    var generationProgress: Double?
    var refreshId: UUID?
    var onSelect: (() -> Void)?
    var onView: ((URL) -> Void)?
    var onDownload: ((URL) -> Void)?
    var onGenerate: (() -> Void)?
    var onEditGenerate: (() -> Void)?
    var onUpload: (() -> Void)?

    @State var isHovering = false

    var hasImage: Bool { imagePath != nil }
    var isGenerating: Bool { generationProgress != nil }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .quaternarySystemFill))
                    .frame(height: 70)

                if let path = imagePath, let basePath = projectBasePath {
                    let fullPath = basePath.appendingPathComponent(path)
                    AsyncImage(url: fullPath) { phase in
                        if case .success(let image) = phase {
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 70)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Image(systemName: "photo")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        }
                    }
                    .id(refreshId ?? UUID())

                    // Hover overlay with actions
                    if isHovering && !isGenerating {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.6))
                            .frame(height: 70)

                        VStack(spacing: 5) {
                            HStack(spacing: 6) {
                                Button {
                                    onView?(fullPath)
                                } label: {
                                    Image(systemName: "eye")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white)
                                        .frame(width: 22, height: 22)
                                        .background(Circle().fill(Color.white.opacity(0.2)))
                                }
                                .buttonStyle(.plain)
                                .help("View full screen")

                                Button {
                                    onDownload?(fullPath)
                                } label: {
                                    Image(systemName: "arrow.down")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white)
                                        .frame(width: 22, height: 22)
                                        .background(Circle().fill(Color.white.opacity(0.2)))
                                }
                                .buttonStyle(.plain)
                                .help("Download image")
                            }

                            HStack(spacing: 4) {
                                Button {
                                    onGenerate?()
                                } label: {
                                    HStack(spacing: 2) {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .font(.system(size: 7))
                                        Text("Redo")
                                            .font(.system(size: 7, weight: .medium))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Color.accentColor.opacity(0.8)))
                                }
                                .buttonStyle(.plain)
                                .help("Regenerate with same prompt")

                                Button {
                                    onEditGenerate?()
                                } label: {
                                    HStack(spacing: 2) {
                                        Image(systemName: "pencil.and.outline")
                                            .font(.system(size: 7))
                                        Text("Edit")
                                            .font(.system(size: 7, weight: .medium))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Color.orange.opacity(0.8)))
                                }
                                .buttonStyle(.plain)
                                .help("Annotate & edit image")

                                Button {
                                    onUpload?()
                                } label: {
                                    HStack(spacing: 2) {
                                        Image(systemName: "photo.badge.plus")
                                            .font(.system(size: 7))
                                        Text("Upload")
                                            .font(.system(size: 7, weight: .medium))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Color.white.opacity(0.25)))
                                }
                                .buttonStyle(.plain)
                                .help("Upload custom image")
                            }
                        }
                    }
                } else if !isGenerating {
                    // Empty state — clickable to generate
                    Button {
                        onGenerate?()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: isHovering ? "wand.and.stars" : "plus")
                                .font(.system(size: isHovering ? 16 : 14))
                                .foregroundColor(isHovering ? .accentColor : Color(nsColor: .tertiaryLabelColor))
                            if isHovering {
                                Text("Generate")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 70)
                    }
                    .buttonStyle(.plain)
                }

                // Generation progress overlay
                if let progress = generationProgress {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.6))
                        .frame(height: 70)

                    LocationProgressRing(progress: progress, size: 36)
                }

                // Selected or hover border
                if isSelected && hasImage {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor, lineWidth: 2)
                        .frame(height: 70)
                } else if !hasImage && !isGenerating && isHovering {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor.opacity(0.5), lineWidth: 1.5)
                        .frame(height: 70)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if hasImage {
                    onSelect?()
                }
            }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }

            Text(label)
                .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .accentColor : (isGenerating ? .accentColor : (isHovering ? .primary : .secondary)))
        }
    }
}

// MARK: - LocationProgressRing

struct LocationProgressRing: View {
    let progress: Double
    var size: CGFloat = 60

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 3)
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                .stroke(
                    Color.accentColor,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)

            VStack(spacing: 1) {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                if size > 50 {
                    Text("Generating")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }
}

// MARK: - LocationFullScreenViewer

struct LocationFullScreenViewer: View {
    let imageURL: URL?
    let title: String
    var onDownload: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline)

                Spacer()

                Button {
                    onDownload?()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 11))
                            .foregroundColor(.green)
                        Text("Download")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(nsColor: .quaternarySystemFill))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.green.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10))
                        Text("Close")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.8))
                    )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            if let url = imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        ScrollView([.horizontal, .vertical]) {
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    case .failure:
                        VStack {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 48))
                                .foregroundColor(.orange)
                            Text("Failed to load image")
                                .foregroundColor(.secondary)
                        }
                    case .empty:
                        ProgressView("Loading...")
                    @unknown default:
                        ProgressView()
                    }
                }
            } else {
                VStack {
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("No image selected")
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .background(Color.black)
    }
}

// MARK: - Location Prompt Editor

struct LocationPromptEditor: View {
    let variation: String
    let variationLabel: String
    @Binding var prompt: String
    var onGenerate: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "pencil.and.outline")
                    .font(.system(size: 14))
                    .foregroundColor(.accentColor)
                Text("EDIT PROMPT")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(.secondary)

                Spacer()

                Text(variationLabel.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.accentColor))
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()

            // Prompt editor
            VStack(alignment: .leading, spacing: 8) {
                Text("Image Generation Prompt")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                TextEditor(text: $prompt)
                    .font(.system(size: 12))
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(Color(nsColor: .quaternarySystemFill))
                    .cornerRadius(8)
                    .frame(minHeight: 140)

                Text("Describe the location, mood, lighting, time of day, and camera angle. The AI will generate a photorealistic image based on this prompt.")
                    .font(.system(size: 10))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    .lineLimit(2)
            }
            .padding(20)

            Divider()

            // Action buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Spacer()

                Button(action: onGenerate) {
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 11))
                        Text("Generate")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.accentColor))
                }
                .buttonStyle(.plain)
                .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 520, height: 360)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Discovered Location Images

struct DiscoveredLocationImages {
    var primary: String?
    var day: String?
    var night: String?
    var goldenHour: String?
    var overcast: String?
    var wide: String?
    var detail: String?

    static func discover(for locationName: String, basePath: URL?) -> DiscoveredLocationImages {
        guard let basePath = basePath else { return DiscoveredLocationImages() }

        var result = DiscoveredLocationImages()
        let fileManager = FileManager.default
        let sanitizedName = sanitizeName(locationName)

        let locationFolder = basePath
            .appendingPathComponent("assets")
            .appendingPathComponent("locations")
            .appendingPathComponent(sanitizedName)

        func findImage(patterns: [String]) -> String? {
            guard fileManager.fileExists(atPath: locationFolder.path) else { return nil }
            guard let contents = try? fileManager.contentsOfDirectory(atPath: locationFolder.path) else { return nil }

            let files = contents.compactMap { filename -> (String, Date)? in
                let path = locationFolder.appendingPathComponent(filename).path
                guard let attrs = try? fileManager.attributesOfItem(atPath: path),
                      let modDate = attrs[.modificationDate] as? Date else { return nil }
                return (filename, modDate)
            }.sorted { $0.1 > $1.1 }

            for (filename, _) in files {
                let lower = filename.lowercased()
                for pattern in patterns {
                    if lower.contains(pattern.lowercased()) && (lower.hasSuffix(".png") || lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg")) {
                        return "assets/locations/\(sanitizedName)/\(filename)"
                    }
                }
            }
            return nil
        }

        result.primary = findImage(patterns: ["primary", "main", "hero"])
        result.day = findImage(patterns: ["day"])
        result.night = findImage(patterns: ["night"])
        result.goldenHour = findImage(patterns: ["golden_hour", "golden", "sunset"])
        result.overcast = findImage(patterns: ["overcast", "rain", "fog"])
        result.wide = findImage(patterns: ["wide", "establishing"])
        result.detail = findImage(patterns: ["detail", "close", "macro"])

        return result
    }

    static func sanitizeName(_ name: String) -> String {
        var sanitized = name
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "(", with: "_")
            .replacingOccurrences(of: ")", with: "_")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\"", with: "")

        while sanitized.contains("__") {
            sanitized = sanitized.replacingOccurrences(of: "__", with: "_")
        }

        return sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }
}

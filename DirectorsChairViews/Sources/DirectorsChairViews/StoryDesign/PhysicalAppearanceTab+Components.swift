//
// PhysicalAppearanceTab+Components.swift
//
// Extracted from PhysicalAppearanceTab.swift (WS9.1 tier decomposition).
//

import SwiftUI
import DirectorsChairCore
import DirectorsChairServices
import AppKit
import UniformTypeIdentifiers


// MARK: - Reusable Components

/// Card container for attribute groups
struct AttributeCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
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

/// Gender selection chip with icon
struct GenderChip: View {
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

/// Build type selection chip
struct BuildChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : Color(nsColor: .quaternarySystemFill))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

/// Compact selection chip for options like hair length, eye shape
struct CompactChip: View {
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

/// Face shape chip with visual shape indicator
struct FaceShapeChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var shapeIcon: String {
        switch label {
        case "Oval": return "oval"
        case "Round": return "circle"
        case "Square": return "square"
        case "Heart": return "heart"
        case "Oblong": return "rectangle"
        case "Diamond": return "diamond"
        default: return "circle"
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: shapeIcon)
                    .font(.system(size: 14))
                Text(label)
                    .font(.system(size: 9, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : Color(nsColor: .quaternarySystemFill))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

/// Measurement input with label, unit, icon, and optional slider
struct MeasurementField: View {
    let label: String
    let unit: String
    @Binding var value: Double?
    let icon: String
    let range: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 6) {
                TextField("—", value: $value, format: .number)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .frame(width: 52)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: .quaternarySystemFill))
                    .cornerRadius(8)

                Text(unit)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))

                Spacer()
            }

            // Subtle slider
            Slider(
                value: Binding(
                    get: { value ?? range.lowerValue(range) },
                    set: { value = $0 }
                ),
                in: range,
                step: 1
            )
            .controlSize(.mini)
            .tint(.accentColor.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }
}

/// Gallery action button with icon + label, hover effect, optional prominent style
struct GalleryButton: View {
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

extension ClosedRange where Bound == Double {
    func lowerValue(_ range: ClosedRange<Double>) -> Double {
        let mid = (range.lowerBound + range.upperBound) / 2
        return mid
    }
}

// MARK: - Angle Thumbnail

struct AngleThumbnail: View {
    let label: String
    let imagePath: String?
    let projectBasePath: URL?
    let characterName: String
    var generationProgress: Double?  // nil = idle, 0.0-1.0 = generating
    var refreshId: UUID?             // Changes to force AsyncImage reload
    var onView: ((URL) -> Void)?
    var onDownload: ((URL) -> Void)?
    var onGenerate: (() -> Void)?
    var onEditAnnotate: (() -> Void)?

    @State var isHovering = false

    var hasImage: Bool { imagePath != nil }
    var isGenerating: Bool { generationProgress != nil }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .quaternarySystemFill))
                    .frame(width: 80, height: 80)

                if let path = imagePath, let basePath = projectBasePath {
                    let fullPath = basePath.appendingPathComponent(path)
                    AsyncImage(url: fullPath) { phase in
                        if case .success(let image) = phase {
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Image(systemName: "person.crop.rectangle")
                                .font(.system(size: 20))
                                .foregroundColor(.gray)
                        }
                    }
                    .id(refreshId ?? UUID())

                    // Hover overlay with action buttons (only when not generating)
                    if isHovering && !isGenerating {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 80, height: 80)

                        VStack(spacing: 4) {
                            HStack(spacing: 4) {
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
                                    onEditAnnotate?()
                                } label: {
                                    Image(systemName: "pencil.and.outline")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white)
                                        .frame(width: 22, height: 22)
                                        .background(Circle().fill(Color.white.opacity(0.2)))
                                }
                                .buttonStyle(.plain)
                                .help("Annotate & edit image")

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
                                .help("Regenerate this angle")
                            }
                        }
                    }
                } else if !isGenerating {
                    // Empty state — clickable to generate
                    Button {
                        onGenerate?()
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: isHovering ? "wand.and.stars" : "plus")
                                .font(.system(size: isHovering ? 18 : 16))
                                .foregroundColor(isHovering ? .accentColor : Color(nsColor: .tertiaryLabelColor))
                            if isHovering {
                                Text("Generate")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .frame(width: 80, height: 80)
                    }
                    .buttonStyle(.plain)
                    .help("Generate \(label) image")
                }

                // Generation progress overlay
                if let progress = generationProgress {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.6))
                        .frame(width: 80, height: 80)

                    GenerationProgressRing(progress: progress, size: 44)
                }

                // Accent border when hovering on empty
                if !hasImage && !isGenerating && isHovering {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor.opacity(0.5), lineWidth: 1.5)
                        .frame(width: 80, height: 80)
                }
            }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isGenerating ? .accentColor : (isHovering ? .primary : .secondary))
        }
    }
}

// MARK: - Generation Progress Ring

struct GenerationProgressRing: View {
    let progress: Double
    var size: CGFloat = 60

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 3)
                .frame(width: size, height: size)

            // Progress ring
            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                .stroke(
                    Color.accentColor,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)

            // Percentage text
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

// MARK: - Full Screen Image Viewer

struct FullScreenImageViewer: View {
    let imageURL: URL?
    let title: String
    var onDownload: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
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
                .help("Save image to your computer")

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

            // Image
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

// MARK: - Discovered Character Images

/// Auto-discovered images from the character folder structure
struct DiscoveredCharacterImages {
    var baseImage: String?
    var front: String?
    var threeQuarterLeft: String?
    var threeQuarterRight: String?
    var profileLeft: String?
    var profileRight: String?
    var back: String?

    /// Discover images from the character folder
    /// Looks in: assets/characters/{CharacterName}/face/ and assets/characters/{CharacterName}/body/
    static func discover(for characterName: String, basePath: URL?) -> DiscoveredCharacterImages {
        guard let basePath = basePath else { return DiscoveredCharacterImages() }

        var result = DiscoveredCharacterImages()
        let fileManager = FileManager.default

        // Sanitize character name for folder lookup
        let sanitizedName = sanitizeName(characterName)

        // Check face folder
        let faceFolder = basePath
            .appendingPathComponent("assets")
            .appendingPathComponent("characters")
            .appendingPathComponent(sanitizedName)
            .appendingPathComponent("face")

        // Check body folder
        let bodyFolder = basePath
            .appendingPathComponent("assets")
            .appendingPathComponent("characters")
            .appendingPathComponent(sanitizedName)
            .appendingPathComponent("body")

        // Helper to find first image matching patterns
        func findImage(in folder: URL, patterns: [String]) -> String? {
            guard fileManager.fileExists(atPath: folder.path) else { return nil }
            guard let contents = try? fileManager.contentsOfDirectory(atPath: folder.path) else { return nil }

            // Sort by modification date descending to get most recent
            let files = contents.compactMap { filename -> (String, Date)? in
                let path = folder.appendingPathComponent(filename).path
                guard let attrs = try? fileManager.attributesOfItem(atPath: path),
                      let modDate = attrs[.modificationDate] as? Date else { return nil }
                return (filename, modDate)
            }.sorted { $0.1 > $1.1 }

            for (filename, _) in files {
                let lower = filename.lowercased()
                for pattern in patterns {
                    if lower.contains(pattern.lowercased()) && (lower.hasSuffix(".png") || lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg")) {
                        let relativePath = "assets/characters/\(sanitizedName)/\(folder.lastPathComponent)/\(filename)"
                        return relativePath
                    }
                }
            }
            return nil
        }

        // Discover face images
        result.baseImage = findImage(in: faceFolder, patterns: ["base", "front"])
        result.front = findImage(in: faceFolder, patterns: ["front", "face_front"])
        result.threeQuarterLeft = findImage(in: faceFolder, patterns: ["three_quarter_left", "3_4_left", "3/4_left"])
        result.threeQuarterRight = findImage(in: faceFolder, patterns: ["three_quarter_right", "3_4_right", "3/4_right"])
        result.profileLeft = findImage(in: faceFolder, patterns: ["profile_left", "profile"])
        result.profileRight = findImage(in: faceFolder, patterns: ["profile_right"])

        // Discover body images (can also serve as front/back)
        if result.front == nil {
            result.front = findImage(in: bodyFolder, patterns: ["front"])
        }
        result.back = findImage(in: bodyFolder, patterns: ["back"])

        // If no specific base image, use any front image
        if result.baseImage == nil {
            result.baseImage = result.front
        }

        return result
    }

    static func sanitizedName(for name: String) -> String {
        return sanitizeName(name)
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

#Preview {
    PhysicalAppearanceTab(
        character: .constant(Character(
            name: "John",
            role: "Protagonist",
            color: "#4A90D9",
            age: 30,
            hairColor: "#8B4513",
            hairStyle: "Short and wavy",
            hairLength: "Short",
            eyeColor: "#4169E1",
            eyeColorDescription: "Royal blue",
            eyeShape: "Almond",
            skinTone: "#DEB887",
            ethnicity: "Caucasian",
            facialStructure: "Oval"
        ))
    )
    .frame(width: 800, height: 600)
}

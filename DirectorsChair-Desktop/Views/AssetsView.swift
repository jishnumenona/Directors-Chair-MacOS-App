//
//  AssetsView.swift
//  DirectorsChair-Desktop
//
//  Phase 8E: Project Management
//  Media library and asset management — full implementation
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import AVFoundation

// MARK: - Data Model

enum MediaCategory: String, CaseIterable, Identifiable {
    case image = "Images"
    case audio = "Audio"
    case video = "Video"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .image: return "photo"
        case .audio: return "waveform"
        case .video: return "film"
        }
    }

    static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "bmp", "tiff", "heic", "webp"]
    static let audioExtensions: Set<String> = ["mp3", "wav", "aiff", "m4a", "flac", "aac", "ogg"]
    static let videoExtensions: Set<String> = ["mp4", "mov", "avi", "mkv", "m4v", "webm"]

    static func from(extension ext: String) -> MediaCategory? {
        let lower = ext.lowercased()
        if imageExtensions.contains(lower) { return .image }
        if audioExtensions.contains(lower) { return .audio }
        if videoExtensions.contains(lower) { return .video }
        return nil
    }
}

enum AssetCategory: String, CaseIterable, Identifiable {
    case characters = "Characters"
    case scenes = "Scenes"
    case shots = "Shots"
    case locations = "Locations"
    case visionBoard = "Vision Board"
    case props = "Props"
    case costumes = "Costumes"
    case posters = "Posters"
    case projectIcons = "Project Icons"
    case dialogueAudio = "Dialogue Audio"
    case soundEffects = "Sound Effects"
    case music = "Music"
    case videoReferences = "Video References"
    case videoFootage = "Video Footage"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .characters: return "person.fill"
        case .scenes: return "film"
        case .shots: return "camera.fill"
        case .locations: return "map.fill"
        case .visionBoard: return "rectangle.3.group.fill"
        case .props: return "cube.fill"
        case .costumes: return "tshirt.fill"
        case .posters: return "rectangle.portrait.fill"
        case .projectIcons: return "app.fill"
        case .dialogueAudio: return "person.wave.2.fill"
        case .soundEffects: return "speaker.wave.3.fill"
        case .music: return "music.note"
        case .videoReferences: return "play.rectangle.fill"
        case .videoFootage: return "video.fill"
        case .other: return "doc.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .characters: return .blue
        case .scenes: return .purple
        case .shots: return .orange
        case .locations: return .green
        case .visionBoard: return .pink
        case .props: return .brown
        case .costumes: return .cyan
        case .posters: return .red
        case .projectIcons: return .indigo
        case .dialogueAudio: return .teal
        case .soundEffects: return .yellow
        case .music: return .mint
        case .videoReferences: return .purple
        case .videoFootage: return .orange
        case .other: return .gray
        }
    }

    static func from(path: String) -> AssetCategory {
        let lower = path.lowercased()
        if lower.contains("assets/icons") || lower.contains("assets/icon") { return .projectIcons }
        if lower.contains("assets/characters") || lower.contains("characters/") { return .characters }
        if lower.contains("assets/scenes") || lower.contains("scenes/") { return .scenes }
        if lower.contains("assets/shots") || lower.contains("shots/") { return .shots }
        if lower.contains("locations/") { return .locations }
        if lower.contains("vision_board") || lower.contains("visionboard") || lower.contains("vision board") { return .visionBoard }
        if lower.contains("props/") { return .props }
        if lower.contains("costumes/") || lower.contains("wardrobe/") { return .costumes }
        if lower.contains("posters/") || lower.contains("poster") { return .posters }
        if lower.contains("audio/dialogue") || lower.contains("dialogue/") { return .dialogueAudio }
        if lower.contains("audio/sfx") || lower.contains("sfx/") || lower.contains("sound_effects") { return .soundEffects }
        if lower.contains("audio/music") || lower.contains("music/") || lower.contains("soundtrack") { return .music }
        if lower.contains("video/references") || lower.contains("references/") { return .videoReferences }
        if lower.contains("video/footage") || lower.contains("footage/") { return .videoFootage }
        return .other
    }
}

struct DiscoveredAsset: Identifiable, Hashable {
    let id: UUID
    let fileName: String
    let relativePath: String
    let fullURL: URL
    let fileExtension: String
    let mediaType: MediaCategory
    let fileSize: Int64
    let modificationDate: Date?
    let category: AssetCategory
    let contextLabel: String

    init(fileName: String, relativePath: String, fullURL: URL, fileExtension: String, mediaType: MediaCategory, fileSize: Int64, modificationDate: Date?, category: AssetCategory, contextLabel: String) {
        self.id = UUID()
        self.fileName = fileName
        self.relativePath = relativePath
        self.fullURL = fullURL
        self.fileExtension = fileExtension
        self.mediaType = mediaType
        self.fileSize = fileSize
        self.modificationDate = modificationDate
        self.category = category
        self.contextLabel = contextLabel
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    static func == (lhs: DiscoveredAsset, rhs: DiscoveredAsset) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Asset Scanner

@MainActor
final class AssetScanner: ObservableObject {
    @Published var assets: [DiscoveredAsset] = []
    @Published var isScanning = false

    private static let skipDirectories: Set<String> = [
        ".build", ".git", ".backups", ".swiftpm", "xcuserdata",
        "ModuleCache", "DerivedData", "build", ".Trash", "node_modules"
    ]

    var imageCount: Int { assets.filter { $0.mediaType == .image }.count }
    var audioCount: Int { assets.filter { $0.mediaType == .audio }.count }
    var videoCount: Int { assets.filter { $0.mediaType == .video }.count }

    func scan(projectURL: URL) {
        guard !isScanning else { return }
        isScanning = true
        assets = []

        let skipDirs = Self.skipDirectories
        Task.detached(priority: .userInitiated) {
            var discovered: [DiscoveredAsset] = []

            let projectDir = projectURL.deletingLastPathComponent()
            let fm = FileManager.default
            let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey, .isHiddenKey]

            guard let enumerator = fm.enumerator(
                at: projectDir,
                includingPropertiesForKeys: keys,
                options: [.skipsPackageDescendants]
            ) else {
                await MainActor.run {
                    self.isScanning = false
                }
                return
            }

            for case let fileURL as URL in enumerator {
                let fileName = fileURL.lastPathComponent

                // Skip hidden files
                if fileName.hasPrefix(".") {
                    if (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                        enumerator.skipDescendants()
                    }
                    continue
                }

                // Skip known build/cache directories
                if skipDirs.contains(fileName) {
                    enumerator.skipDescendants()
                    continue
                }

                // Check if directory
                if let values = try? fileURL.resourceValues(forKeys: [.isDirectoryKey]),
                   values.isDirectory == true {
                    continue
                }

                // Check extension
                let ext = fileURL.pathExtension.lowercased()
                guard let mediaType = MediaCategory.from(extension: ext) else { continue }

                // Get file attributes
                let resourceValues = try? fileURL.resourceValues(forKeys: Set(keys))
                let fileSize = Int64(resourceValues?.fileSize ?? 0)
                let modDate = resourceValues?.contentModificationDate

                // Compute relative path
                let relativePath = fileURL.path.replacingOccurrences(of: projectDir.path + "/", with: "")

                // Determine category from path
                let category = AssetCategory.from(path: relativePath)

                // Extract context label from parent folder
                let parentDir = fileURL.deletingLastPathComponent().lastPathComponent
                let contextLabel = parentDir == projectDir.lastPathComponent ? "" : parentDir

                discovered.append(DiscoveredAsset(
                    fileName: fileName,
                    relativePath: relativePath,
                    fullURL: fileURL,
                    fileExtension: ext,
                    mediaType: mediaType,
                    fileSize: fileSize,
                    modificationDate: modDate,
                    category: category,
                    contextLabel: contextLabel
                ))
            }

            // Sort by category order then filename
            discovered.sort { a, b in
                if a.category != b.category {
                    let aIdx = AssetCategory.allCases.firstIndex(of: a.category) ?? 0
                    let bIdx = AssetCategory.allCases.firstIndex(of: b.category) ?? 0
                    return aIdx < bIdx
                }
                return a.fileName.localizedCaseInsensitiveCompare(b.fileName) == .orderedAscending
            }

            await MainActor.run {
                self.assets = discovered
                self.isScanning = false
            }
        }
    }
}

// MARK: - Thumbnail Cache

final class AssetThumbnailCache {
    static let shared = AssetThumbnailCache()
    private let cache = NSCache<NSURL, NSImage>()

    private init() {
        cache.countLimit = 500
    }

    func thumbnail(for url: URL) -> NSImage? {
        cache.object(forKey: url as NSURL)
    }

    func setThumbnail(_ image: NSImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }

    static func generateThumbnail(for url: URL, maxSize: CGFloat = 200) async -> NSImage? {
        if let cached = shared.thumbnail(for: url) {
            return cached
        }

        return await withCheckedContinuation { continuation in
            Task.detached(priority: .utility) {
                guard let image = NSImage(contentsOf: url) else {
                    continuation.resume(returning: nil)
                    return
                }

                let size = image.size
                let scale = min(maxSize / size.width, maxSize / size.height, 1.0)
                let newSize = NSSize(width: size.width * scale, height: size.height * scale)

                let thumbnail = NSImage(size: newSize)
                thumbnail.lockFocus()
                image.draw(in: NSRect(origin: .zero, size: newSize),
                           from: NSRect(origin: .zero, size: size),
                           operation: .copy,
                           fraction: 1.0)
                thumbnail.unlockFocus()

                await MainActor.run {
                    shared.setThumbnail(thumbnail, for: url)
                }

                continuation.resume(returning: thumbnail)
            }
        }
    }
}

// MARK: - Main View

struct AssetsView: View {
    @EnvironmentObject var projectViewModel: ProjectViewModel

    @StateObject private var scanner = AssetScanner()
    @State private var searchText = ""
    @State private var selectedMediaFilter: MediaCategory? = nil
    @State private var viewMode: ViewMode = .sections
    @State private var selectedAsset: DiscoveredAsset? = nil

    enum ViewMode: String {
        case sections = "Sections"
        case grid = "Grid"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            assetsToolbar

            Divider()

            // Stats bar
            if !scanner.assets.isEmpty {
                assetsStatsBar
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }

            // Content
            if scanner.isScanning {
                scanningView
            } else if filteredAssets.isEmpty {
                emptyStateView
            } else {
                switch viewMode {
                case .sections:
                    sectionView
                case .grid:
                    gridView
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
        .onAppear {
            startScan()
        }
        .sheet(item: $selectedAsset) { asset in
            AssetDetailSheet(asset: asset)
        }
    }

    // MARK: - Filtering

    private var filteredAssets: [DiscoveredAsset] {
        var result = scanner.assets

        if let filter = selectedMediaFilter {
            result = result.filter { $0.mediaType == filter }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.fileName.lowercased().contains(query) ||
                $0.relativePath.lowercased().contains(query) ||
                $0.contextLabel.lowercased().contains(query) ||
                $0.category.rawValue.lowercased().contains(query)
            }
        }

        return result
    }

    private var groupedAssets: [(AssetCategory, [DiscoveredAsset])] {
        let grouped = Dictionary(grouping: filteredAssets) { $0.category }
        return AssetCategory.allCases
            .compactMap { cat in
                guard let items = grouped[cat], !items.isEmpty else { return nil }
                return (cat, items)
            }
    }

    // MARK: - Scan

    private func startScan() {
        if let path = projectViewModel.projectPath {
            scanner.scan(projectURL: path)
        }
    }

    // MARK: - Toolbar

    private var assetsToolbar: some View {
        HStack(spacing: 12) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search assets...", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)

            // Type filter
            HStack(spacing: 4) {
                filterButton(label: "All", count: scanner.assets.count, mediaType: nil)
                filterButton(label: "Images", count: scanner.imageCount, mediaType: .image)
                filterButton(label: "Audio", count: scanner.audioCount, mediaType: .audio)
                filterButton(label: "Video", count: scanner.videoCount, mediaType: .video)
            }

            Spacer()

            // View mode toggle
            Picker("", selection: $viewMode) {
                Image(systemName: "rectangle.split.2x2")
                    .tag(ViewMode.sections)
                Image(systemName: "square.grid.3x3")
                    .tag(ViewMode.grid)
            }
            .pickerStyle(.segmented)
            .frame(width: 80)

            // Rescan button
            Button(action: { startScan() }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(scanner.isScanning)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func filterButton(label: String, count: Int, mediaType: MediaCategory?) -> some View {
        Button(action: { selectedMediaFilter = mediaType }) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                Text("\(count)")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        Capsule().fill(selectedMediaFilter == mediaType
                            ? Color.white.opacity(0.3)
                            : Color(nsColor: .separatorColor).opacity(0.3))
                    )
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(selectedMediaFilter == mediaType
                        ? Color.accentColor
                        : Color(nsColor: .controlBackgroundColor))
            )
            .foregroundColor(selectedMediaFilter == mediaType ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Stats Bar

    private var assetsStatsBar: some View {
        HStack(spacing: 0) {
            AssetStatPill(icon: "folder.fill", label: "Total", value: scanner.assets.count)
            AssetStatDivider()
            AssetStatPill(icon: "photo", label: "Images", value: scanner.imageCount)
            AssetStatDivider()
            AssetStatPill(icon: "waveform", label: "Audio", value: scanner.audioCount)
            AssetStatDivider()
            AssetStatPill(icon: "film", label: "Video", value: scanner.videoCount)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 20)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Scanning View

    private var scanningView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Scanning project for media assets...")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Media Assets Found")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Add images, audio, or video files to your project directory.\nOrganize them in folders like assets/characters, audio/music, etc.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            Button(action: { startScan() }) {
                Label("Rescan Project", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Section View

    private var sectionView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                ForEach(groupedAssets, id: \.0) { category, assets in
                    AssetSectionView(
                        category: category,
                        assets: assets,
                        onSelect: { selectedAsset = $0 }
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Grid View

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)
            ], spacing: 16) {
                ForEach(filteredAssets) { asset in
                    AssetCardView(asset: asset)
                        .onTapGesture { selectedAsset = asset }
                }
            }
            .padding(24)
        }
    }
}

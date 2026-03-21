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
            StatPill(icon: "folder.fill", label: "Total", value: scanner.assets.count)
            AssetStatDivider()
            StatPill(icon: "photo", label: "Images", value: scanner.imageCount)
            AssetStatDivider()
            StatPill(icon: "waveform", label: "Audio", value: scanner.audioCount)
            AssetStatDivider()
            StatPill(icon: "film", label: "Video", value: scanner.videoCount)
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

// MARK: - Section View

private struct AssetSectionView: View {
    let category: AssetCategory
    let assets: [DiscoveredAsset]
    let onSelect: (DiscoveredAsset) -> Void

    /// For characters/locations, group assets by entity name extracted from path
    private var groupedByEntity: [(String, [DiscoveredAsset])]? {
        guard category == .characters || category == .locations else { return nil }

        let folderKey = category == .characters ? "characters" : "locations"
        var groups: [String: [DiscoveredAsset]] = [:]
        var order: [String] = []

        for asset in assets {
            let parts = asset.relativePath.components(separatedBy: "/")
            let entityName: String
            if let idx = parts.firstIndex(of: folderKey), idx + 1 < parts.count {
                entityName = parts[idx + 1]
            } else {
                entityName = "Other"
            }

            if groups[entityName] == nil {
                order.append(entityName)
            }
            groups[entityName, default: []].append(asset)
        }

        let result = order.compactMap { name -> (String, [DiscoveredAsset])? in
            guard let items = groups[name], !items.isEmpty else { return nil }
            return (name, items)
        }
        return result.isEmpty ? nil : result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.system(size: 13))
                    .foregroundColor(category.accentColor)

                Text(category.rawValue.uppercased())
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(1.2)

                Text("\(assets.count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(category.accentColor.opacity(0.8)))
            }

            if let grouped = groupedByEntity {
                // Grouped view: sub-sections by entity name
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(grouped, id: \.0) { entityName, entityAssets in
                        VStack(alignment: .leading, spacing: 8) {
                            // Entity sub-header
                            HStack(spacing: 6) {
                                Image(systemName: category == .characters ? "person.fill" : "mappin.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(category.accentColor.opacity(0.7))

                                Text(entityName)
                                    .font(.system(size: 12, weight: .semibold))

                                Text("\(entityAssets.count)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(category.accentColor)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(
                                        Capsule().fill(category.accentColor.opacity(0.15))
                                    )
                            }

                            // Horizontal scroll of cards for this entity
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 14) {
                                    ForEach(entityAssets) { asset in
                                        AssetCardView(asset: asset)
                                            .onTapGesture { onSelect(asset) }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            } else {
                // Default flat horizontal scroll
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 14) {
                        ForEach(assets) { asset in
                            AssetCardView(asset: asset)
                                .onTapGesture { onSelect(asset) }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

// MARK: - Asset Card

private struct AssetCardView: View {
    let asset: DiscoveredAsset
    @State private var isHovered = false
    @State private var thumbnail: NSImage? = nil
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlayingAudio = false

    var body: some View {
        Group {
            switch asset.mediaType {
            case .image:
                imageCard
            case .audio:
                audioCard
            case .video:
                videoCard
            }
        }
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .shadow(color: .black.opacity(isHovered ? 0.25 : 0.1), radius: isHovered ? 8 : 4, y: isHovered ? 4 : 2)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
        .help(asset.relativePath)
        .contextMenu {
            if asset.mediaType == .audio {
                Button(action: { toggleAudioPlayback() }) {
                    Label(isPlayingAudio ? "Stop Playback" : "Play Audio", systemImage: isPlayingAudio ? "stop.fill" : "play.fill")
                }
                Divider()
            }
            Button(action: { saveToDownloads(asset: asset) }) {
                Label("Save to Downloads", systemImage: "arrow.down.circle")
            }
            Button(action: { saveAs(asset: asset) }) {
                Label("Save As...", systemImage: "square.and.arrow.down")
            }
            Divider()
            Button(action: { revealInFinder(asset: asset) }) {
                Label("Reveal in Finder", systemImage: "folder")
            }
            Button(action: { NSWorkspace.shared.open(asset.fullURL) }) {
                Label("Open with Default App", systemImage: "arrow.up.right.square")
            }
            Divider()
            Button(action: { copyPath(asset: asset) }) {
                Label("Copy File Path", systemImage: "doc.on.doc")
            }
        }
    }

    // MARK: Image Card

    private var imageCard: some View {
        ZStack(alignment: .bottomLeading) {
            // Thumbnail
            Group {
                if let thumb = thumbnail {
                    Image(nsImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 28))
                                .foregroundColor(.secondary)
                        )
                }
            }
            .frame(width: 160, height: 140)
            .clipped()

            // Gradient overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 60)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

            // Label
            VStack(alignment: .leading, spacing: 2) {
                if !asset.contextLabel.isEmpty {
                    Text(asset.contextLabel)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(asset.category.accentColor)
                        .textCase(.uppercase)
                }
                Text(asset.fileName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .padding(8)
        }
        .frame(width: 160, height: 140)
        .cornerRadius(10)
        .task {
            thumbnail = await AssetThumbnailCache.generateThumbnail(for: asset.fullURL)
        }
    }

    // MARK: Audio Card

    private var audioCard: some View {
        VStack(spacing: 0) {
            // Icon area with play button
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [asset.category.accentColor.opacity(0.3), Color(nsColor: .controlBackgroundColor)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 70)
                .overlay(
                    ZStack {
                        VStack(spacing: 6) {
                            Image(systemName: isPlayingAudio ? "speaker.wave.3.fill" : "waveform")
                                .font(.system(size: 24))
                                .foregroundColor(asset.category.accentColor)
                                .symbolEffect(.variableColor.iterative, isActive: isPlayingAudio)
                            Text(asset.fileExtension.uppercased())
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.secondary)
                        }

                        // Play/Stop button on hover
                        if isHovered {
                            Button(action: { toggleAudioPlayback() }) {
                                Image(systemName: isPlayingAudio ? "stop.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.white)
                                    .shadow(radius: 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                )

            // Info area
            VStack(alignment: .leading, spacing: 4) {
                Text(asset.fileName)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                HStack {
                    Text(asset.formattedSize)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Spacer()
                    if !asset.contextLabel.isEmpty {
                        Text(asset.contextLabel)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(asset.category.accentColor)
                    }
                }
            }
            .padding(8)
        }
        .frame(width: 160, height: 120)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }

    private func toggleAudioPlayback() {
        if isPlayingAudio {
            audioPlayer?.stop()
            audioPlayer = nil
            isPlayingAudio = false
        } else {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: asset.fullURL)
                audioPlayer?.delegate = AssetAudioDelegate.shared
                AssetAudioDelegate.shared.onFinished = { [weak audioPlayer] in
                    if audioPlayer != nil {
                        self.isPlayingAudio = false
                    }
                }
                audioPlayer?.play()
                isPlayingAudio = true
            } catch {
                print("Error playing audio asset: \(error)")
            }
        }
    }

    // MARK: Video Card

    private var videoCard: some View {
        VStack(spacing: 0) {
            // Icon area with play badge
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [asset.category.accentColor.opacity(0.3), Color(nsColor: .controlBackgroundColor)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 70)
                .overlay(
                    ZStack {
                        Image(systemName: "film")
                            .font(.system(size: 24))
                            .foregroundColor(asset.category.accentColor)

                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .offset(x: 20, y: 14)
                    }
                )

            // Info area
            VStack(alignment: .leading, spacing: 4) {
                Text(asset.fileName)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                HStack {
                    Text(asset.formattedSize)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Spacer()
                    if !asset.contextLabel.isEmpty {
                        Text(asset.contextLabel)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(asset.category.accentColor)
                    }
                }
            }
            .padding(8)
        }
        .frame(width: 160, height: 120)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }

    // MARK: - Context Menu Actions

    private func saveToDownloads(asset: DiscoveredAsset) {
        guard let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else { return }
        let destURL = uniqueDestination(for: asset.fileName, in: downloadsURL)
        do {
            try FileManager.default.copyItem(at: asset.fullURL, to: destURL)
            NSWorkspace.shared.activateFileViewerSelecting([destURL])
        } catch {
            debugLog("Failed to save asset to Downloads: \(error)")
        }
    }

    private func saveAs(asset: DiscoveredAsset) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = asset.fileName
        panel.canCreateDirectories = true
        if let contentType = UTType(filenameExtension: asset.fileExtension) {
            panel.allowedContentTypes = [contentType]
        }
        panel.begin { response in
            guard response == .OK, let destURL = panel.url else { return }
            do {
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }
                try FileManager.default.copyItem(at: asset.fullURL, to: destURL)
            } catch {
                debugLog("Failed to save asset: \(error)")
            }
        }
    }

    private func revealInFinder(asset: DiscoveredAsset) {
        NSWorkspace.shared.activateFileViewerSelecting([asset.fullURL])
    }

    private func copyPath(asset: DiscoveredAsset) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(asset.fullURL.path, forType: .string)
    }

    private func uniqueDestination(for fileName: String, in directory: URL) -> URL {
        let base = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        var dest = directory.appendingPathComponent(fileName)
        var counter = 1
        while FileManager.default.fileExists(atPath: dest.path) {
            let newName = ext.isEmpty ? "\(base) (\(counter))" : "\(base) (\(counter)).\(ext)"
            dest = directory.appendingPathComponent(newName)
            counter += 1
        }
        return dest
    }
}

// MARK: - Stats Components

private struct StatPill: View {
    let icon: String
    let label: String
    let value: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Text("\(value)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct AssetStatDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor).opacity(0.4))
            .frame(width: 1, height: 28)
    }
}

// MARK: - Detail Sheet

struct AssetDetailSheet: View {
    let asset: DiscoveredAsset
    @State private var thumbnail: NSImage? = nil
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlayingAudio = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: asset.category.icon)
                    .foregroundColor(asset.category.accentColor)
                Text(asset.fileName)
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    // Preview
                    previewArea
                        .frame(maxHeight: 300)

                    // File info
                    fileInfoSection

                    // Actions
                    actionsSection
                }
                .padding(24)
            }
        }
        .frame(width: 480, height: 560)
        .task {
            if asset.mediaType == .image {
                thumbnail = await AssetThumbnailCache.generateThumbnail(for: asset.fullURL, maxSize: 400)
            }
        }
    }

    @ViewBuilder
    private var previewArea: some View {
        switch asset.mediaType {
        case .image:
            if let thumb = thumbnail {
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(8)
            } else {
                ProgressView()
                    .frame(height: 200)
            }
        case .audio:
            VStack(spacing: 16) {
                Image(systemName: isPlayingAudio ? "speaker.wave.3.fill" : "waveform.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(asset.category.accentColor)
                    .symbolEffect(.variableColor.iterative, isActive: isPlayingAudio)

                Text(asset.fileExtension.uppercased())
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)

                Button(action: { toggleDetailAudioPlayback() }) {
                    HStack(spacing: 6) {
                        Image(systemName: isPlayingAudio ? "stop.fill" : "play.fill")
                        Text(isPlayingAudio ? "Stop" : "Play")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(isPlayingAudio ? .red : asset.category.accentColor)
            }
            .frame(height: 180)
        case .video:
            VStack(spacing: 12) {
                ZStack {
                    Image(systemName: "film")
                        .font(.system(size: 64))
                        .foregroundColor(asset.category.accentColor)
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                        .offset(x: 28, y: 20)
                }
                Text(asset.fileExtension.uppercased())
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .frame(height: 150)
        }
    }

    private var fileInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FILE INFO")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .tracking(1.2)

            infoRow(label: "Name", value: asset.fileName)
            infoRow(label: "Type", value: asset.mediaType.rawValue)
            infoRow(label: "Category", value: asset.category.rawValue)
            infoRow(label: "Extension", value: asset.fileExtension.uppercased())
            infoRow(label: "Size", value: asset.formattedSize)
            infoRow(label: "Path", value: asset.relativePath)
            if let date = asset.modificationDate {
                infoRow(label: "Modified", value: date.formatted(date: .abbreviated, time: .shortened))
            }
            if !asset.contextLabel.isEmpty {
                infoRow(label: "Context", value: asset.contextLabel)
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(10)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .trailing)
            Text(value)
                .font(.system(size: 12))
                .textSelection(.enabled)
            Spacer()
        }
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Button(action: saveToDownloads) {
                    Label("Save to Downloads", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.borderedProminent)

                Button(action: saveAs) {
                    Label("Save As...", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)

                Spacer()
            }

            HStack(spacing: 12) {
                Button(action: revealInFinder) {
                    Label("Reveal in Finder", systemImage: "folder")
                }
                .buttonStyle(.bordered)

                Button(action: openWithDefault) {
                    Label("Open", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.bordered)

                Button(action: copyPath) {
                    Label("Copy Path", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)

                Spacer()
            }
        }
    }

    private func saveToDownloads() {
        guard let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else { return }
        let destURL = uniqueDestination(for: asset.fileName, in: downloadsURL)
        do {
            try FileManager.default.copyItem(at: asset.fullURL, to: destURL)
            NSWorkspace.shared.activateFileViewerSelecting([destURL])
        } catch {
            debugLog("Failed to save asset to Downloads: \(error)")
        }
    }

    private func saveAs() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = asset.fileName
        panel.canCreateDirectories = true
        if let contentType = UTType(filenameExtension: asset.fileExtension) {
            panel.allowedContentTypes = [contentType]
        }
        panel.begin { response in
            guard response == .OK, let destURL = panel.url else { return }
            do {
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }
                try FileManager.default.copyItem(at: asset.fullURL, to: destURL)
            } catch {
                debugLog("Failed to save asset: \(error)")
            }
        }
    }

    private func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([asset.fullURL])
    }

    private func openWithDefault() {
        NSWorkspace.shared.open(asset.fullURL)
    }

    private func copyPath() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(asset.fullURL.path, forType: .string)
    }

    private func uniqueDestination(for fileName: String, in directory: URL) -> URL {
        let base = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        var dest = directory.appendingPathComponent(fileName)
        var counter = 1
        while FileManager.default.fileExists(atPath: dest.path) {
            let newName = ext.isEmpty ? "\(base) (\(counter))" : "\(base) (\(counter)).\(ext)"
            dest = directory.appendingPathComponent(newName)
            counter += 1
        }
        return dest
    }

    private func toggleDetailAudioPlayback() {
        if isPlayingAudio {
            audioPlayer?.stop()
            audioPlayer = nil
            isPlayingAudio = false
        } else {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: asset.fullURL)
                audioPlayer?.delegate = AssetAudioDelegate.shared
                AssetAudioDelegate.shared.onFinished = {
                    self.isPlayingAudio = false
                }
                audioPlayer?.play()
                isPlayingAudio = true
            } catch {
                print("Error playing audio asset: \(error)")
            }
        }
    }
}

// MARK: - Asset Audio Delegate

private class AssetAudioDelegate: NSObject, AVAudioPlayerDelegate {
    static let shared = AssetAudioDelegate()
    var onFinished: (() -> Void)?

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.onFinished?()
        }
    }
}

// MARK: - Preview

#Preview {
    AssetsView()
        .environmentObject(ProjectViewModel())
}

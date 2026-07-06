// CurationViewModel.swift
// DirectorsChair-Desktop
//
// ViewModel for the Curation tab — footage organization and symlink generation

import Foundation
import DirectorsChairCore
import DirectorsChairViews
import DirectorsChairServices
import AppKit
import UniformTypeIdentifiers

/// Represents a file found on a camera source (SD card, external drive)
struct CameraFile: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    var fileName: String { url.lastPathComponent }
    var fileSize: Int64
    var creationDate: Date?
    var mappedToTakeId: String?
    var sourceId: UUID? // which MediaSource this came from
}

/// Represents an external audio file (wav, mp3, aif, etc.)
struct AudioFile: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    var fileName: String { url.lastPathComponent }
    var fileSize: Int64
    var creationDate: Date?
    var sourceId: UUID? // which MediaSource this came from
}

/// A media source directory (video or audio) added by the user
struct MediaSource: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let type: MediaSourceType
    var label: String { url.lastPathComponent }
    var fileCount: Int = 0
    var lastScanned: Date?

    enum MediaSourceType: String, Hashable {
        case video
        case audio
    }
}

/// Sort order for takes in the navigator
enum CurationSortOrder: String, CaseIterable {
    case takeNumber = "Take #"
    case timestamp = "Timestamp"
    case rating = "Rating"
    case matchStatus = "Match Status"
}

/// Result from auto-matching takes to camera files
struct AutoMatchResult: Identifiable {
    let id = UUID()
    let takeId: String
    let takeName: String
    let cameraFile: CameraFile
    let timeDifference: TimeInterval
    let confidence: MatchConfidence

    enum MatchConfidence: String {
        case high = "High"
        case medium = "Medium"
        case low = "Low"

        var color: String {
            switch self {
            case .high: return "green"
            case .medium: return "orange"
            case .low: return "yellow"
            }
        }
    }
}

@MainActor
class CurationViewModel: ObservableObject {

    // MARK: - Published State

    @Published var selectedScene: DCScene?
    @Published var selectedShot: Shot?
    @Published var selectedTake: Take?
    @Published var cameraSourceDirectory: URL?
    @Published var cameraFiles: [CameraFile] = []
    @Published var filterRating: TakeRating?
    @Published var isGeneratingLinks: Bool = false
    @Published var searchQuery: String = ""
    @Published var isExtractingMetadata: Bool = false
    @Published var isDetectingCues: Bool = false
    @Published var detectionStatus: DetectionStatus = .idle
    @Published var isDetectingSyncTones: Bool = false
    @Published var syncDetectionStatus: SyncDetectionStatus = .idle
    @Published var audioFiles: [AudioFile] = []
    @Published var audioSourceDirectory: URL?
    @Published var autoMatchResults: [AutoMatchResult] = []

    // Multi-source management
    @Published var mediaSources: [MediaSource] = []
    @Published var isScanning: Bool = false
    @Published var sortOrder: CurationSortOrder = .takeNumber
    @Published var showOnlyUnmatched: Bool = false
    @Published var showSourcesBar: Bool = true

    // MARK: - Camera Source Directory

    /// Opens an NSOpenPanel to select the camera source directory
    func selectCameraSourceDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select the camera source folder (e.g., SD card DCIM folder)"

        if panel.runModal() == .OK, let url = panel.url {
            cameraSourceDirectory = url
            scanCameraFiles()
        }
    }

    /// Scans the camera source directory for video files
    func scanCameraFiles() {
        guard let sourceDir = cameraSourceDirectory else { return }
        let fm = FileManager.default

        var files: [CameraFile] = []

        let videoExtensions = Set(["mov", "mp4", "m4v", "mxf", "avi", "mkv", "mts", "m2ts"])

        if let enumerator = fm.enumerator(at: sourceDir, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                let ext = fileURL.pathExtension.lowercased()
                guard videoExtensions.contains(ext) else { continue }

                let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
                let file = CameraFile(
                    url: fileURL,
                    fileSize: Int64(resourceValues?.fileSize ?? 0),
                    creationDate: resourceValues?.creationDate,
                    mappedToTakeId: nil
                )
                files.append(file)
            }
        }

        cameraFiles = files.sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
    }

    /// Maps a camera file to a take
    func mapCameraFile(_ file: CameraFile, toTake take: Take, inShot shot: Shot, project: inout Project) {
        // Find and update the take in the project
        for seqIdx in project.sequences.indices {
            for sceneIdx in project.sequences[seqIdx].scenes.indices {
                for shotIdx in project.sequences[seqIdx].scenes[sceneIdx].shots.indices {
                    let s = project.sequences[seqIdx].scenes[sceneIdx].shots[shotIdx]
                    if s.id == shot.id {
                        for takeIdx in project.sequences[seqIdx].scenes[sceneIdx].shots[shotIdx].takes.indices {
                            if project.sequences[seqIdx].scenes[sceneIdx].shots[shotIdx].takes[takeIdx].id == take.id {
                                project.sequences[seqIdx].scenes[sceneIdx].shots[shotIdx].takes[takeIdx].cameraSourceFileName = file.fileName
                            }
                        }
                    }
                }
            }
        }

        // Update mapping state
        if let idx = cameraFiles.firstIndex(where: { $0.id == file.id }) {
            cameraFiles[idx].mappedToTakeId = take.id
        }
    }

    /// Generates the _best_takes/ folder with symlinks to circled takes
    func generateBestTakesFolder(project: Project, projectDir: URL) {
        isGeneratingLinks = true

        let scenes: [(name: String, shots: [(shotId: Int, takes: [(takeNumber: Int, rating: String, videoPath: String?)])])] =
            project.sequences.flatMap { sequence in
                sequence.scenes.map { scene in
                    let shots = scene.shots.map { shot in
                        let takes = shot.takes.map { take in
                            (takeNumber: take.takeNumber, rating: take.rating.rawValue, videoPath: take.capturedVideoPath)
                        }
                        return (shotId: shot.shotId, takes: takes)
                    }
                    return (name: scene.name, shots: shots)
                }
            }

        do {
            try ProjectDirectoryManager.generateBestTakesFolder(scenes: scenes, in: projectDir)
        } catch {
            debugLog("Failed to generate best takes folder: \(error)")
        }

        isGeneratingLinks = false
    }

    /// Generates the full curated structure with symlinks from camera source
    func generateCuratedStructure(project: Project, projectDir: URL) {
        guard let cameraDir = cameraSourceDirectory else { return }
        isGeneratingLinks = true

        let scenes: [(name: String, shots: [(shotId: Int, takes: [(takeNumber: Int, cameraFileName: String?)])])] =
            project.sequences.flatMap { sequence in
                sequence.scenes.map { scene in
                    let shots = scene.shots.map { shot in
                        let takes = shot.takes.map { take in
                            (takeNumber: take.takeNumber, cameraFileName: take.cameraSourceFileName)
                        }
                        return (shotId: shot.shotId, takes: takes)
                    }
                    return (name: scene.name, shots: shots)
                }
            }

        do {
            try ProjectDirectoryManager.createCuratedStructure(scenes: scenes, in: projectDir, cameraSourceDir: cameraDir)
        } catch {
            debugLog("Failed to generate curated structure: \(error)")
        }

        isGeneratingLinks = false
    }

    // MARK: - Multi-Source Management

    /// Add a video source directory
    func addVideoSource() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = "Select camera media folder(s) — SD card, SSD, DCIM, etc."

        if panel.runModal() == .OK {
            for url in panel.urls {
                guard !mediaSources.contains(where: { $0.url == url }) else { continue }
                var source = MediaSource(url: url, type: .video)
                // Scan immediately
                let files = scanVideoFilesIn(url, sourceId: source.id)
                source.fileCount = files.count
                source.lastScanned = Date()
                mediaSources.append(source)
                cameraFiles.append(contentsOf: files)
            }
            // Update legacy single-dir for backward compat
            if cameraSourceDirectory == nil, let first = mediaSources.first(where: { $0.type == .video }) {
                cameraSourceDirectory = first.url
            }
        }
    }

    /// Add an audio source directory
    func addAudioSource() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = "Select external audio folder(s) — recorder SD card, etc."

        if panel.runModal() == .OK {
            for url in panel.urls {
                guard !mediaSources.contains(where: { $0.url == url }) else { continue }
                var source = MediaSource(url: url, type: .audio)
                let files = scanAudioFilesIn(url, sourceId: source.id)
                source.fileCount = files.count
                source.lastScanned = Date()
                mediaSources.append(source)
                audioFiles.append(contentsOf: files)
            }
            if audioSourceDirectory == nil, let first = mediaSources.first(where: { $0.type == .audio }) {
                audioSourceDirectory = first.url
            }
        }
    }

    /// Remove a media source and its scanned files
    func removeSource(_ source: MediaSource) {
        mediaSources.removeAll { $0.id == source.id }
        if source.type == .video {
            cameraFiles.removeAll { $0.sourceId == source.id }
            if cameraSourceDirectory == source.url {
                cameraSourceDirectory = mediaSources.first(where: { $0.type == .video })?.url
            }
        } else {
            audioFiles.removeAll { $0.sourceId == source.id }
            if audioSourceDirectory == source.url {
                audioSourceDirectory = mediaSources.first(where: { $0.type == .audio })?.url
            }
        }
    }

    /// Rescan all sources
    func rescanAllSources() {
        isScanning = true
        cameraFiles.removeAll()
        audioFiles.removeAll()

        for idx in mediaSources.indices {
            let source = mediaSources[idx]
            if source.type == .video {
                let files = scanVideoFilesIn(source.url, sourceId: source.id)
                mediaSources[idx].fileCount = files.count
                mediaSources[idx].lastScanned = Date()
                cameraFiles.append(contentsOf: files)
            } else {
                let files = scanAudioFilesIn(source.url, sourceId: source.id)
                mediaSources[idx].fileCount = files.count
                mediaSources[idx].lastScanned = Date()
                audioFiles.append(contentsOf: files)
            }
        }
        isScanning = false
    }

    /// Scan a directory for video files, returning the results
    private func scanVideoFilesIn(_ directory: URL, sourceId: UUID) -> [CameraFile] {
        let fm = FileManager.default
        let videoExtensions = Set(["mov", "mp4", "m4v", "mxf", "avi", "mkv", "mts", "m2ts"])
        var files: [CameraFile] = []

        if let enumerator = fm.enumerator(at: directory, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                let ext = fileURL.pathExtension.lowercased()
                guard videoExtensions.contains(ext) else { continue }

                let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
                let file = CameraFile(
                    url: fileURL,
                    fileSize: Int64(resourceValues?.fileSize ?? 0),
                    creationDate: resourceValues?.creationDate,
                    mappedToTakeId: nil,
                    sourceId: sourceId
                )
                files.append(file)
            }
        }
        return files.sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
    }

    /// Scan a directory for audio files, returning the results
    private func scanAudioFilesIn(_ directory: URL, sourceId: UUID) -> [AudioFile] {
        let fm = FileManager.default
        let audioExtensions = Set(["wav", "mp3", "aif", "aiff", "m4a", "bwf"])
        var files: [AudioFile] = []

        if let enumerator = fm.enumerator(at: directory, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                let ext = fileURL.pathExtension.lowercased()
                guard audioExtensions.contains(ext) else { continue }

                let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
                let file = AudioFile(
                    url: fileURL,
                    fileSize: Int64(resourceValues?.fileSize ?? 0),
                    creationDate: resourceValues?.creationDate,
                    sourceId: sourceId
                )
                files.append(file)
            }
        }
        return files.sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
    }

    /// Summary stats for the toolbar
    var videoSourceCount: Int { mediaSources.filter { $0.type == .video }.count }
    var audioSourceCount: Int { mediaSources.filter { $0.type == .audio }.count }
    var totalVideoFiles: Int { cameraFiles.count }
    var totalAudioFiles: Int { audioFiles.count }

    func matchedTakeCount(in project: Project) -> Int {
        project.sequences.flatMap { $0.scenes }.flatMap { $0.shots }.flatMap { $0.takes }
            .filter { $0.cameraSourceFileName != nil }.count
    }

    func unmatchedTakeCount(in project: Project) -> Int {
        let allTakes = project.sequences.flatMap { $0.scenes }.flatMap { $0.shots }.flatMap { $0.takes }
        return allTakes.filter { $0.capturedVideoPath != nil && $0.cameraSourceFileName == nil }.count
    }

    /// Sort takes within shots based on current sort order
    func sortedTakes(_ takes: [Take]) -> [Take] {
        switch sortOrder {
        case .takeNumber:
            return takes.sorted { $0.takeNumber < $1.takeNumber }
        case .timestamp:
            return takes.sorted { ($0.startTimestamp ?? .distantPast) < ($1.startTimestamp ?? .distantPast) }
        case .rating:
            let order: [TakeRating] = [.circle, .alt, .none, .ng]
            return takes.sorted { order.firstIndex(of: $0.rating) ?? 99 < order.firstIndex(of: $1.rating) ?? 99 }
        case .matchStatus:
            // Unmatched first, then partially matched, then fully matched
            return takes.sorted { t1, t2 in
                let s1 = matchScore(t1)
                let s2 = matchScore(t2)
                return s1 < s2
            }
        }
    }

    private func matchScore(_ take: Take) -> Int {
        var score = 0
        if take.cameraSourceFileName != nil { score += 2 }
        else if take.hasCameraMetadata { score += 1 }
        if take.externalAudioFileName != nil { score += 2 }
        return score
    }

    // MARK: - Camera Metadata Extraction

    /// Extract camera metadata from a take's captured video using OCR
    func extractCameraMetadata(for take: Take, projectDir: URL) async -> ExtractedCameraMetadata? {
        guard let videoPath = take.capturedVideoPath else { return nil }
        let videoURL = projectDir.appendingPathComponent(videoPath)
        guard FileManager.default.fileExists(atPath: videoURL.path) else { return nil }

        isExtractingMetadata = true
        defer { isExtractingMetadata = false }

        do {
            let metadata = try await CameraMetadataExtractor.shared.extractMetadata(fromVideoAt: videoURL)
            return metadata
        } catch {
            debugLog("Camera metadata extraction failed: \(error)")
            return nil
        }
    }

    // MARK: - Auto-Match by Timestamp

    /// Matches takes to camera files by closest creation date within tolerance
    func autoMatchByTimestamp(project: Project, toleranceSeconds: TimeInterval = 30) -> [AutoMatchResult] {
        guard !cameraFiles.isEmpty else { return [] }

        var results: [AutoMatchResult] = []
        let allTakes = project.sequences.flatMap { seq in
            seq.scenes.flatMap { scene in
                scene.shots.flatMap { shot in
                    shot.takes.map { take in
                        (take: take, shotId: shot.shotId, sceneName: scene.name)
                    }
                }
            }
        }

        for takeInfo in allTakes {
            let take = takeInfo.take
            guard let startTime = take.startTimestamp else { continue }

            // Find closest camera file by creation date
            var bestFile: CameraFile?
            var bestDiff: TimeInterval = .greatestFiniteMagnitude

            for file in cameraFiles {
                guard let created = file.creationDate else { continue }
                let diff = abs(created.timeIntervalSince(startTime))
                if diff < bestDiff && diff <= toleranceSeconds {
                    bestDiff = diff
                    bestFile = file
                }
            }

            if let file = bestFile {
                let confidence: AutoMatchResult.MatchConfidence
                if bestDiff < 5 { confidence = .high }
                else if bestDiff < 15 { confidence = .medium }
                else { confidence = .low }

                results.append(AutoMatchResult(
                    takeId: take.id,
                    takeName: "\(takeInfo.sceneName) - Shot #\(takeInfo.shotId) Take \(take.takeNumber)",
                    cameraFile: file,
                    timeDifference: bestDiff,
                    confidence: confidence
                ))
            }
        }

        autoMatchResults = results
        return results
    }

    // MARK: - Auto-Match by Clip Name

    /// Matches OCR-extracted clip names to camera filenames
    func autoMatchByClipName(project: Project) -> [AutoMatchResult] {
        guard !cameraFiles.isEmpty else { return [] }

        var results: [AutoMatchResult] = []
        let allTakes = project.sequences.flatMap { seq in
            seq.scenes.flatMap { scene in
                scene.shots.flatMap { shot in
                    shot.takes.map { take in
                        (take: take, shotId: shot.shotId, sceneName: scene.name)
                    }
                }
            }
        }

        for takeInfo in allTakes {
            let take = takeInfo.take
            guard let clipName = take.cameraClipName, !clipName.isEmpty else { continue }

            // Find camera file whose name contains the clip name
            if let matchedFile = cameraFiles.first(where: {
                $0.fileName.localizedCaseInsensitiveContains(clipName)
            }) {
                results.append(AutoMatchResult(
                    takeId: take.id,
                    takeName: "\(takeInfo.sceneName) - Shot #\(takeInfo.shotId) Take \(take.takeNumber)",
                    cameraFile: matchedFile,
                    timeDifference: 0,
                    confidence: .high
                ))
            }
        }

        autoMatchResults = results
        return results
    }

    /// Apply auto-match results: write camera source file names to takes
    func applyAutoMatchResults(_ results: [AutoMatchResult], project: inout Project) {
        for result in results {
            for seqIdx in project.sequences.indices {
                for sceneIdx in project.sequences[seqIdx].scenes.indices {
                    for shotIdx in project.sequences[seqIdx].scenes[sceneIdx].shots.indices {
                        for takeIdx in project.sequences[seqIdx].scenes[sceneIdx].shots[shotIdx].takes.indices {
                            if project.sequences[seqIdx].scenes[sceneIdx].shots[shotIdx].takes[takeIdx].id == result.takeId {
                                project.sequences[seqIdx].scenes[sceneIdx].shots[shotIdx].takes[takeIdx].cameraSourceFileName = result.cameraFile.fileName
                            }
                        }
                    }
                }
            }

            // Update mapping state
            if let idx = cameraFiles.firstIndex(where: { $0.id == result.cameraFile.id }) {
                cameraFiles[idx].mappedToTakeId = result.takeId
            }
        }
    }

    // MARK: - File URL Lookup

    /// Returns the full URL for a camera file by filename
    func cameraFileURL(for fileName: String) -> URL? {
        cameraFiles.first { $0.fileName == fileName }?.url
    }

    /// Returns the full URL for an audio file by filename
    func audioFileURL(for fileName: String) -> URL? {
        audioFiles.first { $0.fileName == fileName }?.url
    }

    // MARK: - Single Take Matching

    /// Attempts to match a single take to a camera file by timestamp, then by clip name.
    /// Returns the matched filename, or nil if no match found.
    func matchSingleTake(_ take: Take, toleranceSeconds: TimeInterval = 30) -> String? {
        // Try timestamp match first
        if let startTime = take.startTimestamp {
            var bestFile: CameraFile?
            var bestDiff: TimeInterval = .greatestFiniteMagnitude

            for file in cameraFiles {
                guard let created = file.creationDate else { continue }
                let diff = abs(created.timeIntervalSince(startTime))
                if diff < bestDiff && diff <= toleranceSeconds {
                    bestDiff = diff
                    bestFile = file
                }
            }
            if let file = bestFile {
                return file.fileName
            }
        }

        // Try clip name match
        if let clipName = take.cameraClipName, !clipName.isEmpty {
            if let matchedFile = cameraFiles.first(where: {
                $0.fileName.localizedCaseInsensitiveContains(clipName)
            }) {
                return matchedFile.fileName
            }
        }

        return nil
    }

    /// Attempts to match a single take to an audio file by closest timestamp.
    func matchSingleTakeAudio(_ take: Take, toleranceSeconds: TimeInterval = 30) -> String? {
        guard let startTime = take.startTimestamp else { return nil }

        var bestFile: AudioFile?
        var bestDiff: TimeInterval = .greatestFiniteMagnitude

        for file in audioFiles {
            guard let created = file.creationDate else { continue }
            let diff = abs(created.timeIntervalSince(startTime))
            if diff < bestDiff && diff <= toleranceSeconds {
                bestDiff = diff
                bestFile = file
            }
        }

        return bestFile?.fileName
    }

    // MARK: - External Audio

    /// Opens an NSOpenPanel to select audio source directory
    func selectAudioDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select the external audio folder"

        if panel.runModal() == .OK, let url = panel.url {
            audioSourceDirectory = url
            scanAudioFiles(in: url)
        }
    }

    /// Scans a directory for audio files
    func scanAudioFiles(in directory: URL) {
        let fm = FileManager.default
        let audioExtensions = Set(["wav", "mp3", "aif", "aiff", "m4a", "bwf"])
        var files: [AudioFile] = []

        if let enumerator = fm.enumerator(at: directory, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                let ext = fileURL.pathExtension.lowercased()
                guard audioExtensions.contains(ext) else { continue }

                let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
                let file = AudioFile(
                    url: fileURL,
                    fileSize: Int64(resourceValues?.fileSize ?? 0),
                    creationDate: resourceValues?.creationDate
                )
                files.append(file)
            }
        }

        audioFiles = files.sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
    }

    /// Maps an audio file to a take
    func mapAudioFile(_ file: AudioFile, toTake take: Take, inShot shot: Shot, project: inout Project) {
        for seqIdx in project.sequences.indices {
            for sceneIdx in project.sequences[seqIdx].scenes.indices {
                for shotIdx in project.sequences[seqIdx].scenes[sceneIdx].shots.indices {
                    let s = project.sequences[seqIdx].scenes[sceneIdx].shots[shotIdx]
                    if s.id == shot.id {
                        for takeIdx in project.sequences[seqIdx].scenes[sceneIdx].shots[shotIdx].takes.indices {
                            if project.sequences[seqIdx].scenes[sceneIdx].shots[shotIdx].takes[takeIdx].id == take.id {
                                project.sequences[seqIdx].scenes[sceneIdx].shots[shotIdx].takes[takeIdx].externalAudioFileName = file.fileName
                            }
                        }
                    }
                }
            }
        }
    }

    /// Clears the external audio mapping for a take
    func clearAudioMapping(for take: Take, inShot shot: Shot, project: inout Project) {
        for seqIdx in project.sequences.indices {
            for sceneIdx in project.sequences[seqIdx].scenes.indices {
                for shotIdx in project.sequences[seqIdx].scenes[sceneIdx].shots.indices {
                    let s = project.sequences[seqIdx].scenes[sceneIdx].shots[shotIdx]
                    if s.id == shot.id {
                        for takeIdx in project.sequences[seqIdx].scenes[sceneIdx].shots[shotIdx].takes.indices {
                            if project.sequences[seqIdx].scenes[sceneIdx].shots[shotIdx].takes[takeIdx].id == take.id {
                                project.sequences[seqIdx].scenes[sceneIdx].shots[shotIdx].takes[takeIdx].externalAudioFileName = nil
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Audio Cue Detection

    /// Detect "Action" and "Cut" speech cues in a take's video
    func detectAudioCues(for take: Take, projectDir: URL) async -> ActionCutDetectionResult? {
        guard let videoPath = take.capturedVideoPath else {
            debugLog("[CurationVM] detectAudioCues: no capturedVideoPath")
            return nil
        }
        let videoURL = projectDir.appendingPathComponent(videoPath)
        debugLog("[CurationVM] detectAudioCues: videoURL = \(videoURL.path), exists = \(FileManager.default.fileExists(atPath: videoURL.path))")
        guard FileManager.default.fileExists(atPath: videoURL.path) else { return nil }

        isDetectingCues = true
        detectionStatus = .idle

        defer {
            isDetectingCues = false
        }

        do {
            let result = try await ActionCutDetector.shared.detect(
                inVideoAt: videoURL,
                statusHandler: { [weak self] status in
                    Task { @MainActor in
                        self?.detectionStatus = status
                    }
                }
            )
            detectionStatus = .completed
            return result
        } catch {
            detectionStatus = .failed(error.localizedDescription)
            debugLog("Audio cue detection failed: \(error)")
            return nil
        }
    }

    // MARK: - Sync Tone Detection

    /// Detect sync tone chirps in a take's video/audio file
    func detectSyncTones(for take: Take, projectDir: URL) async -> SyncToneDetectionResult? {
        guard let videoPath = take.capturedVideoPath else {
            debugLog("[CurationVM] detectSyncTones: no capturedVideoPath")
            return nil
        }
        let videoURL = projectDir.appendingPathComponent(videoPath)
        debugLog("[CurationVM] detectSyncTones: videoURL = \(videoURL.path), exists = \(FileManager.default.fileExists(atPath: videoURL.path))")
        guard FileManager.default.fileExists(atPath: videoURL.path) else { return nil }

        isDetectingSyncTones = true
        syncDetectionStatus = .idle

        defer {
            isDetectingSyncTones = false
        }

        do {
            let result = try await SyncToneDetector.shared.detect(
                inFileAt: videoURL,
                statusHandler: { [weak self] status in
                    Task { @MainActor in
                        self?.syncDetectionStatus = status
                    }
                }
            )
            syncDetectionStatus = .completed
            return result
        } catch {
            syncDetectionStatus = .failed(error.localizedDescription)
            debugLog("Sync tone detection failed: \(error)")
            return nil
        }
    }

    /// Detect sync tones in both DC recording and camera footage, compute alignment offset
    func computeSyncOffset(for take: Take, projectDir: URL) async -> Double? {
        // Detect in the DC recording (capturedVideoPath)
        guard let dcResult = await detectSyncTones(for: take, projectDir: projectDir),
              dcResult.hasResults else {
            debugLog("[CurationVM] computeSyncOffset: no sync tones found in DC recording")
            return nil
        }

        // If camera source is mapped, detect in camera footage too
        if let cameraFileName = take.cameraSourceFileName,
           let cameraDir = cameraSourceDirectory {
            let cameraURL = cameraDir.appendingPathComponent(cameraFileName)
            guard FileManager.default.fileExists(atPath: cameraURL.path) else { return nil }

            do {
                let cameraResult = try await SyncToneDetector.shared.detect(inFileAt: cameraURL)
                guard cameraResult.hasResults else { return nil }
                return SyncToneDetector.computeOffset(sourceA: dcResult, sourceB: cameraResult)
            } catch {
                debugLog("[CurationVM] computeSyncOffset: camera detection failed: \(error)")
                return nil
            }
        }

        return nil
    }

    /// Format a cue timestamp as "MM:SS.d"
    func formatCueTimestamp(_ seconds: Double?) -> String {
        guard let seconds else { return "--:--.--" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let tenths = Int((seconds.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", mins, secs, tenths)
    }

    // MARK: - Filtering

    /// All takes from the project matching current filter
    func filteredScenes(from project: Project) -> [DCScene] {
        let allScenes = project.sequences.flatMap { $0.scenes }

        if searchQuery.isEmpty && filterRating == nil {
            return allScenes
        }

        return allScenes.compactMap { scene in
            var filteredScene = scene
            filteredScene.shots = scene.shots.compactMap { shot in
                var filteredShot = shot
                filteredShot.takes = shot.takes.filter { take in
                    var matchesRating = true
                    var matchesSearch = true

                    if let rating = filterRating {
                        matchesRating = take.rating == rating
                    }
                    if !searchQuery.isEmpty {
                        matchesSearch = take.notes.localizedCaseInsensitiveContains(searchQuery)
                            || take.tags.contains { $0.localizedCaseInsensitiveContains(searchQuery) }
                            || scene.name.localizedCaseInsensitiveContains(searchQuery)
                    }

                    return matchesRating && matchesSearch
                }
                return filteredShot.takes.isEmpty ? nil : filteredShot
            }
            return filteredScene.shots.isEmpty ? nil : filteredScene
        }
    }

    // MARK: - Helpers

    func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    func formatDuration(_ seconds: Double?) -> String {
        guard let seconds else { return "--:--" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

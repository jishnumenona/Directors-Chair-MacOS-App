//
// TakesSectionView+Actions.swift
//
// Extracted from TakesSectionView.swift (WS9.1 god-file decomposition).
// Members moved verbatim into an extension; private -> internal so the
// main struct's body can still reach them. Behaviour unchanged.
//

import SwiftUI
import AVFoundation
import AVKit
import DirectorsChairCore
import DirectorsChairServices

extension TakesSectionView {

    // MARK: - Actions

    func addManualTake() {
        var updated = shot
        let newTake = Take(takeNumber: shot.nextTakeNumber)
        updated.takes.append(newTake)
        updated.updateStatusFromTakes()
        onShotUpdated(updated)
        selectedTakeId = newTake.id
    }

    func deleteTake(_ take: Take) {
        var updated = shot
        updated.takes.removeAll { $0.id == take.id }
        if selectedTakeId == take.id { selectedTakeId = nil }
        updated.updateStatusFromTakes()
        onShotUpdated(updated)
    }

    func renumberTakes() {
        var updated = shot
        for i in updated.takes.indices {
            updated.takes[i].takeNumber = i + 1
        }
        onShotUpdated(updated)
    }

    func addTag(_ tag: String, to take: Take) {
        let trimmed = tag.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var updated = shot
        if let idx = updated.takes.firstIndex(where: { $0.id == take.id }) {
            if !updated.takes[idx].tags.contains(trimmed) {
                updated.takes[idx].tags.append(trimmed)
                onShotUpdated(updated)
            }
        }
    }

    func removeTag(_ tag: String, from take: Take) {
        var updated = shot
        if let idx = updated.takes.firstIndex(where: { $0.id == take.id }) {
            updated.takes[idx].tags.removeAll { $0 == tag }
            onShotUpdated(updated)
        }
    }

    func mapCameraFile(for take: Take) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.movie, .video, .quickTimeMovie, .mpeg4Movie]
        panel.message = "Select the camera source file for Take #\(take.takeNumber)"
        if panel.runModal() == .OK, let url = panel.url {
            var updated = shot
            if let idx = updated.takes.firstIndex(where: { $0.id == take.id }) {
                updated.takes[idx].cameraSourceFileName = url.lastPathComponent
                onShotUpdated(updated)
            }
        }
    }

    /// The take that will be recorded into: the selected take if it has no video yet, otherwise nil (new take).
    var recordingTargetTake: Take? {
        guard let take = selectedTake else { return nil }
        // Only target an existing take if it hasn't been recorded yet
        if take.capturedVideoPath == nil && take.startTimestamp == nil {
            return take
        }
        return nil
    }

    func startRecording() {
        guard let basePath = projectBasePath else { return }
        let projectDir = basePath.deletingLastPathComponent()
        let sanitizedScene = "Scene_\(shot.shotId)".replacingOccurrences(of: "/", with: "_")
        let shotFolder = String(format: "Shot_%03d", shot.shotId)

        var updated = shot
        let targetTake = recordingTargetTake
        let takeNumber = targetTake?.takeNumber ?? shot.nextTakeNumber
        let takeId: String

        let fileName = String(format: "Take_%03d.mov", takeNumber)
        let footageDir = projectDir.appendingPathComponent("footage").appendingPathComponent(sanitizedScene).appendingPathComponent(shotFolder)
        let outputURL = footageDir.appendingPathComponent(fileName)
        try? FileManager.default.createDirectory(at: footageDir, withIntermediateDirectories: true)

        if let existing = targetTake, let idx = updated.takes.firstIndex(where: { $0.id == existing.id }) {
            // Record into the pre-planned take
            updated.takes[idx].startTimestamp = Date()
            updated.takes[idx].capturedVideoPath = outputURL.path.replacingOccurrences(of: projectDir.path + "/", with: "")
            takeId = existing.id
        } else {
            // Create a new take
            var newTake = Take(takeNumber: takeNumber, startTimestamp: Date())
            newTake.capturedVideoPath = outputURL.path.replacingOccurrences(of: projectDir.path + "/", with: "")
            takeId = newTake.id
            updated.takes.append(newTake)
        }

        updated.updateStatusFromTakes()
        onShotUpdated(updated)
        selectedTakeId = takeId

        captureService.startRecording(to: outputURL) { fileURL, error in
            Task { @MainActor in
                var finalShot = updated
                if let idx = finalShot.takes.firstIndex(where: { $0.id == takeId }) {
                    finalShot.takes[idx].endTimestamp = Date()
                    if let start = finalShot.takes[idx].startTimestamp {
                        finalShot.takes[idx].durationSeconds = Date().timeIntervalSince(start)
                    }
                    if let fileURL {
                        finalShot.takes[idx].capturedVideoPath = fileURL.path.replacingOccurrences(of: projectDir.path + "/", with: "")
                        saveTakePreviewImage(from: fileURL)
                    }
                    onShotUpdated(finalShot)
                }
            }
        }
    }

    func stopRecording() { captureService.stopRecording() }

    // MARK: - Remote Control Handlers

    func handleRemoteStart() {
        NSLog("[RemoteStart] called. isRecording=%d, isBlindLogging=%d", captureService.isRecording ? 1 : 0, isBlindLogging ? 1 : 0)
        guard !captureService.isRecording && !isBlindLogging else {
            NSLog("[RemoteStart] BLOCKED by guard — already recording or logging")
            return
        }

        // Two-press workflow: first press arms, second press records
        let isArmed = UserDefaults.standard.bool(forKey: "pref.remote.armed")
        NSLog("[RemoteStart] isArmed=%d, selectedDevice=%@, defaultDevice=%@, timestampMode=%d",
              isArmed ? 1 : 0,
              captureService.selectedDevice?.localizedName ?? "nil",
              captureService.defaultDevice?.localizedName ?? "nil",
              isTimestampMode ? 1 : 0)

        if isArmed {
            // Second press: start recording
            UserDefaults.standard.set(false, forKey: "pref.remote.armed")
            isRemoteArmed = false
            // Play recording start tone
            NotificationCenter.default.post(
                name: Notification.Name("remoteControl.recordingStartTone"),
                object: nil
            )
            if captureService.selectedDevice != nil {
                NSLog("[RemoteStart] Starting recording (device selected)")
                startRecording()
            } else if captureService.defaultDevice != nil {
                NSLog("[RemoteStart] Connecting device then recording")
                captureService.connectAndStart { [self] in
                    startRecording()
                }
            } else if isTimestampMode {
                NSLog("[RemoteStart] Starting blind log (timestamp mode)")
                startBlindLog()
            }
        } else {
            // First press: arm the system
            UserDefaults.standard.set(true, forKey: "pref.remote.armed")
            isRemoteArmed = true
            NSLog("[RemoteStart] ARMED — announcing")
            // Connect camera if needed (so second press records instantly)
            if captureService.selectedDevice == nil && captureService.defaultDevice != nil {
                captureService.connectAndStart()
            }
            // Play ready sound via RemoteControlService
            NotificationCenter.default.post(
                name: Notification.Name("remoteControl.announce"),
                object: nil
            )
        }
    }

    func handleRemoteStop() {
        // Reset armed state on stop
        UserDefaults.standard.set(false, forKey: "pref.remote.armed")
        isRemoteArmed = false
        if captureService.isRecording {
            stopRecording()
        } else if isBlindLogging {
            stopBlindLog()
        }
    }

    /// Extracts a frame 2s before end of the video and saves a collage as `preview_take.png`.
    /// Prefers a circled take's video; falls back to the provided videoURL.
    /// Collage: AI-generated preview (left) + take frame (right). Falls back to take-only if no AI preview.
    /// Only runs for post-shooting statuses (Review, Approved, etc.).
    func saveTakePreviewImage(from videoURL: URL) {
        let preShootingStatuses = ["Planning", "Ready", "Shooting"]
        guard !preShootingStatuses.contains(shot.status) else { return }
        guard let basePath = projectBasePath else { return }
        let projectDir = basePath.deletingLastPathComponent()
        let shotDir = projectDir
            .appendingPathComponent("assets")
            .appendingPathComponent("shots")
            .appendingPathComponent("shot_\(shot.shotId)")

        // Prefer a circled take's video over the just-recorded one
        let effectiveVideoURL: URL
        if let circledPath = shot.circledTakes.first(where: { $0.capturedVideoPath != nil })?.capturedVideoPath {
            effectiveVideoURL = projectDir.appendingPathComponent(circledPath)
        } else {
            effectiveVideoURL = videoURL
        }

        // Find latest AI-generated preview
        let aiPreviewImage: CGImage? = {
            guard FileManager.default.fileExists(atPath: shotDir.path),
                  let contents = try? FileManager.default.contentsOfDirectory(at: shotDir, includingPropertiesForKeys: nil) else { return nil }
            let aiPreviews = contents
                .filter { $0.pathExtension.lowercased() == "png" }
                .filter { $0.lastPathComponent.hasPrefix("preview_") && $0.lastPathComponent != "preview_take.png" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            guard let latestAI = aiPreviews.last,
                  let nsImage = NSImage(contentsOf: latestAI),
                  let cgImg = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
            return cgImg
        }()

        Task {
            let asset = AVAsset(url: effectiveVideoURL)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 1280, height: 720)

            let duration = try await asset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)
            let targetSeconds = max(0, durationSeconds - 2.0)
            let time = CMTime(seconds: targetSeconds, preferredTimescale: 600)

            guard let takeFrame = try? await generator.image(at: time).image else { return }

            let collageData: Data?
            if let aiImage = aiPreviewImage {
                collageData = Self.createCollage(leftImage: aiImage, leftLabel: "AI PREVIEW", rightImage: takeFrame, rightLabel: "TAKE")
            } else {
                let bitmapRep = NSBitmapImageRep(cgImage: takeFrame)
                collageData = bitmapRep.representation(using: .png, properties: [:])
            }

            guard let pngData = collageData else { return }

            try? FileManager.default.createDirectory(at: shotDir, withIntermediateDirectories: true)
            let outputURL = shotDir.appendingPathComponent("preview_take.png")
            try? pngData.write(to: outputURL)
        }
    }

    /// Creates a side-by-side collage at 1920x540 with labeled panels and a dark gap.
    static func createCollage(leftImage: CGImage, leftLabel: String, rightImage: CGImage, rightLabel: String) -> Data? {
        let canvasWidth: CGFloat = 1920
        let canvasHeight: CGFloat = 540
        let gap: CGFloat = 4
        let panelWidth = (canvasWidth - gap) / 2
        let labelHeight: CGFloat = 28
        let labelFontSize: CGFloat = 13

        guard let ctx = CGContext(
            data: nil,
            width: Int(canvasWidth),
            height: Int(canvasHeight),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // Fill background black
        ctx.setFillColor(CGColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))

        func drawPanel(image: CGImage, label: String, originX: CGFloat) {
            let imgW = CGFloat(image.width)
            let imgH = CGFloat(image.height)
            let availableHeight = canvasHeight - labelHeight
            let scale = min(panelWidth / imgW, availableHeight / imgH)
            let drawW = imgW * scale
            let drawH = imgH * scale
            let x = originX + (panelWidth - drawW) / 2
            let y = labelHeight + (availableHeight - drawH) / 2
            ctx.draw(image, in: CGRect(x: x, y: y, width: drawW, height: drawH))

            // Label background
            ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.6))
            ctx.fill(CGRect(x: originX, y: 0, width: panelWidth, height: labelHeight))

            // Label text
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: labelFontSize, weight: .semibold),
                .foregroundColor: NSColor.white,
                .kern: 1.5
            ]
            let attrString = NSAttributedString(string: label, attributes: attributes)
            let textSize = attrString.size()
            let textX = originX + (panelWidth - textSize.width) / 2
            let textY = (labelHeight - textSize.height) / 2

            NSGraphicsContext.saveGraphicsState()
            let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
            NSGraphicsContext.current = nsCtx
            attrString.draw(at: NSPoint(x: textX, y: textY))
            NSGraphicsContext.restoreGraphicsState()
        }

        drawPanel(image: leftImage, label: leftLabel, originX: 0)
        drawPanel(image: rightImage, label: rightLabel, originX: panelWidth + gap)

        guard let compositeImage = ctx.makeImage() else { return nil }
        let bitmapRep = NSBitmapImageRep(cgImage: compositeImage)
        return bitmapRep.representation(using: .png, properties: [:])
    }

    /// Deletes existing `preview_take.png` and regenerates from the best available take.
    func regenerateTakePreview(for updatedShot: Shot) {
        let preShootingStatuses = ["Planning", "Ready", "Shooting"]
        guard !preShootingStatuses.contains(updatedShot.status) else { return }
        guard let basePath = projectBasePath else { return }
        let projectDir = basePath.deletingLastPathComponent()
        let shotDir = projectDir
            .appendingPathComponent("assets")
            .appendingPathComponent("shots")
            .appendingPathComponent("shot_\(updatedShot.shotId)")
        let takePreviewURL = shotDir.appendingPathComponent("preview_take.png")

        // Delete existing collage so it gets regenerated
        try? FileManager.default.removeItem(at: takePreviewURL)

        // Pick circled take first, then latest take with video
        let selectedTake = updatedShot.circledTakes.first(where: { $0.capturedVideoPath != nil })
            ?? updatedShot.takes.last(where: { $0.capturedVideoPath != nil })
        guard let selectedTake, let videoRelPath = selectedTake.capturedVideoPath else { return }

        let videoURL = projectDir.appendingPathComponent(videoRelPath)
        guard FileManager.default.fileExists(atPath: videoURL.path) else { return }

        saveTakePreviewImage(from: videoURL)
    }

    // MARK: - Blind Timestamp Logging

    func startBlindLog() {
        let now = Date()
        var updated = shot
        let targetTake = recordingTargetTake
        let takeNumber = targetTake?.takeNumber ?? shot.nextTakeNumber
        let takeId: String

        if let existing = targetTake, let idx = updated.takes.firstIndex(where: { $0.id == existing.id }) {
            updated.takes[idx].startTimestamp = now
            takeId = existing.id
        } else {
            let newTake = Take(takeNumber: takeNumber, startTimestamp: now)
            takeId = newTake.id
            updated.takes.append(newTake)
        }

        updated.updateStatusFromTakes()
        onShotUpdated(updated)
        selectedTakeId = takeId
        blindLogTakeId = takeId
        blindLogStartTime = now
        blindLogDuration = 0
        isBlindLogging = true

        // Start a duration timer
        blindLogTimer?.invalidate()
        blindLogTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                guard let start = blindLogStartTime else { return }
                blindLogDuration = Date().timeIntervalSince(start)
            }
        }
    }

    func stopBlindLog() {
        let now = Date()
        blindLogTimer?.invalidate()
        blindLogTimer = nil

        if let takeId = blindLogTakeId {
            var updated = shot
            if let idx = updated.takes.firstIndex(where: { $0.id == takeId }) {
                updated.takes[idx].endTimestamp = now
                if let start = updated.takes[idx].startTimestamp {
                    updated.takes[idx].durationSeconds = now.timeIntervalSince(start)
                }
                onShotUpdated(updated)
            }
        }

        isBlindLogging = false
        blindLogStartTime = nil
        blindLogDuration = 0
        blindLogTakeId = nil
    }

    func cancelBlindLog() {
        blindLogTimer?.invalidate()
        blindLogTimer = nil

        // Remove the take that was auto-created for this log, if it has no other data
        if let takeId = blindLogTakeId {
            var updated = shot
            if let idx = updated.takes.firstIndex(where: { $0.id == takeId }) {
                let take = updated.takes[idx]
                // Only remove if the take was freshly created by this log (no notes, tags, rating, or video)
                if take.notes.isEmpty && take.tags.isEmpty && take.rating == .none && take.capturedVideoPath == nil {
                    updated.takes.remove(at: idx)
                    if selectedTakeId == takeId { selectedTakeId = nil }
                    onShotUpdated(updated)
                }
            }
        }

        isBlindLogging = false
        blindLogStartTime = nil
        blindLogDuration = 0
        blindLogTakeId = nil
        // Stay in timestamp mode — user can start another log
    }

    func formatBlindDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let tenths = Int((duration.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }

    // MARK: - Helpers

    func ratingColor(_ rating: TakeRating) -> Color {
        switch rating {
        case .none: return .gray
        case .circle: return .green
        case .alt: return .orange
        case .ng: return .red
        }
    }

    func formatDuration(_ seconds: Double?) -> String {
        guard let seconds else { return "--:--" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    /// Compact time-only formatter for filmstrip cards (HH:mm:ss)
    var compactTimeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }
}

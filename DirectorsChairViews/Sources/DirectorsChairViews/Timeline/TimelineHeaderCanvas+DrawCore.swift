//
// TimelineHeaderCanvas+DrawCore.swift
//
// Extracted from TimelineHeaderCanvas.swift (WS9.1 god-file decomposition).
// Members moved verbatim into an extension. Behaviour unchanged.
//

import SwiftUI
import AppKit
import DirectorsChairCore

extension TimelineHeaderCanvas {

    // MARK: - Drawing Methods

    /// Draw the header background
    func drawBackground(context: GraphicsContext, size: CGSize) {
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(Color(hex: "#262626"))
        )
    }

    /// Draw time ruler at top
    func drawTimeRuler(context: GraphicsContext, size: CGSize) {
        let rulerY = TimelineLayoutConstants.topMargin
        let baselineY = rulerY + TimelineLayoutConstants.rulerHeight - 1

        // Ruler background
        let rulerRect = CGRect(
            x: 0,
            y: rulerY,
            width: size.width,
            height: TimelineLayoutConstants.rulerHeight
        )
        context.fill(Path(rulerRect), with: .color(Color(hex: "#262626")))

        // Baseline
        context.stroke(
            Path { path in
                path.move(to: CGPoint(x: originX, y: baselineY))
                path.addLine(to: CGPoint(x: size.width - 20, y: baselineY))
            },
            with: .color(Color(hex: "#3A3A3A")),
            lineWidth: 1
        )

        let canvasSecondsCapacity = (size.width - originX - 20) / pxPerSec
        let totalSecs = Int(max(totalSeconds, canvasSecondsCapacity))

        let tickInterval: Int
        let labelInterval: Int

        if pxPerSec < 25 {
            tickInterval = 10
            labelInterval = 10
        } else if pxPerSec < 40 {
            tickInterval = 5
            labelInterval = 10
        } else if pxPerSec < 80 {
            tickInterval = 1
            labelInterval = 5
        } else {
            tickInterval = 1
            labelInterval = 5
        }

        for sec in stride(from: 0, through: totalSecs, by: tickInterval) {
            let px = originX + CGFloat(sec) * pxPerSec

            if px > size.width { break }

            let tickHeight: CGFloat
            if sec % 60 == 0 {
                tickHeight = TimelineLayoutConstants.minuteTickHeight
            } else if sec % 10 == 0 {
                tickHeight = TimelineLayoutConstants.majorTickHeight
            } else if sec % 5 == 0 {
                tickHeight = TimelineLayoutConstants.mediumTickHeight
            } else {
                tickHeight = TimelineLayoutConstants.minorTickHeight
            }

            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: px, y: baselineY))
                    path.addLine(to: CGPoint(x: px, y: baselineY - tickHeight))
                },
                with: .color(Color(hex: "#3A3A3A")),
                lineWidth: 1
            )

            if sec % labelInterval == 0 {
                let label = DurationEstimator.formatTime(CGFloat(sec))
                let textPoint = CGPoint(x: px, y: rulerY + 4)

                context.draw(
                    Text(label)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundColor(Color(hex: "#CCCCCC")),
                    at: textPoint,
                    anchor: .top
                )
            }
        }
    }

    /// Draw shot labels lane (film-strip style) or collapsed strip
    func drawShotLabels(context: GraphicsContext, size: CGSize) {
        let laneY = TimelineLayoutConstants.topMargin +
                    TimelineLayoutConstants.rulerHeight +
                    TimelineLayoutConstants.rulerGap
        let totalLaneHeight = shotLaneOffset

        // --- Collapsed strip (showShotLabels == false) ---
        if !showShotLabels {
            let collapsedRect = CGRect(x: 0, y: laneY, width: size.width, height: totalLaneHeight)
            context.fill(Path(collapsedRect), with: .color(Color(hex: "#1A1A1A").opacity(0.7)))

            // Separator lines
            context.stroke(
                Path { p in p.move(to: CGPoint(x: 0, y: laneY)); p.addLine(to: CGPoint(x: size.width, y: laneY)) },
                with: .color(Color(hex: "#444444")), lineWidth: 1
            )
            context.stroke(
                Path { p in p.move(to: CGPoint(x: 0, y: laneY + totalLaneHeight)); p.addLine(to: CGPoint(x: size.width, y: laneY + totalLaneHeight)) },
                with: .color(Color(hex: "#444444")), lineWidth: 1
            )

            // Collapsed label
            let labelRect = CGRect(x: 4, y: laneY + 2, width: TimelineLayoutConstants.rowLabelWidth - 12, height: 20)
            context.fill(Path(roundedRect: labelRect, cornerRadius: 3), with: .color(Color(hex: "#333333").opacity(0.7)))
            context.stroke(Path(roundedRect: labelRect, cornerRadius: 3), with: .color(Color(hex: "#555555")), lineWidth: 1)

            let centerY = laneY + totalLaneHeight / 2

            // Eye.slash icon
            context.draw(
                Text(Image(systemName: "eye.slash")).font(.system(size: 9)).foregroundColor(Color(hex: "#888888")),
                at: CGPoint(x: labelRect.minX + 14, y: centerY), anchor: .center
            )
            // Film icon
            context.draw(
                Text(Image(systemName: "film")).font(.system(size: 9)).foregroundColor(Color(hex: "#666666")),
                at: CGPoint(x: labelRect.minX + 34, y: centerY), anchor: .center
            )
            // "Shots" text
            context.draw(
                Text("Shots").font(.system(size: 10, weight: .medium)).foregroundColor(Color(hex: "#666666")),
                at: CGPoint(x: labelRect.maxX - 8, y: centerY), anchor: .trailing
            )
            return
        }

        // --- Expanded shot lane ---
        let singleLaneHeight = TimelineLayoutConstants.shotLaneHeight
        let perfSize = TimelineLayoutConstants.filmPerforationSize
        let perfSpacing = TimelineLayoutConstants.filmPerforationSpacing

        // Film-strip background
        let laneRect = CGRect(x: 0, y: laneY, width: size.width, height: totalLaneHeight)
        context.fill(Path(laneRect), with: .color(Color(hex: "#1A1A1A").opacity(0.95)))

        // Top/bottom separator lines
        context.stroke(
            Path { p in p.move(to: CGPoint(x: 0, y: laneY)); p.addLine(to: CGPoint(x: size.width, y: laneY)) },
            with: .color(Color(hex: "#555555")), lineWidth: 1
        )
        context.stroke(
            Path { p in p.move(to: CGPoint(x: 0, y: laneY + totalLaneHeight)); p.addLine(to: CGPoint(x: size.width, y: laneY + totalLaneHeight)) },
            with: .color(Color(hex: "#555555")), lineWidth: 1
        )

        // Perforation holes
        let perfStartX = originX
        let perfTopY = laneY + 3
        let perfBottomY = laneY + totalLaneHeight - perfSize - 3
        let step = perfSize + perfSpacing

        var px = perfStartX
        while px < size.width {
            context.fill(Path(roundedRect: CGRect(x: px, y: perfTopY, width: perfSize, height: perfSize), cornerRadius: 1), with: .color(Color(hex: "#333333")))
            context.fill(Path(roundedRect: CGRect(x: px, y: perfBottomY, width: perfSize, height: perfSize), cornerRadius: 1), with: .color(Color(hex: "#333333")))
            px += step
        }

        // "Shots" row label with eye toggle
        let labelRect = CGRect(x: 4, y: laneY + 4, width: TimelineLayoutConstants.rowLabelWidth - 12, height: totalLaneHeight - 8)
        context.fill(Path(roundedRect: labelRect, cornerRadius: 4), with: .color(Color(hex: "#2A2A2A")))
        context.stroke(Path(roundedRect: labelRect, cornerRadius: 4), with: .color(Color(hex: "#444444")), lineWidth: 1)

        let centerY = laneY + totalLaneHeight / 2

        // Eye toggle icon (leftmost)
        context.draw(
            Text(Image(systemName: "eye.fill")).font(.system(size: 10)).foregroundColor(Color(hex: "#666666")),
            at: CGPoint(x: labelRect.minX + 14, y: centerY), anchor: .center
        )
        // Film icon (after eye)
        context.draw(
            Text(Image(systemName: "film")).font(.system(size: 10)).foregroundColor(Color(hex: "#999999")),
            at: CGPoint(x: labelRect.minX + 34, y: centerY), anchor: .center
        )
        context.draw(
            Text("Shots").font(.system(size: 11, weight: .medium)).foregroundColor(Color(hex: "#BBBBBB")),
            at: CGPoint(x: labelRect.maxX - 8, y: centerY), anchor: .trailing
        )

        // Shot cards with sub-lane offsets
        let cardInset = perfSize + 6
        let cardHeight = singleLaneHeight - cardInset * 2

        for shotLabel in shotLabels {
            var cardX = originX + shotLabel.time * pxPerSec
            var cardWidth = shotLabel.displayWidth(pxPerSec: pxPerSec)
            let isDragging = shotLabel.id == draggingShotId
            let isResizing = shotLabel.id == resizingShotId

            if isDragging && !isResizing {
                cardX += (dragCurrentX - dragStartX)
            }

            if isResizing {
                cardWidth += (dragCurrentX - resizeStartX)
                cardWidth = max(TimelineLayoutConstants.minShotCardWidth, cardWidth)
            }

            if cardX + cardWidth < 0 || cardX > size.width { continue }

            let subLane = shotSubLaneAssignments[shotLabel.id] ?? 0
            let subLaneY = laneY + CGFloat(subLane) * singleLaneHeight
            let cardTopY = subLaneY + cardInset

            let shotTypeColor = Color(hex: TimelineDefaultColors.colorForShotType(shotLabel.shotType))

            let cardRect = CGRect(x: cardX + 2, y: cardTopY, width: cardWidth - 4, height: cardHeight)

            // Check if we should show preview mode (Command key held)
            var previewNSImage: NSImage? = nil

            if let imgPath = shotLabel.previewImagePath, let basePath = projectBasePath {
                if let cached = previewImageCache[imgPath] {
                    previewNSImage = cached
                } else {
                    let fullPath = basePath.appendingPathComponent(imgPath)
                    if let img = NSImage(contentsOf: fullPath) {
                        DispatchQueue.main.async {
                            previewImageCache[imgPath] = img
                        }
                        previewNSImage = img
                    }
                }
            }

            if isCommandKeyDown {
                // Command held — show text-only shot label card
                context.fill(
                    Path(roundedRect: cardRect, cornerRadius: 3),
                    with: .color(shotTypeColor.opacity(isDragging ? 0.40 : 0.25))
                )
                context.stroke(
                    Path(roundedRect: cardRect, cornerRadius: 3),
                    with: .color(shotTypeColor.opacity(isDragging ? 1.0 : 0.7)),
                    lineWidth: isDragging ? 2 : 1
                )

                // Left accent bar
                let accentRect = CGRect(x: cardRect.minX, y: cardRect.minY, width: TimelineLayoutConstants.shotAccentBarWidth, height: cardRect.height)
                context.fill(Path(roundedRect: accentRect, cornerRadius: 2), with: .color(shotTypeColor))

                // Clip text to card
                var clippedCtx = context
                let textClip = CGRect(
                    x: cardRect.minX + TimelineLayoutConstants.shotAccentBarWidth + 4,
                    y: cardRect.minY,
                    width: cardRect.width - TimelineLayoutConstants.shotAccentBarWidth - 8,
                    height: cardRect.height
                )
                clippedCtx.clip(to: Path(textClip))

                let textLeft = cardRect.minX + TimelineLayoutConstants.shotAccentBarWidth + 6

                let topText = "\(shotLabel.shotName) \u{2022} \(shotLabel.shotType)"
                clippedCtx.draw(
                    Text(topText).font(.system(size: 10, weight: .bold)).foregroundColor(.white),
                    at: CGPoint(x: textLeft, y: cardRect.minY + cardRect.height * 0.30), anchor: .leading
                )

                var bottomParts: [String] = [shotLabel.cameraAngle]
                if let lens = shotLabel.lensMm { bottomParts.append("\(lens)mm") }
                let bottomText = bottomParts.joined(separator: " \u{2022} ")
                clippedCtx.draw(
                    Text(bottomText).font(.system(size: 8.5)).foregroundColor(Color(hex: "#999999")),
                    at: CGPoint(x: textLeft, y: cardRect.minY + cardRect.height * 0.50), anchor: .leading
                )

                // Video indicator icon
                if shotLabel.hasVideo {
                    clippedCtx.draw(
                        Text(Image(systemName: "video.fill")).font(.system(size: 7.5, weight: .medium)).foregroundColor(.green.opacity(0.9)),
                        at: CGPoint(x: cardRect.maxX - 10, y: cardRect.maxY - 8), anchor: .center
                    )
                }

                if let movementIcon = TimelineDefaultColors.iconForMovement(shotLabel.movement) {
                    clippedCtx.draw(
                        Text(Image(systemName: movementIcon)).font(.system(size: 9)).foregroundColor(shotTypeColor.opacity(0.8)),
                        at: CGPoint(x: cardRect.maxX - 10, y: cardRect.midY - (shotLabel.hasVideo ? 4 : 0)), anchor: .center
                    )
                }
            } else {
                // Normal card rendering — always show thumbnail + text bar
                let textBarHeight: CGFloat = 18
                let imageAreaRect = CGRect(x: cardRect.minX, y: cardRect.minY, width: cardRect.width, height: cardRect.height - textBarHeight)
                let textBarRect = CGRect(x: cardRect.minX, y: cardRect.maxY - textBarHeight, width: cardRect.width, height: textBarHeight)

                if let nsImage = previewNSImage {
                    // Draw thumbnail image aspect-fill in image area
                    context.fill(
                        Path(roundedRect: cardRect, cornerRadius: 3),
                        with: .color(Color.black)
                    )

                    var imgCtx = context
                    imgCtx.clip(to: Path(roundedRect: imageAreaRect, cornerRadius: 3))

                    let imageAspect = nsImage.size.width / max(nsImage.size.height, 1)
                    let fillWidth: CGFloat
                    let fillHeight: CGFloat
                    if imageAspect > imageAreaRect.width / max(imageAreaRect.height, 1) {
                        fillHeight = imageAreaRect.height
                        fillWidth = fillHeight * imageAspect
                    } else {
                        fillWidth = imageAreaRect.width
                        fillHeight = fillWidth / max(imageAspect, 0.01)
                    }
                    let fillX = imageAreaRect.midX - fillWidth / 2
                    let fillY = imageAreaRect.midY - fillHeight / 2
                    let fillRect = CGRect(x: fillX, y: fillY, width: fillWidth, height: fillHeight)

                    let image = Image(nsImage: nsImage)
                    let resolved = imgCtx.resolve(image)
                    imgCtx.draw(resolved, in: fillRect)
                } else {
                    // No image — colored placeholder with camera icon
                    context.fill(
                        Path(roundedRect: cardRect, cornerRadius: 3),
                        with: .color(shotTypeColor.opacity(isDragging ? 0.30 : 0.15))
                    )

                    context.draw(
                        Text(Image(systemName: "camera.fill")).font(.system(size: 14)).foregroundColor(shotTypeColor.opacity(0.4)),
                        at: CGPoint(x: imageAreaRect.midX, y: imageAreaRect.midY), anchor: .center
                    )
                }

                // Text bar at bottom
                context.fill(Path(roundedRect: CGRect(x: textBarRect.minX, y: textBarRect.minY, width: textBarRect.width, height: textBarRect.height + 3), cornerRadius: 3), with: .color(Color.black.opacity(0.65)))

                var textCtx = context
                textCtx.clip(to: Path(CGRect(x: textBarRect.minX + 4, y: textBarRect.minY, width: textBarRect.width - 8, height: textBarHeight)))
                let shotText = "\(shotLabel.shotName) \u{2022} \(shotLabel.shotType)"
                textCtx.draw(
                    Text(shotText).font(.system(size: 9, weight: .bold)).foregroundColor(.white),
                    at: CGPoint(x: textBarRect.minX + 6, y: textBarRect.midY), anchor: .leading
                )

                // Border in shot type color
                context.stroke(
                    Path(roundedRect: cardRect, cornerRadius: 3),
                    with: .color(shotTypeColor.opacity(isDragging ? 1.0 : 0.7)),
                    lineWidth: isDragging ? 2 : 1
                )

                // Video indicator icon
                if shotLabel.hasVideo {
                    context.draw(
                        Text(Image(systemName: "video.fill")).font(.system(size: 7.5, weight: .medium)).foregroundColor(.green.opacity(0.9)),
                        at: CGPoint(x: cardRect.maxX - 10, y: imageAreaRect.maxY - 8), anchor: .center
                    )
                }

                if let movementIcon = TimelineDefaultColors.iconForMovement(shotLabel.movement) {
                    context.draw(
                        Text(Image(systemName: movementIcon)).font(.system(size: 9)).foregroundColor(shotTypeColor.opacity(0.8)),
                        at: CGPoint(x: cardRect.maxX - 10, y: imageAreaRect.midY), anchor: .center
                    )
                }
            }

            // Connection indicator: small triangle at bottom of linked shot cards
            if showShotConnections {
                let hasConnection = shotDialogueConnections.contains { $0.shotLabelId == shotLabel.id }
                if hasConnection {
                    let triX = cardX + 4  // Align with connection line offset
                    let triY = cardRect.maxY
                    let triSize: CGFloat = 5

                    let trianglePath = Path { path in
                        path.move(to: CGPoint(x: triX - triSize, y: triY))
                        path.addLine(to: CGPoint(x: triX + triSize, y: triY))
                        path.addLine(to: CGPoint(x: triX, y: triY + triSize))
                        path.closeSubpath()
                    }

                    context.fill(trianglePath, with: .color(shotTypeColor.opacity(0.8)))
                }
            }
        }
    }

    /// Draw soundtrack waveform lanes below the shot lane
    func drawSoundtrackLane(context: GraphicsContext, size: CGSize) {
        guard showSoundtracks, !soundtrackTracks.isEmpty else { return }

        let soundtrackBaseY = TimelineLayoutConstants.topMargin +
                              TimelineLayoutConstants.rulerHeight +
                              TimelineLayoutConstants.rulerGap +
                              shotLaneOffset
        let laneH = TimelineLayoutConstants.soundtrackLaneHeight
        let padding = TimelineLayoutConstants.soundtrackWaveformPadding

        // Background for entire soundtrack area
        let bgRect = CGRect(x: 0, y: soundtrackBaseY, width: size.width, height: soundtrackLaneHeight)
        context.fill(Path(bgRect), with: .color(Color(hex: "#1A1A1A").opacity(0.6)))

        // Top separator
        context.stroke(
            Path { p in p.move(to: CGPoint(x: 0, y: soundtrackBaseY)); p.addLine(to: CGPoint(x: size.width, y: soundtrackBaseY)) },
            with: .color(Color(hex: "#444444")), lineWidth: 1
        )

        for (index, track) in soundtrackTracks.enumerated() {
            let laneY = soundtrackBaseY + CGFloat(index) * laneH
            let trackColor = Color(hex: track.color) ?? Color(hex: TimelineDefaultColors.soundtrackWaveform)
            let alpha: CGFloat = track.isMuted ? 0.3 : 1.0

            // Track background
            let trackRect = CGRect(x: originX, y: laneY, width: size.width - originX, height: laneH)
            context.fill(Path(trackRect), with: .color(trackColor.opacity(0.05 * alpha)))

            // Label on left
            let labelRect = CGRect(x: 4, y: laneY + 4, width: originX - 12, height: laneH - 8)
            context.fill(Path(roundedRect: labelRect, cornerRadius: 3), with: .color(Color(hex: "#333333").opacity(0.7)))

            // Mute icon
            let muteIcon = track.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill"
            context.draw(
                Text(Image(systemName: muteIcon)).font(.system(size: 9)).foregroundColor(trackColor.opacity(alpha)),
                at: CGPoint(x: labelRect.minX + 14, y: laneY + laneH / 2), anchor: .center
            )

            // Track name
            let displayName = track.name.count > 16 ? String(track.name.prefix(16)) + "..." : track.name
            context.draw(
                Text(displayName).font(.system(size: 9, weight: .medium)).foregroundColor(Color(hex: "#CCCCCC").opacity(alpha)),
                at: CGPoint(x: labelRect.minX + 28, y: laneY + laneH / 2), anchor: .leading
            )

            // Waveform rendering
            let samples = track.waveformSamples
            guard !samples.isEmpty else { continue }

            // Account for drag offset
            var trackOffsetSec = track.startTimeOffset
            if let dragId = draggingSoundtrackId, dragId == track.id {
                let deltaX = dragCurrentX - soundtrackDragStartX
                trackOffsetSec = max(0, trackOffsetSec + Double(deltaX / pxPerSec))
            }

            let waveX = originX + CGFloat(trackOffsetSec) * pxPerSec
            let waveW = CGFloat(track.duration) * pxPerSec
            let waveH = laneH - padding * 2
            let midY = laneY + laneH / 2

            // Viewport culling
            let visibleLeft: CGFloat = 0
            let visibleRight = size.width + 20
            if waveX + waveW < visibleLeft || waveX > visibleRight { continue }

            // Draw waveform background bar
            let waveRect = CGRect(x: waveX, y: laneY + padding, width: waveW, height: waveH)
            context.fill(Path(roundedRect: waveRect, cornerRadius: 4), with: .color(trackColor.opacity(0.12 * alpha)))
            context.stroke(Path(roundedRect: waveRect, cornerRadius: 4), with: .color(trackColor.opacity(0.3 * alpha)), lineWidth: 1)

            // Draw mirrored waveform path
            let samplesCount = samples.count
            let pixelsPerSample = waveW / CGFloat(samplesCount)

            // Skip rendering very thin waveforms
            guard pixelsPerSample > 0.1 else { continue }

            var waveformPath = Path()
            // Top half
            for i in 0..<samplesCount {
                let x = waveX + CGFloat(i) * pixelsPerSample
                let amp = CGFloat(samples[i]) * (waveH / 2) * alpha
                if i == 0 {
                    waveformPath.move(to: CGPoint(x: x, y: midY - amp))
                } else {
                    waveformPath.addLine(to: CGPoint(x: x, y: midY - amp))
                }
            }
            // Bottom half (mirror)
            for i in stride(from: samplesCount - 1, through: 0, by: -1) {
                let x = waveX + CGFloat(i) * pixelsPerSample
                let amp = CGFloat(samples[i]) * (waveH / 2) * alpha
                waveformPath.addLine(to: CGPoint(x: x, y: midY + amp))
            }
            waveformPath.closeSubpath()

            context.fill(waveformPath, with: .color(trackColor.opacity(0.6 * alpha)))

            // Center line
            context.stroke(
                Path { p in p.move(to: CGPoint(x: waveX, y: midY)); p.addLine(to: CGPoint(x: waveX + waveW, y: midY)) },
                with: .color(trackColor.opacity(0.3 * alpha)), lineWidth: 0.5
            )

            // Bottom separator between tracks
            if index < soundtrackTracks.count - 1 {
                let sepY = laneY + laneH
                context.stroke(
                    Path { p in p.move(to: CGPoint(x: 0, y: sepY)); p.addLine(to: CGPoint(x: size.width, y: sepY)) },
                    with: .color(Color(hex: "#333333")), lineWidth: 0.5
                )
            }
        }

        // Bottom separator for entire soundtrack area
        let bottomY = soundtrackBaseY + soundtrackLaneHeight
        context.stroke(
            Path { p in p.move(to: CGPoint(x: 0, y: bottomY)); p.addLine(to: CGPoint(x: size.width, y: bottomY)) },
            with: .color(Color(hex: "#444444")), lineWidth: 1
        )
    }

    /// Draw the playhead (red vertical line with triangle handle)
    func drawPlayhead(context: GraphicsContext, size: CGSize) {
        guard let time = playheadTime else { return }
        let x = originX + time * pxPerSec
        let rulerTop = TimelineLayoutConstants.topMargin
        let handleW = TimelineLayoutConstants.playheadHandleWidth
        let handleH = TimelineLayoutConstants.playheadHandleHeight
        let playheadColor = Color(hex: TimelineDefaultColors.playheadColor)

        // Triangle handle at ruler top
        let trianglePath = Path { path in
            path.move(to: CGPoint(x: x - handleW / 2, y: rulerTop - 2))
            path.addLine(to: CGPoint(x: x + handleW / 2, y: rulerTop - 2))
            path.addLine(to: CGPoint(x: x, y: rulerTop + handleH - 2))
            path.closeSubpath()
        }
        context.fill(trianglePath, with: .color(playheadColor))
        context.stroke(trianglePath, with: .color(playheadColor.opacity(0.8)), lineWidth: 1)

        // Vertical line from triangle tip to bottom of canvas
        context.stroke(
            Path { path in
                path.move(to: CGPoint(x: x, y: rulerTop + handleH - 2))
                path.addLine(to: CGPoint(x: x, y: size.height))
            },
            with: .color(playheadColor.opacity(0.8)),
            lineWidth: 1.5
        )

        // Time label above triangle
        let label = formatPlayheadTime(time)
        context.draw(
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(playheadColor),
            at: CGPoint(x: x, y: rulerTop - 6),
            anchor: .bottom
        )
    }

    /// Format playhead time as MM:SS.f
    func formatPlayheadTime(_ t: CGFloat) -> String {
        let totalSec = Int(t)
        let minutes = totalSec / 60
        let secs = totalSec % 60
        let frac = Int((t - CGFloat(totalSec)) * 10)
        return String(format: "%02d:%02d.%d", minutes, secs, frac)
    }
}

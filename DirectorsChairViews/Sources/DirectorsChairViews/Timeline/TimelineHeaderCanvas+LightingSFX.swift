//
// TimelineHeaderCanvas+LightingSFX.swift
//
// Extracted from TimelineHeaderCanvas.swift (WS9.1 god-file decomposition).
// Members moved verbatim into an extension. Behaviour unchanged.
//

import SwiftUI
import AppKit
import DirectorsChairCore

extension TimelineHeaderCanvas {

    // MARK: - Lighting Cue Lane

    /// Find a light cue at the given point
    func findLightCue(at point: CGPoint) -> LightCue? {
        guard showLightingLane, !lightCues.isEmpty else { return nil }
        let baseLaneY = TimelineLayoutConstants.topMargin +
                        TimelineLayoutConstants.rulerHeight +
                        TimelineLayoutConstants.rulerGap +
                        shotLaneOffset +
                        soundtrackLaneHeight
        let singleLaneH = TimelineLayoutConstants.lightingLaneHeight
        let barHeight: CGFloat = 36
        let hitMargin: CGFloat = 4
        let subLanes = lightCueSubLanes

        for cue in lightCues {
            let subLane = subLanes[cue.id] ?? 0
            let laneY = baseLaneY + CGFloat(subLane) * singleLaneH
            let barY = laneY + (singleLaneH - barHeight) / 2
            let cueX = originX + CGFloat(cue.startTime) * pxPerSec
            let cueW = max(20, CGFloat(cue.duration) * pxPerSec)
            let cueRect = CGRect(
                x: cueX - hitMargin,
                y: barY - hitMargin,
                width: cueW + hitMargin * 2,
                height: barHeight + hitMargin * 2
            )
            if cueRect.contains(point) {
                return cue
            }
        }
        return nil
    }

    /// Find a light cue whose right edge is within 8px of the given point (for resize)
    func findLightCueRightEdge(at point: CGPoint) -> LightCue? {
        guard showLightingLane, !lightCues.isEmpty else { return nil }
        let baseLaneY = TimelineLayoutConstants.topMargin +
                        TimelineLayoutConstants.rulerHeight +
                        TimelineLayoutConstants.rulerGap +
                        shotLaneOffset +
                        soundtrackLaneHeight
        let singleLaneH = TimelineLayoutConstants.lightingLaneHeight
        let barHeight: CGFloat = 36
        let edgeThreshold: CGFloat = 8
        let subLanes = lightCueSubLanes

        for cue in lightCues {
            let subLane = subLanes[cue.id] ?? 0
            let laneY = baseLaneY + CGFloat(subLane) * singleLaneH
            let barY = laneY + (singleLaneH - barHeight) / 2
            let cueX = originX + CGFloat(cue.startTime) * pxPerSec
            let cueW = max(20, CGFloat(cue.duration) * pxPerSec)
            let cueRight = cueX + cueW

            if point.y >= barY && point.y <= barY + barHeight &&
               abs(point.x - cueRight) <= edgeThreshold {
                return cue
            }
        }
        return nil
    }

    /// Check if a point hits the lighting lane eye toggle area
    func isLightingEyeToggleHit(at point: CGPoint) -> Bool {
        guard !lightCues.isEmpty else { return false }
        let baseLaneY = TimelineLayoutConstants.topMargin +
                        TimelineLayoutConstants.rulerHeight +
                        TimelineLayoutConstants.rulerGap +
                        shotLaneOffset +
                        soundtrackLaneHeight
        let totalLaneHeight = lightingLaneOffset

        if showLightingLane {
            // Expanded: eye icon area in the label
            let labelRect = CGRect(x: 4, y: baseLaneY + 4, width: TimelineLayoutConstants.rowLabelWidth - 12, height: totalLaneHeight - 8)
            let eyeRect = CGRect(x: labelRect.minX, y: labelRect.minY, width: 28, height: labelRect.height)
            return eyeRect.contains(point)
        } else {
            // Collapsed: entire label strip is clickable to re-expand
            let labelRect = CGRect(x: 4, y: baseLaneY + 2, width: TimelineLayoutConstants.rowLabelWidth - 12, height: 20)
            return labelRect.contains(point)
        }
    }

    /// Draw the lighting cue lane below the soundtrack lane
    func drawLightingCueLane(context: GraphicsContext, size: CGSize) {
        guard !lightCues.isEmpty else { return }

        let baseLaneY = TimelineLayoutConstants.topMargin +
                        TimelineLayoutConstants.rulerHeight +
                        TimelineLayoutConstants.rulerGap +
                        shotLaneOffset +
                        soundtrackLaneHeight
        let totalLaneHeight = lightingLaneOffset

        // --- Collapsed strip ---
        if !showLightingLane {
            let collapsedRect = CGRect(x: 0, y: baseLaneY, width: size.width, height: totalLaneHeight)
            context.fill(Path(collapsedRect), with: .color(Color(hex: "#1A1A1A").opacity(0.7)))

            // Separator lines
            context.stroke(
                Path { p in p.move(to: CGPoint(x: 0, y: baseLaneY)); p.addLine(to: CGPoint(x: size.width, y: baseLaneY)) },
                with: .color(Color(hex: "#444444")), lineWidth: 1
            )
            context.stroke(
                Path { p in p.move(to: CGPoint(x: 0, y: baseLaneY + totalLaneHeight)); p.addLine(to: CGPoint(x: size.width, y: baseLaneY + totalLaneHeight)) },
                with: .color(Color(hex: "#444444")), lineWidth: 1
            )

            // Collapsed label
            let labelRect = CGRect(x: 4, y: baseLaneY + 2, width: TimelineLayoutConstants.rowLabelWidth - 12, height: 20)
            context.fill(Path(roundedRect: labelRect, cornerRadius: 3), with: .color(Color(hex: "#333333").opacity(0.7)))
            context.stroke(Path(roundedRect: labelRect, cornerRadius: 3), with: .color(Color(hex: "#555555")), lineWidth: 1)

            let centerY = baseLaneY + totalLaneHeight / 2

            // Eye.slash icon
            context.draw(
                Text(Image(systemName: "eye.slash")).font(.system(size: 9)).foregroundColor(Color(hex: "#888888")),
                at: CGPoint(x: labelRect.minX + 14, y: centerY), anchor: .center
            )
            // Lightbulb icon
            context.draw(
                Text(Image(systemName: "lightbulb.fill")).font(.system(size: 9)).foregroundColor(Color(hex: "#666666")),
                at: CGPoint(x: labelRect.minX + 34, y: centerY), anchor: .center
            )
            // "Lights" text
            context.draw(
                Text("Lights").font(.system(size: 10, weight: .medium)).foregroundColor(Color(hex: "#666666")),
                at: CGPoint(x: labelRect.maxX - 8, y: centerY), anchor: .trailing
            )
            return
        }

        // --- Expanded lane ---
        let singleLaneH = TimelineLayoutConstants.lightingLaneHeight
        let barHeight: CGFloat = 36
        let subLanes = lightCueSubLanes

        // Lane background
        let laneBg = CGRect(x: 0, y: baseLaneY, width: size.width, height: totalLaneHeight)
        context.fill(Path(laneBg), with: .color(Color(nsColor: .controlBackgroundColor).opacity(0.3)))

        // Top separator
        context.stroke(
            Path { p in p.move(to: CGPoint(x: 0, y: baseLaneY)); p.addLine(to: CGPoint(x: size.width, y: baseLaneY)) },
            with: .color(Color(hex: "#555555")), lineWidth: 1
        )
        // Bottom separator
        context.stroke(
            Path { p in p.move(to: CGPoint(x: 0, y: baseLaneY + totalLaneHeight)); p.addLine(to: CGPoint(x: size.width, y: baseLaneY + totalLaneHeight)) },
            with: .color(Color(hex: "#555555")), lineWidth: 1
        )

        // Lane label with eye toggle
        let labelRect = CGRect(x: 4, y: baseLaneY + 4, width: TimelineLayoutConstants.rowLabelWidth - 12, height: totalLaneHeight - 8)
        context.fill(Path(roundedRect: labelRect, cornerRadius: 4), with: .color(Color(hex: "#2A2A2A")))
        context.stroke(Path(roundedRect: labelRect, cornerRadius: 4), with: .color(Color(hex: "#444444")), lineWidth: 1)

        let centerY = baseLaneY + totalLaneHeight / 2

        // Eye toggle icon (leftmost)
        context.draw(
            Text(Image(systemName: "eye.fill")).font(.system(size: 10)).foregroundColor(Color(hex: "#666666")),
            at: CGPoint(x: labelRect.minX + 14, y: centerY), anchor: .center
        )
        // Lightbulb icon (after eye)
        context.draw(
            Text(Image(systemName: "lightbulb.fill")).font(.system(size: 10)).foregroundColor(Color(hex: "#999999")),
            at: CGPoint(x: labelRect.minX + 34, y: centerY), anchor: .center
        )
        context.draw(
            Text("Lights").font(.system(size: 11, weight: .medium)).foregroundColor(Color(hex: "#BBBBBB")),
            at: CGPoint(x: labelRect.maxX - 8, y: centerY), anchor: .trailing
        )

        for cue in lightCues {
            let subLane = subLanes[cue.id] ?? 0
            let laneY = baseLaneY + CGFloat(subLane) * singleLaneH
            let barY = laneY + (singleLaneH - barHeight) / 2

            var cueX = originX + CGFloat(cue.startTime) * pxPerSec
            var cueW = max(20, CGFloat(cue.duration) * pxPerSec)
            let isDragging = cue.id == draggingLightCueId
            let isResizing = cue.id == resizingLightCueId

            // Apply drag offset for move
            if isDragging && !isResizing {
                cueX += (dragCurrentX - lightCueDragStartX)
            }

            // Apply resize offset
            if isResizing {
                cueW += (dragCurrentX - lightCueResizeStartX)
                cueW = max(20, cueW)
            }

            // Skip if outside viewport
            if cueX + cueW < 0 || cueX > size.width { continue }

            let cueColor = Color(hex: cue.markerColor)

            // Main bar
            let barRect = CGRect(x: cueX, y: barY, width: cueW, height: barHeight)
            let barPath = Path(roundedRect: barRect, cornerRadius: 4)
            context.fill(barPath, with: .color(cueColor.opacity(CGFloat(cue.intensity) * 0.6 + 0.15)))
            context.stroke(barPath, with: .color(cueColor.opacity(isDragging || isResizing ? 1.0 : 0.8)), lineWidth: isDragging || isResizing ? 2 : 1)

            // Fade-in ramp (left gradient)
            if cue.fadeInDuration > 0 {
                let fadeW = min(CGFloat(cue.fadeInDuration) * pxPerSec, cueW * 0.4)
                let fadeRect = CGRect(x: cueX, y: barY, width: fadeW, height: barHeight)
                context.fill(
                    Path(fadeRect),
                    with: .linearGradient(
                        Gradient(colors: [cueColor.opacity(0), cueColor.opacity(CGFloat(cue.intensity) * 0.4)]),
                        startPoint: CGPoint(x: cueX, y: barY),
                        endPoint: CGPoint(x: cueX + fadeW, y: barY)
                    )
                )
            }

            // Fade-out ramp (right gradient)
            if cue.fadeOutDuration > 0 {
                let fadeW = min(CGFloat(cue.fadeOutDuration) * pxPerSec, cueW * 0.4)
                let fadeRect = CGRect(x: cueX + cueW - fadeW, y: barY, width: fadeW, height: barHeight)
                context.fill(
                    Path(fadeRect),
                    with: .linearGradient(
                        Gradient(colors: [cueColor.opacity(CGFloat(cue.intensity) * 0.4), cueColor.opacity(0)]),
                        startPoint: CGPoint(x: cueX + cueW - fadeW, y: barY),
                        endPoint: CGPoint(x: cueX + cueW, y: barY)
                    )
                )
            }

            // Label: lightbulb icon + truncated name
            let labelMaxW = max(0, cueW - 8)
            if labelMaxW > 20 {
                var clipped = context
                clipped.clip(to: Path(CGRect(x: cueX + 4, y: barY, width: labelMaxW, height: barHeight)))

                // Icon
                clipped.draw(
                    Text(Image(systemName: "lightbulb.fill"))
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.9)),
                    at: CGPoint(x: cueX + 12, y: barY + barHeight / 2),
                    anchor: .center
                )

                // Name text
                if labelMaxW > 40 {
                    let displayName = cue.cueNumber + " " + cue.name
                    clipped.draw(
                        Text(displayName)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white.opacity(0.9)),
                        at: CGPoint(x: cueX + 22, y: barY + barHeight / 2),
                        anchor: .leading
                    )
                }
            }

            // Intensity indicator (small bar at bottom)
            let intensityW = cueW * CGFloat(cue.intensity)
            let intensityRect = CGRect(x: cueX, y: barY + barHeight - 3, width: intensityW, height: 3)
            context.fill(Path(intensityRect), with: .color(cueColor))

            // Resize handle (thin line at right edge)
            let handleX = cueX + cueW - 2
            context.stroke(
                Path { p in
                    p.move(to: CGPoint(x: handleX, y: barY + 4))
                    p.addLine(to: CGPoint(x: handleX, y: barY + barHeight - 4))
                },
                with: .color(.white.opacity(0.3)),
                lineWidth: 2
            )
        }
    }

    // MARK: - SFX Cue Lane Drawing

    func drawSFXCueLane(context: GraphicsContext, size: CGSize) {
        guard !sfxCues.isEmpty else { return }

        let baseLaneY = TimelineLayoutConstants.topMargin +
                        TimelineLayoutConstants.rulerHeight +
                        TimelineLayoutConstants.rulerGap +
                        shotLaneOffset +
                        soundtrackLaneHeight +
                        lightingLaneOffset
        let totalLaneHeight = sfxLaneOffset

        // --- Collapsed strip ---
        if !showSFXLane {
            let collapsedRect = CGRect(x: 0, y: baseLaneY, width: size.width, height: totalLaneHeight)
            context.fill(Path(collapsedRect), with: .color(Color(hex: "#1A1A1A").opacity(0.7)))

            context.stroke(
                Path { p in p.move(to: CGPoint(x: 0, y: baseLaneY)); p.addLine(to: CGPoint(x: size.width, y: baseLaneY)) },
                with: .color(Color(hex: "#444444")), lineWidth: 1
            )
            context.stroke(
                Path { p in p.move(to: CGPoint(x: 0, y: baseLaneY + totalLaneHeight)); p.addLine(to: CGPoint(x: size.width, y: baseLaneY + totalLaneHeight)) },
                with: .color(Color(hex: "#444444")), lineWidth: 1
            )

            let labelRect = CGRect(x: 4, y: baseLaneY + 2, width: TimelineLayoutConstants.rowLabelWidth - 12, height: 20)
            context.fill(Path(roundedRect: labelRect, cornerRadius: 3), with: .color(Color(hex: "#333333").opacity(0.7)))
            context.stroke(Path(roundedRect: labelRect, cornerRadius: 3), with: .color(Color(hex: "#555555")), lineWidth: 1)

            let centerY = baseLaneY + totalLaneHeight / 2

            context.draw(
                Text(Image(systemName: "eye.slash")).font(.system(size: 9)).foregroundColor(Color(hex: "#888888")),
                at: CGPoint(x: labelRect.minX + 14, y: centerY), anchor: .center
            )
            context.draw(
                Text(Image(systemName: "sparkles")).font(.system(size: 9)).foregroundColor(Color(hex: "#666666")),
                at: CGPoint(x: labelRect.minX + 34, y: centerY), anchor: .center
            )
            context.draw(
                Text("SFX").font(.system(size: 10, weight: .medium)).foregroundColor(Color(hex: "#666666")),
                at: CGPoint(x: labelRect.maxX - 8, y: centerY), anchor: .trailing
            )
            return
        }

        // --- Expanded lane ---
        let singleLaneH = TimelineLayoutConstants.sfxLaneHeight
        let barHeight: CGFloat = 36
        let subLanes = sfxCueSubLanes

        // Lane background
        let laneBg = CGRect(x: 0, y: baseLaneY, width: size.width, height: totalLaneHeight)
        context.fill(Path(laneBg), with: .color(Color(nsColor: .controlBackgroundColor).opacity(0.3)))

        // Top separator
        context.stroke(
            Path { p in p.move(to: CGPoint(x: 0, y: baseLaneY)); p.addLine(to: CGPoint(x: size.width, y: baseLaneY)) },
            with: .color(Color(hex: "#555555")), lineWidth: 1
        )
        // Bottom separator
        context.stroke(
            Path { p in p.move(to: CGPoint(x: 0, y: baseLaneY + totalLaneHeight)); p.addLine(to: CGPoint(x: size.width, y: baseLaneY + totalLaneHeight)) },
            with: .color(Color(hex: "#555555")), lineWidth: 1
        )

        // Lane label with eye toggle
        let labelRect = CGRect(x: 4, y: baseLaneY + 4, width: TimelineLayoutConstants.rowLabelWidth - 12, height: totalLaneHeight - 8)
        context.fill(Path(roundedRect: labelRect, cornerRadius: 4), with: .color(Color(hex: "#2A2A2A")))
        context.stroke(Path(roundedRect: labelRect, cornerRadius: 4), with: .color(Color(hex: "#444444")), lineWidth: 1)

        let centerY = baseLaneY + totalLaneHeight / 2

        context.draw(
            Text(Image(systemName: "eye.fill")).font(.system(size: 10)).foregroundColor(Color(hex: "#666666")),
            at: CGPoint(x: labelRect.minX + 14, y: centerY), anchor: .center
        )
        context.draw(
            Text(Image(systemName: "sparkles")).font(.system(size: 10)).foregroundColor(Color(hex: "#FF6B35")),
            at: CGPoint(x: labelRect.minX + 34, y: centerY), anchor: .center
        )
        context.draw(
            Text("SFX").font(.system(size: 11, weight: .medium)).foregroundColor(Color(hex: "#BBBBBB")),
            at: CGPoint(x: labelRect.maxX - 8, y: centerY), anchor: .trailing
        )

        for cue in sfxCues {
            let subLane = subLanes[cue.id] ?? 0
            let laneY = baseLaneY + CGFloat(subLane) * singleLaneH
            let barY = laneY + (singleLaneH - barHeight) / 2

            var cueX = originX + CGFloat(cue.startTime) * pxPerSec
            var cueW = max(20, CGFloat(cue.duration) * pxPerSec)
            let isDragging = cue.id == draggingSFXCueId
            let isResizing = cue.id == resizingSFXCueId

            if isDragging && !isResizing {
                cueX += (dragCurrentX - sfxCueDragStartX)
            }

            if isResizing {
                cueW += (dragCurrentX - sfxCueResizeStartX)
                cueW = max(20, cueW)
            }

            if cueX + cueW < 0 || cueX > size.width { continue }

            let cueColor = Color(hex: cue.markerColor)

            // Main bar
            let barRect = CGRect(x: cueX, y: barY, width: cueW, height: barHeight)
            let barPath = Path(roundedRect: barRect, cornerRadius: 4)
            context.fill(barPath, with: .color(cueColor.opacity(CGFloat(cue.intensity) * 0.6 + 0.15)))
            context.stroke(barPath, with: .color(cueColor.opacity(isDragging || isResizing ? 1.0 : 0.8)), lineWidth: isDragging || isResizing ? 2 : 1)

            // Fade-in ramp
            if cue.fadeInDuration > 0 {
                let fadeW = min(CGFloat(cue.fadeInDuration) * pxPerSec, cueW * 0.4)
                let fadeRect = CGRect(x: cueX, y: barY, width: fadeW, height: barHeight)
                context.fill(
                    Path(fadeRect),
                    with: .linearGradient(
                        Gradient(colors: [cueColor.opacity(0), cueColor.opacity(CGFloat(cue.intensity) * 0.4)]),
                        startPoint: CGPoint(x: cueX, y: barY),
                        endPoint: CGPoint(x: cueX + fadeW, y: barY)
                    )
                )
            }

            // Fade-out ramp
            if cue.fadeOutDuration > 0 {
                let fadeW = min(CGFloat(cue.fadeOutDuration) * pxPerSec, cueW * 0.4)
                let fadeRect = CGRect(x: cueX + cueW - fadeW, y: barY, width: fadeW, height: barHeight)
                context.fill(
                    Path(fadeRect),
                    with: .linearGradient(
                        Gradient(colors: [cueColor.opacity(CGFloat(cue.intensity) * 0.4), cueColor.opacity(0)]),
                        startPoint: CGPoint(x: cueX + cueW - fadeW, y: barY),
                        endPoint: CGPoint(x: cueX + cueW, y: barY)
                    )
                )
            }

            // Label: effect icon + truncated name
            let labelMaxW = max(0, cueW - 8)
            if labelMaxW > 20 {
                var clipped = context
                clipped.clip(to: Path(CGRect(x: cueX + 4, y: barY, width: labelMaxW, height: barHeight)))

                clipped.draw(
                    Text(Image(systemName: cue.effectType.icon))
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.9)),
                    at: CGPoint(x: cueX + 12, y: barY + barHeight / 2),
                    anchor: .center
                )

                if labelMaxW > 40 {
                    let displayName = cue.cueNumber + " " + cue.name
                    clipped.draw(
                        Text(displayName)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white.opacity(0.9)),
                        at: CGPoint(x: cueX + 22, y: barY + barHeight / 2),
                        anchor: .leading
                    )
                }
            }

            // Intensity indicator
            let intensityW = cueW * CGFloat(cue.intensity)
            let intensityRect = CGRect(x: cueX, y: barY + barHeight - 3, width: intensityW, height: 3)
            context.fill(Path(intensityRect), with: .color(cueColor))

            // Resize handle
            let handleX = cueX + cueW - 2
            context.stroke(
                Path { p in
                    p.move(to: CGPoint(x: handleX, y: barY + 4))
                    p.addLine(to: CGPoint(x: handleX, y: barY + barHeight - 4))
                },
                with: .color(.white.opacity(0.3)),
                lineWidth: 2
            )
        }
    }

    // MARK: - SFX Hit Testing

    func findSFXCue(at point: CGPoint) -> SFXCue? {
        guard showSFXLane, !sfxCues.isEmpty else { return nil }
        let baseLaneY = TimelineLayoutConstants.topMargin +
                        TimelineLayoutConstants.rulerHeight +
                        TimelineLayoutConstants.rulerGap +
                        shotLaneOffset +
                        soundtrackLaneHeight +
                        lightingLaneOffset
        let singleLaneH = TimelineLayoutConstants.sfxLaneHeight
        let barHeight: CGFloat = 36
        let hitMargin: CGFloat = 4
        let subLanes = sfxCueSubLanes

        for cue in sfxCues {
            let subLane = subLanes[cue.id] ?? 0
            let laneY = baseLaneY + CGFloat(subLane) * singleLaneH
            let barY = laneY + (singleLaneH - barHeight) / 2
            let cueX = originX + CGFloat(cue.startTime) * pxPerSec
            let cueW = max(20, CGFloat(cue.duration) * pxPerSec)
            let cueRect = CGRect(
                x: cueX - hitMargin,
                y: barY - hitMargin,
                width: cueW + hitMargin * 2,
                height: barHeight + hitMargin * 2
            )
            if cueRect.contains(point) {
                return cue
            }
        }
        return nil
    }

    func findSFXCueRightEdge(at point: CGPoint) -> SFXCue? {
        guard showSFXLane, !sfxCues.isEmpty else { return nil }
        let baseLaneY = TimelineLayoutConstants.topMargin +
                        TimelineLayoutConstants.rulerHeight +
                        TimelineLayoutConstants.rulerGap +
                        shotLaneOffset +
                        soundtrackLaneHeight +
                        lightingLaneOffset
        let singleLaneH = TimelineLayoutConstants.sfxLaneHeight
        let barHeight: CGFloat = 36
        let edgeThreshold: CGFloat = 8
        let subLanes = sfxCueSubLanes

        for cue in sfxCues {
            let subLane = subLanes[cue.id] ?? 0
            let laneY = baseLaneY + CGFloat(subLane) * singleLaneH
            let barY = laneY + (singleLaneH - barHeight) / 2
            let cueX = originX + CGFloat(cue.startTime) * pxPerSec
            let cueW = max(20, CGFloat(cue.duration) * pxPerSec)
            let cueRight = cueX + cueW

            if point.y >= barY && point.y <= barY + barHeight &&
               abs(point.x - cueRight) <= edgeThreshold {
                return cue
            }
        }
        return nil
    }

    func isSFXEyeToggleHit(at point: CGPoint) -> Bool {
        guard !sfxCues.isEmpty else { return false }
        let baseLaneY = TimelineLayoutConstants.topMargin +
                        TimelineLayoutConstants.rulerHeight +
                        TimelineLayoutConstants.rulerGap +
                        shotLaneOffset +
                        soundtrackLaneHeight +
                        lightingLaneOffset
        let totalLaneHeight = sfxLaneOffset

        if showSFXLane {
            let labelRect = CGRect(x: 4, y: baseLaneY + 4, width: TimelineLayoutConstants.rowLabelWidth - 12, height: totalLaneHeight - 8)
            let eyeRect = CGRect(x: labelRect.minX, y: labelRect.minY, width: 28, height: labelRect.height)
            return eyeRect.contains(point)
        } else {
            let labelRect = CGRect(x: 4, y: baseLaneY + 2, width: TimelineLayoutConstants.rowLabelWidth - 12, height: 20)
            return labelRect.contains(point)
        }
    }
}

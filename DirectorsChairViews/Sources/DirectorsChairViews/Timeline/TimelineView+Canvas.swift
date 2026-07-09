//
// TimelineView+Canvas.swift
//
// Extracted from TimelineView.swift (WS9.1 tier decomposition).
//

import SwiftUI
import Combine
import DirectorsChairCore
import AppKit

extension TimelineView {

    // MARK: - Helpers

    /// Extracted to reduce body expression complexity for the Swift type-checker
    func makeHeaderCanvas(geometry: GeometryProxy) -> TimelineHeaderCanvas {
        TimelineHeaderCanvas(
            segments: viewModel.visibleSegments,
            sceneBoundaries: viewModel.sceneBoundaries,
            sequenceBoundaries: viewModel.sequenceBoundaries,
            shotLabels: viewModel.shotLabels,
            showShotLabels: viewModel.showShotLabels,
            pxPerSec: viewModel.pxPerSec,
            mode: viewModel.mode,
            viewportSize: geometry.size,
            shotSubLaneAssignments: viewModel.shotSubLaneAssignments,
            shotLaneSubLaneCount: viewModel.shotLaneSubLaneCount,
            shotDialogueConnections: viewModel.shotDialogueConnections,
            showShotConnections: viewModel.showShotConnections,
            playheadTime: viewModel.playheadTime,
            playheadActive: viewModel.playheadActive,
            userMarkers: viewModel.showUserMarkers ? viewModel.userMarkers : [],
            projectBasePath: projectBasePath,
            soundtrackTracks: viewModel.soundtrackTracks,
            showSoundtracks: viewModel.showSoundtracks,
            lightCues: viewModel.lightCues,
            showLightingLane: viewModel.showLightingLane,
            sfxCues: viewModel.sfxCues,
            showSFXLane: viewModel.showSFXLane,
            supportCues: viewModel.supportCues,
            showSupportLane: viewModel.showSupportLane,
            onLightCueAdded: { time, name, number, workflow, fixture, intensity, duration, color in
                let cue = LightCue(
                    name: name,
                    cueNumber: number,
                    workflow: workflow,
                    fixtureType: fixture,
                    startTime: Double(time),
                    duration: duration,
                    intensity: intensity,
                    color: color,
                    markerColor: color
                )
                viewModel.lightCues.append(cue)
                viewModel.onLightCuesChanged?(viewModel.lightCues)
            },
            onLightCueDeleted: { cueId in
                viewModel.removeLightCue(id: cueId)
            },
            onLightCueUpdated: { cue in
                viewModel.updateLightCue(cue)
            },
            onLightCueMoved: { cueId, newStartTime in
                if var cue = viewModel.lightCues.first(where: { $0.id == cueId }) {
                    cue.startTime = newStartTime
                    viewModel.updateLightCue(cue)
                }
            },
            onLightCueResized: { cueId, newDuration in
                if var cue = viewModel.lightCues.first(where: { $0.id == cueId }) {
                    cue.duration = newDuration
                    viewModel.updateLightCue(cue)
                }
            },
            onLightCueDoubleClicked: { cueId in
                onLightCueDoubleClicked?(cueId)
            },
            onLightingLaneToggled: {
                viewModel.showLightingLane.toggle()
            },
            onSFXCueAdded: { time, name, number, effectType, intensity, duration, color in
                let cue = SFXCue(
                    name: name,
                    cueNumber: number,
                    effectType: effectType,
                    startTime: Double(time),
                    duration: duration,
                    intensity: intensity,
                    color: color,
                    markerColor: color
                )
                viewModel.sfxCues.append(cue)
                viewModel.onSFXCuesChanged?(viewModel.sfxCues)
            },
            onSFXCueDeleted: { cueId in
                viewModel.removeSFXCue(id: cueId)
            },
            onSFXCueUpdated: { cue in
                viewModel.updateSFXCue(cue)
            },
            onSFXCueMoved: { cueId, newStartTime in
                if var cue = viewModel.sfxCues.first(where: { $0.id == cueId }) {
                    cue.startTime = newStartTime
                    viewModel.updateSFXCue(cue)
                }
            },
            onSFXCueResized: { cueId, newDuration in
                if var cue = viewModel.sfxCues.first(where: { $0.id == cueId }) {
                    cue.duration = newDuration
                    viewModel.updateSFXCue(cue)
                }
            },
            onSFXCueDoubleClicked: { cueId in
                onSFXCueDoubleClicked?(cueId)
            },
            onSFXLaneToggled: {
                viewModel.showSFXLane.toggle()
            },
            onSupportCueAdded: { time, name, number, actionType, duration, color in
                let cue = SupportCue(
                    name: name,
                    cueNumber: number,
                    actionType: actionType,
                    startTime: Double(time),
                    duration: duration,
                    markerColor: color
                )
                viewModel.supportCues.append(cue)
                viewModel.onSupportCuesChanged?(viewModel.supportCues)
            },
            onSupportCueDeleted: { cueId in
                viewModel.removeSupportCue(id: cueId)
            },
            onSupportCueUpdated: { cue in
                viewModel.updateSupportCue(cue)
            },
            onSupportCueMoved: { cueId, newStartTime in
                if var cue = viewModel.supportCues.first(where: { $0.id == cueId }) {
                    cue.startTime = newStartTime
                    viewModel.updateSupportCue(cue)
                }
            },
            onSupportCueResized: { cueId, newDuration in
                if var cue = viewModel.supportCues.first(where: { $0.id == cueId }) {
                    cue.duration = newDuration
                    viewModel.updateSupportCue(cue)
                }
            },
            onSupportCueDoubleClicked: { cueId in
                onSupportCueDoubleClicked?(cueId)
            },
            onSupportLaneToggled: {
                viewModel.showSupportLane.toggle()
            },
            onSoundtrackMoved: { trackId, newOffset in
                viewModel.moveSoundtrack(id: trackId, newOffset: newOffset)
            },
            onSoundtrackTrackToggled: {
                viewModel.showSoundtracks.toggle()
            },
            onSoundtrackMuteToggled: { trackId in
                viewModel.toggleSoundtrackMute(id: trackId)
            },
            onSoundtrackRemoved: { trackId in
                viewModel.removeSoundtrack(id: trackId)
            },
            onShotLabelDoubleClicked: { shotId, sceneName in
                onShotLabelDoubleClicked?(shotId, sceneName)
            },
            onSceneMarkerDoubleClicked: onSceneMarkerDoubleClicked,
            onShotLabelMoved: { shotId, sceneName, newTime in
                viewModel.moveShotLabel(shotId: shotId, sceneName: sceneName, newTime: newTime)
                onShotLabelMoved?(shotId, sceneName, newTime)
            },
            onShotLabelSelected: { labelId in
                viewModel.selectedShotLabelId = labelId
            },
            onOptionClickShotLabel: { shotId, sceneName in
                onOptionClickShotLabel?(shotId, sceneName)
            },
            onShotTrackToggled: {
                viewModel.showShotLabels.toggle()
            },
            onShotLabelResized: { shotId, sceneName, newDuration in
                viewModel.resizeShotLabel(shotId: shotId, sceneName: sceneName, newDuration: newDuration)
                onShotLabelResized?(shotId, sceneName, newDuration)
            },
            onSceneBoundaryMoved: { name, newTime in
                viewModel.moveSceneBoundary(name: name, newTime: newTime)
            },
            onSequenceBoundaryMoved: { name, newTime in
                viewModel.moveSequenceBoundary(name: name, newTime: newTime)
            },
            onRulerClicked: { x in
                viewModel.seekPlayheadFromX(x)
            },
            onPlayheadDragged: { x in
                viewModel.seekPlayheadFromX(x)
            },
            onMarkerDeleted: { id in
                viewModel.deleteUserMarker(id: id)
            },
            onMarkerUpdated: { id, label, icon, color in
                viewModel.updateUserMarker(id: id, label: label, icon: icon, color: color)
            },
            onMarkerAdded: { time, label, icon, color in
                viewModel.addUserMarker(at: time, label: label, icon: icon, color: color)
            }
        )
    }

    /// Extracted to reduce body expression complexity for the Swift type-checker
    func makeTimelineCanvas(geometry: GeometryProxy) -> some View {
        let minTrackHeight: CGFloat = 100
        let naturalHeaderHeight = headerHeight
        let computedTrackHeight: CGFloat = geometry.size.height >= naturalHeaderHeight + minTrackHeight
            ? geometry.size.height - naturalHeaderHeight
            : min(minTrackHeight, geometry.size.height)

        var canvas = TimelineCanvas(
            segments: viewModel.visibleSegments,
            markers: viewModel.visibleMarkers,
            sceneBoundaries: viewModel.sceneBoundaries,
            sequenceBoundaries: viewModel.sequenceBoundaries,
            playheadTime: viewModel.playheadTime,
            pxPerSec: viewModel.pxPerSec,
            showThumbs: viewModel.showThumbs,
            mode: viewModel.mode,
            projectBasePath: projectBasePath,
            viewportSize: geometry.size,
            hiddenTracks: viewModel.hiddenTracks,
            subLaneAssignments: viewModel.subLaneAssignments,
            laneSubLaneCounts: viewModel.laneSubLaneCounts,
            shotDialogueConnections: viewModel.shotDialogueConnections,
            showShotConnections: viewModel.showShotConnections,
            selectedShotLabelId: viewModel.selectedShotLabelId,
            allCharacterNames: viewModel.allCharacterNames,
            verticalOffset: tracksVerticalOffset,
            availableHeight: computedTrackHeight,
            selectedSegmentIds: $viewModel.selectedSegmentIds,
            viewportOffset: $viewModel.viewportOffset,
            onSegmentSelected: { segment in
                onSegmentClicked?(segment)
            },
            onSegmentDoubleClicked: { segment in
                onSegmentDoubleClicked?(segment)
            },
            onOptionClickSegment: { segment in
                onOptionClickSegment?(segment)
            },
            onTrackToggled: { trackName in
                viewModel.toggleTrackVisibility(trackName)
            },
            onSegmentMoved: { segment, newTime in
                viewModel.moveSegment(id: segment.id, newStart: newTime)
                onSegmentMoved?(segment, newTime)
            },
            onSegmentsMoved: { moves in
                let tuples = moves.map { (segment: $0.0, newStart: $0.1) }
                viewModel.moveSegments(tuples)
                onSegmentsMoved?(moves)
            }
        )
        canvas.effectiveDuration = viewModel.totalDuration
        canvas.generatingAudioSourceIds = viewModel.generatingAudioSourceIds
        canvas.playingAudioSourceId = viewModel.playingAudioSourceId
        canvas.onEmptySpaceClicked = { x in
            viewModel.seekPlayheadFromX(x)
        }
        canvas.onSegmentRightClicked = { segment, point, nsView in
            let menu = NSMenu()

            if segment.contentType == .dialogue, let sourceId = segment.sourceItemId {
                let isGenerating = viewModel.generatingAudioSourceIds.contains(sourceId)
                let isPlaying = viewModel.playingAudioSourceId == sourceId

                if isGenerating {
                    let item = NSMenuItem(title: "Generating...", action: nil, keyEquivalent: "")
                    item.isEnabled = false
                    item.image = NSImage(systemSymbolName: "hourglass", accessibilityDescription: nil)
                    menu.addItem(item)
                } else if isPlaying {
                    let stopItem = NSMenuItem(title: "Stop Voice", action: nil, keyEquivalent: "")
                    stopItem.image = NSImage(systemSymbolName: "stop.fill", accessibilityDescription: nil)
                    let stopHandler = TrackMenuHandler { [weak viewModel] in
                        viewModel?.playingAudioSourceId = nil
                        self.onStopAudio?()
                    }
                    stopItem.target = stopHandler
                    stopItem.action = #selector(TrackMenuHandler.execute)
                    stopItem.representedObject = stopHandler
                    menu.addItem(stopItem)
                } else if segment.hasAudio {
                    let playItem = NSMenuItem(title: "Play Voice", action: nil, keyEquivalent: "")
                    playItem.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: nil)
                    let playHandler = TrackMenuHandler {
                        self.onPlayAudio?(segment)
                    }
                    playItem.target = playHandler
                    playItem.action = #selector(TrackMenuHandler.execute)
                    playItem.representedObject = playHandler
                    menu.addItem(playItem)

                    let regenItem = NSMenuItem(title: "Regenerate Voice", action: nil, keyEquivalent: "")
                    regenItem.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: nil)
                    let regenHandler = TrackMenuHandler {
                        self.onGenerateAudio?(segment)
                    }
                    regenItem.target = regenHandler
                    regenItem.action = #selector(TrackMenuHandler.execute)
                    regenItem.representedObject = regenHandler
                    menu.addItem(regenItem)
                } else {
                    let genItem = NSMenuItem(title: "Generate Voice", action: nil, keyEquivalent: "")
                    genItem.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: nil)
                    let genHandler = TrackMenuHandler {
                        self.onGenerateAudio?(segment)
                    }
                    genItem.target = genHandler
                    genItem.action = #selector(TrackMenuHandler.execute)
                    genItem.representedObject = genHandler
                    menu.addItem(genItem)
                }

                menu.addItem(NSMenuItem.separator())
            }

            // Always include track mute option
            let character = segment.character
            let isMuted = viewModel.mutedTracks.contains(character)
            let muteItem = NSMenuItem(
                title: isMuted ? "Unmute \"\(character)\" TTS" : "Mute \"\(character)\" TTS",
                action: nil,
                keyEquivalent: ""
            )
            muteItem.image = NSImage(systemSymbolName: isMuted ? "speaker.wave.2.fill" : "speaker.slash.fill", accessibilityDescription: nil)
            let muteHandler = TrackMenuHandler {
                if isMuted {
                    viewModel.mutedTracks.remove(character)
                } else {
                    viewModel.mutedTracks.insert(character)
                }
                viewModel.onTrackMuteToggled?(character)
            }
            muteItem.target = muteHandler
            muteItem.action = #selector(TrackMenuHandler.execute)
            muteItem.representedObject = muteHandler
            menu.addItem(muteItem)

            let screenPoint = nsView.window?.convertPoint(toScreen: nsView.convert(
                CGPoint(x: point.x, y: nsView.bounds.height - point.y), to: nil
            )) ?? NSEvent.mouseLocation
            menu.popUp(positioning: nil, at: screenPoint, in: nil)
        }
        canvas.onTrackRightClicked = { character, point, nsView in
            let isMuted = viewModel.mutedTracks.contains(character)
            let menu = NSMenu()

            let muteItem = NSMenuItem(
                title: isMuted ? "Unmute \"\(character)\" TTS" : "Mute \"\(character)\" TTS",
                action: nil,
                keyEquivalent: ""
            )
            let muteIcon = NSImage(systemSymbolName: isMuted ? "speaker.wave.2.fill" : "speaker.slash.fill", accessibilityDescription: nil)
            muteItem.image = muteIcon

            let handler = TrackMenuHandler {
                if isMuted {
                    viewModel.mutedTracks.remove(character)
                } else {
                    viewModel.mutedTracks.insert(character)
                }
                viewModel.onTrackMuteToggled?(character)
            }
            muteItem.target = handler
            muteItem.action = #selector(TrackMenuHandler.execute)
            muteItem.representedObject = handler
            menu.addItem(muteItem)

            let screenPoint = nsView.window?.convertPoint(toScreen: nsView.convert(
                CGPoint(x: point.x, y: nsView.bounds.height - point.y), to: nil
            )) ?? NSEvent.mouseLocation
            menu.popUp(positioning: nil, at: screenPoint, in: nil)
        }
        // Render-input pruning: skip the full-canvas repaint when nothing
        // the draw closures read has changed (closure props otherwise defeat
        // SwiftUI's automatic dependency pruning).
        return canvas.equatable()
    }

    // MARK: - Gestures

    /// Pinch-to-zoom gesture
    var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                viewModel.zoomByFactor(scale)
            }
    }
}

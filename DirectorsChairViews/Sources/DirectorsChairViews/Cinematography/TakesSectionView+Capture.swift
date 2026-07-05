//
// TakesSectionView+Capture.swift
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

    // MARK: - Section Header

    var sectionHeader: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "film.stack.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.accentColor)

                    Text("TAKES")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.2)
                        .foregroundColor(.gray)

                    if !shot.takes.isEmpty {
                        Text("\(shot.takes.count)")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.accentColor))
                    }

                    // Stats summary
                    if !shot.takes.isEmpty {
                        HStack(spacing: 10) {
                            if !shot.circledTakes.isEmpty {
                                HStack(spacing: 3) {
                                    Circle().fill(Color.green).frame(width: 5, height: 5)
                                    Text("\(shot.circledTakes.count)")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(.green)
                                }
                            }
                            let altCount = shot.takes.filter { $0.rating == .alt }.count
                            if altCount > 0 {
                                HStack(spacing: 3) {
                                    Circle().fill(Color.orange).frame(width: 5, height: 5)
                                    Text("\(altCount)")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        .padding(.leading, 4)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.gray.opacity(0.6))
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Capture device controls
            captureDeviceBar

            // Navigate to Curation
            if shot.hasTakes, let navigate = onNavigateToCuration {
                Button { navigate(shot) } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "film.stack")
                            .font(.system(size: 9, weight: .semibold))
                        Text("Curate")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.accentColor.opacity(0.2)))
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }

            // Add take
            Button { addManualTake() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .semibold))
                    Text("Take")
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color(hex: "#3A3A3A")))
                .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
            .onHover { h in }
        }
    }

    // MARK: - Capture Device Bar

    var captureDeviceBar: some View {
        HStack(spacing: 6) {
            // Device display: shows default or connected device
            let displayName = captureService.selectedDevice?.localizedName
                ?? captureService.defaultDevice?.localizedName
                ?? "No Device"
            let isLive = captureService.isSessionRunning
            let hasDefault = captureService.defaultDevice != nil

            if !captureService.availableDevices.isEmpty {
                Menu {
                    ForEach(captureService.availableDevices, id: \.uniqueID) { device in
                        Button {
                            // Override: set as default and connect immediately
                            captureService.setDefaultDevice(device)
                            captureService.connectAndStart(device: device)
                        } label: {
                            HStack {
                                if captureService.defaultDevice?.uniqueID == device.uniqueID {
                                    Image(systemName: "checkmark")
                                }
                                Label(device.localizedName, systemImage: "video.fill")
                            }
                        }
                    }
                    if isLive {
                        Divider()
                        Button("Stop Preview", role: .destructive) { captureService.disconnect() }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(isLive ? Color.green : hasDefault ? Color.accentColor : Color.gray.opacity(0.4))
                            .frame(width: 6, height: 6)
                        Text(displayName)
                            .font(.system(size: 9))
                            .foregroundColor(isLive ? .green : .gray)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color(hex: "#3A3A3A")))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            // Stop preview button
            if isLive {
                Button { captureService.disconnect() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 9))
                        Text("Stop").font(.system(size: 9, weight: .medium))
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .foregroundColor(.red)
                    .background(Capsule().fill(Color.red.opacity(0.15)))
                }
                .buttonStyle(.plain)
            }

            Button { captureService.discoverDevices() } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 9)).foregroundColor(.gray.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Capture Mode Chooser (no device set)

    var captureModeChooser: some View {
        HStack(spacing: 12) {
            // Option A: Connect a video source
            Button {
                // Discover and pick from available devices
                captureService.discoverDevices()
                if let first = captureService.availableDevices.first {
                    captureService.setDefaultDevice(first)
                }
            } label: {
                VStack(spacing: 10) {
                    Image(systemName: "video.badge.plus")
                        .font(.system(size: 22))
                        .foregroundColor(.accentColor)
                    Text("Video Source")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Connect a camera or HDMI capture card to record video with takes")
                        .font(.system(size: 9))
                        .foregroundColor(.gray.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)

                    if !captureService.availableDevices.isEmpty {
                        Menu {
                            ForEach(captureService.availableDevices, id: \.uniqueID) { device in
                                Button(device.localizedName) {
                                    captureService.setDefaultDevice(device)
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.down").font(.system(size: 7))
                                Text("Choose Device").font(.system(size: 9, weight: .medium))
                            }
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Capsule().fill(Color.accentColor))
                            .foregroundColor(.white)
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    } else {
                        Text("No devices found")
                            .font(.system(size: 8))
                            .foregroundColor(.gray.opacity(0.35))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: "#1E1E1E"))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            // Divider
            VStack(spacing: 6) {
                Rectangle().fill(Color.gray.opacity(0.2)).frame(width: 1, height: 30)
                Text("OR")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.gray.opacity(0.4))
                Rectangle().fill(Color.gray.opacity(0.2)).frame(width: 1, height: 30)
            }

            // Option B: Blind timestamp logging
            Button { isTimestampMode = true } label: {
                VStack(spacing: 10) {
                    Image(systemName: "clock.badge.checkmark.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.orange)
                    Text("Timestamp Only")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Log start/end timestamps to match with camera footage later")
                        .font(.system(size: 9))
                        .foregroundColor(.gray.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)

                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill").font(.system(size: 8))
                        Text("Use Timestamps").font(.system(size: 9, weight: .medium))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(Color.orange))
                    .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: "#1E1E1E"))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Blind Logging Card (stopwatch without video)

    var blindLoggingCard: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
            // Centered stopwatch display
            VStack(spacing: 16) {
                // LOG badge
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                        .shadow(color: .orange.opacity(0.6), radius: 4)
                    Text("TIMESTAMP LOG")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Capsule().stroke(Color.orange.opacity(0.3), lineWidth: 1))

                // Big timecode
                Text(formatBlindDuration(blindLogDuration))
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .monospacedDigit()

                // Metadata row
                HStack(spacing: 20) {
                    // Started at
                    if let start = blindLogStartTime {
                        VStack(spacing: 2) {
                            Text("STARTED")
                                .font(.system(size: 7, weight: .semibold))
                                .tracking(0.8)
                                .foregroundColor(.gray.opacity(0.5))
                            Text(Take.formatForCameraMatch(start))
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(.orange.opacity(0.8))
                                .monospacedDigit()
                        }
                    }

                    // Target take
                    if let takeId = blindLogTakeId, let take = shot.takes.first(where: { $0.id == takeId }) {
                        VStack(spacing: 2) {
                            Text("TAKE")
                                .font(.system(size: 7, weight: .semibold))
                                .tracking(0.8)
                                .foregroundColor(.gray.opacity(0.5))
                            Text("#\(take.takeNumber)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.accentColor)
                        }
                    }
                }

                // Stop button
                Button { stopBlindLog() } label: {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                .frame(width: 36, height: 36)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.orange)
                                .frame(width: 14, height: 14)
                        }
                        Text("Stop Logging")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .background(Color.black)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1.5)
            )

            // Cancel — discard log and go back to mode chooser
            Button { cancelBlindLog() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .semibold))
                    Text("Cancel")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundColor(.gray.opacity(0.6))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color(hex: "#3A3A3A")))
            }
            .buttonStyle(.plain)
            .padding(10)
            } // end ZStack
        }
    }

    // MARK: - Timestamp Ready Card (timestamp mode chosen, not yet logging)

    var timestampReadyCard: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)

                VStack(spacing: 12) {
                    Image(systemName: "clock.badge.checkmark.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.orange.opacity(0.3))

                    Text("Timestamp Logging")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gray.opacity(0.6))

                    if let take = selectedTake, take.startTimestamp == nil {
                        Text("Take #\(take.takeNumber)")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.accentColor)
                    }

                    Button { startBlindLog() } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 8, height: 8)
                            Text("Start Logging")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.orange))
                        .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)

                    Text("Logs start & end timestamps for camera footage matching")
                        .font(.system(size: 8))
                        .foregroundColor(.gray.opacity(0.35))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.orange.opacity(0.15), lineWidth: 1)
            )

            // Back to mode chooser
            Button { isTimestampMode = false } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 8, weight: .semibold))
                    Text("Change")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundColor(.gray.opacity(0.6))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color(hex: "#3A3A3A")))
            }
            .buttonStyle(.plain)
            .padding(10)
        }
    }

    // MARK: - Start Monitoring Card (default device set, not yet connected)

    var startMonitoringCard: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black)
                    .aspectRatio(16/9, contentMode: .fit)
                    .frame(maxHeight: 240)

                VStack(spacing: 12) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.gray.opacity(0.25))

                    Text(captureService.defaultDevice?.localizedName ?? "Video Source")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gray.opacity(0.6))

                    if let take = selectedTake {
                        Text("Take #\(take.takeNumber)")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.accentColor)
                    }

                    Button {
                        captureService.connectAndStart()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "video.badge.waveform.fill")
                                .font(.system(size: 10))
                            Text("Start Monitoring")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.accentColor))
                        .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)

                    Text("Camera and microphone access will be requested")
                        .font(.system(size: 8))
                        .foregroundColor(.gray.opacity(0.35))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )

            // Back to mode chooser
            Button {
                captureService.setDefaultDevice(nil)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 8, weight: .semibold))
                    Text("Change")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundColor(.gray.opacity(0.6))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color(hex: "#3A3A3A")))
            }
            .buttonStyle(.plain)
            .padding(10)
        }
    }

    // MARK: - Live Monitor

    var liveMonitorCard: some View {
        VStack(spacing: 0) {
            // 16:9 preview — conditional: raw preview layer vs LUT-processed Metal view
            ZStack {
                if captureService.selectedLUT != .none {
                    // LUT active: render processed frames via Metal
                    LUTMonitorView(
                        processedFrame: captureService.processedFrame,
                        ciContext: captureService.lutProcessor.ciContext
                    )
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16/9, contentMode: .fit)
                    .frame(maxHeight: 320)
                    .background(Color.black)
                } else if let layer = captureService.previewLayer {
                    // No LUT: use zero-overhead preview layer
                    LiveMonitorView(previewLayer: layer)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(16/9, contentMode: .fit)
                        .frame(maxHeight: 320)
                        .background(Color.black)
                } else {
                    Rectangle()
                        .fill(Color.black)
                        .aspectRatio(16/9, contentMode: .fit)
                        .frame(maxHeight: 320)
                        .overlay(
                            VStack(spacing: 6) {
                                Image(systemName: "video.slash.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.gray.opacity(0.3))
                                Text("Connecting...")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray.opacity(0.4))
                            }
                        )
                }

                // Fullscreen button — bottom right of preview
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button { isFullScreen = true } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(7)
                                .background(Circle().fill(Color.black.opacity(0.6)))
                        }
                        .buttonStyle(.plain)
                        .padding(8)
                    }
                }

                // Recording HUD overlay
                if captureService.isRecording {
                    VStack {
                        HStack {
                            // REC badge — top left
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                    .shadow(color: .red.opacity(0.6), radius: 4)

                                Text("REC")
                                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                    .foregroundColor(.red)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule().fill(Color.black.opacity(0.75))
                            )
                            .padding(10)

                            Spacer()

                            // Timecode — top right
                            Text(captureService.formattedDuration)
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule().fill(Color.black.opacity(0.75))
                                )
                                .padding(10)
                        }
                        Spacer()
                    }
                }
            }
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(captureService.isRecording ? Color.red.opacity(0.5) : Color.white.opacity(0.06), lineWidth: captureService.isRecording ? 2 : 1)
            )

            // LUT selector row
            lutSelectorRow

            // Transport bar
            HStack(spacing: 16) {
                Spacer()

                // Timecode
                Text(captureService.formattedDuration)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(captureService.isRecording ? .red : .white.opacity(0.5))
                    .monospacedDigit()

                // Record / Stop
                Button {
                    if captureService.isRecording { stopRecording() }
                    else { startRecording() }
                } label: {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            .frame(width: 40, height: 40)

                        if captureService.isRecording {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.red)
                                .frame(width: 16, height: 16)
                        } else {
                            Circle()
                                .fill(isRemoteArmed ? Color.yellow : Color.red)
                                .frame(width: 28, height: 28)
                        }
                    }
                }
                .buttonStyle(.plain)

                // Take target indicator
                let targetTake = recordingTargetTake
                VStack(spacing: 2) {
                    Text("T\(targetTake?.takeNumber ?? shot.nextTakeNumber)")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(targetTake != nil ? .accentColor : .gray)
                    if targetTake != nil {
                        Text("selected")
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(.accentColor.opacity(0.6))
                    } else {
                        Text("new")
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(.gray.opacity(0.5))
                    }
                }

                Spacer()

                // Sync tone button
                Button {
                    let timestamp = SyncToneGenerator.shared.playTriplet()
                    // Store sync event on current take via notification
                    NotificationCenter.default.post(
                        name: Notification.Name("syncTone.recordEvent"),
                        object: nil,
                        userInfo: [
                            "timestamp": timestamp,
                            "isRecording": captureService.isRecording,
                            "recordingDuration": captureService.recordingDuration
                        ]
                    )
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform.badge.plus")
                            .font(.system(size: 10))
                        Text("Sync")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.purple.opacity(0.7)))
                }
                .buttonStyle(.plain)

                // Full screen button
                Button { isFullScreen = true } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 11))
                        .foregroundColor(.gray.opacity(0.6))
                        .padding(6)
                        .background(Circle().fill(Color(hex: "#3A3A3A")))
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 12)

            // Remote control status
            if isRemoteEnabled {
                remoteControlBanner
            }
        }
    }

    // MARK: - Remote Control Banner

    var isRemoteEnabled: Bool {
        UserDefaults.standard.bool(forKey: "pref.remote.enabled")
    }

    var remoteStartKeyName: String? {
        guard let data = UserDefaults.standard.data(forKey: "pref.remote.keyMappings"),
              let decoded = try? JSONDecoder().decode([String: RemoteKeyInfo].self, from: data),
              let mapping = decoded["startTakeRecording"] else { return nil }
        return mapping.keyName
    }

    var remoteStopKeyName: String? {
        guard let data = UserDefaults.standard.data(forKey: "pref.remote.keyMappings"),
              let decoded = try? JSONDecoder().decode([String: RemoteKeyInfo].self, from: data),
              let mapping = decoded["stopTakeRecording"] else { return nil }
        return mapping.keyName
    }

    var remoteControlBanner: some View {
        VStack(spacing: 8) {
            // Status bar
            HStack(spacing: 6) {
                Image(systemName: "av.remote.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.green)
                Circle()
                    .fill(Color.green)
                    .frame(width: 5, height: 5)
                Text("REMOTE CONNECTED")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1.0)
                    .foregroundColor(.green.opacity(0.9))
                Spacer()
                if let startKey = remoteStartKeyName {
                    HStack(spacing: 3) {
                        Text("REC")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.red.opacity(0.7))
                        Text(startKey)
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                if let stopKey = remoteStopKeyName {
                    HStack(spacing: 3) {
                        Text("STOP")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.orange.opacity(0.7))
                        Text(stopKey)
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }

            // Workflow description
            HStack(spacing: 8) {
                workflowStep(number: "1", text: "Press to arm — system beep confirms ready")
                workflowStep(number: "2", text: "Press again to start recording")
            }
        }
        .padding(10)
        .background(Color.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.green.opacity(0.2), lineWidth: 1)
        )
    }

    func workflowStep(number: String, text: String) -> some View {
        HStack(spacing: 5) {
            Text(number)
                .font(.system(size: 8, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 14, height: 14)
                .background(Circle().fill(Color.green.opacity(0.5)))
            Text(text)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.gray.opacity(0.8))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

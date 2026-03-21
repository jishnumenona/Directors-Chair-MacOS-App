// DirectorsChairViews/Sources/DirectorsChairViews/Cinematography/TakesSectionView.swift
//
// Takes management — horizontal filmstrip, live monitor, one-tap rating
// Matches KeyframeGallery / VideoSettingsCard design language

import SwiftUI
import AVFoundation
import DirectorsChairCore
import DirectorsChairServices

// MARK: - Takes Section View

public struct TakesSectionView: View {
    let shot: Shot
    let projectBasePath: URL?
    let onShotUpdated: (Shot) -> Void
    @ObservedObject var captureService: LiveCaptureService

    @State private var selectedTakeId: String?
    @State private var newTagText: String = ""
    @State private var isExpanded: Bool = true
    @State private var hoveredTakeId: String?
    @State private var isFullScreen: Bool = false

    // Blind timestamp logging (no video source)
    @State private var isTimestampMode: Bool = false   // user chose timestamp approach
    @State private var isBlindLogging: Bool = false     // actively logging
    @State private var blindLogStartTime: Date?
    @State private var blindLogDuration: TimeInterval = 0
    @State private var blindLogTakeId: String?
    @State private var blindLogTimer: Timer?

    public init(
        shot: Shot,
        projectBasePath: URL?,
        onShotUpdated: @escaping (Shot) -> Void,
        captureService: LiveCaptureService
    ) {
        self.shot = shot
        self.projectBasePath = projectBasePath
        self.onShotUpdated = onShotUpdated
        self.captureService = captureService
    }

    private var sortedTakes: [Take] {
        shot.takes.sorted { $0.takeNumber < $1.takeNumber }
    }

    private var selectedTake: Take? {
        guard let id = selectedTakeId else { return sortedTakes.first }
        return shot.takes.first { $0.id == id }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader

            if isExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    // Capture mode: live monitor, start monitoring, timestamp ready/active, or mode chooser
                    // Hide inline monitor when fullscreen is active (preview layer can only attach to one view)
                    if captureService.selectedDevice != nil && !isFullScreen {
                        liveMonitorCard
                    } else if isBlindLogging {
                        blindLoggingCard
                    } else if isTimestampMode {
                        timestampReadyCard
                    } else if captureService.defaultDevice != nil {
                        startMonitoringCard
                    } else {
                        captureModeChooser
                    }

                    // Filmstrip gallery
                    if !shot.takes.isEmpty {
                        takesFilmstrip
                    }

                    // Selected take detail
                    if let take = selectedTake {
                        takeDetailCard(take)
                    }

                    // Empty state (only when truly empty — no takes, no mode chosen)
                    if shot.takes.isEmpty && captureService.selectedDevice == nil && !isBlindLogging && !isTimestampMode && captureService.defaultDevice == nil {
                        emptyState
                    }

                }
                .padding(.top, 12)
            }
        }
        .padding(14)
        .background(Color(hex: "#252525"))
        .cornerRadius(10)
        .onAppear {
            // Just refresh available devices — don't auto-start the session.
            // The default device only pre-populates the picker; user starts preview explicitly.
            captureService.discoverDevices()
        }
        .sheet(isPresented: $isFullScreen) {
            fullScreenMonitor
                .frame(minWidth: 1200, minHeight: 800)
        }
    }

    // MARK: - Section Header

    private var sectionHeader: some View {
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

    private var captureDeviceBar: some View {
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

    private var captureModeChooser: some View {
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

    private var blindLoggingCard: some View {
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

    private var timestampReadyCard: some View {
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

    private var startMonitoringCard: some View {
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

    private var liveMonitorCard: some View {
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
                                .fill(Color.red)
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
        }
    }

    // MARK: - LUT Selector

    private var lutSelectorRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "camera.filters")
                .font(.system(size: 9))
                .foregroundColor(.gray.opacity(0.5))

            Text("LUT")
                .font(.system(size: 8, weight: .semibold))
                .tracking(0.8)
                .foregroundColor(.gray.opacity(0.5))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(LUTPreset.allCases) { preset in
                        lutChip(preset)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    private func lutChip(_ preset: LUTPreset) -> some View {
        let isSelected = captureService.selectedLUT == preset

        return Button {
            captureService.setLUT(preset)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: preset.icon)
                    .font(.system(size: 8))
                Text(preset.shortLabel)
                    .font(.system(size: 9, weight: isSelected ? .semibold : .medium))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .foregroundColor(isSelected ? .white : .gray)
            .background(
                Capsule()
                    .fill(isSelected ? Color.accentColor : Color(hex: "#3A3A3A"))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Filmstrip Gallery

    private var takesFilmstrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Filmstrip header
            HStack {
                Image(systemName: "rectangle.split.3x1")
                    .font(.system(size: 10))
                    .foregroundColor(.gray.opacity(0.5))
                Text("FILMSTRIP")
                    .font(.system(size: 9, weight: .medium))
                    .tracking(1.0)
                    .foregroundColor(.gray.opacity(0.5))

                Spacer()

                Text("\(sortedTakes.count) take\(sortedTakes.count == 1 ? "" : "s")")
                    .font(.system(size: 9))
                    .foregroundColor(.gray.opacity(0.4))
            }

            // Horizontal scroll of take cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(sortedTakes) { take in
                        filmstripCard(take)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func filmstripCard(_ take: Take) -> some View {
        let isSelected = (selectedTakeId ?? sortedTakes.first?.id) == take.id
        let isHovered = hoveredTakeId == take.id

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { selectedTakeId = take.id }
        } label: {
            VStack(spacing: 0) {
                // Top: rating color bar
                ratingColorBar(take.rating)

                VStack(spacing: 8) {
                    // Take number — hero
                    Text("\(take.takeNumber)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(isSelected ? .white : .gray)

                    // Rating icon
                    Image(systemName: take.rating.icon)
                        .font(.system(size: 14))
                        .foregroundColor(ratingColor(take.rating))

                    // Duration
                    Text(formatDuration(take.durationSeconds))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray.opacity(0.7))
                        .monospacedDigit()

                    // Compact timestamp (HH:mm:ss)
                    if let ts = take.startTimestamp {
                        Text(compactTimeFormatter.string(from: ts))
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.45))
                            .monospacedDigit()
                    }

                    // Video indicator
                    if take.capturedVideoPath != nil {
                        Image(systemName: "film.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.green.opacity(0.5))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
            }
            .frame(width: 80)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color(hex: "#2A2A2A"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? Color.accentColor.opacity(0.5) :
                            isHovered ? Color.accentColor.opacity(0.2) : Color.clear,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { h in hoveredTakeId = h ? take.id : nil }
        .contextMenu {
            Button { deleteTake(take) } label: {
                Label("Delete Take", systemImage: "trash")
            }
        }
    }

    private func ratingColorBar(_ rating: TakeRating) -> some View {
        Rectangle()
            .fill(
                rating == .none ? Color.gray.opacity(0.15) :
                    ratingColor(rating).opacity(0.6)
            )
            .frame(height: 3)
            .cornerRadius(2, corners: [.topLeft, .topRight])
    }

    // MARK: - Take Detail Card

    private func takeDetailCard(_ take: Take) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header row
            HStack(spacing: 10) {
                // Big take number
                Text("#\(take.takeNumber)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                // One-tap rating bar
                HStack(spacing: 4) {
                    ratingPill(take: take, rating: .circle)
                    ratingPill(take: take, rating: .alt)
                    ratingPill(take: take, rating: .ng)
                }

                Spacer()

                // Duration
                if let dur = take.durationSeconds {
                    Text(formatDuration(dur))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .monospacedDigit()
                } else {
                    Text("--:--")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray.opacity(0.3))
                }

                // Delete
                Button { deleteTake(take) } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 9))
                        .foregroundColor(.gray.opacity(0.3))
                }
                .buttonStyle(.plain)
            }

            // Timestamp row — camera-metadata-compatible format for matching with camera footage
            if take.startTimestamp != nil || take.endTimestamp != nil {
                HStack(spacing: 12) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.accentColor)

                    if let formatted = take.formattedStartTimestamp {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("REC START")
                                .font(.system(size: 7, weight: .semibold))
                                .tracking(0.8)
                                .foregroundColor(.gray.opacity(0.5))
                            Text(formatted)
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.9))
                                .monospacedDigit()
                        }
                    }

                    if let formatted = take.formattedEndTimestamp {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("REC END")
                                .font(.system(size: 7, weight: .semibold))
                                .tracking(0.8)
                                .foregroundColor(.gray.opacity(0.5))
                            Text(formatted)
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.9))
                                .monospacedDigit()
                        }
                    }

                    Spacer()

                    // Copy timestamp button for easy matching
                    if let formatted = take.formattedStartTimestamp {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(formatted, forType: .string)
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "doc.on.clipboard")
                                    .font(.system(size: 8))
                                Text("Copy")
                                    .font(.system(size: 8, weight: .medium))
                            }
                            .foregroundColor(.gray.opacity(0.5))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color(hex: "#3A3A3A")))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color(hex: "#1E1E1E"))
                .cornerRadius(6)
            }

            // Notes — inline field
            HStack(spacing: 8) {
                Image(systemName: "note.text")
                    .font(.system(size: 9))
                    .foregroundColor(.gray.opacity(0.4))

                TextField("Notes...", text: Binding(
                    get: { take.notes },
                    set: { newValue in
                        var updated = shot
                        if let idx = updated.takes.firstIndex(where: { $0.id == take.id }) {
                            updated.takes[idx].notes = newValue
                            onShotUpdated(updated)
                        }
                    }
                ))
                .textFieldStyle(.plain)
                .font(.system(size: 11))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(hex: "#1E1E1E"))
            .cornerRadius(6)

            // Tags + Camera file row
            HStack(alignment: .top, spacing: 16) {
                // Tags
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tags")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.gray)
                        .textCase(.uppercase)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(take.tags, id: \.self) { tag in
                                HStack(spacing: 4) {
                                    Text(tag)
                                        .font(.system(size: 10, weight: .medium))
                                    Button { removeTag(tag, from: take) } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 7, weight: .bold))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .foregroundColor(.white)
                                .background(Capsule().fill(Color.accentColor.opacity(0.6)))
                            }

                            // Inline add
                            HStack(spacing: 3) {
                                Image(systemName: "plus")
                                    .font(.system(size: 7, weight: .semibold))
                                    .foregroundColor(.gray)
                                TextField("add", text: $newTagText, onCommit: {
                                    addTag(newTagText, to: take)
                                    newTagText = ""
                                })
                                .textFieldStyle(.plain)
                                .font(.system(size: 9))
                                .frame(width: 40)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color(hex: "#3A3A3A")))
                        }
                    }
                }

                Divider().frame(height: 30).opacity(0.3)

                // Camera source
                VStack(alignment: .leading, spacing: 6) {
                    Text("Camera File")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.gray)
                        .textCase(.uppercase)

                    Button { mapCameraFile(for: take) } label: {
                        HStack(spacing: 5) {
                            Image(systemName: take.cameraSourceFileName != nil ? "checkmark.circle.fill" : "sdcard")
                                .font(.system(size: 9))
                                .foregroundColor(take.cameraSourceFileName != nil ? .green : .gray)
                            Text(take.cameraSourceFileName ?? "Map file...")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(take.cameraSourceFileName != nil ? .white : .gray)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color(hex: "#3A3A3A")))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Action row
            if let videoPath = take.capturedVideoPath, let basePath = projectBasePath {
                let fullURL = basePath.deletingLastPathComponent().appendingPathComponent(videoPath)
                HStack(spacing: 8) {
                    Button {
                        NSWorkspace.shared.open(fullURL)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill").font(.system(size: 9))
                            Text("Play").font(.system(size: 10, weight: .medium))
                        }
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(Color.accentColor))
                        .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)

                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([fullURL])
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "folder").font(.system(size: 9))
                            Text("Reveal").font(.system(size: 10, weight: .medium))
                        }
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(Color(hex: "#3A3A3A")))
                        .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    // File path pill
                    Text(fullURL.lastPathComponent)
                        .font(.system(size: 8))
                        .foregroundColor(.gray.opacity(0.3))
                        .lineLimit(1)
                }
            }
        }
        .padding(14)
        .background(Color(hex: "#1A1A1A"))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
        )
    }

    // MARK: - Rating Pill

    private func ratingPill(take: Take, rating: TakeRating) -> some View {
        let isSelected = take.rating == rating

        return Button {
            var updated = shot
            if let idx = updated.takes.firstIndex(where: { $0.id == take.id }) {
                updated.takes[idx].rating = isSelected ? .none : rating
                onShotUpdated(updated)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: rating.icon)
                    .font(.system(size: 9))
                Text(rating.rawValue)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundColor(isSelected ? .white : ratingColor(rating))
            .background(
                Capsule()
                    .fill(isSelected ? ratingColor(rating) : Color(hex: "#3A3A3A"))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "film.stack")
                .font(.system(size: 28))
                .foregroundColor(.gray.opacity(0.2))
            Text("No takes yet")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray.opacity(0.5))
            Text("Connect a video source to record, or use timestamp logging to match footage later")
                .font(.system(size: 10))
                .foregroundColor(.gray.opacity(0.3))
                .multilineTextAlignment(.center)

            Button { addManualTake() } label: {
                HStack(spacing: 5) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 10))
                    Text("Add First Take")
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(Color.accentColor))
                .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Full Screen Monitor

    private var fullScreenMonitor: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Live preview — fills available space, conditional on LUT
            if captureService.selectedLUT != .none {
                LUTMonitorView(
                    processedFrame: captureService.processedFrame,
                    ciContext: captureService.lutProcessor.ciContext
                )
                .ignoresSafeArea()
            } else if let layer = captureService.previewLayer {
                LiveMonitorView(previewLayer: layer)
                    .ignoresSafeArea()
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "video.slash.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.2))
                    Text("No preview available")
                        .font(.system(size: 14))
                        .foregroundColor(.gray.opacity(0.4))
                }
            }

            // HUD overlay
            VStack {
                HStack(alignment: .top) {
                    // REC badge — top left
                    if captureService.isRecording {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 10, height: 10)
                                .shadow(color: .red.opacity(0.6), radius: 6)
                            Text("REC")
                                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.black.opacity(0.7)))
                    }

                    Spacer()

                    // LUT selector — top center-right
                    HStack(spacing: 5) {
                        Image(systemName: "camera.filters")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.6))

                        ForEach(LUTPreset.allCases) { preset in
                            let isActive = captureService.selectedLUT == preset
                            Button { captureService.setLUT(preset) } label: {
                                Text(preset.shortLabel)
                                    .font(.system(size: 9, weight: isActive ? .semibold : .medium))
                                    .foregroundColor(isActive ? .white : .white.opacity(0.5))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(isActive ? Color.accentColor : Color.white.opacity(0.1))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(Color.black.opacity(0.7))
                    )

                    // Timecode — top right
                    Text(captureService.formattedDuration)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .monospacedDigit()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.black.opacity(0.7)))
                }
                .padding(20)

                Spacer()

                // Bottom transport bar
                HStack(spacing: 24) {
                    // Device name
                    HStack(spacing: 6) {
                        Circle()
                            .fill(captureService.isSessionRunning ? Color.green : Color.gray.opacity(0.4))
                            .frame(width: 8, height: 8)
                        Text(captureService.selectedDevice?.localizedName ?? "No Device")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.black.opacity(0.7)))

                    Spacer()

                    // Record / Stop
                    Button {
                        if captureService.isRecording { stopRecording() }
                        else { startRecording() }
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.4), lineWidth: 3)
                                .frame(width: 56, height: 56)

                            if captureService.isRecording {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.red)
                                    .frame(width: 22, height: 22)
                            } else {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 40, height: 40)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    // Close button
                    Button {
                        isFullScreen = false
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Exit")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.white.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape, modifiers: [])
                }
                .padding(20)
            }
        }
    }

    // MARK: - Actions

    private func addManualTake() {
        var updated = shot
        let newTake = Take(takeNumber: shot.nextTakeNumber)
        updated.takes.append(newTake)
        onShotUpdated(updated)
        selectedTakeId = newTake.id
    }

    private func deleteTake(_ take: Take) {
        var updated = shot
        updated.takes.removeAll { $0.id == take.id }
        if selectedTakeId == take.id { selectedTakeId = nil }
        onShotUpdated(updated)
    }

    private func addTag(_ tag: String, to take: Take) {
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

    private func removeTag(_ tag: String, from take: Take) {
        var updated = shot
        if let idx = updated.takes.firstIndex(where: { $0.id == take.id }) {
            updated.takes[idx].tags.removeAll { $0 == tag }
            onShotUpdated(updated)
        }
    }

    private func mapCameraFile(for take: Take) {
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
    private var recordingTargetTake: Take? {
        guard let take = selectedTake else { return nil }
        // Only target an existing take if it hasn't been recorded yet
        if take.capturedVideoPath == nil && take.startTimestamp == nil {
            return take
        }
        return nil
    }

    private func startRecording() {
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
                    }
                    onShotUpdated(finalShot)
                }
            }
        }
    }

    private func stopRecording() { captureService.stopRecording() }

    // MARK: - Blind Timestamp Logging

    private func startBlindLog() {
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

    private func stopBlindLog() {
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

    private func cancelBlindLog() {
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

    private func formatBlindDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let tenths = Int((duration.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }

    // MARK: - Helpers

    private func ratingColor(_ rating: TakeRating) -> Color {
        switch rating {
        case .none: return .gray
        case .circle: return .green
        case .alt: return .orange
        case .ng: return .red
        }
    }

    private func formatDuration(_ seconds: Double?) -> String {
        guard let seconds else { return "--:--" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    /// Compact time-only formatter for filmstrip cards (HH:mm:ss)
    private var compactTimeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }
}

// MARK: - Corner Radius Extension

private extension View {
    func cornerRadius(_ radius: CGFloat, corners: [RectCorner]) -> some View {
        clipShape(PartialRoundedRectangle(radius: radius, corners: corners))
    }
}

private enum RectCorner { case topLeft, topRight, bottomLeft, bottomRight }

private struct PartialRoundedRectangle: Shape {
    var radius: CGFloat
    var corners: [RectCorner]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tl = corners.contains(.topLeft) ? radius : 0
        let tr = corners.contains(.topRight) ? radius : 0
        let bl = corners.contains(.bottomLeft) ? radius : 0
        let br = corners.contains(.bottomRight) ? radius : 0

        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY + tr), radius: tr)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.maxX - br, y: rect.maxY), radius: br)
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.maxY - bl), radius: bl)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.minX + tl, y: rect.minY), radius: tl)
        return path
    }
}

// DirectorsChairViews/Sources/DirectorsChairViews/Cinematography/TakesSectionView.swift
//
// Takes management — horizontal filmstrip, live monitor, one-tap rating
// Matches KeyframeGallery / VideoSettingsCard design language

import SwiftUI
import AVFoundation
import AVKit
import DirectorsChairCore
import DirectorsChairServices

// Lightweight decode-only mirror of KeyMapping from the main app target
private struct RemoteKeyInfo: Codable {
    let keyCode: UInt16
    let action: String
    let keyName: String
}

// MARK: - Takes Section View

public struct TakesSectionView: View {
    let shot: Shot
    let projectBasePath: URL?
    let onShotUpdated: (Shot) -> Void
    @ObservedObject var captureService: LiveCaptureService
    var onNavigateToCuration: ((Shot) -> Void)?

    @State private var selectedTakeId: String?
    @State private var newTagText: String = ""
    @State private var isExpanded: Bool = true
    @State private var hoveredTakeId: String?
    @State private var isFullScreen: Bool = false
    @State private var ratingFilter: TakeRating? = nil  // nil = show all

    // Debounced notes editing
    @State private var editingNotes: String = ""
    @State private var editingNotesTakeId: String?
    @State private var notesDebounceTask: Task<Void, Never>?

    // Blind timestamp logging (no video source)
    @State private var isTimestampMode: Bool = false   // user chose timestamp approach
    @State private var isBlindLogging: Bool = false     // actively logging
    @State private var blindLogStartTime: Date?
    @State private var blindLogDuration: TimeInterval = 0
    @State private var blindLogTakeId: String?
    @State private var blindLogTimer: Timer?

    // Remote control armed state (drives record button color)
    @State private var isRemoteArmed: Bool = false

    public init(
        shot: Shot,
        projectBasePath: URL?,
        onShotUpdated: @escaping (Shot) -> Void,
        captureService: LiveCaptureService,
        onNavigateToCuration: ((Shot) -> Void)? = nil
    ) {
        self.shot = shot
        self.projectBasePath = projectBasePath
        self.onShotUpdated = onShotUpdated
        self.captureService = captureService
        self.onNavigateToCuration = onNavigateToCuration
    }

    private var sortedTakes: [Take] {
        shot.takes.sorted { $0.takeNumber < $1.takeNumber }
    }

    private var filteredTakes: [Take] {
        guard let filter = ratingFilter else { return sortedTakes }
        return sortedTakes.filter { $0.rating == filter }
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

                    // Review Bay (take strip + player + metadata)
                    if !shot.takes.isEmpty, let take = selectedTake {
                        takeReviewBay(take)
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
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("remoteControl.startTakeRecording"))) { _ in
            handleRemoteStart()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("remoteControl.stopTakeRecording"))) { _ in
            handleRemoteStop()
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

    private var isRemoteEnabled: Bool {
        UserDefaults.standard.bool(forKey: "pref.remote.enabled")
    }

    private var remoteStartKeyName: String? {
        guard let data = UserDefaults.standard.data(forKey: "pref.remote.keyMappings"),
              let decoded = try? JSONDecoder().decode([String: RemoteKeyInfo].self, from: data),
              let mapping = decoded["startTakeRecording"] else { return nil }
        return mapping.keyName
    }

    private var remoteStopKeyName: String? {
        guard let data = UserDefaults.standard.data(forKey: "pref.remote.keyMappings"),
              let decoded = try? JSONDecoder().decode([String: RemoteKeyInfo].self, from: data),
              let mapping = decoded["stopTakeRecording"] else { return nil }
        return mapping.keyName
    }

    private var remoteControlBanner: some View {
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

    private func workflowStep(number: String, text: String) -> some View {
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

    // MARK: - Review Bay

    private func takeReviewBay(_ take: Take) -> some View {
        VStack(spacing: 0) {
            // Top: Video (left) + Metadata (right)
            reviewPanel(take)

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)

            // Bottom: Horizontal take grid with filter
            takesGrid
        }
        .background(Color(hex: "#1A1A1A"))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
        )
    }

    // MARK: - Takes Grid (Bottom Pane)

    private var takesGrid: some View {
        VStack(spacing: 0) {
            // Filter bar
            HStack(spacing: 8) {
                Image(systemName: "film.stack.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.accentColor)
                Text("TAKES")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1.0)
                    .foregroundColor(.gray.opacity(0.5))

                Text("\(sortedTakes.count)")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentColor.opacity(0.4)))

                // Renumber takes
                if shot.takes.count > 1 {
                    Button { renumberTakes() } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 8, weight: .semibold))
                            Text("Renumber")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                    .help("Renumber takes sequentially")
                }

                Spacer()

                // Rating filter chips
                takeFilterChip(label: "All", icon: "film.stack", filter: nil)
                takeFilterChip(label: "Circle", icon: "checkmark.circle.fill", filter: .circle, color: .green)
                takeFilterChip(label: "Alt", icon: "star.fill", filter: .alt, color: .orange)
                takeFilterChip(label: "NG", icon: "xmark.circle.fill", filter: .ng, color: .red)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Rectangle()
                .fill(Color.white.opacity(0.04))
                .frame(height: 1)

            // Horizontal scrolling grid of take cards
            ScrollView(.horizontal, showsIndicators: true) {
                LazyHStack(spacing: 8) {
                    ForEach(filteredTakes) { take in
                        takeGridCard(take)
                    }
                }
                .padding(10)
            }
            .frame(height: 140)
        }
        .background(Color(hex: "#161616"))
    }

    private func takeFilterChip(label: String, icon: String, filter: TakeRating?, color: Color = .accentColor) -> some View {
        let isActive = ratingFilter == filter
        let count = filter == nil ? sortedTakes.count : sortedTakes.filter { $0.rating == filter }.count

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { ratingFilter = filter }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 8))
                Text(label)
                    .font(.system(size: 9, weight: isActive ? .semibold : .medium))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(isActive ? .white : .gray)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .foregroundColor(isActive ? .white : color == .accentColor ? .gray : color)
            .background(
                Capsule().fill(isActive ? color.opacity(0.7) : Color(hex: "#2A2A2A"))
            )
        }
        .buttonStyle(.plain)
    }

    private func takeGridCard(_ take: Take) -> some View {
        let isSelected = (selectedTakeId ?? sortedTakes.first?.id) == take.id
        let isHovered = hoveredTakeId == take.id

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { selectedTakeId = take.id }
        } label: {
            VStack(spacing: 0) {
                // Thumbnail
                ZStack(alignment: .bottomTrailing) {
                    if let videoPath = take.capturedVideoPath, let basePath = projectBasePath {
                        let fullURL = basePath.deletingLastPathComponent().appendingPathComponent(videoPath)
                        TakeThumbnailView(videoURL: fullURL)
                            .id("\(take.id)-\(take.endTimestamp?.timeIntervalSince1970 ?? 0)")
                            .frame(width: 150, height: 84)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color(hex: "#1E1E1E"))
                            .frame(width: 150, height: 84)
                            .overlay(
                                Image(systemName: "video.slash")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray.opacity(0.2))
                            )
                    }

                    // Duration badge
                    if let dur = take.durationSeconds {
                        Text(formatDuration(dur))
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .monospacedDigit()
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.75))
                            .cornerRadius(3)
                            .padding(4)
                    }
                }

                // Info bar: T#, rating label, film icon
                HStack(spacing: 5) {
                    Text("T\(take.takeNumber)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(isSelected ? .white : .white.opacity(0.7))

                    // Rating label badge
                    if take.rating != .none {
                        takeRatingBadge(take.rating)
                    }

                    Spacer()

                    if take.capturedVideoPath != nil {
                        Image(systemName: "film.fill")
                            .font(.system(size: 7))
                            .foregroundColor(.green.opacity(0.5))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
            }
            .frame(width: 150)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : isHovered ? Color.white.opacity(0.04) : Color(hex: "#222222"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        isSelected ? Color.accentColor.opacity(0.5) :
                            isHovered ? Color.white.opacity(0.08) : Color.white.opacity(0.03),
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

    private func takeRatingBadge(_ rating: TakeRating) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(ratingColor(rating))
                .frame(width: 5, height: 5)
            Text(rating == .circle ? "Circle" : rating == .alt ? "Alt" : "NG")
                .font(.system(size: 8, weight: .semibold))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .foregroundColor(ratingColor(rating))
        .background(
            Capsule().fill(ratingColor(rating).opacity(0.15))
        )
    }

    // MARK: - Review Panel (Right Pane) — Video left, Metadata right

    private func reviewPanel(_ take: Take) -> some View {
        HStack(alignment: .top, spacing: 0) {
            // Left half: Video + transport
            VStack(spacing: 0) {
                reviewVideoSection(take)
            }
            .frame(maxWidth: .infinity)
            .padding(12)

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 1)

            // Right half: Metadata
            ScrollView(.vertical, showsIndicators: false) {
                reviewMetadataCard(take)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func reviewVideoSection(_ take: Take) -> some View {
        Group {
            if let videoPath = take.capturedVideoPath, let basePath = projectBasePath {
                let fullURL = basePath.deletingLastPathComponent().appendingPathComponent(videoPath)
                ReviewPlayerView(videoURL: fullURL)
                    .id("\(take.id)-\(take.endTimestamp?.timeIntervalSince1970 ?? 0)")
            } else {
                // No-video placeholder
                VStack(spacing: 0) {
                    ZStack {
                        Rectangle()
                            .fill(Color.black)
                            .aspectRatio(16/9, contentMode: .fit)

                        VStack(spacing: 10) {
                            Image(systemName: "film")
                                .font(.system(size: 28))
                                .foregroundColor(.gray.opacity(0.25))
                            Text("No Video")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.gray.opacity(0.4))
                            Button { mapCameraFile(for: take) } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 9))
                                    Text("Map Camera File")
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.accentColor))
                                .foregroundColor(.white)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(hex: "#3A3A3A"), lineWidth: 1)
                    )
                }
            }
        }
    }

    private func reviewMetadataCard(_ take: Take) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Take # + rating pills
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("#\(take.takeNumber)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Spacer()

                    if let dur = take.durationSeconds {
                        Text(formatDuration(dur))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.accentColor)
                            .monospacedDigit()
                    } else {
                        Text("--:--")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.3))
                    }

                    Button { deleteTake(take) } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 9))
                            .foregroundColor(.gray.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                }

                // Rating pills
                HStack(spacing: 4) {
                    ratingPill(take: take, rating: .circle)
                    ratingPill(take: take, rating: .alt)
                    ratingPill(take: take, rating: .ng)
                }
            }

            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)

            // Timestamps
            if take.startTimestamp != nil || take.endTimestamp != nil {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.accentColor)
                        Text("TIMESTAMPS")
                            .font(.system(size: 7, weight: .bold))
                            .tracking(0.8)
                            .foregroundColor(.gray.opacity(0.5))
                        Spacer()
                        if let formatted = take.formattedStartTimestamp {
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(formatted, forType: .string)
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "doc.on.clipboard")
                                        .font(.system(size: 7))
                                    Text("Copy")
                                        .font(.system(size: 7, weight: .medium))
                                }
                                .foregroundColor(.gray.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack(spacing: 12) {
                        if let formatted = take.formattedStartTimestamp {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("REC START")
                                    .font(.system(size: 7, weight: .semibold))
                                    .tracking(0.6)
                                    .foregroundColor(.gray.opacity(0.4))
                                Text(formatted)
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.9))
                                    .monospacedDigit()
                            }
                        }

                        if let formatted = take.formattedEndTimestamp {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("REC END")
                                    .font(.system(size: 7, weight: .semibold))
                                    .tracking(0.6)
                                    .foregroundColor(.gray.opacity(0.4))
                                Text(formatted)
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.9))
                                    .monospacedDigit()
                            }
                        }
                    }
                }
                .padding(10)
                .background(Color(hex: "#1A1A1A"))
                .cornerRadius(6)
            }

            // Notes
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: "note.text")
                        .font(.system(size: 8))
                        .foregroundColor(.gray.opacity(0.4))
                    Text("NOTES")
                        .font(.system(size: 7, weight: .bold))
                        .tracking(0.8)
                        .foregroundColor(.gray.opacity(0.4))
                }

                TextField("Add notes...", text: Binding(
                    get: { editingNotesTakeId == take.id ? editingNotes : take.notes },
                    set: { newValue in
                        editingNotes = newValue
                        editingNotesTakeId = take.id
                        notesDebounceTask?.cancel()
                        notesDebounceTask = Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            guard !Task.isCancelled else { return }
                            var updated = shot
                            if let idx = updated.takes.firstIndex(where: { $0.id == take.id }) {
                                updated.takes[idx].notes = newValue
                                onShotUpdated(updated)
                            }
                        }
                    }
                ))
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(hex: "#1A1A1A"))
                .cornerRadius(4)
                .onSubmit {
                    notesDebounceTask?.cancel()
                    var updated = shot
                    if let idx = updated.takes.firstIndex(where: { $0.id == take.id }) {
                        updated.takes[idx].notes = editingNotes
                        onShotUpdated(updated)
                    }
                    editingNotesTakeId = nil
                }
            }

            // Tags
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.gray.opacity(0.4))
                    Text("TAGS")
                        .font(.system(size: 7, weight: .bold))
                        .tracking(0.8)
                        .foregroundColor(.gray.opacity(0.4))
                }

                FlowLayout(spacing: 4) {
                    ForEach(take.tags, id: \.self) { tag in
                        HStack(spacing: 3) {
                            Text(tag)
                                .font(.system(size: 9, weight: .medium))
                            Button { removeTag(tag, from: take) } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 6, weight: .bold))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .foregroundColor(.white)
                        .background(Capsule().fill(Color.accentColor.opacity(0.5)))
                    }

                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                            .font(.system(size: 6, weight: .semibold))
                            .foregroundColor(.gray)
                        TextField("add", text: $newTagText, onCommit: {
                            addTag(newTagText, to: take)
                            newTagText = ""
                        })
                        .textFieldStyle(.plain)
                        .font(.system(size: 9))
                        .frame(width: 36)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color(hex: "#3A3A3A")))
                }
            }

            // Camera File
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.gray.opacity(0.4))
                    Text("CAMERA FILE")
                        .font(.system(size: 7, weight: .bold))
                        .tracking(0.8)
                        .foregroundColor(.gray.opacity(0.4))
                }

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

            // File info
            if let videoPath = take.capturedVideoPath, let basePath = projectBasePath {
                let fullURL = basePath.deletingLastPathComponent().appendingPathComponent(videoPath)
                HStack(spacing: 5) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 7))
                        .foregroundColor(.gray.opacity(0.3))
                    Text(fullURL.lastPathComponent)
                        .font(.system(size: 9))
                        .foregroundColor(.gray.opacity(0.4))
                        .lineLimit(1)
                }
            }
        }
        .padding(14)
    }

    // MARK: - Rating Pill

    private func ratingPill(take: Take, rating: TakeRating) -> some View {
        let isSelected = take.rating == rating

        return Button {
            var updated = shot
            if let idx = updated.takes.firstIndex(where: { $0.id == take.id }) {
                updated.takes[idx].rating = isSelected ? .none : rating
                updated.updateStatusFromTakes()
                onShotUpdated(updated)

                // Regenerate collage when circle rating changes
                if rating == .circle {
                    regenerateTakePreview(for: updated)
                }
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
        updated.updateStatusFromTakes()
        onShotUpdated(updated)
        selectedTakeId = newTake.id
    }

    private func deleteTake(_ take: Take) {
        var updated = shot
        updated.takes.removeAll { $0.id == take.id }
        if selectedTakeId == take.id { selectedTakeId = nil }
        updated.updateStatusFromTakes()
        onShotUpdated(updated)
    }

    private func renumberTakes() {
        var updated = shot
        for i in updated.takes.indices {
            updated.takes[i].takeNumber = i + 1
        }
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

    private func stopRecording() { captureService.stopRecording() }

    // MARK: - Remote Control Handlers

    private func handleRemoteStart() {
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

    private func handleRemoteStop() {
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
    private func saveTakePreviewImage(from videoURL: URL) {
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
    private static func createCollage(leftImage: CGImage, leftLabel: String, rightImage: CGImage, rightLabel: String) -> Data? {
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
    private func regenerateTakePreview(for updatedShot: Shot) {
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

// MARK: - Take Thumbnail View

/// Generates and displays a thumbnail from a video file
private struct TakeThumbnailView: View {
    let videoURL: URL
    @State private var thumbnail: NSImage?

    var body: some View {
        Group {
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color(hex: "#1A1A1A"))
                    .overlay(
                        Image(systemName: "film")
                            .font(.system(size: 14))
                            .foregroundColor(.gray.opacity(0.3))
                    )
            }
        }
        .onAppear { generateThumbnail() }
    }

    private func generateThumbnail() {
        Task {
            let asset = AVAsset(url: videoURL)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 240, height: 136)

            // Extract frame 2 seconds before end of video
            let duration = try await asset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)
            let targetSeconds = max(0, durationSeconds - 2.0)
            let time = CMTime(seconds: targetSeconds, preferredTimescale: 600)

            if let cgImage = try? await generator.image(at: time).image {
                await MainActor.run {
                    thumbnail = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                }
            }
        }
    }
}

// MARK: - Review Player View

/// Self-contained video player with transport bar, skip buttons, and seek bar with thumb knob
private struct ReviewPlayerView: View {
    let videoURL: URL
    @State private var player: AVPlayer?
    @State private var isPlaying: Bool = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var timeObserver: Any?

    var body: some View {
        VStack(spacing: 0) {
            // Video viewport — clean, no overlaid controls
            ZStack {
                if let player {
                    TakeAVPlayerView(player: player)
                        .aspectRatio(16/9, contentMode: .fit)
                        .frame(maxHeight: 320)
                        .background(Color.black)
                } else {
                    Rectangle()
                        .fill(Color.black)
                        .aspectRatio(16/9, contentMode: .fit)
                        .frame(maxHeight: 320)
                        .overlay(ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)))
                }
            }
            .cornerRadius(8, corners: [.topLeft, .topRight])

            // Transport bar — below video, always accessible
            HStack(spacing: 10) {
                // Skip back 5s
                Button { skip(-5) } label: {
                    Image(systemName: "gobackward.5")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)

                // Play / Pause — prominent button
                Button { togglePlay() } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30)
                        .background(
                            Circle().fill(isPlaying ? Color.accentColor : Color(hex: "#3A3A3A"))
                        )
                }
                .buttonStyle(.plain)

                // Skip forward 5s
                Button { skip(5) } label: {
                    Image(systemName: "goforward.5")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)

                // Current time
                Text(formatTime(currentTime))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                    .monospacedDigit()
                    .frame(width: 38, alignment: .trailing)

                // Seek bar with visible thumb knob
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Track background
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: "#3A3A3A"))
                            .frame(height: 4)
                        // Filled portion
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.accentColor)
                            .frame(width: duration > 0 ? geo.size.width * CGFloat(currentTime / duration) : 0, height: 4)
                        // Thumb knob
                        if duration > 0 {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 10, height: 10)
                                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                                .offset(x: max(0, min(geo.size.width - 10, geo.size.width * CGFloat(currentTime / duration) - 5)))
                        }
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let fraction = max(0, min(1, value.location.x / geo.size.width))
                                let seekTime = fraction * duration
                                player?.seek(to: CMTime(seconds: seekTime, preferredTimescale: 600))
                                currentTime = seekTime
                            }
                    )
                }
                .frame(height: 20)

                // Duration
                Text(formatTime(duration))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.5))
                    .monospacedDigit()
                    .frame(width: 38, alignment: .leading)

                Spacer()

                // Open External
                Button {
                    NSWorkspace.shared.open(videoURL)
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 10))
                        .foregroundColor(.gray.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help("Open in external player")

                // Reveal in Finder
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([videoURL])
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 10))
                        .foregroundColor(.gray.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help("Reveal in Finder")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(hex: "#1A1A1A"))
            .cornerRadius(8, corners: [.bottomLeft, .bottomRight])
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(hex: "#3A3A3A"), lineWidth: 1)
        )
        .onAppear { setupPlayer() }
        .onDisappear { cleanupPlayer() }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("toggleShotVideoPlayback"))) { _ in
            togglePlay()
        }
    }

    private func setupPlayer() {
        let avPlayer = AVPlayer(url: videoURL)
        player = avPlayer
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            currentTime = time.seconds
        }
        Task {
            if let dur = try? await avPlayer.currentItem?.asset.load(.duration) {
                await MainActor.run { duration = dur.seconds.isFinite ? dur.seconds : 0 }
            }
        }
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: avPlayer.currentItem, queue: .main) { _ in
            isPlaying = false
            avPlayer.seek(to: .zero)
            currentTime = 0
        }
    }

    private func cleanupPlayer() {
        player?.pause()
        if let observer = timeObserver { player?.removeTimeObserver(observer) }
        player = nil
    }

    private func togglePlay() {
        guard let player else { return }
        if isPlaying { player.pause() } else { player.play() }
        isPlaying.toggle()
    }

    private func skip(_ seconds: Double) {
        guard let player else { return }
        let newTime = max(0, min(duration, currentTime + seconds))
        player.seek(to: CMTime(seconds: newTime, preferredTimescale: 600))
        currentTime = newTime
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Take AVPlayer NSView Wrapper

private struct TakeAVPlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .none
        view.showsFullScreenToggleButton = false
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
    }
}


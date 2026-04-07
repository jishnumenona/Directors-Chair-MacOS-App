//
//  HardwareView.swift
//  DirectorsChair-Desktop
//
//  Hardware dashboard — popover showing video devices,
//  audio devices, and capture cards with live status.
//

import SwiftUI
import DirectorsChairServices

// MARK: - Popover Content (launched from toolbar)

struct HardwarePopoverView: View {
    @ObservedObject var captureService: LiveCaptureService
    @StateObject private var hardwareService = HardwareMonitorService()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "cable.connector.horizontal")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.accentColor)
                        Text("HARDWARE")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    HardwareSummaryPills(
                        videoCount: hardwareService.videoDevices.count,
                        audioCount: hardwareService.audioInputDevices.count + hardwareService.audioOutputDevices.count,
                        captureCount: hardwareService.captureCards.count
                    )

                    Button {
                        hardwareService.refresh()
                        captureService.discoverDevices()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.borderless)
                    .help("Refresh devices")
                }
                .padding(.bottom, 2)

                // Video Devices
                HardwareSection(icon: "video.fill", title: "VIDEO DEVICES", count: hardwareService.videoDevices.count) {
                    if hardwareService.videoDevices.isEmpty {
                        EmptyDeviceRow(message: "No video devices detected")
                    } else {
                        VStack(spacing: 8) {
                            ForEach(hardwareService.videoDevices) { device in
                                VideoDeviceRow(
                                    device: device,
                                    isDefault: captureService.defaultDevice?.uniqueID == device.id,
                                    onSetDefault: { captureService.setDefaultDevice(device.avDevice) }
                                )
                            }
                        }
                    }
                }

                // Audio Input
                HardwareSection(icon: "mic.fill", title: "AUDIO INPUT", count: hardwareService.audioInputDevices.count) {
                    if hardwareService.audioInputDevices.isEmpty {
                        EmptyDeviceRow(message: "No audio inputs detected")
                    } else {
                        VStack(spacing: 6) {
                            ForEach(hardwareService.audioInputDevices) { device in
                                AudioDeviceRow(device: device, isInput: true)
                            }
                        }
                    }
                }

                // Audio Output
                HardwareSection(icon: "speaker.wave.2.fill", title: "AUDIO OUTPUT", count: hardwareService.audioOutputDevices.count) {
                    if hardwareService.audioOutputDevices.isEmpty {
                        EmptyDeviceRow(message: "No audio outputs detected")
                    } else {
                        VStack(spacing: 6) {
                            ForEach(hardwareService.audioOutputDevices) { device in
                                AudioDeviceRow(device: device, isInput: false)
                            }
                        }
                    }
                }

                // Capture Cards
                if !hardwareService.captureCards.isEmpty {
                    HardwareSection(icon: "rectangle.connected.to.line.below", title: "CAPTURE CARDS", count: hardwareService.captureCards.count) {
                        VStack(spacing: 8) {
                            ForEach(hardwareService.captureCards) { device in
                                VideoDeviceRow(
                                    device: device,
                                    isDefault: captureService.defaultDevice?.uniqueID == device.id,
                                    onSetDefault: { captureService.setDefaultDevice(device.avDevice) }
                                )
                            }
                        }
                    }
                }

                // Remote Control
                RemoteControlSection()

                // Session controls
                if captureService.isSessionRunning || captureService.defaultDevice != nil {
                    Divider()
                    HStack(spacing: 10) {
                        if captureService.isSessionRunning {
                            Button(role: .destructive) {
                                captureService.disconnect()
                            } label: {
                                Label("Stop Preview", systemImage: "stop.circle")
                                    .font(.system(size: 10))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        if captureService.defaultDevice != nil {
                            Button(role: .destructive) {
                                captureService.tearDown()
                            } label: {
                                Label("Clear Default", systemImage: "xmark.circle")
                                    .font(.system(size: 10))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        Spacer()
                    }
                }
            }
            .padding(16)
        }
        .frame(width: 380, height: min(CGFloat(estimatedHeight), 520))
        .onAppear { hardwareService.startMonitoring() }
        .onDisappear { hardwareService.stopMonitoring() }
    }

    private var estimatedHeight: Int {
        var h = 80 // header + padding
        h += max(1, hardwareService.videoDevices.count) * 52 + 50 // video section
        h += max(1, hardwareService.audioInputDevices.count) * 36 + 50 // audio in
        h += max(1, hardwareService.audioOutputDevices.count) * 36 + 50 // audio out
        if !hardwareService.captureCards.isEmpty {
            h += hardwareService.captureCards.count * 52 + 50
        }
        h += 150 // remote control section
        if captureService.isSessionRunning || captureService.defaultDevice != nil {
            h += 50
        }
        return h
    }
}

// MARK: - Summary Pills

private struct HardwareSummaryPills: View {
    let videoCount: Int
    let audioCount: Int
    let captureCount: Int

    var body: some View {
        HStack(spacing: 8) {
            pillView(icon: "video.fill", count: videoCount)
            pillView(icon: "waveform", count: audioCount)
            if captureCount > 0 {
                pillView(icon: "rectangle.connected.to.line.below", count: captureCount)
            }
        }
    }

    private func pillView(icon: String, count: Int) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundStyle(Color.accentColor)
            Text("\(count)")
                .font(.system(size: 9, weight: .bold, design: .rounded))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .clipShape(Capsule())
    }
}

// MARK: - Section Container

struct HardwareSection<Content: View>: View {
    let icon: String
    let title: String
    let count: Int
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.accentColor)
                Text(title)
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                Text("\(count)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(Capsule())
            }

            content
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(nsColor: .separatorColor).opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Video Device Row

private struct VideoDeviceRow: View {
    let device: VideoDeviceInfo
    let isDefault: Bool
    let onSetDefault: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(device.name)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                    if device.isExternal {
                        Text("EXT")
                            .font(.system(size: 7, weight: .bold))
                            .tracking(0.6)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                HStack(spacing: 8) {
                    Text(device.resolution)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    if !device.frameRate.isEmpty {
                        Text(device.frameRate)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if isDefault {
                Text("DEFAULT")
                    .font(.system(size: 7, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(Capsule())
            } else {
                Button("Set Default") { onSetDefault() }
                    .buttonStyle(.borderless)
                    .font(.system(size: 9))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isDefault ? Color.accentColor.opacity(0.06) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isDefault ? Color.accentColor.opacity(0.2) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Audio Device Row

private struct AudioDeviceRow: View {
    let device: AudioDeviceInfo
    let isInput: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)

            Text(device.name)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)

            if device.sampleRate > 0 {
                Text(formatSampleRate(device.sampleRate))
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }

            let channels = isInput ? device.inputChannelCount : device.outputChannelCount
            if channels > 0 {
                Text("\(channels)ch")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            AudioLevelBar(level: isInput ? device.inputLevel : device.outputLevel)
                .frame(width: 80)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
    }

    private func formatSampleRate(_ rate: Double) -> String {
        let khz = rate / 1000.0
        if khz >= 1 {
            return khz == khz.rounded() ? "\(Int(khz))kHz" : String(format: "%.1fkHz", khz)
        }
        return "\(Int(rate))Hz"
    }
}

// MARK: - Audio Level Bar

private struct AudioLevelBar: View {
    let level: Float

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(nsColor: .separatorColor).opacity(0.25))
                RoundedRectangle(cornerRadius: 2)
                    .fill(levelColor)
                    .frame(width: max(0, geo.size.width * CGFloat(level)))
                    .animation(.linear(duration: 0.08), value: level)
            }
        }
        .frame(height: 4)
    }

    private var levelColor: Color {
        if level > 0.9 { return .red }
        if level > 0.7 { return .orange }
        return .green
    }
}

// MARK: - Empty Row

struct EmptyDeviceRow: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
    }
}

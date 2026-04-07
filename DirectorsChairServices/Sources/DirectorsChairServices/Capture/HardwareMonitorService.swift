//
//  HardwareMonitorService.swift
//  DirectorsChairServices
//
//  Hardware dashboard service — discovers and monitors
//  video devices, audio devices, and capture cards.
//

import Foundation
import AVFoundation
import CoreAudio
import Combine

// MARK: - Device Models

public enum DeviceConnectionStatus: String {
    case connected
    case available
    case disconnected
}

public struct VideoDeviceInfo: Identifiable {
    public let id: String          // AVCaptureDevice.uniqueID
    public let name: String
    public let modelID: String
    public let manufacturer: String
    public let isExternal: Bool
    public var connectionStatus: DeviceConnectionStatus
    public let resolution: String
    public let frameRate: String
    public let avDevice: AVCaptureDevice
}

public struct AudioDeviceInfo: Identifiable, Equatable {
    public let id: AudioDeviceID
    public let name: String
    public let manufacturer: String
    public let sampleRate: Double
    public let inputChannelCount: Int
    public let outputChannelCount: Int
    public let isInput: Bool
    public let isOutput: Bool
    public var inputLevel: Float   // 0.0–1.0
    public var outputLevel: Float  // 0.0–1.0

    public static func == (lhs: AudioDeviceInfo, rhs: AudioDeviceInfo) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.inputLevel == rhs.inputLevel &&
        lhs.outputLevel == rhs.outputLevel
    }
}

// MARK: - HardwareMonitorService

@MainActor
public class HardwareMonitorService: ObservableObject {

    // MARK: - Published State

    @Published public var videoDevices: [VideoDeviceInfo] = []
    @Published public var audioInputDevices: [AudioDeviceInfo] = []
    @Published public var audioOutputDevices: [AudioDeviceInfo] = []
    @Published public var captureCards: [VideoDeviceInfo] = []
    @Published public var errorMessage: String?

    // MARK: - Private State

    private var levelTimer: Timer?
    private var deviceNotificationObservers: [NSObjectProtocol] = []
    private var audioPropertyListenerBlock: AudioObjectPropertyListenerBlock?
    private var isMonitoring = false

    // MARK: - Init

    public init() {}

    deinit {
        // Cleanup handled by stopMonitoring()
    }

    // MARK: - Lifecycle

    public func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        discoverAllDevices()
        setupVideoNotifications()
        setupAudioNotifications()
        startLevelPolling()
    }

    public func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false

        levelTimer?.invalidate()
        levelTimer = nil

        for observer in deviceNotificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        deviceNotificationObservers.removeAll()

        removeAudioPropertyListener()
    }

    public func refresh() {
        discoverAllDevices()
    }

    // MARK: - Device Discovery

    private func discoverAllDevices() {
        discoverVideoDevices()
        discoverAudioDevices()
    }

    private func discoverVideoDevices() {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.external, .builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        )

        var allVideo: [VideoDeviceInfo] = []
        var external: [VideoDeviceInfo] = []

        for device in discoverySession.devices {
            let isExternal = device.deviceType == .external
            let resolution = formatResolution(device)
            let frameRate = formatFrameRate(device)

            let info = VideoDeviceInfo(
                id: device.uniqueID,
                name: device.localizedName,
                modelID: device.modelID,
                manufacturer: device.manufacturer,
                isExternal: isExternal,
                connectionStatus: .connected,
                resolution: resolution,
                frameRate: frameRate,
                avDevice: device
            )

            allVideo.append(info)
            if isExternal {
                external.append(info)
            }
        }

        videoDevices = allVideo
        captureCards = external
    }

    private func discoverAudioDevices() {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0, nil,
            &dataSize
        )

        guard status == noErr else {
            errorMessage = "Failed to query audio devices"
            return
        }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0, nil,
            &dataSize,
            &deviceIDs
        )

        guard status == noErr else {
            errorMessage = "Failed to get audio device list"
            return
        }

        var inputs: [AudioDeviceInfo] = []
        var outputs: [AudioDeviceInfo] = []

        for deviceID in deviceIDs {
            let name = getAudioDeviceString(deviceID, selector: kAudioObjectPropertyName) ?? "Unknown"
            let manufacturer = getAudioDeviceString(deviceID, selector: kAudioObjectPropertyManufacturer) ?? ""
            let sampleRate = getAudioDeviceSampleRate(deviceID)
            let inputChannels = getAudioDeviceChannelCount(deviceID, scope: kAudioDevicePropertyScopeInput)
            let outputChannels = getAudioDeviceChannelCount(deviceID, scope: kAudioDevicePropertyScopeOutput)

            let isInput = inputChannels > 0
            let isOutput = outputChannels > 0

            // Skip devices with no channels (virtual/aggregate system devices)
            guard isInput || isOutput else { continue }

            let info = AudioDeviceInfo(
                id: deviceID,
                name: name,
                manufacturer: manufacturer,
                sampleRate: sampleRate,
                inputChannelCount: inputChannels,
                outputChannelCount: outputChannels,
                isInput: isInput,
                isOutput: isOutput,
                inputLevel: 0,
                outputLevel: 0
            )

            if isInput { inputs.append(info) }
            if isOutput { outputs.append(info) }
        }

        audioInputDevices = inputs
        audioOutputDevices = outputs
    }

    // MARK: - Audio Device Helpers

    private func getAudioDeviceString(_ deviceID: AudioDeviceID, selector: AudioObjectPropertySelector) -> String? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        let sizeStatus = AudioObjectGetPropertyDataSize(
            deviceID,
            &propertyAddress,
            0, nil,
            &dataSize
        )
        guard sizeStatus == noErr, dataSize > 0 else { return nil }

        var nameRef: Unmanaged<CFString>?
        var refSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)

        let status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0, nil,
            &refSize,
            &nameRef
        )

        guard status == noErr, let cfString = nameRef?.takeRetainedValue() else { return nil }
        return cfString as String
    }

    private func getAudioDeviceSampleRate(_ deviceID: AudioDeviceID) -> Double {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var sampleRate: Float64 = 0
        var dataSize = UInt32(MemoryLayout<Float64>.size)

        let status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0, nil,
            &dataSize,
            &sampleRate
        )

        return status == noErr ? sampleRate : 0
    }

    private func getAudioDeviceChannelCount(_ deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> Int {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(
            deviceID,
            &propertyAddress,
            0, nil,
            &dataSize
        )

        guard status == noErr, dataSize > 0 else { return 0 }

        let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
        defer { bufferListPointer.deallocate() }

        let getStatus = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0, nil,
            &dataSize,
            bufferListPointer
        )

        guard getStatus == noErr else { return 0 }

        let bufferList = UnsafeMutableAudioBufferListPointer(bufferListPointer)
        var totalChannels = 0
        for buffer in bufferList {
            totalChannels += Int(buffer.mNumberChannels)
        }
        return totalChannels
    }

    private func getAudioDeviceVolumeLevel(_ deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> Float {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )

        // Check if volume property exists
        guard AudioObjectHasProperty(deviceID, &propertyAddress) else { return 0 }

        var volume: Float32 = 0
        var dataSize = UInt32(MemoryLayout<Float32>.size)

        let status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0, nil,
            &dataSize,
            &volume
        )

        return status == noErr ? volume : 0
    }

    // MARK: - Video Device Helpers

    private func formatResolution(_ device: AVCaptureDevice) -> String {
        guard let format = device.activeFormat.formatDescription as CMFormatDescription? else {
            return "Unknown"
        }
        let dimensions = CMVideoFormatDescriptionGetDimensions(format)
        return "\(dimensions.width)×\(dimensions.height)"
    }

    private func formatFrameRate(_ device: AVCaptureDevice) -> String {
        let ranges = device.activeFormat.videoSupportedFrameRateRanges
        if let range = ranges.first {
            let fps = Int(range.maxFrameRate)
            return "\(fps)fps"
        }
        return ""
    }

    // MARK: - Notifications

    private func setupVideoNotifications() {
        let connected = NotificationCenter.default.addObserver(
            forName: .AVCaptureDeviceWasConnected,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.discoverAllDevices()
            }
        }

        let disconnected = NotificationCenter.default.addObserver(
            forName: .AVCaptureDeviceWasDisconnected,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.discoverAllDevices()
            }
        }

        deviceNotificationObservers.append(contentsOf: [connected, disconnected])
    }

    private func setupAudioNotifications() {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let listenerBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.discoverAllDevices()
            }
        }

        audioPropertyListenerBlock = listenerBlock

        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            DispatchQueue.main,
            listenerBlock
        )
    }

    private func removeAudioPropertyListener() {
        guard let block = audioPropertyListenerBlock else { return }

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            DispatchQueue.main,
            block
        )

        audioPropertyListenerBlock = nil
    }

    // MARK: - Level Polling

    private func startLevelPolling() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pollAudioLevels()
            }
        }
    }

    private func pollAudioLevels() {
        for i in audioInputDevices.indices {
            let level = getAudioDeviceVolumeLevel(audioInputDevices[i].id, scope: kAudioDevicePropertyScopeInput)
            if audioInputDevices[i].inputLevel != level {
                audioInputDevices[i].inputLevel = level
            }
        }

        for i in audioOutputDevices.indices {
            let level = getAudioDeviceVolumeLevel(audioOutputDevices[i].id, scope: kAudioDevicePropertyScopeOutput)
            if audioOutputDevices[i].outputLevel != level {
                audioOutputDevices[i].outputLevel = level
            }
        }
    }
}

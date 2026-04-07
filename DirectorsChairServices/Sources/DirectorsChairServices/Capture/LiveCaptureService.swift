// DirectorsChairServices/Sources/DirectorsChairServices/Capture/LiveCaptureService.swift
//
// Live video capture service for HDMI capture cards and cameras
//
// Architecture:
// - `defaultDevice` = the globally chosen device (set from toolbar, persists across shots)
// - `selectedDevice` = the currently connected/active device (session running)
// - Toolbar sets `defaultDevice` only (no session start)
// - TakesSectionView auto-connects using `defaultDevice` when it appears
// - CaptureSessionWorker owns all AVFoundation objects on a serial background queue
// - When a LUT is active, frames are processed via AVCaptureVideoDataOutput → LUTProcessor → CIImage

import Foundation
import AVFoundation
import CoreImage
import CoreMedia
import Combine

// MARK: - Capture Session Worker (non-isolated, all work on serial queue)

private class CaptureSessionWorker: NSObject, AVCaptureFileOutputRecordingDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    let movieOutput = AVCaptureMovieFileOutput()
    let videoDataOutput = AVCaptureVideoDataOutput()
    let queue = DispatchQueue(label: "com.directorschair.capture")
    private let videoDataQueue = DispatchQueue(label: "com.directorschair.capture.videodata", qos: .userInteractive)

    var onRecordingFinished: ((URL?, Error?) -> Void)?
    var onVideoFrame: ((CMSampleBuffer) -> Void)?
    var isVideoDataOutputEnabled: Bool = false

    func configureAndStart(_ device: AVCaptureDevice, enableVideoData: Bool, completion: @escaping (Bool, String?, AVCaptureVideoPreviewLayer?) -> Void) {
        queue.async { [self] in
            session.beginConfiguration()

            for input in session.inputs {
                session.removeInput(input)
            }

            do {
                let videoInput = try AVCaptureDeviceInput(device: device)
                if session.canAddInput(videoInput) {
                    session.addInput(videoInput)
                }
            } catch {
                session.commitConfiguration()
                DispatchQueue.main.async { completion(false, error.localizedDescription, nil) }
                return
            }

            if let audioDevice = AVCaptureDevice.default(for: .audio) {
                if let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
                   session.canAddInput(audioInput) {
                    session.addInput(audioInput)
                }
            }

            if !session.outputs.contains(movieOutput) {
                if session.canAddOutput(movieOutput) {
                    session.addOutput(movieOutput)
                }
            }

            // Configure video data output for LUT processing
            configureVideoDataOutput(enabled: enableVideoData)

            if session.canSetSessionPreset(.high) {
                session.sessionPreset = .high
            }

            session.commitConfiguration()

            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspect

            if !session.isRunning {
                session.startRunning()
            }

            DispatchQueue.main.async { completion(true, nil, layer) }
        }
    }

    func setVideoDataOutputEnabled(_ enabled: Bool) {
        queue.async { [self] in
            session.beginConfiguration()
            configureVideoDataOutput(enabled: enabled)
            session.commitConfiguration()
        }
    }

    private func configureVideoDataOutput(enabled: Bool) {
        isVideoDataOutputEnabled = enabled
        if enabled {
            if !session.outputs.contains(videoDataOutput) {
                videoDataOutput.alwaysDiscardsLateVideoFrames = true
                videoDataOutput.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                ]
                if session.canAddOutput(videoDataOutput) {
                    session.addOutput(videoDataOutput)
                }
                videoDataOutput.setSampleBufferDelegate(self, queue: videoDataQueue)
            }
        } else {
            if session.outputs.contains(videoDataOutput) {
                session.removeOutput(videoDataOutput)
            }
        }
    }

    func stopRunning(completion: @escaping () -> Void) {
        queue.async { [self] in
            if session.isRunning { session.stopRunning() }
            DispatchQueue.main.async { completion() }
        }
    }

    func beginRecording(to url: URL) {
        queue.async { [self] in
            movieOutput.startRecording(to: url, recordingDelegate: self)
        }
    }

    func endRecording() {
        queue.async { [self] in
            if movieOutput.isRecording { movieOutput.stopRecording() }
        }
    }

    func tearDownSession(completion: @escaping () -> Void) {
        queue.async { [self] in
            if movieOutput.isRecording { movieOutput.stopRecording() }
            if session.isRunning { session.stopRunning() }
            for input in session.inputs { session.removeInput(input) }
            for output in session.outputs { session.removeOutput(output) }
            DispatchQueue.main.async { completion() }
        }
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        let handler = onRecordingFinished
        DispatchQueue.main.async { handler?(outputFileURL, error) }
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        onVideoFrame?(sampleBuffer)
    }
}

// MARK: - Live Capture Service

@MainActor
public class LiveCaptureService: NSObject, ObservableObject {

    // MARK: - Published State

    /// The globally chosen default device (set from toolbar). Does NOT start a session.
    @Published public var defaultDevice: AVCaptureDevice?

    /// The currently connected and active device (session running).
    @Published public var selectedDevice: AVCaptureDevice?

    @Published public var isSessionRunning: Bool = false
    @Published public var isRecording: Bool = false
    @Published public var availableDevices: [AVCaptureDevice] = []
    @Published public var errorMessage: String?
    @Published public var recordingDuration: TimeInterval = 0
    @Published public var previewLayer: AVCaptureVideoPreviewLayer?

    /// The currently selected LUT preset for live preview color correction.
    @Published public var selectedLUT: LUTPreset = .none

    /// The latest LUT-processed frame (nil when LUT is .none — use previewLayer instead).
    @Published public var processedFrame: CIImage?

    // MARK: - LUT Processing

    public let lutProcessor = LUTProcessor()

    // MARK: - Private

    private let worker = CaptureSessionWorker()
    private var durationTimer: Timer?
    private var recordingStartTime: Date?
    private var recordingCompletionHandler: ((URL?, Error?) -> Void)?

    // MARK: - Init

    public override init() {
        super.init()
        discoverDevices()
        worker.onRecordingFinished = { [weak self] url, error in
            self?.isRecording = false
            self?.durationTimer?.invalidate()
            self?.durationTimer = nil
            self?.recordingCompletionHandler?(url, error)
            self?.recordingCompletionHandler = nil
        }
        worker.onVideoFrame = { [weak self] sampleBuffer in
            guard let self else { return }
            let processed = self.lutProcessor.processFrame(sampleBuffer)
            DispatchQueue.main.async {
                self.processedFrame = processed
            }
        }
    }

    // MARK: - Device Discovery

    public func discoverDevices() {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.external, .builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        )
        availableDevices = discoverySession.devices
    }

    // MARK: - Default Device (toolbar sets this — no session start)

    /// Sets the global default device without starting a capture session.
    /// The TakesSectionView will auto-connect when it appears.
    public func setDefaultDevice(_ device: AVCaptureDevice?) {
        defaultDevice = device
    }

    // MARK: - LUT Selection

    public func setLUT(_ preset: LUTPreset) {
        selectedLUT = preset
        lutProcessor.setPreset(preset)

        if preset == .none {
            // Disable video data output for zero-overhead preview
            processedFrame = nil
            worker.setVideoDataOutputEnabled(false)
        } else {
            // Enable video data output for frame processing
            worker.setVideoDataOutputEnabled(true)
        }
    }

    // MARK: - Connect & Start (called by TakesSectionView when it needs live preview)

    /// Connects to the given device (or the default device), configures session, and starts preview.
    public func connectAndStart(device: AVCaptureDevice? = nil, completion: (() -> Void)? = nil) {
        let targetDevice = device ?? defaultDevice
        guard let targetDevice else { return }

        // Already connected to this device
        if selectedDevice?.uniqueID == targetDevice.uniqueID && isSessionRunning {
            completion?()
            return
        }

        let needsVideoData = selectedLUT != .none
        worker.configureAndStart(targetDevice, enableVideoData: needsVideoData) { [weak self] success, errorMsg, layer in
            guard let self else { return }
            if success {
                self.selectedDevice = targetDevice
                self.errorMessage = nil
                self.previewLayer = layer
                self.isSessionRunning = true
                completion?()
            } else {
                self.errorMessage = "Failed to configure: \(errorMsg ?? "Unknown")"
            }
        }
    }

    // MARK: - Disconnect (stops session, releases hardware, keeps defaultDevice)

    /// Stops the active session and releases the camera. Does NOT clear `defaultDevice`.
    public func disconnect() {
        durationTimer?.invalidate()
        durationTimer = nil
        recordingCompletionHandler = nil

        previewLayer?.session = nil
        selectedDevice = nil
        previewLayer = nil
        processedFrame = nil
        isRecording = false
        isSessionRunning = false
        recordingDuration = 0
        recordingStartTime = nil

        worker.tearDownSession { }
    }

    /// Full teardown: disconnect AND clear the default device.
    public func tearDown() {
        defaultDevice = nil
        disconnect()
    }

    // MARK: - Recording

    public func startRecording(to outputURL: URL, completion: @escaping (URL?, Error?) -> Void) {
        guard !isRecording else { return }
        recordingCompletionHandler = completion

        let parentDir = outputURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: outputURL)

        worker.beginRecording(to: outputURL)

        isRecording = true
        recordingStartTime = Date()
        recordingDuration = 0

        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let start = self.recordingStartTime else { return }
                self.recordingDuration = Date().timeIntervalSince(start)
            }
        }
    }

    public func stopRecording() {
        guard isRecording else { return }
        worker.endRecording()
    }

    // MARK: - Helpers

    public var formattedDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        let tenths = Int((recordingDuration.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }
}

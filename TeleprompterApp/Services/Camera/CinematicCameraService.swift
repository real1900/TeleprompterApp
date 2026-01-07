import Foundation
import AVFoundation
import CoreMedia
import Photos
import Combine
import SwiftUI

/// Enhanced camera service with professional cinematic controls
@MainActor
class CinematicCameraService: NSObject, ObservableObject {
    // MARK: - Session State
    
    @Published private(set) var isSessionRunning = false
    @Published private(set) var isRecording = false
    @Published private(set) var recordingDuration: TimeInterval = 0
    @Published private(set) var error: CameraError?
    
    // MARK: - Permissions
    
    @Published private(set) var cameraPermission: CameraPermission = .notDetermined
    @Published private(set) var microphonePermission: CameraPermission = .notDetermined
    
    // MARK: - Focus Control
    
    @Published var focusMode: FocusMode = .continuousAutoFocus {
        didSet { applyFocusMode() }
    }
    @Published var focusPosition: Float = 0.5 {
        didSet { if focusMode == .manual { applyManualFocus() } }
    }
    @Published private(set) var isAdjustingFocus = false
    
    // MARK: - Exposure Control
    
    @Published var exposureMode: ExposureMode = .continuousAutoExposure {
        didSet { applyExposureMode() }
    }
    @Published var exposureCompensation: Float = 0 {
        didSet { applyExposureCompensation() }
    }
    @Published var iso: Float = 100 {
        didSet { if exposureMode == .manual { applyManualExposure() } }
    }
    @Published var shutterSpeed: Double = 1.0/60.0 {
        didSet { if exposureMode == .manual { applyManualExposure() } }
    }
    
    // MARK: - White Balance
    
    @Published var whiteBalanceMode: WhiteBalanceMode = .auto {
        didSet { applyWhiteBalance() }
    }
    @Published var colorTemperature: Float = 5500 {
        didSet { if whiteBalanceMode == .locked { applyManualWhiteBalance() } }
    }
    @Published var tint: Float = 0 {
        didSet { if whiteBalanceMode == .locked { applyManualWhiteBalance() } }
    }
    
    // MARK: - Depth (Portrait Mode)
    
    @Published var depthEnabled = false
    @Published var simulatedAperture: Float = 2.8
    @Published private(set) var isDepthSupported = false
    
    // MARK: - Filters
    
    @Published var activeFilter: CameraFilter = .none
    
    // MARK: - Video Quality
    
    @Published var videoQuality: VideoQuality = .medium {
        didSet { applyVideoQuality() }
    }
    
    // MARK: - Device Capabilities
    
    @Published private(set) var minISO: Float = 50
    @Published private(set) var maxISO: Float = 3200
    
    // MARK: - AVFoundation Components
    
    let captureSession = AVCaptureSession()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var audioDeviceInput: AVCaptureDeviceInput?
    private let movieFileOutput = AVCaptureMovieFileOutput()
    
    // MARK: - Queues
    
    private let sessionQueue = DispatchQueue(label: "com.teleprompter.camera.session")
    
    // MARK: - Recording State
    
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var currentVideoURL: URL?
    private var recordingContinuation: CheckedContinuation<URL, Error>?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
    }
    
    // MARK: - Permissions
    
    func checkPermissions() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined: cameraPermission = .notDetermined
        case .authorized: cameraPermission = .authorized
        case .denied: cameraPermission = .denied
        case .restricted: cameraPermission = .restricted
        @unknown default: cameraPermission = .notDetermined
        }
        
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined: microphonePermission = .notDetermined
        case .authorized: microphonePermission = .authorized
        case .denied: microphonePermission = .denied
        case .restricted: microphonePermission = .restricted
        @unknown default: microphonePermission = .notDetermined
        }
    }
    
    func requestCameraPermission() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        cameraPermission = granted ? .authorized : .denied
        return granted
    }
    
    func requestMicrophonePermission() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        microphonePermission = granted ? .authorized : .denied
        return granted
    }
    
    // MARK: - Session Configuration
    
    func configureSession() async throws {
        if cameraPermission == .notDetermined {
            _ = await requestCameraPermission()
        }
        if microphonePermission == .notDetermined {
            _ = await requestMicrophonePermission()
        }
        
        guard cameraPermission == .authorized else {
            throw CameraError.permissionDenied
        }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: CameraError.setupFailed(NSError(domain: "CinematicCamera", code: -1)))
                    return
                }
                
                do {
                    try self.setupSession()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func setupSession() throws {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        
        if captureSession.canSetSessionPreset(videoQuality.sessionPreset) {
            captureSession.sessionPreset = videoQuality.sessionPreset
        } else {
            captureSession.sessionPreset = .high
        }
        
        // Add video input (front camera)
        guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw CameraError.cameraUnavailable
        }
        
        let videoInput = try AVCaptureDeviceInput(device: frontCamera)
        guard captureSession.canAddInput(videoInput) else {
            throw CameraError.setupFailed(NSError(domain: "CinematicCamera", code: -2))
        }
        captureSession.addInput(videoInput)
        videoDeviceInput = videoInput
        
        // Read device capabilities
        Task { @MainActor in
            self.minISO = frontCamera.activeFormat.minISO
            self.maxISO = frontCamera.activeFormat.maxISO
            self.isDepthSupported = !frontCamera.activeFormat.supportedDepthDataFormats.isEmpty
        }
        
        // Add audio input
        if let microphone = AVCaptureDevice.default(for: .audio) {
            do {
                let audioInput = try AVCaptureDeviceInput(device: microphone)
                if captureSession.canAddInput(audioInput) {
                    captureSession.addInput(audioInput)
                    audioDeviceInput = audioInput
                }
            } catch {
                print("Audio input error: \(error)")
            }
        }
        
        // Add movie file output
        guard captureSession.canAddOutput(movieFileOutput) else {
            throw CameraError.setupFailed(NSError(domain: "CinematicCamera", code: -3))
        }
        captureSession.addOutput(movieFileOutput)
        
        if let connection = movieFileOutput.connection(with: .video) {
            if connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = .auto
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = true
            }
        }
    }
    
    // MARK: - Session Control
    
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self, !self.captureSession.isRunning else { return }
            self.captureSession.startRunning()
            
            Task { @MainActor in
                self.isSessionRunning = true
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
            
            Task { @MainActor in
                self.isSessionRunning = false
            }
        }
    }
    
    // MARK: - Focus Control
    
    func setFocus(at point: CGPoint) {
        guard let device = videoDeviceInput?.device,
              device.isFocusPointOfInterestSupported else { return }
        
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = point
                    device.exposureMode = .autoExpose
                }
                device.unlockForConfiguration()
                
                Task { @MainActor in
                    self.isAdjustingFocus = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    Task { @MainActor in
                        self.isAdjustingFocus = false
                    }
                }
            } catch {
                print("Focus error: \(error)")
            }
        }
    }
    
    private func applyFocusMode() {
        guard let device = videoDeviceInput?.device else { return }
        
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                
                switch self.focusMode {
                case .locked:
                    device.focusMode = .locked
                case .autoFocus:
                    if device.isFocusModeSupported(.autoFocus) {
                        device.focusMode = .autoFocus
                    }
                case .continuousAutoFocus:
                    if device.isFocusModeSupported(.continuousAutoFocus) {
                        device.focusMode = .continuousAutoFocus
                    }
                case .manual:
                    device.focusMode = .locked
                    device.setFocusModeLocked(lensPosition: self.focusPosition)
                }
                
                device.unlockForConfiguration()
            } catch {
                print("Focus mode error: \(error)")
            }
        }
    }
    
    private func applyManualFocus() {
        guard let device = videoDeviceInput?.device else { return }
        
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                device.setFocusModeLocked(lensPosition: self.focusPosition)
                device.unlockForConfiguration()
            } catch {
                print("Manual focus error: \(error)")
            }
        }
    }
    
    // MARK: - Exposure Control
    
    private func applyExposureMode() {
        guard let device = videoDeviceInput?.device else { return }
        
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                
                switch self.exposureMode {
                case .locked:
                    device.exposureMode = .locked
                case .autoExpose:
                    if device.isExposureModeSupported(.autoExpose) {
                        device.exposureMode = .autoExpose
                    }
                case .continuousAutoExposure:
                    if device.isExposureModeSupported(.continuousAutoExposure) {
                        device.exposureMode = .continuousAutoExposure
                    }
                case .manual:
                    if device.isExposureModeSupported(.custom) {
                        let duration = CMTime(seconds: self.shutterSpeed, preferredTimescale: 1000000)
                        device.setExposureModeCustom(duration: duration, iso: self.iso)
                    }
                }
                
                device.unlockForConfiguration()
            } catch {
                print("Exposure mode error: \(error)")
            }
        }
    }
    
    private func applyExposureCompensation() {
        guard let device = videoDeviceInput?.device else { return }
        
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                device.setExposureTargetBias(self.exposureCompensation)
                device.unlockForConfiguration()
            } catch {
                print("Exposure compensation error: \(error)")
            }
        }
    }
    
    private func applyManualExposure() {
        guard let device = videoDeviceInput?.device,
              device.isExposureModeSupported(.custom) else { return }
        
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                let duration = CMTime(seconds: self.shutterSpeed, preferredTimescale: 1000000)
                let clampedISO = min(max(self.iso, device.activeFormat.minISO), device.activeFormat.maxISO)
                device.setExposureModeCustom(duration: duration, iso: clampedISO)
                device.unlockForConfiguration()
            } catch {
                print("Manual exposure error: \(error)")
            }
        }
    }
    
    // MARK: - White Balance Control
    
    private func applyWhiteBalance() {
        guard let device = videoDeviceInput?.device else { return }
        
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                
                switch self.whiteBalanceMode {
                case .auto:
                    if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                        device.whiteBalanceMode = .continuousAutoWhiteBalance
                    }
                case .locked:
                    device.whiteBalanceMode = .locked
                default:
                    let tempTint = self.whiteBalanceMode.temperatureAndTint
                    let gains = device.deviceWhiteBalanceGains(for: AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
                        temperature: tempTint.temperature,
                        tint: tempTint.tint
                    ))
                    let normalizedGains = self.normalizeGains(gains, for: device)
                    device.setWhiteBalanceModeLocked(with: normalizedGains)
                }
                
                device.unlockForConfiguration()
            } catch {
                print("White balance error: \(error)")
            }
        }
    }
    
    private func applyManualWhiteBalance() {
        guard let device = videoDeviceInput?.device else { return }
        
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                let gains = device.deviceWhiteBalanceGains(for: AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
                    temperature: self.colorTemperature,
                    tint: self.tint
                ))
                let normalizedGains = self.normalizeGains(gains, for: device)
                device.setWhiteBalanceModeLocked(with: normalizedGains)
                device.unlockForConfiguration()
            } catch {
                print("Manual white balance error: \(error)")
            }
        }
    }
    
    private func normalizeGains(_ gains: AVCaptureDevice.WhiteBalanceGains, for device: AVCaptureDevice) -> AVCaptureDevice.WhiteBalanceGains {
        var g = gains
        let maxGain = device.maxWhiteBalanceGain
        g.redGain = min(max(1.0, g.redGain), maxGain)
        g.greenGain = min(max(1.0, g.greenGain), maxGain)
        g.blueGain = min(max(1.0, g.blueGain), maxGain)
        return g
    }
    
    // MARK: - Video Quality
    
    private func applyVideoQuality() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            
            self.captureSession.beginConfiguration()
            if self.captureSession.canSetSessionPreset(self.videoQuality.sessionPreset) {
                self.captureSession.sessionPreset = self.videoQuality.sessionPreset
            }
            self.captureSession.commitConfiguration()
        }
    }
    
    // MARK: - Recording
    
    func startRecording() throws -> URL {
        guard !isRecording else {
            throw CameraError.recordingFailed(NSError(domain: "CinematicCamera", code: -4))
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "teleprompter_\(UUID().uuidString).mov"
        let outputURL = tempDir.appendingPathComponent(fileName)
        
        try? FileManager.default.removeItem(at: outputURL)
        currentVideoURL = outputURL
        
        sessionQueue.async { [weak self] in
            self?.movieFileOutput.startRecording(to: outputURL, recordingDelegate: self!)
        }
        
        recordingStartTime = Date()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let startTime = self.recordingStartTime else { return }
            Task { @MainActor in
                self.recordingDuration = Date().timeIntervalSince(startTime)
            }
        }
        
        isRecording = true
        return outputURL
    }
    
    func stopRecording() async throws -> URL {
        guard isRecording else {
            throw CameraError.recordingFailed(NSError(domain: "CinematicCamera", code: -5))
        }
        
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        return try await withCheckedThrowingContinuation { continuation in
            recordingContinuation = continuation
            sessionQueue.async { [weak self] in
                self?.movieFileOutput.stopRecording()
            }
        }
    }
    
    func exportToPhotos(videoURL: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw CameraError.exportFailed(NSError(domain: "CinematicCamera", code: -6))
        }
        
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
        }
    }
    
    func cleanup() {
        stopSession()
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        if let url = currentVideoURL {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension CinematicCameraService: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {}
    
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        Task { @MainActor in
            self.isRecording = false
            self.recordingDuration = 0
            self.recordingStartTime = nil
            
            if let error {
                self.recordingContinuation?.resume(throwing: CameraError.recordingFailed(error))
            } else {
                self.recordingContinuation?.resume(returning: outputFileURL)
            }
            self.recordingContinuation = nil
        }
    }
}

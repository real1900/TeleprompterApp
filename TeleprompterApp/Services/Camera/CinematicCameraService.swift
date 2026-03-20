import Foundation
@preconcurrency import AVFoundation
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
    
    @Published var depthEnabled = false {
        didSet {
            if depthEnabled {
                greenScreenEnabled = false // Mutually exclusive
                depthProcessor.effectMode = .blur
                depthProcessor.isEnabled = true
            } else if !greenScreenEnabled {
                // Only disable if green screen is also off
                depthProcessor.isEnabled = false
            }
        }
    }
    
    @Published var greenScreenEnabled = false {
        didSet {
            if greenScreenEnabled {
                depthEnabled = false // Mutually exclusive
                depthProcessor.effectMode = .greenScreen
                depthProcessor.isEnabled = true
            } else if !depthEnabled {
                // Only disable if blur is also off
                depthProcessor.isEnabled = false
            }
        }
    }
    
    @Published var simulatedAperture: Float = 13.0 {
        didSet { 
            depthProcessor.aperture = simulatedAperture
            applyAperture() 
        }
    }
    @Published private(set) var isDepthSupported = false
    
    // Aperture range: f/1.4 (max blur) to f/16 (no blur)
    static let minAperture: Float = 1.4
    static let maxAperture: Float = 16.0
    
    // MARK: - Center Stage (Face Tracking)
    
    @Published var centerStageEnabled = true {
        didSet { applyCenterStage() }
    }
    @Published private(set) var isCenterStageSupported = false
    
    // MARK: - Filters
    
    @Published var activeFilter: CameraFilter = .none {
        didSet { renderStateFilter = activeFilter }
    }
    
    // MARK: - Thread-Safe Render State (Double Buffered for Background Reader)
    nonisolated(unsafe) var renderStateFilter: CameraFilter = .none
    nonisolated(unsafe) var renderStateIsWriting: Bool = false
    nonisolated(unsafe) var renderStateStartTime: CMTime? = nil
    
    // MARK: - Video Quality
    
    @Published var videoQuality: VideoQuality = .medium {
        didSet { applyVideoQuality() }
    }
    
    // MARK: - Device Capabilities
    
    @Published private(set) var minISO: Float = 50
    @Published private(set) var maxISO: Float = 3200
    
    // MARK: - AVFoundation Components
    
    nonisolated(unsafe) lazy var captureSession = AVCaptureSession()
    nonisolated(unsafe) private var videoDeviceInput: AVCaptureDeviceInput?
    nonisolated(unsafe) private var audioDeviceInput: AVCaptureDeviceInput?
    // DELETED: `movieFileOutput` totally conflicts with VideoDataOutput at an OS-level, producing 10+ second deadlocks on startRunning()
    
    nonisolated(unsafe) private var videoDataOutput: AVCaptureVideoDataOutput?
    nonisolated(unsafe) private var audioDataOutput: AVCaptureAudioDataOutput?
    
    // Depth processing (Thread-safe background processor)
    nonisolated(unsafe) lazy var depthProcessor = DepthBlurProcessor()
    
    // For processed frame preview
    @Published var processedPreviewImage: CIImage?
    
    // Asset writer for recording processed frames
    nonisolated(unsafe) private var assetWriter: AVAssetWriter?
    nonisolated(unsafe) private var assetWriterVideoInput: AVAssetWriterInput?
    nonisolated(unsafe) private var assetWriterAudioInput: AVAssetWriterInput?
    nonisolated(unsafe) private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    @Published private var isWritingProcessedVideo = false {
        didSet { renderStateIsWriting = isWritingProcessedVideo }
    }
    private var assetWriterStartTime: CMTime? {
        didSet { renderStateStartTime = assetWriterStartTime }
    }
    private var framesWritten: Int = 0
    
    // MARK: - Queues
    
    private let sessionQueue = DispatchQueue(label: "com.teleprompter.camera.session")
    private let videoProcessingQueue = DispatchQueue(label: "com.teleprompter.camera.videoProcessing")
    private let audioProcessingQueue = DispatchQueue(label: "com.teleprompter.camera.audioProcessing") // Added Audio Queue
    private let audioSetupQueue = DispatchQueue(label: "com.teleprompter.camera.audioSetup") // Dedicated queue for audio init
    
    // MARK: - Recording State
    
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var currentVideoURL: URL?
    private var recordingContinuation: CheckedContinuation<URL, Error>?
    
    // MARK: - Dynamic Dimensions
    
    /// Tracks the actual size of incoming video buffers (Handling orientation & quality).
    /// Written from the nonisolated captureOutput callback, read from setupAssetWriter.
    nonisolated(unsafe) private var _capturedFrameSize: CGSize?
    
    // MARK: - Initialization
    
    /// Compact wall-clock timestamp for timing logs (HH:mm:ss.SSS)
    nonisolated private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()
    
    nonisolated private func ts() -> String {
        Self.timestampFormatter.string(from: Date())
    }
    
    override init() {
        super.init()
    }
    
    // MARK: - Permissions
    
    func checkPermissions() async {
        #if targetEnvironment(simulator)
        cameraPermission = .authorized
        microphonePermission = .authorized
        #else
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
        #endif
    }
    
    func requestCameraPermission() async -> Bool {
        #if targetEnvironment(simulator)
        cameraPermission = .authorized
        return true
        #else
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        cameraPermission = granted ? .authorized : .denied
        return granted
        #endif
    }
    
    func requestMicrophonePermission() async -> Bool {
        #if targetEnvironment(simulator)
        microphonePermission = .authorized
        return true
        #else
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        microphonePermission = granted ? .authorized : .denied
        return granted
        #endif
    }
    
    // MARK: - Session Configuration
    
    /// Whether the capture session has been fully configured (inputs/outputs wired)
    @Published private(set) var isConfigured = false
    
    func configureSession() async throws {
        guard !isConfigured else { return }
        
        // CRITICAL BUG FIX: We MUST evaluate the current TCC status from the OS
        // *before* blindly calling requestAccess. On iOS Simulators, calling requestAccess 
        // when permissions are already authorized triggers a catastrophic 25s deadlock in `tccd`.
        await checkPermissions()
        
        if cameraPermission == .notDetermined {
            _ = await requestCameraPermission()
        }
        if microphonePermission == .notDetermined {
            _ = await requestMicrophonePermission()
        }
        
        guard cameraPermission == .authorized else {
            throw CameraError.permissionDenied
        }
        
        // Fallback path: if warmUp didn't run, do the same two-phase setup
        let quality = videoQuality
        warmUp(quality: quality)
    }
    
    /// Whether audio input has been added to the capture session (deferred until recording)
    @Published private(set) var isAudioReady = false
    
    /// Two-phase session startup for fast camera preview.
    ///
    /// Phase 1 (sessionQueue): Video-only config + startRunning (~3s total).
    ///   - startRunning with video-only takes ~0.7s (no audio route negotiation).
    ///   - Preview appears as soon as startRunning returns.
    ///
    /// Phase 2 (audioSetupQueue → sessionQueue): Deferred audio addition.
    ///   - Expensive audio prep (AVAudioSession, mic discovery) runs on audioSetupQueue.
    ///   - Then stop → addAudio → restart runs on sessionQueue (~7s total).
    ///   - This does NOT block tab switches because:
    ///     a) RecordingView is persistent (never destroyed on tab switch)
    ///     b) CameraPreviewView.dismantleUIView is a no-op
    ///     c) The work runs entirely on background queues
    func warmUp(quality: VideoQuality = .medium) {
        sessionQueue.async { [self] in
            guard captureSession.inputs.isEmpty else { return }
            let t0 = CFAbsoluteTimeGetCurrent()
            
            captureSession.beginConfiguration()
            
            if captureSession.canSetSessionPreset(quality.sessionPreset) {
                captureSession.sessionPreset = quality.sessionPreset
            } else {
                captureSession.sessionPreset = .high
            }
            
            // --- Video input: wide-angle camera (fast) ---
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
                captureSession.commitConfiguration()
                print("⚠️ No front camera available")
                return
            }
            
            do {
                let videoInput = try AVCaptureDeviceInput(device: camera)
                guard captureSession.canAddInput(videoInput) else {
                    captureSession.commitConfiguration()
                    return
                }
                captureSession.addInput(videoInput)
                self.videoDeviceInput = videoInput
            } catch {
                captureSession.commitConfiguration()
                print("⚠️ Video input failed: \(error)")
                return
            }
            
            // --- Video data output ---
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: videoProcessingQueue)
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            videoOutput.alwaysDiscardsLateVideoFrames = true
            
            if captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
                self.videoDataOutput = videoOutput
                
                if let connection = videoOutput.connection(with: .video) {
                    if connection.isVideoMirroringSupported {
                        connection.isVideoMirrored = true
                    }
                    self.updateConnectionOrientation(connection, to: .portrait)
                }
            }
            
            captureSession.commitConfiguration()
            print("⏱️ [\(self.ts())] [PHASE1] config+commit took \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - t0))s")
            
            // Start video-only session — preview appears after this returns
            let t1 = CFAbsoluteTimeGetCurrent()
            captureSession.startRunning()
            print("⏱️ [\(self.ts())] [PHASE1] startRunning took \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - t1))s")
            print("⏱️ [\(self.ts())] [PHASE1] TOTAL video-only: \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - t0))s")
            
            // Publish state — preview is live
            Task { @MainActor in
                self.minISO = camera.activeFormat.minISO
                self.maxISO = camera.activeFormat.maxISO
                self.isDepthSupported = false
                if #available(iOS 14.5, *) {
                    self.isCenterStageSupported = true
                }
                self.isConfigured = true
                self.isSessionRunning = true
            }
            
            // Audio is NOT added here. Adding audio to a session with a connected
            // AVCaptureVideoPreviewLayer requires stop→config→restart, which blocks
            // the main thread for 10-20s via AVFoundation internal synchronization.
            // Audio is deferred to the first recording via ensureAudioReady().
        }
    }
    
    /// Phase 2: Add audio input/output to the capture session.
    ///
    /// Expensive prep (AVAudioSession, mic discovery, device input creation) runs on
    /// audioSetupQueue. Session mutation runs on sessionQueue using beginConfiguration/
    /// commitConfiguration WITHOUT stop→restart. The preview layer is temporarily
    /// disconnected to prevent AVFoundation's internal dispatch_sync(main) deadlock.
    nonisolated private func addAudioInput() {
        guard audioDeviceInput == nil else { return }
        let t0 = CFAbsoluteTimeGetCurrent()
        let thread = Thread.current.description
        print("⏱️ [\(self.ts())] [PHASE2] START on \(thread)")
        
        // --- Expensive prep on audioSetupQueue ---
        do {
            let ta = CFAbsoluteTimeGetCurrent()
            try AVAudioSession.sharedInstance().setCategory(
                .playAndRecord,
                mode: .videoRecording,
                options: [.defaultToSpeaker]
            )
            print("⏱️ [\(self.ts())] [PHASE2] AVAudioSession.setCategory took \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - ta))s")
        } catch {
            print("⚠️ Audio session config failed: \(error)")
        }
        
        let tb = CFAbsoluteTimeGetCurrent()
        guard let microphone = AVCaptureDevice.default(for: .audio) else {
            print("⚠️ No microphone available")
            return
        }
        print("⏱️ [\(self.ts())] [PHASE2] mic discovery took \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - tb))s")
        
        let tc = CFAbsoluteTimeGetCurrent()
        let audioInput: AVCaptureDeviceInput
        do {
            audioInput = try AVCaptureDeviceInput(device: microphone)
        } catch {
            print("⚠️ Audio input error: \(error)")
            return
        }
        print("⏱️ [\(self.ts())] [PHASE2] AVCaptureDeviceInput took \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - tc))s")
        
        let audioOutput = AVCaptureAudioDataOutput()
        audioOutput.setSampleBufferDelegate(self, queue: audioProcessingQueue)
        
        // --- Session mutation on sessionQueue: config-only, NO stop/restart ---
        // The stop→restart cycle was causing an 18.7s deadlock because stopRunning()
        // and commitConfiguration() both internally dispatch_sync to the main thread
        // to negotiate with AVCaptureVideoPreviewLayer. By skipping stop/restart and
        // just using beginConfiguration/commitConfiguration, we avoid the deadlock.
        print("⏱️ [\(self.ts())] [PHASE2] about to dispatch to sessionQueue...")
        let td = CFAbsoluteTimeGetCurrent()
        sessionQueue.async { [self] in
            print("⏱️ [\(self.ts())] [PHASE2] entered sessionQueue (waited \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - td))s)")
            let session = captureSession
            
            let tCfg = CFAbsoluteTimeGetCurrent()
            session.beginConfiguration()
            if session.canAddInput(audioInput) {
                session.addInput(audioInput)
                audioDeviceInput = audioInput
                if session.canAddOutput(audioOutput) {
                    session.addOutput(audioOutput)
                    audioDataOutput = audioOutput
                }
            }
            session.commitConfiguration()
            print("⏱️ [\(self.ts())] [PHASE2] beginConfig+add+commit took \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - tCfg))s")
            print("⏱️ [\(self.ts())] [PHASE2] session config TOTAL took \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - td))s")
        }
        print("⏱️ [\(self.ts())] [PHASE2] addAudioInput TOTAL took \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - t0))s")
        
        Task { @MainActor in
            self.isAudioReady = true
        }
    }
    
    /// Ensure audio is wired up before recording. Returns immediately if already ready.
    func ensureAudioReady() async {
        guard !isAudioReady else { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            audioSetupQueue.async { [self] in
                self.addAudioInput()
                continuation.resume()
            }
        }
    }
    
    // MARK: - Session Control
    
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            let session = self.captureSession
            // Don't start an empty/unconfigured session — it wastes time and
            // causes contention when setupSession runs later on this serial queue.
            guard !session.inputs.isEmpty, !session.isRunning else { return }
            
            session.startRunning()
            
            Task { @MainActor in
                self.isSessionRunning = true
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            let session = self.captureSession
            guard session.isRunning else { return }
            session.stopRunning()
            
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
        let currentFocusMode = focusMode
        let currentFocusPosition = focusPosition
        
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                
                switch currentFocusMode {
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
                    device.setFocusModeLocked(lensPosition: currentFocusPosition)
                }
                
                device.unlockForConfiguration()
            } catch {
                print("Focus mode error: \(error)")
            }
        }
    }
    
    private func applyManualFocus() {
        guard let device = videoDeviceInput?.device else { return }
        let currentFocusPosition = focusPosition
        
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                device.setFocusModeLocked(lensPosition: currentFocusPosition)
                device.unlockForConfiguration()
            } catch {
                print("Manual focus error: \(error)")
            }
        }
    }
    
    // MARK: - Exposure Control
    
    private func applyExposureMode() {
        guard let device = videoDeviceInput?.device else { return }
        let currentExposureMode = exposureMode
        let currentShutterSpeed = shutterSpeed
        let currentISO = iso
        
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                
                switch currentExposureMode {
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
                        let duration = CMTime(seconds: currentShutterSpeed, preferredTimescale: 1000000)
                        device.setExposureModeCustom(duration: duration, iso: currentISO)
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
        
        // Clamp to physical device limits (-3 to 3 is typical, but varies by hardware)
        var targetBias = exposureCompensation
        targetBias = max(targetBias, device.minExposureTargetBias)
        targetBias = min(targetBias, device.maxExposureTargetBias)
        
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                device.setExposureTargetBias(targetBias)
                device.unlockForConfiguration()
            } catch {
                print("Exposure compensation error: \(error)")
            }
        }
    }
    
    private func applyManualExposure() {
        guard let device = videoDeviceInput?.device,
              device.isExposureModeSupported(.custom) else { return }
        let currentShutterSpeed = shutterSpeed
        let currentISO = iso
        
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                let duration = CMTime(seconds: currentShutterSpeed, preferredTimescale: 1000000)
                let clampedISO = min(max(currentISO, device.activeFormat.minISO), device.activeFormat.maxISO)
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
        let currentWhiteBalanceMode = whiteBalanceMode
        
        sessionQueue.async { [self] in
            do {
                try device.lockForConfiguration()
                
                switch currentWhiteBalanceMode {
                case .auto:
                    if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                        device.whiteBalanceMode = .continuousAutoWhiteBalance
                    }
                case .locked:
                    device.whiteBalanceMode = .locked
                default:
                    let tempTint = currentWhiteBalanceMode.temperatureAndTint
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
        let currentColorTemperature = colorTemperature
        let currentTint = tint
        
        sessionQueue.async { [self] in
            do {
                try device.lockForConfiguration()
                let gains = device.deviceWhiteBalanceGains(for: AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
                    temperature: currentColorTemperature,
                    tint: currentTint
                ))
                let normalizedGains = self.normalizeGains(gains, for: device)
                device.setWhiteBalanceModeLocked(with: normalizedGains)
                device.unlockForConfiguration()
            } catch {
                print("Manual white balance error: \(error)")
            }
        }
    }
    
    nonisolated private func normalizeGains(_ gains: AVCaptureDevice.WhiteBalanceGains, for device: AVCaptureDevice) -> AVCaptureDevice.WhiteBalanceGains {
        var g = gains
        let maxGain = device.maxWhiteBalanceGain
        g.redGain = min(max(1.0, g.redGain), maxGain)
        g.greenGain = min(max(1.0, g.greenGain), maxGain)
        g.blueGain = min(max(1.0, g.blueGain), maxGain)
        return g
    }
    
    // MARK: - Video Quality & Hardware Sync
    
    private func applyVideoQuality() {
        // Obsolete stub, use applyVideoSettings instead on mass updates
        let preset = videoQuality.sessionPreset
        sessionQueue.async { [weak self] in
            self?.captureSession.beginConfiguration()
            if self?.captureSession.canSetSessionPreset(preset) == true {
                self?.captureSession.sessionPreset = preset
            }
            self?.captureSession.commitConfiguration()
        }
    }
    
    /// Synchronize Quality, Frame Rate, and Stabilization to Physical Hardware
    func applyVideoSettings(quality: VideoQuality, frameRate: Int, stabilization: Bool) {
        
        let session = captureSession
        let preset = quality.sessionPreset
        print("⏱️ [\(ts())] [SETTINGS] applyVideoSettings called (dispatching to sessionQueue)")
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            let t0 = CFAbsoluteTimeGetCurrent()
            print("⏱️ [\(self.ts())] [SETTINGS] entered sessionQueue")
            
            // 1. Set Quality
            let tc = CFAbsoluteTimeGetCurrent()
            session.beginConfiguration()
            if session.canSetSessionPreset(preset) {
                session.sessionPreset = preset
                print("🎥 hardware sync: Quality set to \(preset.rawValue)")
            }
            session.commitConfiguration()
            print("⏱️ [\(self.ts())] [SETTINGS] beginConfig+commit took \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - tc))s")
            
            // 2. Set Frame Rate
            if let device = self.videoDeviceInput?.device {
                do {
                    try device.lockForConfiguration()
                    let targetFrameRate = Float64(frameRate)
                    var supportsFrameRate = false
                    
                    for range in device.activeFormat.videoSupportedFrameRateRanges {
                        if range.minFrameRate <= targetFrameRate && targetFrameRate <= range.maxFrameRate {
                            supportsFrameRate = true
                            break
                        }
                    }
                    
                    if supportsFrameRate {
                        device.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: Int32(frameRate))
                        device.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: Int32(frameRate))
                        print("🎥 hardware sync: Frame rate set to \(frameRate) fps")
                    } else {
                        print("⚠️ hardware sync: Frame rate \(frameRate) fps unsupported by preset \(preset.rawValue)")
                    }
                    device.unlockForConfiguration()
                } catch {
                    print("❌ hardware sync: Failed locking device for framerate - \(error)")
                }
            }
            
            // 3. Set Stabilization
            let stabMode: AVCaptureVideoStabilizationMode = stabilization ? .auto : .off
            if let connection = self.videoDataOutput?.connection(with: .video), connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = stabMode
            }
            print("🎥 hardware sync: Stabilization set to \(stabilization ? "auto" : "off")")
            print("⏱️ [\(self.ts())] [SETTINGS] applyVideoSettings TOTAL took \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - t0))s")
        }
    }
    
    // MARK: - Orientation Control
    
    func updateVideoOrientation(_ orientation: UIDeviceOrientation) {
        let videoOutput = videoDataOutput
        print("⏱️ [\(ts())] [ORIENT] updateVideoOrientation called with \(orientation.rawValue)")
        sessionQueue.async { [self] in
            print("⏱️ [\(self.ts())] [ORIENT] entered sessionQueue")
            if let dataConnection = videoOutput?.connection(with: .video) {
                self.updateConnectionOrientation(dataConnection, to: orientation)
            }
            print("⏱️ [\(self.ts())] [ORIENT] done")
        }
    }
    
    nonisolated private func updateConnectionOrientation(_ connection: AVCaptureConnection, to orientation: UIDeviceOrientation) {
        let videoOrientation: AVCaptureVideoOrientation
        switch orientation {
        case .portrait:
            videoOrientation = .portrait
        case .landscapeLeft:
            videoOrientation = .landscapeRight
        case .landscapeRight:
            videoOrientation = .landscapeLeft
        case .portraitUpsideDown:
            videoOrientation = .portraitUpsideDown
        default:
            // Fallback: assume portrait for .unknown / .faceUp.
            // IMPORTANT: Do NOT use DispatchQueue.main.sync here — this runs on
            // sessionQueue, and main.sync risks deadlock if main is waiting on
            // sessionQueue (e.g. AVCaptureSession internal sync).
            videoOrientation = .portrait
        }
        
        if connection.isVideoOrientationSupported {
            connection.videoOrientation = videoOrientation
        }
    }

    // MARK: - Center Stage (Face Tracking)
    
    private func applyCenterStage() {
        if #available(iOS 14.5, *) {
            // Center Stage is a class-level property on AVCaptureDevice
            AVCaptureDevice.centerStageControlMode = .cooperative
            AVCaptureDevice.isCenterStageEnabled = centerStageEnabled
            
            print("Center Stage \(centerStageEnabled ? "enabled" : "disabled")")
        }
    }
    
    /// Toggle Center Stage on/off
    func toggleCenterStage() {
        if #available(iOS 14.5, *) {
            centerStageEnabled.toggle()
        }
    }
    
    // MARK: - Portrait/Depth Effect
    
    // applyDepthEffect REMOVED - specialized hardware depth capture conflicts with Center Stage.
    // We now use software-only Vision segmentation which works with standard capture.
    private func applyDepthEffect() {
        // No-op
    }
    
    private func applyAperture() {
        // Simulated aperture affects the blur intensity
        // Lower f-number = more blur, higher f-number = less blur
        // This is used for UI display and potential future CoreImage-based blur
        print("Aperture set to f/\(simulatedAperture)")
        
        // For devices supporting AVCaptureDevice.PortraitEffectsMatteDelivery,
        // the blur amount is controlled by the system based on depth data
        // Custom blur would require a Metal/CoreImage-based solution
    }
    
    /// Toggle Portrait Effect on/off
    func toggleDepthEffect() {
        depthEnabled.toggle()
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
        
        // ALL recordings now use AVAssetWriter to avoid OS-level input/output graph deadlocks
        // caused by combining AVCaptureMovieFileOutput with VideoDataOutput.
        try setupAssetWriter(outputURL: outputURL)
        // Reset frame tracking state
        assetWriterStartTime = nil
        framesWritten = 0
        isWritingProcessedVideo = true
        
        let startTime = Date()
        recordingStartTime = startTime
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordingDuration = Date().timeIntervalSince(startTime)
            }
        }
        
        isRecording = true
        return outputURL
    }
    
    private func setupAssetWriter(outputURL: URL) throws {
        assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
        
        // Determine dimensions dynamically from actual buffers
        var videoWidth: Int
        var videoHeight: Int
        
        if let size = _capturedFrameSize {
            videoWidth = Int(size.width)
            videoHeight = Int(size.height)
            print("🎥 setupAssetWriter: Using live buffer dimensions: \(videoWidth)x\(videoHeight)")
        } else {
            // Fallback: Determine based on device orientation
            let orientation = UIDevice.current.orientation
            let isPortrait = orientation == .portrait || orientation == .portraitUpsideDown || orientation == .faceUp || orientation == .unknown
            
            videoWidth = isPortrait ? 1080 : 1920
            videoHeight = isPortrait ? 1920 : 1080
            print("🎥 setupAssetWriter: No buffer yet, using fallback dimensions: \(videoWidth)x\(videoHeight)")
        }
        
        // Calculate appropriate bitrate based on resolution
        // Target approx 0.15-0.2 bits per pixel at 30fps
        // 1080p (2M px) -> ~10-12 Mbps
        // 4K (8M px) -> ~40-50 Mbps
        // 720p (0.9M px) -> ~5 Mbps
        let pixelCount = videoWidth * videoHeight
        let targetBitrate = Int(Double(pixelCount) * 6.0) // 2M * 6 = 12M
        
        print("🎥 configured bitrate: \(targetBitrate / 1_000_000) Mbps for \(videoWidth)x\(videoHeight)")
        
        // Video settings - match the video quality and orientation
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: videoWidth,
            AVVideoHeightKey: videoHeight,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: targetBitrate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        
        assetWriterVideoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        assetWriterVideoInput?.expectsMediaDataInRealTime = true
        // assetWriterVideoInput?.transform = CGAffineTransform(rotationAngle: .pi / 2) // Portrait orientation
        // Since we are now rotating the buffers themselves via updateVideoOrientation, 
        // we should write with identity transform (upright pixels)
        assetWriterVideoInput?.transform = .identity
        
        // Create pixel buffer adaptor for processed frames
        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: videoWidth,
            kCVPixelBufferHeightKey as String: videoHeight,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
        
        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: assetWriterVideoInput!,
            sourcePixelBufferAttributes: sourcePixelBufferAttributes
        )
        
        if assetWriter!.canAdd(assetWriterVideoInput!) {
            assetWriter!.add(assetWriterVideoInput!)
        }
        
        // Audio settings (Standard 48kHz for video)
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 128000
        ]
        
        assetWriterAudioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        assetWriterAudioInput?.expectsMediaDataInRealTime = true
        
        if assetWriter!.canAdd(assetWriterAudioInput!) {
            assetWriter!.add(assetWriterAudioInput!)
        }
        
        
        assetWriter!.startWriting()
        // assetWriter!.startSession(atSourceTime: .zero) // REMOVED: We will start session at Source Time of first video frame

        
        print("Asset writer started for depth recording")
    }
    
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Handle Video and Audio explicitly sequentially on hardware queue
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { 
            // If no pixel buffer, it is Audio
            if let description = CMSampleBufferGetFormatDescription(sampleBuffer) {
                let mediaType = CMFormatDescriptionGetMediaType(description)
                if mediaType == kCMMediaType_Audio {
                    if self.renderStateIsWriting {
                        self.writeAudioSample(sampleBuffer)
                    }
                }
            }
            return 
        }
        
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let frameSize = CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
        
        // 1. CoreImage Heavy Vision CNN (Background Thread Execution!)
        var ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        if self.depthProcessor.isEnabled {
            if let processedImage = self.depthProcessor.processFrame(videoBuffer: sampleBuffer, depthData: nil) {
                ciImage = processedImage
            }
        }
        
        let currentFilter = self.renderStateFilter
        if currentFilter != .none {
            if let filtered = self.applyFilter(currentFilter, to: ciImage) {
                ciImage = filtered
            }
        }
        
        // 2. Heavy Write I/O (Background Thread Execution!)
        if self.renderStateIsWriting {
            if self.renderStateStartTime == nil {
                self.renderStateStartTime = presentationTime
                Task { @MainActor in self.assetWriterStartTime = presentationTime } // Sync back to struct state async
                self.assetWriter?.startSession(atSourceTime: presentationTime)
                print("🎥 Started AssetWriter Session at \(presentationTime.seconds)")
            }
            self.writeProcessedFrame(ciImage, at: presentationTime)
        }
        
        // 3. UI Sync — ONLY when effects are active (depth/greenscreen/filter).
        // Publishing processedPreviewImage on every frame (30fps) fires objectWillChange
        // on this @EnvironmentObject, causing SwiftUI to re-evaluate every observing view
        // 30 times/second — even hidden ones. This floods the main thread and causes
        // 30+ second UI freezes during tab transitions.
        // Cache frame size for setupAssetWriter (nonisolated-safe, no main-thread hop).
        self._capturedFrameSize = frameSize
        
        // Only publish processedPreviewImage when effects are active (depth/greenscreen/filter).
        // Publishing on every frame (30fps) fires objectWillChange on this @EnvironmentObject,
        // causing SwiftUI to re-evaluate every observing view 30 times/second — even hidden ones.
        // This floods the main thread and causes 30+ second UI freezes during tab transitions.
        let needsProcessedPreview = self.depthProcessor.isEnabled || currentFilter != .none
        if needsProcessedPreview {
            Task { @MainActor in
                self.processedPreviewImage = ciImage
            }
        }
    }
    
    /// Write a processed frame to the asset writer
    nonisolated func writeProcessedFrame(_ image: CIImage, at time: CMTime) {
        guard renderStateIsWriting,
              let adaptor = pixelBufferAdaptor,
              let input = assetWriterVideoInput,
              input.isReadyForMoreMediaData else {
            return
        }
        
        guard let pixelBufferPool = adaptor.pixelBufferPool else { return }
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &pixelBuffer)
        guard let buffer = pixelBuffer else { return }
        
        depthProcessor.render(image, to: buffer)
        adaptor.append(buffer, withPresentationTime: time)
    }
    
    /// Write audio sample buffer
    nonisolated func writeAudioSample(_ sampleBuffer: CMSampleBuffer) {
        guard renderStateIsWriting,
              let audioInput = assetWriterAudioInput,
              audioInput.isReadyForMoreMediaData,
              renderStateStartTime != nil else {
            return
        }
        audioInput.append(sampleBuffer)
    }
    
    /// Apply a CIFilter to the image using the filter's ciFilterName property
    nonisolated private func applyFilter(_ filter: CameraFilter, to image: CIImage) -> CIImage? {
        // ... (body remains identical)
        guard filter != .none else { return image }
        
        guard let filterName = filter.ciFilterName,
              let ciFilter = CIFilter(name: filterName) else {
            print("⚠️ Filter: No CIFilter available for \(filter.rawValue)")
            return image
        }
        
        ciFilter.setValue(image, forKey: kCIInputImageKey)
        if filter == .sepia {
            ciFilter.setValue(0.8, forKey: kCIInputIntensityKey)
        }
        guard let output = ciFilter.outputImage else {
            print("⚠️ Filter: \(filter.rawValue) produced no output")
            return image
        }
        return output
    }
    
    func stopRecording() async throws -> URL {
        print("📹 stopRecording: isRecording=\(isRecording), isWritingProcessedVideo=\(renderStateIsWriting)")
        
        guard isRecording else {
            throw CameraError.recordingFailed(NSError(domain: "CinematicCamera", code: -5))
        }
        
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            self.recordingContinuation = continuation
            
            // All recordings use AssetWriter
            isWritingProcessedVideo = false
            assetWriterVideoInput?.markAsFinished()
            assetWriterAudioInput?.markAsFinished()
            
            let writer = assetWriter
            assetWriter = nil
            
            writer?.finishWriting { [weak self] in
                guard let self = self else { return }
                if let error = writer?.error {
                    self.recordingContinuation?.resume(throwing: error)
                } else if let url = self.currentVideoURL {
                    self.recordingContinuation?.resume(returning: url)
                } else {
                    self.recordingContinuation?.resume(throwing: CameraError.recordingFailed(NSError(domain: "CinematicCamera", code: -6)))
                }
                self.recordingContinuation = nil
            }
        }
    }
    
    private let albumName = "GoPrompt"
    
    private func fetchOrCreateAlbum() async throws -> PHAssetCollection {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let collection = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
        
        if let existingAlbum = collection.firstObject {
            return existingAlbum
        }
        
        var albumPlaceholder: PHObjectPlaceholder?
        try await PHPhotoLibrary.shared().performChanges {
            let createAlbumRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: self.albumName)
            albumPlaceholder = createAlbumRequest.placeholderForCreatedAssetCollection
        }
        
        guard let placeholder = albumPlaceholder else {
            throw CameraError.exportFailed(NSError(domain: "CinematicCamera", code: -11, userInfo: [NSLocalizedDescriptionKey: "Failed to create album"]))
        }
        
        let newCollection = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)
        guard let album = newCollection.firstObject else {
            throw CameraError.exportFailed(NSError(domain: "CinematicCamera", code: -12, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch created album"]))
        }
        
        return album
    }
    
    func exportToPhotos(videoURL: URL, scriptTitle: String? = nil) async throws {
        print("📹 Export: Starting export of \(videoURL.lastPathComponent)")
        
        // Rename the internal file to the script title for metadata accuracy in Photos
        var fileToExport = videoURL
        if let title = scriptTitle, !title.isEmpty {
            let sanitizedTitle = title.replacingOccurrences(of: "/", with: "-")
                                      .replacingOccurrences(of: "\\", with: "-")
            let newURL = videoURL.deletingLastPathComponent()
                                 .appendingPathComponent("\(sanitizedTitle).mov")
            
            do {
                if FileManager.default.fileExists(atPath: newURL.path) {
                    try FileManager.default.removeItem(at: newURL)
                }
                try FileManager.default.moveItem(at: videoURL, to: newURL)
                fileToExport = newURL
                print("📹 Export: Renamed video to \(newURL.lastPathComponent)")
            } catch {
                print("⚠️ Export: Failed to rename video, using original name. Error: \(error.localizedDescription)")
            }
        }
        
        // Verify file exists
        guard FileManager.default.fileExists(atPath: fileToExport.path) else {
            print("❌ Export: File does not exist at \(fileToExport.path)")
            throw CameraError.exportFailed(NSError(domain: "CinematicCamera", code: -9, userInfo: [NSLocalizedDescriptionKey: "Video file not found"]))
        }
        
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else {
            print("❌ Export: Photo library access denied")
            throw CameraError.exportFailed(NSError(domain: "CinematicCamera", code: -6))
        }
        
        do {
            let album = try await fetchOrCreateAlbum()
            var localIdentifier: String?
            
            try await PHPhotoLibrary.shared().performChanges {
                let assetChangeRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileToExport)
                guard let assetPlaceholder = assetChangeRequest?.placeholderForCreatedAsset else { return }
                guard let albumChangeRequest = PHAssetCollectionChangeRequest(for: album) else { return }
                albumChangeRequest.addAssets([assetPlaceholder] as NSArray)
                
                localIdentifier = assetPlaceholder.localIdentifier
            }
            
            if let title = scriptTitle, let id = localIdentifier {
                VideoMetadataCache.shared.saveTitle(title, for: id)
                print("✅ Export: Saved metadata title '\(title)' for asset \(id)")
            }
            
            print("✅ Export: Video saved to GoPrompt album successfully!")
        } catch {
            print("❌ Export: Failed to save - \(error.localizedDescription)")
            throw CameraError.exportFailed(error)
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

// MARK: - AVCaptureDataOutputSynchronizerDelegate

// MARK: - AVCaptureDataOutputSynchronizerDelegate
// Conformance REMOVED - no longer using hardware depth sync


extension CinematicCameraService: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    // Protocol implementations are located in the main class body above
}

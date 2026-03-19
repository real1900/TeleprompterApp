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
    
    @Published var activeFilter: CameraFilter = .none
    
    // MARK: - Video Quality
    
    @Published var videoQuality: VideoQuality = .medium {
        didSet { applyVideoQuality() }
    }
    
    // MARK: - Device Capabilities
    
    @Published private(set) var minISO: Float = 50
    @Published private(set) var maxISO: Float = 3200
    
    // MARK: - AVFoundation Components
    
    nonisolated(unsafe) let captureSession = AVCaptureSession()
    nonisolated(unsafe) private var videoDeviceInput: AVCaptureDeviceInput?
    nonisolated(unsafe) private var audioDeviceInput: AVCaptureDeviceInput?
    nonisolated(unsafe) private let movieFileOutput = AVCaptureMovieFileOutput()
    
    // Depth capturing components REMOVED for Center Stage compatibility
    // Vision-based blur uses standard video frames
    
    nonisolated(unsafe) private var videoDataOutput: AVCaptureVideoDataOutput?
    nonisolated(unsafe) private var audioDataOutput: AVCaptureAudioDataOutput?
    
    // Depth processing
    let depthProcessor = DepthBlurProcessor()
    
    // For processed frame preview
    @Published var processedPreviewImage: CIImage?
    
    // Asset writer for recording processed frames
    private var assetWriter: AVAssetWriter?
    private var assetWriterVideoInput: AVAssetWriterInput?
    private var assetWriterAudioInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var isWritingProcessedVideo = false
    private var assetWriterStartTime: CMTime?
    private var framesWritten: Int = 0
    // private var depthSyncWritingFrames = false  // REMOVED
    
    // MARK: - Queues
    
    private let sessionQueue = DispatchQueue(label: "com.teleprompter.camera.session")
    private let videoProcessingQueue = DispatchQueue(label: "com.teleprompter.camera.videoProcessing")
    private let audioProcessingQueue = DispatchQueue(label: "com.teleprompter.camera.audioProcessing") // Added Audio Queue
    
    // MARK: - Recording State
    
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var currentVideoURL: URL?
    private var recordingContinuation: CheckedContinuation<URL, Error>?
    
    // MARK: - Dynamic Dimensions
    
    /// Tracks the actual size of incoming video buffers (Handling orientation & quality)
    private var lastFrameSize: CGSize?
    
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
        
        let quality = videoQuality
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [self] in
                do {
                    try self.setupSession(quality: quality)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    nonisolated private func setupSession(quality: VideoQuality) throws {
        // Configure Audio Session for recording
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .videoRecording, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("⚠️ Audio session configuration failed: \(error)")
        }

        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        
        if captureSession.canSetSessionPreset(quality.sessionPreset) {
            captureSession.sessionPreset = quality.sessionPreset
        } else {
            captureSession.sessionPreset = .high
        }
        
        // Try TrueDepth camera first (for depth data), then fallback to wide angle
        var frontCamera: AVCaptureDevice?
        var hasDepthCapability = false
        
        // Check for TrueDepth camera (supports depth)
        if let trueDepthCamera = AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .front) {
            frontCamera = trueDepthCamera
            hasDepthCapability = true
            print("Using TrueDepth camera with depth support")
        } else if let wideAngleCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
            frontCamera = wideAngleCamera
            print("Using wide angle camera (no depth support)")
        }
        
        guard let camera = frontCamera else {
            throw CameraError.cameraUnavailable
        }
        
        let videoInput = try AVCaptureDeviceInput(device: camera)
        guard captureSession.canAddInput(videoInput) else {
            throw CameraError.setupFailed(NSError(domain: "CinematicCamera", code: -2))
        }
        captureSession.addInput(videoInput)
        videoDeviceInput = videoInput
        
        // Read device capabilities
        Task { @MainActor in
            self.minISO = camera.activeFormat.minISO
            self.maxISO = camera.activeFormat.maxISO
            self.isDepthSupported = hasDepthCapability
            
            // Check Center Stage support (iOS 14.5+)
            if #available(iOS 14.5, *) {
                self.isCenterStageSupported = true
            }
        }
        
        // Add audio input
        if let microphone = AVCaptureDevice.default(for: .audio) {
            do {
                let audioInput = try AVCaptureDeviceInput(device: microphone)
                if captureSession.canAddInput(audioInput) {
                    captureSession.addInput(audioInput)
                    audioDeviceInput = audioInput
                    
                    // Add Audio Data Output for custom recording
                    let audioOutput = AVCaptureAudioDataOutput()
                    audioOutput.setSampleBufferDelegate(self, queue: audioProcessingQueue)
                    if captureSession.canAddOutput(audioOutput) {
                        captureSession.addOutput(audioOutput)
                        audioDataOutput = audioOutput
                    }
                }
            } catch {
                print("Audio input error: \(error)")
            }
        }
        
        // Add video data output for frame-by-frame processing
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: videoProcessingQueue)
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
            videoDataOutput = videoOutput
            
            if let connection = videoOutput.connection(with: .video) {
                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = true
                }
                
                // Set initial orientation to portrait
                self.updateConnectionOrientation(connection, to: .portrait)
            }
        }
        
        // Note: Depth output logic removed to support Center Stage
        // We now use Vision-based segmentation on standard video frames
        
        // Add movie file output (for non-depth recording fallback)
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
        let session = captureSession
        sessionQueue.async { [weak self] in
            guard !session.isRunning else { return }
            session.startRunning()
            
            Task { @MainActor in
                self?.isSessionRunning = true
            }
        }
    }
    
    func stopSession() {
        let session = captureSession
        sessionQueue.async { [weak self] in
            guard session.isRunning else { return }
            session.stopRunning()
            
            Task { @MainActor in
                self?.isSessionRunning = false
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
        let currentExposureCompensation = exposureCompensation
        
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                device.setExposureTargetBias(currentExposureCompensation)
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
    
    // MARK: - Video Quality
    
    private func applyVideoQuality() {
        let session = captureSession
        let preset = videoQuality.sessionPreset
        
        sessionQueue.async {
            session.beginConfiguration()
            if session.canSetSessionPreset(preset) {
                session.sessionPreset = preset
            }
            session.commitConfiguration()
        }
    }
    
    // MARK: - Orientation Control
    
    func updateVideoOrientation(_ orientation: UIDeviceOrientation) {
        let output = videoDataOutput
        sessionQueue.async { [self] in
            guard let connection = output?.connection(with: .video) else { return }
            self.updateConnectionOrientation(connection, to: orientation)
        }
    }
    
    nonisolated private func updateConnectionOrientation(_ connection: AVCaptureConnection, to orientation: UIDeviceOrientation) {
        let angle: CGFloat
        switch orientation {
        case .portrait:
            angle = 90
        case .landscapeLeft:
            angle = 180 // Inverted for front camera
        case .landscapeRight:
            angle = 0 // Inverted for front camera
        case .portraitUpsideDown:
            angle = 270
        default:
            return
        }
        
        if connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
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
        
        // If depth or green screen is enabled, use AVAssetWriter to record processed frames
        if depthEnabled || greenScreenEnabled {
            try setupAssetWriter(outputURL: outputURL)
            // Reset frame tracking state
            assetWriterStartTime = nil
            framesWritten = 0
            isWritingProcessedVideo = true
        } else {
            // Use standard movie file output for non-depth recording
            let output = movieFileOutput
            sessionQueue.async { [weak self] in
                guard let self else { return }
                output.startRecording(to: outputURL, recordingDelegate: self)
            }
        }
        
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
        
        if let size = lastFrameSize {
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
    
    /// Write a processed frame to the asset writer
    func writeProcessedFrame(_ image: CIImage, at time: CMTime) {
        guard isWritingProcessedVideo,
              let adaptor = pixelBufferAdaptor,
              let input = assetWriterVideoInput,
              input.isReadyForMoreMediaData else {
            return
        }
        
        // Get pixel buffer from pool
        guard let pixelBufferPool = adaptor.pixelBufferPool else {
            print("No pixel buffer pool available")
            return
        }
        
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &pixelBuffer)
        
        guard let buffer = pixelBuffer else {
            print("Failed to create pixel buffer")
            return
        }
        
        // Render processed image to pixel buffer
        depthProcessor.render(image, to: buffer)
        
        // Append to writer
        adaptor.append(buffer, withPresentationTime: time)
    }
    
    /// Write audio sample buffer
    func writeAudioSample(_ sampleBuffer: CMSampleBuffer) {
        guard isWritingProcessedVideo,
              let audioInput = assetWriterAudioInput,
              audioInput.isReadyForMoreMediaData,
              assetWriterStartTime != nil else { // Drop audio until video starts session
            return
        }
        
        audioInput.append(sampleBuffer)
    }
    
    func stopRecording() async throws -> URL {
        print("📹 stopRecording: isRecording=\(isRecording), isWritingProcessedVideo=\(isWritingProcessedVideo)")
        
        guard isRecording else {
            print("❌ stopRecording: Not recording!")
            throw CameraError.recordingFailed(NSError(domain: "CinematicCamera", code: -5))
        }
        
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        if isWritingProcessedVideo {
            print("📹 stopRecording: Using AVAssetWriter path")
            return try await finishAssetWriterRecording()
        } else {
            print("📹 stopRecording: Using movieFileOutput path")
            let output = movieFileOutput
            return try await withCheckedThrowingContinuation { continuation in
                recordingContinuation = continuation
                sessionQueue.async {
                    output.stopRecording()
                }
            }
        }
    }
    
    private func finishAssetWriterRecording() async throws -> URL {
        guard let writer = assetWriter, let url = currentVideoURL else {
            throw CameraError.recordingFailed(NSError(domain: "CinematicCamera", code: -7))
        }
        
        assetWriterVideoInput?.markAsFinished()
        assetWriterAudioInput?.markAsFinished()
        
        await writer.finishWriting()
        
        // Reset state
        isWritingProcessedVideo = false
        isRecording = false
        recordingDuration = 0
        recordingStartTime = nil
        assetWriter = nil
        assetWriterVideoInput = nil
        assetWriterAudioInput = nil
        pixelBufferAdaptor = nil
        
        if writer.status == .completed {
            print("Asset writer recording completed: \(url)")
            return url
        } else {
            throw CameraError.recordingFailed(writer.error ?? NSError(domain: "CinematicCamera", code: -8))
        }
    }
    
    func exportToPhotos(videoURL: URL) async throws {
        print("📹 Export: Starting export of \(videoURL.lastPathComponent)")
        
        // Verify file exists
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            print("❌ Export: File does not exist at \(videoURL.path)")
            throw CameraError.exportFailed(NSError(domain: "CinematicCamera", code: -9, userInfo: [NSLocalizedDescriptionKey: "Video file not found"]))
        }
        
        // Check file size
        if let attrs = try? FileManager.default.attributesOfItem(atPath: videoURL.path),
           let fileSize = attrs[.size] as? Int64 {
            print("📹 Export: File size = \(fileSize / 1024) KB")
            if fileSize == 0 {
                print("❌ Export: File is empty!")
                throw CameraError.exportFailed(NSError(domain: "CinematicCamera", code: -10, userInfo: [NSLocalizedDescriptionKey: "Video file is empty"]))
            }
        }
        
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        print("📹 Export: Photo library auth status = \(status.rawValue)")
        
        guard status == .authorized || status == .limited else {
            print("❌ Export: Photo library access denied")
            throw CameraError.exportFailed(NSError(domain: "CinematicCamera", code: -6))
        }
        
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
            }
            print("✅ Export: Video saved to Photos successfully!")
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

// MARK: - AVCaptureFileOutputRecordingDelegate

extension CinematicCameraService: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        print("Recording started to: \(fileURL)")
    }
    
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        print("Recording finished: \(outputFileURL), error: \(String(describing: error))")
        
        Task { @MainActor in
            // Reset all recording state
            self.isRecording = false
            self.recordingDuration = 0
            self.recordingStartTime = nil
            self.recordingTimer?.invalidate()
            self.recordingTimer = nil
            
            // Resume the continuation
            if let error {
                self.recordingContinuation?.resume(throwing: CameraError.recordingFailed(error))
            } else {
                self.recordingContinuation?.resume(returning: outputFileURL)
            }
            self.recordingContinuation = nil
            
            // Ensure session is still running (it should be, but verify)
            if !self.captureSession.isRunning {
                print("Warning: Session stopped after recording, restarting...")
                self.startSession()
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate & AVCaptureAudioDataOutputSampleBufferDelegate

extension CinematicCameraService: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // This is called for each video frame AND audio frame
        // Process frames here for filters or raw preview, and write to asset writer if recording
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { 
            // If no pixel buffer, it might be audio
            // Check if this connection is audio
            let description = CMSampleBufferGetFormatDescription(sampleBuffer)
            let mediaType = CMFormatDescriptionGetMediaType(description!)
            
            if mediaType == kCMMediaType_Audio {
                Task { @MainActor in
                    if self.isWritingProcessedVideo {
                        self.writeAudioSample(sampleBuffer)
                    }
                }
            }
            return 
        }
        
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        Task { @MainActor in
            // Capture dimensions from live buffer
            self.lastFrameSize = CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
            
            var ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            
            // 1. Apply Vision Effects (Blur or Green Screen)
            // The processor handles the mode internaly based on configuration
            if self.depthProcessor.isEnabled {
                // Pass nil for depthData since we are using Vision segmentation
                if let processedImage = self.depthProcessor.processFrame(videoBuffer: sampleBuffer, depthData: nil) {
                    ciImage = processedImage
                }
            }
            
            // 2. Apply Filters (if enabled)
            if self.activeFilter != .none {
                if let filtered = self.applyFilter(self.activeFilter, to: ciImage) {
                    ciImage = filtered
                }
            }
            
            // 3. Update Preview
            self.processedPreviewImage = ciImage
            
            // 4. Record Frame (if recording processed video)
            if self.isWritingProcessedVideo {
                // Determine Start Time from first frame
                if self.assetWriterStartTime == nil {
                    self.assetWriterStartTime = presentationTime
                    self.assetWriter?.startSession(atSourceTime: presentationTime)
                    print("🎥 Started AssetWriter Session at \(presentationTime.seconds)")
                }
                
                // Write at Source Time (PresentationTime)
                self.writeProcessedFrame(ciImage, at: presentationTime)
            }
        }
    }
    
    /// Apply a CIFilter to the image using the filter's ciFilterName property
    @MainActor
    private func applyFilter(_ filter: CameraFilter, to image: CIImage) -> CIImage? {
        guard filter != .none else { return image }
        
        // Use the ciFilterName property from the enum
        guard let filterName = filter.ciFilterName,
              let ciFilter = CIFilter(name: filterName) else {
            print("⚠️ Filter: No CIFilter available for \(filter.rawValue)")
            return image
        }
        
        ciFilter.setValue(image, forKey: kCIInputImageKey)
        
        // Special handling for sepia which needs intensity
        if filter == .sepia {
            ciFilter.setValue(0.8, forKey: kCIInputIntensityKey)
        }
        
        guard let output = ciFilter.outputImage else {
            print("⚠️ Filter: \(filter.rawValue) produced no output")
            return image
        }
        
        return output
    }
}

// MARK: - AVCaptureDataOutputSynchronizerDelegate

// MARK: - AVCaptureDataOutputSynchronizerDelegate
// Conformance REMOVED - no longer using hardware depth sync



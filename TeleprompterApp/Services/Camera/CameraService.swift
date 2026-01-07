import Foundation
import AVFoundation
import Photos
import Combine

/// Manages camera permissions
enum CameraPermission {
    case notDetermined
    case authorized
    case denied
    case restricted
}

/// Errors that can occur in camera operations
enum CameraError: LocalizedError {
    case cameraUnavailable
    case microphoneUnavailable
    case setupFailed(Error)
    case permissionDenied
    case recordingFailed(Error)
    case exportFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            return "Front camera is not available"
        case .microphoneUnavailable:
            return "Microphone is not available"
        case .setupFailed(let error):
            return "Camera setup failed: \(error.localizedDescription)"
        case .permissionDenied:
            return "Camera permission was denied"
        case .recordingFailed(let error):
            return "Recording failed: \(error.localizedDescription)"
        case .exportFailed(let error):
            return "Export to Photos failed: \(error.localizedDescription)"
        }
    }
}

/// Service that manages AVFoundation camera capture session
@MainActor
class CameraService: NSObject, ObservableObject {
    // MARK: - Published Properties
    
    @Published private(set) var isSessionRunning = false
    @Published private(set) var isRecording = false
    @Published private(set) var error: CameraError?
    @Published private(set) var recordingDuration: TimeInterval = 0
    @Published private(set) var cameraPermission: CameraPermission = .notDetermined
    @Published private(set) var microphonePermission: CameraPermission = .notDetermined
    
    // MARK: - AVFoundation Components
    
    let captureSession = AVCaptureSession()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var audioDeviceInput: AVCaptureDeviceInput?
    private let movieFileOutput = AVCaptureMovieFileOutput()
    
    // MARK: - Private Properties
    
    private let sessionQueue = DispatchQueue(label: "com.teleprompter.camera.session")
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var currentVideoURL: URL?
    
    // Continuation for async recording completion
    private var recordingContinuation: CheckedContinuation<URL, Error>?
    
    // MARK: - Preview Layer
    
    private lazy var _previewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        return layer
    }()
    
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer {
        return _previewLayer
    }
    
    // MARK: - Permissions
    
    func checkPermissions() async {
        // Check camera permission
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            cameraPermission = .notDetermined
        case .authorized:
            cameraPermission = .authorized
        case .denied:
            cameraPermission = .denied
        case .restricted:
            cameraPermission = .restricted
        @unknown default:
            cameraPermission = .notDetermined
        }
        
        // Check microphone permission
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined:
            microphonePermission = .notDetermined
        case .authorized:
            microphonePermission = .authorized
        case .denied:
            microphonePermission = .denied
        case .restricted:
            microphonePermission = .restricted
        @unknown default:
            microphonePermission = .notDetermined
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
        // Request permissions if needed
        if cameraPermission == .notDetermined {
            _ = await requestCameraPermission()
        }
        if microphonePermission == .notDetermined {
            _ = await requestMicrophonePermission()
        }
        
        guard cameraPermission == .authorized else {
            throw CameraError.permissionDenied
        }
        
        // Configure session on background queue
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: CameraError.setupFailed(NSError(domain: "CameraService", code: -1)))
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
        
        // Set session preset
        captureSession.sessionPreset = .high
        
        // Add video input (front camera)
        guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw CameraError.cameraUnavailable
        }
        
        let videoInput = try AVCaptureDeviceInput(device: frontCamera)
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
            videoDeviceInput = videoInput
        } else {
            throw CameraError.setupFailed(NSError(domain: "CameraService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Cannot add video input"]))
        }
        
        // Add audio input
        if let microphone = AVCaptureDevice.default(for: .audio) {
            let audioInput = try AVCaptureDeviceInput(device: microphone)
            if captureSession.canAddInput(audioInput) {
                captureSession.addInput(audioInput)
                audioDeviceInput = audioInput
            }
        }
        
        // Add movie file output
        if captureSession.canAddOutput(movieFileOutput) {
            captureSession.addOutput(movieFileOutput)
            
            // Set video stabilization if available
            if let connection = movieFileOutput.connection(with: .video) {
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .auto
                }
                // Mirror front camera video
                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = true
                }
            }
        } else {
            throw CameraError.setupFailed(NSError(domain: "CameraService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Cannot add movie output"]))
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
    
    // MARK: - Recording
    
    func startRecording() throws -> URL {
        guard !isRecording else {
            throw CameraError.recordingFailed(NSError(domain: "CameraService", code: -4, userInfo: [NSLocalizedDescriptionKey: "Already recording"]))
        }
        
        // Generate temp file URL
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "teleprompter_\(UUID().uuidString).mov"
        let outputURL = tempDir.appendingPathComponent(fileName)
        
        // Remove existing file if necessary
        try? FileManager.default.removeItem(at: outputURL)
        
        currentVideoURL = outputURL
        
        // Start recording on session queue
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.movieFileOutput.startRecording(to: outputURL, recordingDelegate: self)
        }
        
        // Start duration timer
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
            throw CameraError.recordingFailed(NSError(domain: "CameraService", code: -5, userInfo: [NSLocalizedDescriptionKey: "Not recording"]))
        }
        
        // Stop timer
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        return try await withCheckedThrowingContinuation { continuation in
            recordingContinuation = continuation
            
            sessionQueue.async { [weak self] in
                self?.movieFileOutput.stopRecording()
            }
        }
    }
    
    // MARK: - Export to Photos
    
    func exportToPhotos(videoURL: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        
        guard status == .authorized || status == .limited else {
            throw CameraError.exportFailed(NSError(domain: "CameraService", code: -6, userInfo: [NSLocalizedDescriptionKey: "Photo library access denied"]))
        }
        
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
        }
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        stopSession()
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        // Clean up temp video file
        if let url = currentVideoURL {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension CameraService: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        // Recording started
    }
    
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

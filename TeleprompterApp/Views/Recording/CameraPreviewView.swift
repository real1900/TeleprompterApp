import SwiftUI
import AVFoundation

/// UIViewRepresentable wrapper for AVCaptureVideoPreviewLayer
///
/// CRITICAL: The preview layer's session is connected LAZILY —
/// only AFTER `isSessionRunning` becomes true. This prevents a
/// 44s deadlock where `AVCaptureSession.startRunning()` on the
/// sessionQueue internally calls `dispatch_sync(main_queue)` to
/// negotiate with an already-connected AVCaptureVideoPreviewLayer,
/// while the main thread is busy with SwiftUI layout.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    /// When true, the preview layer connects to the session.
    /// Pass `cameraService.isSessionRunning` here.
    var isSessionRunning: Bool = false
    
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        // Do NOT connect session here — wait until isSessionRunning is true
        // to avoid the startRunning() → dispatch_sync(main) deadlock.
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        // Only connect the session AFTER startRunning() has completed.
        // This avoids the internal AVFoundation deadlock where startRunning
        // tries to dispatch_sync to main to configure an already-connected
        // preview layer while our main thread is busy with SwiftUI layout.
        if isSessionRunning && uiView.session !== session {
            uiView.session = session
        }
    }
    
    static func dismantleUIView(_ uiView: CameraPreviewUIView, coordinator: ()) {
        // Do NOT set session = nil here. Disconnecting an AVCaptureVideoPreviewLayer
        // from a running AVCaptureSession on the main thread triggers internal
        // AVFoundation synchronization that blocks the UI for 10+ seconds.
        // The layer is about to be deallocated anyway — no cleanup needed.
    }
}

/// Custom UIView that hosts AVCaptureVideoPreviewLayer
class CameraPreviewUIView: UIView {
    var session: AVCaptureSession? {
        didSet {
            previewLayer.session = session
            updateVideoOrientation()
        }
    }
    
    private var previewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayer()
        setupOrientationObserver()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
        setupOrientationObserver()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupLayer() {
        previewLayer.videoGravity = .resizeAspectFill
        backgroundColor = .black
        updateVideoOrientation()
    }
    
    private func setupOrientationObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationDidChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func orientationDidChange() {
        updateVideoOrientation()
    }
    
    private func updateVideoOrientation() {
        guard let connection = previewLayer.connection else { return }
        
        let videoOrientation: AVCaptureVideoOrientation
        let orientation = UIDevice.current.orientation
        switch orientation {
        case .portrait:
            videoOrientation = .portrait
        case .landscapeLeft:
            videoOrientation = .landscapeRight // UILandscapeLeft = Device rotated right
        case .landscapeRight:
            videoOrientation = .landscapeLeft
        case .portraitUpsideDown:
            videoOrientation = .portraitUpsideDown
        default:
            // Fallback to Window Scene orientation for .unknown or .faceUp
            var fallback: AVCaptureVideoOrientation = .portrait
            if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                switch windowScene.interfaceOrientation {
                case .landscapeRight: fallback = .landscapeRight
                case .landscapeLeft: fallback = .landscapeLeft
                case .portraitUpsideDown: fallback = .portraitUpsideDown
                default: fallback = .portrait
                }
            }
            videoOrientation = fallback
        }
        
        if connection.isVideoOrientationSupported {
            connection.videoOrientation = videoOrientation
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // Ensure preview layer fills the view
        previewLayer.frame = bounds
        updateVideoOrientation()
    }
}

#Preview {
    CameraPreviewView(session: AVCaptureSession())
        .ignoresSafeArea()
}

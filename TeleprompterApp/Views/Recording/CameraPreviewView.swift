import SwiftUI
import AVFoundation

/// UIViewRepresentable wrapper for AVCaptureVideoPreviewLayer
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.session = session
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        // Update session if needed
        if uiView.session !== session {
            uiView.session = session
        }
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
        guard let connection = previewLayer.connection, connection.isVideoOrientationSupported else { return }
        
        let orientation = UIDevice.current.orientation
        switch orientation {
        case .portrait:
            connection.videoOrientation = .portrait
        case .landscapeLeft:
            connection.videoOrientation = .landscapeRight // Inverted for front camera
        case .landscapeRight:
            connection.videoOrientation = .landscapeLeft // Inverted for front camera
        case .portraitUpsideDown:
            connection.videoOrientation = .portraitUpsideDown
        default:
            // Keep current orientation for face up/down or unknown
            break
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

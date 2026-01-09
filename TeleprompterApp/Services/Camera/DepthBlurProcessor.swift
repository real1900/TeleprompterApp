import Foundation
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision

/// Processes video frames using Vision Person Segmentation for Cinematic Blur
@MainActor
class DepthBlurProcessor: ObservableObject {
    
    // MARK: - Properties
    
    /// Blur intensity (f-stop simulation)
    /// Controls the radius of the background blur
    var aperture: Float = 2.8
    
    enum EffectMode {
        case blur
        case greenScreen
    }
    
    /// Current active effect
    var effectMode: EffectMode = .blur
    
    /// Whether processing is enabled
    var isEnabled: Bool = false
    
    /// Core Image context
    private let ciContext: CIContext
    
    /// Vision Segmentation Request
    private lazy var segmentationRequest: VNGeneratePersonSegmentationRequest = {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .balanced // Balanced offers good trade-off for real-time 30fps
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        return request
    }()
    
    // MARK: - Initialization
    
    init() {
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            self.ciContext = CIContext(mtlDevice: metalDevice, options: [
                .workingColorSpace: CGColorSpaceCreateDeviceRGB(),
                .highQualityDownsample: true,
                .cacheIntermediates: false // Optimize memory
            ])
        } else {
            self.ciContext = CIContext(options: [.useSoftwareRenderer: false])
        }
    }
    
    // MARK: - Processing
    
    /// Process a video frame: Segment Person -> Blur Background -> Composite
    func processFrame(videoBuffer: CMSampleBuffer, depthData: AVDepthData? = nil) -> CIImage? {
        guard isEnabled, let pixelBuffer = CMSampleBufferGetImageBuffer(videoBuffer) else { return nil }
        return processFrame(pixelBuffer: pixelBuffer)
    }
    
    /// Process a pixel buffer
    func processFrame(pixelBuffer: CVPixelBuffer) -> CIImage? {
        guard isEnabled else { return nil }
        
        let inputImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // 1. Generate Person Segmentation Mask via Vision
        // Since frames are pre-rotated to .up (Portrait) by connection, we use .up
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        
        do {
            try handler.perform([segmentationRequest])
            
            guard let result = segmentationRequest.results?.first else {
                // If segmentation fails, and we are in Green Screen mode,
                // we should treat the entire frame as background (Green)
                if effectMode == .greenScreen {
                    let greenColor = CIColor(red: 0, green: 1, blue: 0)
                    return CIImage(color: greenColor).cropped(to: inputImage.extent)
                }
                return inputImage // Fail safe for Blur: return original
            }
            
            // Mask is OneComponent8 (0..255). 255 = Person. 0 = Background.
            let maskImage = CIImage(cvPixelBuffer: result.pixelBuffer)
            
            // 2. Process Mask for Soft Edges
            // Scale mask to video size (Vision output is smaller)
            // CIBlendWithMask handles scaling, but explicit scaling ensures quality
            let scaledMask = maskImage
                .transformed(by: CGAffineTransform(
                    scaleX: inputImage.extent.width / maskImage.extent.width,
                    y: inputImage.extent.height / maskImage.extent.height
                ))
            
            // 3. Create Background (Blurred or Green)
            var backgroundImage: CIImage
            
            switch effectMode {
            case .greenScreen:
                // Solid pure green background (Chroma key friendly: #00FF00)
                // Use inputImage extent to ensure correct sizing
                let greenColor = CIColor(red: 0, green: 1, blue: 0)
                backgroundImage = CIImage(color: greenColor).cropped(to: inputImage.extent)
                
            case .blur:
                // Blurred background
                // Map aperture 1.4...16.0 to Blur Radius 30...0
                let normalizedAp = (min(max(aperture, 1.4), 16.0) - 1.4) / (16.0 - 1.4)
                let blurRadius = 30.0 * (1.0 - normalizedAp)
                
                backgroundImage = inputImage
                    .clampedToExtent()
                    .applyingFilter("CIGaussianBlur", parameters: [
                        kCIInputRadiusKey: blurRadius
                    ])
                    .cropped(to: inputImage.extent)
            }
            
            // 4. Composite: Person (Sharp) over Background
            // Mask is 1.0 (Person).
            return inputImage.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: backgroundImage,
                kCIInputMaskImageKey: scaledMask
            ])
            
        } catch {
            print("⚠️ Segmentation Failed: \(error)")
            return nil
        }
    }
    
    // MARK: - Helper Methods
    
    /// Render a CIImage to a pixel buffer for recording
    func render(_ image: CIImage, to pixelBuffer: CVPixelBuffer) {
        ciContext.render(image, to: pixelBuffer)
    }
    
    /// Create pixel buffer for recording
    func createPixelBuffer(size: CGSize) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferWidthKey: Int(size.width),
            kCVPixelBufferHeightKey: Int(size.height)
        ]
        
        CVPixelBufferCreate(kCFAllocatorDefault,
                           Int(size.width),
                           Int(size.height),
                           kCVPixelFormatType_32BGRA,
                           attrs as CFDictionary,
                           &pixelBuffer)
        return pixelBuffer
    }
}

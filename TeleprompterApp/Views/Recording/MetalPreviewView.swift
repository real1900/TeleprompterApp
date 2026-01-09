import SwiftUI
import MetalKit
import CoreImage

/// Metal-based view for rendering processed CIImages (for depth blur preview)
struct MetalPreviewView: UIViewRepresentable {
    let ciImage: CIImage?
    
    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = MTLCreateSystemDefaultDevice()
        view.framebufferOnly = false
        view.enableSetNeedsDisplay = true
        view.isPaused = true
        view.contentMode = .scaleAspectFill
        view.backgroundColor = .black
        view.delegate = context.coordinator
        return view
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.ciImage = ciImage
        uiView.setNeedsDisplay()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        var ciImage: CIImage?
        private var ciContext: CIContext?
        private var commandQueue: MTLCommandQueue?
        
        override init() {
            super.init()
            if let device = MTLCreateSystemDefaultDevice() {
                commandQueue = device.makeCommandQueue()
                ciContext = CIContext(mtlDevice: device, options: [
                    .workingColorSpace: CGColorSpaceCreateDeviceRGB()
                ])
            }
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // Handle size change
        }
        
        func draw(in view: MTKView) {
            guard var image = ciImage,
                  let currentDrawable = view.currentDrawable,
                  let commandBuffer = commandQueue?.makeCommandBuffer(),
                  let ciContext = ciContext else {
                return
            }
            
            let drawableSize = view.drawableSize
            
            // Video frames are now pre-rotated by the AVCaptureConnection in CinematicCameraService.
            // So we receive upright frames (e.g. 1080x1920 in Portrait) and don't need manual rotation.
            // However, for front camera self-preview, we still need to mirror it horizontally if it's not already mirrored.
            // AVCaptureConnection usually handles mirroring too, but let's trust the input image orientation.
            
            // Standard aspect fill logic below works for upright images.
            
            // Scale image to fit the view while maintaining aspect ratio (aspect fill)
            let scaleX = drawableSize.width / image.extent.width
            let scaleY = drawableSize.height / image.extent.height
            let scale = max(scaleX, scaleY)
            
            var scaledImage = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            
            // Center the image
            let xOffset = (drawableSize.width - scaledImage.extent.width) / 2 - scaledImage.extent.origin.x
            let yOffset = (drawableSize.height - scaledImage.extent.height) / 2 - scaledImage.extent.origin.y
            let centeredImage = scaledImage.transformed(by: CGAffineTransform(translationX: xOffset, y: yOffset))
            
            // Render to drawable
            let destination = CIRenderDestination(
                width: Int(drawableSize.width),
                height: Int(drawableSize.height),
                pixelFormat: view.colorPixelFormat,
                commandBuffer: commandBuffer,
                mtlTextureProvider: { () -> MTLTexture in
                    return currentDrawable.texture
                }
            )
            
            do {
                try ciContext.startTask(toRender: centeredImage, to: destination)
            } catch {
                print("Metal render error: \(error)")
            }
            
            commandBuffer.present(currentDrawable)
            commandBuffer.commit()
        }
    }
}

#Preview {
    MetalPreviewView(ciImage: nil)
        .ignoresSafeArea()
}

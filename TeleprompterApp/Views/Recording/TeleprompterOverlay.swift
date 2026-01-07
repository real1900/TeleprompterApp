import SwiftUI

/// Teleprompter overlay optimized for eye contact with camera
/// Layout is designed to keep text near the camera lens to minimize eye movement
struct TeleprompterOverlay: View {
    let script: Script
    @ObservedObject var engine: TeleprompterEngine
    let settings: TeleprompterSettings
    
    // Layout constants optimized for eye contact
    private let textColumnWidthRatio: CGFloat = 0.62  // 60-65% of screen width
    private let topPadding: CGFloat = 15              // Clear dynamic island/notch
    private let activeZoneRatio: CGFloat = 0.15       // Active line in top 15%
    
    var body: some View {
        GeometryReader { geometry in
            let columnWidth = geometry.size.width * textColumnWidthRatio
            let activeZoneHeight = geometry.size.height * activeZoneRatio
            
            ZStack(alignment: .top) {
                // Semi-transparent background with gradient fade
                LinearGradient(
                    colors: [
                        settings.backgroundColor.opacity(settings.backgroundOpacity),
                        settings.backgroundColor.opacity(settings.backgroundOpacity * 0.8),
                        settings.backgroundColor.opacity(0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                // Scrolling text container
                VStack(spacing: 0) {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            // Top spacer to position first line in active zone
                            Spacer()
                                .frame(height: activeZoneHeight * 0.3)
                            
                            // The script text
                            Text(script.content)
                                .font(.custom("SF Pro Rounded", size: settings.fontSize).weight(.medium))
                                .foregroundColor(settings.textColor)
                                .multilineTextAlignment(.center)
                                .lineSpacing(settings.fontSize * 0.4)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity)
                            
                            // Bottom spacer for scroll-through
                            Spacer()
                                .frame(height: geometry.size.height * 0.5)
                        }
                        .frame(width: columnWidth)
                        .background(GeometryReader { contentGeometry in
                            Color.clear.onAppear {
                                engine.contentHeight = contentGeometry.size.height
                            }
                        })
                        .offset(y: -engine.scrollOffset)
                    }
                    .scrollDisabled(true) // Controlled by engine, not user scroll
                }
                .padding(.top, topPadding)
                .frame(width: columnWidth)
                .frame(maxWidth: .infinity) // Center the column
                
                // Manual scroll gesture overlay
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                // Pause auto-scroll when user drags
                                if engine.isScrolling && !engine.isPaused {
                                    engine.pauseScrolling()
                                }
                                
                                // Manual scroll adjustment
                                let dragDelta = -value.translation.height * 0.5
                                let newOffset = engine.scrollOffset + dragDelta
                                engine.setOffset(newOffset)
                            }
                            .onEnded { _ in
                                // Resume auto-scroll if was scrolling
                                if engine.isScrolling && engine.isPaused {
                                    engine.resumeScrolling()
                                }
                            }
                    )
            }
            .onAppear {
                engine.visibleHeight = geometry.size.height
                engine.scrollSpeed = settings.scrollSpeed
                engine.fontSize = settings.fontSize
            }
            .onChange(of: settings.scrollSpeed) { _, newSpeed in
                engine.scrollSpeed = newSpeed
            }
            .onChange(of: settings.fontSize) { _, newSize in
                engine.fontSize = newSize
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        TeleprompterOverlay(
            script: Script.sample,
            engine: TeleprompterEngine(),
            settings: TeleprompterSettings.default
        )
        .frame(height: 300)
    }
}

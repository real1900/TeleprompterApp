import SwiftUI

/// Teleprompter overlay optimized for eye contact with camera
/// Layout is designed to keep text near the camera lens to minimize eye movement
struct TeleprompterOverlay: View {
    let script: Script
    @ObservedObject var engine: TeleprompterEngine
    let settings: TeleprompterSettings
    let isLandscape: Bool  // Passed from parent to avoid GeometryReader detection issues
    
    // Track drag gesture starting offset
    @State private var dragStartOffset: CGFloat = 0
    
    // Layout constants optimized for eye contact
    private let textColumnWidthRatio: CGFloat = 1.0 // 90% of screen width for portrait
    private let activeZoneRatio: CGFloat = 0.15       // Active line in top 15%
    
    var body: some View {
        GeometryReader { geometry in
            let columnWidth = geometry.size.width * textColumnWidthRatio
            let landscapeColumnWidth = geometry.size.width * 0.95 // Nearly full width in landscape container
            
            ZStack(alignment: isLandscape ? .leading : .top) {
                // Subtle gradient overlay for text readability - ONLY in text column
                // Portrait: gradient from top, confined to column width
                // Landscape: NO background (text floats with shadows only)
                if !isLandscape {
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0.4), location: 0),
                            .init(color: .black.opacity(0.25), location: 0.3),
                            .init(color: .black.opacity(0.1), location: 0.5),
                            .init(color: .clear, location: 0.7)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(width: columnWidth) // Constrain to text column
                    .frame(maxWidth: .infinity) // Center it
                }
                
                // Scrolling text container
                VStack(spacing: 0) {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: isLandscape ? .leading : .center, spacing: 0) {
                            // Top spacer based on active zone
                            Spacer(minLength: geometry.size.height * activeZoneRatio)
                            
                            // The script text
                            Text(script.content)
                                .font(.system(size: isLandscape ? settings.fontSize * 0.85 : settings.fontSize, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 2)
                                .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 4)
                                .multilineTextAlignment(isLandscape ? .leading : .center)
                                .lineSpacing(settings.fontSize * 0.35)
                                .scaleEffect(x: settings.mirrorText ? -1 : 1, y: 1)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: isLandscape ? .leading : .center)
                                .padding(.horizontal, isLandscape ? 16 : 20)
                                .padding(.leading, isLandscape ? max(geometry.safeAreaInsets.leading, 38) : 0)
                            
                            // Bottom spacer to allow scroll-through
                            Spacer(minLength: geometry.size.height * 0.6)
                        }
                        .frame(width: isLandscape ? landscapeColumnWidth : columnWidth)
                        .background(GeometryReader { contentGeometry in
                            Color.clear
                                .onAppear {
                                    engine.contentHeight = contentGeometry.size.height
                                }
                                .onChange(of: contentGeometry.size.height) { _, newHeight in
                                    engine.contentHeight = newHeight
                                }
                        })
                        .offset(y: -engine.scrollOffset)
                    }
                    .scrollDisabled(true)
                }
                .frame(width: isLandscape ? landscapeColumnWidth : columnWidth)
                .frame(maxWidth: .infinity, alignment: isLandscape ? .leading : .center)
                // Soft fade out at the bottom - more gradual transition
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .white, location: 0),
                            .init(color: .white, location: 0.55),
                            .init(color: .white.opacity(0.6), location: 0.70),
                            .init(color: .white.opacity(0.2), location: 0.85),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                
                // Manual scroll gesture overlay
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                // Capture starting offset at the beginning of the drag
                                if value.translation.height == 0 || dragStartOffset == 0 {
                                    dragStartOffset = engine.scrollOffset
                                }
                                
                                // Pause auto-scroll when user drags
                                if engine.isScrolling && !engine.isPaused {
                                    engine.pauseScrolling()
                                }
                                
                                // Calculate new offset from starting position
                                // Drag down (positive translation) = scroll up (negative offset change)
                                let newOffset = dragStartOffset - value.translation.height
                                engine.setOffset(newOffset)
                            }
                            .onEnded { _ in
                                // Reset drag tracking
                                dragStartOffset = 0
                                
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
            settings: TeleprompterSettings.default,
            isLandscape: false
        )
        .frame(height: 300)
    }
}

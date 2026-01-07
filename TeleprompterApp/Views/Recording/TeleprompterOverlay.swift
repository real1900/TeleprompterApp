import SwiftUI

/// Semi-transparent scrolling text overlay for the teleprompter
struct TeleprompterOverlay: View {
    let script: Script
    @ObservedObject var engine: TeleprompterEngine
    let settings: TeleprompterSettings
    
    @State private var textSize: CGSize = .zero
    @State private var dragOffset: CGFloat = 0
    @GestureState private var isDragging = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background - semi-transparent gradient
                LinearGradient(
                    colors: [
                        Color.black.opacity(settings.backgroundOpacity),
                        Color.black.opacity(settings.backgroundOpacity * 0.5),
                        Color.black.opacity(settings.backgroundOpacity * 0.3)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
                
                // Scrolling Text
                VStack(spacing: 0) {
                    // Top padding
                    Spacer()
                        .frame(height: geometry.size.height / 2)
                    
                    // Script text - full text with word wrap
                    Text(script.content)
                        .font(.system(size: settings.fontSize, weight: .medium))
                        .foregroundColor(settings.textColor)
                        .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                        .lineSpacing(settings.lineSpacing)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, settings.horizontalPadding)
                        .scaleEffect(x: settings.mirrorText ? -1 : 1, y: 1)
                        .background(
                            GeometryReader { textGeometry in
                                Color.clear.preference(
                                    key: TextSizePreferenceKey.self,
                                    value: textGeometry.size
                                )
                            }
                        )
                    
                    // Bottom padding
                    Spacer()
                        .frame(height: geometry.size.height / 2)
                }
                .offset(y: -engine.scrollOffset - dragOffset)
                .gesture(
                    DragGesture()
                        .updating($isDragging) { _, state, _ in
                            state = true
                        }
                        .onChanged { value in
                            if engine.isScrolling && !engine.isPaused {
                                engine.pauseScrolling()
                            }
                            dragOffset = -value.translation.height
                        }
                        .onEnded { value in
                            engine.setOffset(engine.scrollOffset + dragOffset)
                            dragOffset = 0
                        }
                )
                
                // Center line indicator
                Rectangle()
                    .fill(Color.red.opacity(0.6))
                    .frame(height: 2)
                    .frame(maxWidth: .infinity)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    .allowsHitTesting(false)
                
                // Progress indicator
                VStack {
                    Spacer()
                    ProgressView(value: engine.progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .red))
                        .frame(height: 4)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }
                .allowsHitTesting(false)
            }
            .onPreferenceChange(TextSizePreferenceKey.self) { size in
                textSize = size
                engine.contentHeight = size.height + geometry.size.height
                engine.visibleHeight = geometry.size.height
            }
            .onAppear {
                engine.visibleHeight = geometry.size.height
                engine.scrollSpeed = settings.scrollSpeed
                engine.fontSize = settings.fontSize
            }
            .onChange(of: settings.scrollSpeed) { _, newValue in
                engine.scrollSpeed = newValue
            }
            .onChange(of: settings.fontSize) { _, newValue in
                engine.fontSize = newValue
            }
        }
    }
}

// MARK: - Text Size Preference Key

struct TextSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

#Preview {
    TeleprompterOverlay(
        script: .sample,
        engine: TeleprompterEngine(),
        settings: .default
    )
    .frame(height: 400)
    .background(Color.gray)
}

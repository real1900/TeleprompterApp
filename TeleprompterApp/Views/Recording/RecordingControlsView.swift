import SwiftUI

/// Recording controls bar matching the Stitch GoPrompt Pro UI
struct RecordingControlsView: View {
    @ObservedObject var cameraService: CinematicCameraService
    @ObservedObject var teleprompterEngine: TeleprompterEngine
    @Binding var showCameraControls: Bool
    
    var onSettingsTapped: () -> Void
    var onScriptTapped: () -> Void
    var onRecordTapped: () -> Void
    var onStopTapped: () -> Void
    
    private let peachTint = Color(red: 1.0, green: 0.7, blue: 0.66)
    
    var body: some View {
        if cameraService.isRecording {
            // RECORDING MODE: Simple Stop Button
            VStack {
                Spacer()
                Button {
                    onStopTapped()
                } label: {
                    ZStack {
                        // Outer Ring
                        Circle()
                            .stroke(DesignSystem.Colors.destructive.opacity(0.3), lineWidth: 4)
                            .frame(width: 80, height: 80)
                        
                        // Stop Square
                        RoundedRectangle(cornerRadius: 8)
                            .fill(DesignSystem.Colors.destructive)
                            .frame(width: 32, height: 32)
                            .shadow(color: DesignSystem.Colors.destructive.opacity(0.5), radius: 20, x: 0, y: 0)
                    }
                }
                .padding(.bottom, 40)
            }
            .transition(.opacity)
        } else {
            // NOT RECORDING (Stitch Bottom Bar)
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    HStack(spacing: 8) {
                        // Settings
                        Button(action: onSettingsTapped) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(peachTint)
                                .frame(width: 48, height: 48)
                        }
                        
                        // Camera Controls (Aperture/Tools)
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showCameraControls.toggle()
                            }
                        }) {
                            Image(systemName: "camera.aperture")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(showCameraControls ? Color.white : peachTint)
                                .frame(width: 48, height: 48)
                        }
                        
                        Spacer()
                        
                        // MASSIVE RECORD BUTTON
                        Button(action: onRecordTapped) {
                            ZStack {
                                // Outer Thin Ring
                                Circle()
                                    .stroke(Color.red.opacity(0.4), lineWidth: 1.5)
                                    .frame(width: 72, height: 72)
                                    
                                // Soft Glow
                                Circle()
                                    .fill(Color.red.opacity(0.15))
                                    .frame(width: 64, height: 64)
                                    .blur(radius: 8)

                                // Main Trigger
                                Circle()
                                    .fill(Color(red: 1.0, green: 0.35, blue: 0.35))
                                    .frame(width: 52, height: 52)
                                    // Deep shadow to glow
                                    .shadow(color: Color.red.opacity(0.8), radius: 12, x: 0, y: 0)
                            }
                        }
                        .padding(.horizontal, 4)
                        
                        Spacer()
                        
                        // Script / Documents
                        Button(action: onScriptTapped) {
                            Image(systemName: "doc.plaintext")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(peachTint)
                                .frame(width: 48, height: 48)
                        }
                        
                        // Resolution Pill
                        Button {
                            cycleVideoQuality()
                        } label: {
                            Text(cameraService.videoQuality == .ultra ? "4K60" : "HD30")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .tracking(1.0)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(white: 0.15))
                                .clipShape(Capsule())
                        }
                        .frame(minWidth: 64)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color(white: 0.1, opacity: 0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 40))
                    .shadow(color: Color.black.opacity(0.5), radius: 30, x: 0, y: 20)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                    Spacer()
                }
            }
            .transition(.opacity)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func cycleVideoQuality() {
        let allQualities = VideoQuality.allCases
        if let currentIndex = allQualities.firstIndex(of: cameraService.videoQuality) {
            let nextIndex = (currentIndex + 1) % allQualities.count
            cameraService.videoQuality = allQualities[nextIndex]
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        RecordingControlsView(
            cameraService: CinematicCameraService(),
            teleprompterEngine: TeleprompterEngine(),
            showCameraControls: .constant(false),
            onSettingsTapped: {},
            onScriptTapped: {},
            onRecordTapped: {},
            onStopTapped: {}
        )
    }
}

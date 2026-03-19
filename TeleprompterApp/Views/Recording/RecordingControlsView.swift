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
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 22))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                                .frame(width: 48, height: 48)
                        }
                        
                        // Camera Controls (Aperture/Tools)
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showCameraControls.toggle()
                            }
                        }) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 22))
                                .foregroundColor(showCameraControls ? DesignSystem.Colors.primaryText : DesignSystem.Colors.secondaryText)
                                .frame(width: 48, height: 48)
                        }
                        
                        Spacer()
                        
                        // MASSIVE RECORD BUTTON
                        Button(action: onRecordTapped) {
                            ZStack {
                                // Outer Ring
                                Circle()
                                    .stroke(DesignSystem.Colors.accent.opacity(0.3), lineWidth: 2)
                                    .frame(width: 68, height: 68)
                                    
                                // Main Trigger
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [DesignSystem.Colors.accent, DesignSystem.Colors.destructive],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 56, height: 56)
                                    .shadow(color: DesignSystem.Colors.accent.opacity(0.5), radius: 15, x: 0, y: 0)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(.white)
                                            .frame(width: 20, height: 20)
                                    )
                            }
                        }
                        
                        Spacer()
                        
                        // Script / Documents
                        Button(action: onScriptTapped) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 22))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                                .frame(width: 48, height: 48)
                        }
                        
                        // Resolution Pill
                        Button {
                            cycleVideoQuality()
                        } label: {
                            HStack(spacing: 2) {
                                Text(cameraService.videoQuality == .ultra ? "4K" : "HD")
                                    .font(DesignSystem.Typography.headline.weight(.heavy))
                                Text(cameraService.videoQuality == .ultra ? "60" : "30")
                                    .font(DesignSystem.Typography.headline.weight(.bold))
                            }
                            .font(.system(size: 11))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                            .tracking(-0.5)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.05))
                            .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .glassPanel(cornerRadius: 40)
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

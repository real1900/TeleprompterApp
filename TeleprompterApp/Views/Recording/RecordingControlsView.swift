import SwiftUI

/// Recording controls bar with record/stop button and status
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
            // RECORDING MODE: Stop button centered at bottom + timer pill
            ZStack {
                // Stop button - centered at bottom
                VStack {
                    Spacer()
                    Button {
                        onStopTapped()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(DesignSystem.Colors.surfaceHighlight)
                                .frame(width: 64, height: 64)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                            
                            RoundedRectangle(cornerRadius: 6)
                                .fill(DesignSystem.Colors.destructive)
                                .frame(width: 24, height: 24)
                        }
                        .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 5)
                    }
                    .padding(.bottom, 40)
                }
                
                // Timer pill - bottom right corner
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(formatDuration(cameraService.recordingDuration))
                            .font(.system(.subheadline, design: .monospaced).weight(.bold))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .glassPill()
                            .padding(.trailing, 20)
                            .padding(.bottom, 20)
                    }
                }
            }
        } else {
            // NOT RECORDING: Full control bar at bottom
            VStack {
                Spacer()
                HStack(spacing: 28) {
                    ControlButton(systemImage: "gearshape.fill", label: "Settings", action: onSettingsTapped)
                    ControlButton(systemImage: "slider.horizontal.3", label: "Controls", isActive: showCameraControls, action: { showCameraControls.toggle() })
                    
                    RecordButton(isRecording: false, onTap: onRecordTapped)
                        .padding(.horizontal, 8)
                        
                    ControlButton(systemImage: "doc.plaintext.fill", label: "Script", action: onScriptTapped)
                    VideoQualityButton(quality: cameraService.videoQuality) { cycleVideoQuality() }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, DesignSystem.Layout.paddingStandard)
                .glassPill()
                .padding(.horizontal, DesignSystem.Layout.paddingStandard)
                .padding(.bottom, 32)
            }
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

// MARK: - Recording Status Bar

struct RecordingStatusBar: View {
    let duration: TimeInterval
    let isScrolling: Bool
    let isPaused: Bool
    var onPauseTapped: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Recording indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(DesignSystem.Colors.accent)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle()
                            .fill(DesignSystem.Colors.accent)
                            .scaleEffect(1.5)
                            .opacity(0.3)
                    )
                    .modifier(PulsingModifier())
                
                Text("REC")
                    .font(DesignSystem.Typography.caption.bold())
                    .foregroundColor(DesignSystem.Colors.accent)
            }
            
            // Duration
            Text(formatDuration(duration))
                .font(.system(.body, design: .monospaced).bold())
                .foregroundColor(DesignSystem.Colors.primaryText)
            
            Spacer()
            
            // Pause/Resume teleprompter button
            Button {
                onPauseTapped()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    Text(isPaused ? "Resume" : "Pause")
                        .font(DesignSystem.Typography.caption.bold())
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isPaused ? Color.green : Color.orange)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, DesignSystem.Layout.paddingLarge)
        .padding(.vertical, 12)
        .glassPanel(cornerRadius: DesignSystem.Layout.cornerRadiusStandard)
        .padding(.horizontal, DesignSystem.Layout.paddingStandard)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Pulsing Modifier

struct PulsingModifier: ViewModifier {
    @State private var isPulsing = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .animation(
                .easeInOut(duration: 0.8)
                .repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

// MARK: - Control Button

struct ControlButton: View {
    let systemImage: String
    let label: String
    var isActive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .medium))
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundColor(isActive ? DesignSystem.Colors.accent : DesignSystem.Colors.primaryText)
        }
    }
}

// MARK: - Video Quality Button

struct VideoQualityButton: View {
    let quality: VideoQuality
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(quality.rawValue)
                    .font(.system(size: 11, weight: .heavy))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(DesignSystem.Colors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
                Text("Quality")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundColor(DesignSystem.Colors.primaryText)
        }
    }
}

// MARK: - Record Button

struct RecordButton: View {
    let isRecording: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Outer ring
                Circle()
                    .stroke(Color.white.opacity(0.8), lineWidth: 4)
                    .frame(width: 76, height: 76)
                
                // Inner shape
                if isRecording {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(DesignSystem.Colors.accent)
                        .frame(width: 32, height: 32)
                } else {
                    Circle()
                        .fill(DesignSystem.Colors.accent)
                        .frame(width: 60, height: 60)
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isRecording)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            Spacer()
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
}

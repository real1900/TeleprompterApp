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
            // RECORDING MODE: Floating stop button + timer pill only
            ZStack {
                // Stop button - floating on right side, vertically centered
                HStack {
                    Spacer()
                    Button {
                        onStopTapped()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.white)
                                .frame(width: 56, height: 56)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.red)
                                .frame(width: 20, height: 20)
                        }
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.trailing, 20)
                }
                
                // Timer pill - bottom right corner
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(formatDuration(cameraService.recordingDuration))
                            .font(.system(.subheadline, design: .monospaced).weight(.medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .padding(.trailing, 20)
                            .padding(.bottom, 20)
                    }
                }
            }
        } else {
            // NOT RECORDING: Full control bar at bottom
            VStack {
                Spacer()
                HStack(spacing: 24) {
                    ControlButton(systemImage: "gear", label: "Settings", action: onSettingsTapped)
                    ControlButton(systemImage: "camera.aperture", label: "Camera", isActive: showCameraControls, action: { showCameraControls.toggle() })
                    RecordButton(isRecording: false, onTap: onRecordTapped)
                    ControlButton(systemImage: "doc.text", label: "Script", action: onScriptTapped)
                    VideoQualityButton(quality: cameraService.videoQuality) { cycleVideoQuality() }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
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
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle()
                            .fill(Color.red)
                            .scaleEffect(1.5)
                            .opacity(0.3)
                    )
                    .modifier(PulsingModifier())
                
                Text("REC")
                    .font(.caption.bold())
                    .foregroundColor(.red)
            }
            
            // Duration
            Text(formatDuration(duration))
                .font(.system(.body, design: .monospaced).bold())
                .foregroundColor(.white)
            
            Spacer()
            
            // Pause/Resume teleprompter button
            Button {
                onPauseTapped()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    Text(isPaused ? "Resume" : "Pause")
                        .font(.caption.bold())
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isPaused ? Color.green : Color.orange)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
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
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.title2)
                Text(label)
                    .font(.caption)
            }
            .foregroundColor(isActive ? .yellow : .white)
        }
    }
}

// MARK: - Video Quality Button

struct VideoQualityButton: View {
    let quality: VideoQuality
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(quality.rawValue)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.yellow.opacity(0.3))
                    .cornerRadius(4)
                Text("Quality")
                    .font(.caption)
            }
            .foregroundColor(.white)
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
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 80, height: 80)
                
                // Inner shape (circle when idle, square when recording)
                if isRecording {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.red)
                        .frame(width: 32, height: 32)
                } else {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 60, height: 60)
                }
            }
        }
        .animation(.spring(response: 0.3), value: isRecording)
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

import SwiftUI

/// Main recording view with camera preview, teleprompter overlay, and controls
struct RecordingView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settings: TeleprompterSettings
    @EnvironmentObject var cameraService: CinematicCameraService
    @StateObject private var teleprompterEngine = TeleprompterEngine()
    
    @State private var showSettings = false
    @State private var showScriptPicker = false
    @State private var showCameraControls = false
    @State private var showCountdown = false
    @State private var countdownValue = 3
    @State private var permissionDenied = false
    
    // Focus indicator
    @State private var showFocusIndicator = false
    @State private var focusIndicatorPosition: CGPoint = .zero
    
    // Track device orientation for camera-side text positioning
    @State private var deviceOrientation: UIDeviceOrientation = UIDevice.current.orientation
    
    // Camera is on LEFT when landscapeLeft (home button on left)
    // Camera is on RIGHT when landscapeRight (home button on right)
    private var cameraOnLeft: Bool {
        deviceOrientation == .landscapeLeft || deviceOrientation == .unknown || deviceOrientation == .portrait
    }
    
    var body: some View {
        ZStack {
            // LAYER 1: Full Screen Background (Video)
            GeometryReader { fullGeo in
                ZStack {
                    if (cameraService.depthEnabled || cameraService.greenScreenEnabled || cameraService.activeFilter != .none),
                       let processedImage = cameraService.processedPreviewImage {
                        MetalPreviewView(ciImage: processedImage)
                            .ignoresSafeArea()
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onEnded { value in
                                        handleTapToFocus(at: value.location, in: fullGeo.size)
                                    }
                            )
                    } else {
                        // Live camera preview — session connected ONLY after startRunning completes
                        // to prevent AVFoundation's internal dispatch_sync(main) deadlock.
                        CameraPreviewView(
                            session: cameraService.captureSession,
                            isSessionRunning: cameraService.isSessionRunning
                        )
                            .ignoresSafeArea()
                    }
                    
                    // Focus indicator
                    FocusIndicatorView(
                        position: focusIndicatorPosition,
                        isVisible: showFocusIndicator
                    )
                    
                    // Teleprompter Overlay - adaptive to orientation
                    let isLandscape = fullGeo.size.width > fullGeo.size.height
                    
                    if isLandscape {
                        HStack(spacing: 0) {
                            if cameraOnLeft {
                                TeleprompterOverlay(
                                    script: appState.currentScript ?? Script.sample,
                                    engine: teleprompterEngine,
                                    isLandscape: true
                                )
                                .frame(width: fullGeo.size.width * 0.40, height: fullGeo.size.height)
                                .clipped()
                                Spacer()
                            } else {
                                Spacer()
                                TeleprompterOverlay(
                                    script: appState.currentScript ?? Script.sample,
                                    engine: teleprompterEngine,
                                    isLandscape: true
                                )
                                .frame(width: fullGeo.size.width * 0.40, height: fullGeo.size.height)
                                .clipped()
                            }
                        }
                    } else {
                        VStack(spacing: 0) {
                            TeleprompterOverlay(
                                script: appState.currentScript ?? Script.sample,
                                engine: teleprompterEngine,
                                isLandscape: false
                            )
                            .frame(height: fullGeo.size.height * 0.45)
                            .clipped()
                            Spacer()
                        }
                    }
                    
                    // Countdown Overlay
                    if showCountdown {
                        CountdownOverlay(value: countdownValue)
                    }
                    
                    // Permission Request Overlay
                    if permissionDenied {
                        PermissionDeniedView()
                    }
                    
                    // Camera Loading Overlay — shown during ~12s hardware init
                    if !cameraService.isSessionRunning && !permissionDenied {
                        CameraLoadingOverlay()
                            .transition(.opacity)
                            .animation(.easeOut(duration: 0.6), value: cameraService.isSessionRunning)
                    }
                }
            }
            .ignoresSafeArea()
            
            // LAYER 2: Controls & Interfaces
            GeometryReader { safeGeo in
                ZStack {
                    
                    // HUD (Top)
                    if cameraService.isRecording {
                        VStack {
                            RecordingHUDView(
                                duration: cameraService.recordingDuration,
                                isPaused: teleprompterEngine.isPaused,
                                onPauseToggled: {
                                    if teleprompterEngine.isPaused {
                                        teleprompterEngine.resumeScrolling()
                                    } else {
                                        teleprompterEngine.pauseScrolling()
                                    }
                                }
                            )
                            Spacer()
                        }
                        .zIndex(3)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    VStack(spacing: 8) {
                        Spacer()
                        
                        // Camera Controls Overlay (pops up above RecordingControlsView)
                        if showCameraControls && !cameraService.isRecording {
                            CameraControlsOverlay(cameraService: cameraService)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 8)
                                .frame(maxWidth: safeGeo.size.width)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        
                        // Main Recording Controls Bar
                        // Automatically rests on the bottom safeArea managed by ContentView
                        RecordingControlsView(
                            cameraService: cameraService,
                            teleprompterEngine: teleprompterEngine,
                            showCameraControls: $showCameraControls,
                            onSettingsTapped: { showSettings = true },
                            onScriptTapped: { showScriptPicker = true },
                            onRecordTapped: handleRecordTapped,
                            onStopTapped: handleStopTapped
                        )
                    }
                    .zIndex(4)
                }
            }
        }
        .toolbar(cameraService.isRecording ? .hidden : .visible, for: .tabBar)
        .animation(.easeInOut(duration: 0.3), value: cameraService.isRecording)
        .task {
            let t = CFAbsoluteTimeGetCurrent()
            await setupCamera()
            print("⏱️ [RV] .task setupCamera completed in \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - t))s")
        }
        .sheet(isPresented: $showSettings) {
             // Let settings sheet handle dismissing correctly to unpause
            QuickSettingsSheet()
                .environmentObject(settings)
        }
        .sheet(isPresented: $showScriptPicker) {
            ScriptPickerSheet(selectedScript: $appState.currentScript)
        }
        .onDisappear {
            let t = CFAbsoluteTimeGetCurrent()
            let fmt = DateFormatter(); fmt.dateFormat = "HH:mm:ss.SSS"
            print("⏱️ [\(fmt.string(from: Date()))] [RV] onDisappear fired")
            // Only stop scrolling on tab switch; camera session stays alive
            // to avoid the expensive AVAudioSession teardown that freezes the UI
            // for ~10 seconds on the first stop/start cycle.
            teleprompterEngine.stopScrolling()
            print("⏱️ [\(fmt.string(from: Date()))] [RV] onDisappear completed in \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - t))s")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            let newOrientation = UIDevice.current.orientation
            if newOrientation.isLandscape || newOrientation == .portrait {
                deviceOrientation = newOrientation
            }
            cameraService.updateVideoOrientation(newOrientation)
        }
        .onAppear {
            let fmt = DateFormatter(); fmt.dateFormat = "HH:mm:ss.SSS"
            print("⏱️ [\(fmt.string(from: Date()))] [RV] onAppear fired, isConfigured=\(cameraService.isConfigured), isSessionRunning=\(cameraService.isSessionRunning)")
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            // Only restart the session if it was previously configured but stopped
            // (e.g. returning from background). Never start an unconfigured session —
            // setupCamera() handles the full configure→start sequence.
            if cameraService.isConfigured && !cameraService.isSessionRunning && !permissionDenied {
                cameraService.startSession()
            }
            cameraService.updateVideoOrientation(UIDevice.current.orientation)
        }
        .onChange(of: showSettings) { _, isShowing in
            if !isShowing && !cameraService.isSessionRunning && !permissionDenied {
                cameraService.startSession()
            }
        }
        .onChange(of: showScriptPicker) { _, isShowing in
            if !isShowing && !cameraService.isSessionRunning && !permissionDenied {
                cameraService.startSession()
            }
        }
        .onChange(of: settings.videoQuality) { _, _ in syncCameraSettings() }
        .onChange(of: settings.frameRate) { _, _ in syncCameraSettings() }
        .onChange(of: settings.stabilizationEnabled) { _, _ in syncCameraSettings() }
    }
    
    // MARK: - Methods
    
    // Formatting duration for Top HUD
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func setupCamera() async {
        // warmUp() runs at app launch and handles Phase 1 (video-only preview).
        // Here we just need to handle permissions and fallback if warmUp hasn't finished.
        print("⏱️ [RV] setupCamera: isConfigured=\(cameraService.isConfigured), isSessionRunning=\(cameraService.isSessionRunning)")
        
        await cameraService.checkPermissions()
        
        if cameraService.cameraPermission == .notDetermined {
            let granted = await cameraService.requestCameraPermission()
            if !granted {
                permissionDenied = true
                return
            }
        }
        
        if cameraService.microphonePermission == .notDetermined {
            _ = await cameraService.requestMicrophonePermission()
        }
        
        guard cameraService.cameraPermission == .authorized else {
            permissionDenied = true
            return
        }
        
        // If warmUp already configured + started, just apply settings
        if cameraService.isConfigured && cameraService.isSessionRunning {
            syncCameraSettings()
            return
        }
        
        // Fallback: warmUp hasn't completed yet, trigger it
        do {
            try await cameraService.configureSession()
            syncCameraSettings()
        } catch {
            print("Camera setup failed: \(error)")
        }
    }
    
    private func syncCameraSettings() {
        let fmt = DateFormatter(); fmt.dateFormat = "HH:mm:ss.SSS"
        print("⏱️ [\(fmt.string(from: Date()))] [RV] syncCameraSettings called")
        cameraService.applyVideoSettings(
            quality: settings.videoQuality,
            frameRate: settings.frameRate,
            stabilization: settings.stabilizationEnabled
        )
    }
    
    private func handleTapToFocus(at location: CGPoint, in size: CGSize) {
        let normalizedPoint = CGPoint(
            x: location.x / size.width,
            y: location.y / size.height
        )
        focusIndicatorPosition = location
        showFocusIndicator = true
        cameraService.setFocus(at: normalizedPoint)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showFocusIndicator = false
        }
    }
    
    // Track recording interaction state to avoid double-firing bugs
    @State private var isStartingRecording = false
    @State private var countdownTimer: Timer?
    
    private func handleRecordTapped() {
        guard !isStartingRecording && !cameraService.isRecording else { return }
        showCameraControls = false // dismiss controls if open
        
        if settings.showCountdown {
            startCountdown()
        } else {
            startRecording()
        }
    }
    
    private func startCountdown() {
        countdownValue = settings.countdownDuration
        showCountdown = true
        isStartingRecording = true
        
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] timer in
            Task { @MainActor in
                countdownValue -= 1
                if countdownValue <= 0 {
                    timer.invalidate()
                    showCountdown = false
                    startRecording()
                }
            }
        }
    }
    
    private func startRecording() {
        isStartingRecording = true
        Task {
            // Ensure audio is wired up before we begin (no-op if already ready)
            await cameraService.ensureAudioReady()
            
            if !cameraService.isSessionRunning {
                cameraService.startSession()
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
            }
            
            beginRecording()
            isStartingRecording = false
        }
    }
    
    private func beginRecording() {
        do {
            _ = try cameraService.startRecording()
            if let script = appState.currentScript {
                teleprompterEngine.configureForScript(script)
            }
            teleprompterEngine.resetToTop()
            teleprompterEngine.startScrolling()
        } catch {
            print("Recording failed: \(error)")
        }
    }
    
    private func handleStopTapped() {
        Task {
            do {
                let videoURL = try await cameraService.stopRecording()
                teleprompterEngine.stopScrolling()
                teleprompterEngine.resetToTop()
                
                let title = appState.currentScript?.title ?? Script.sample.title
                try await cameraService.exportToPhotos(videoURL: videoURL, scriptTitle: title)
                
                try? FileManager.default.removeItem(at: videoURL)
            } catch {
                print("Stop recording failed: \(error)")
            }
        }
    }
}

// MARK: - HUD Overlay
struct RecordingHUDView: View {
    let duration: TimeInterval
    let isPaused: Bool
    var onPauseToggled: () -> Void
    
    var body: some View {
        HStack {
            // REC Pill
            HStack(spacing: 8) {
                Image(systemName: "video.fill")
                    .foregroundColor(DesignSystem.Colors.destructive)
                    .modifier(PulsingModifier())
                
                Text("REC \(formatDuration(duration))")
                    .font(DesignSystem.Typography.headline.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .fontDesign(.monospaced)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .glassPanel(cornerRadius: 30)
            
            Spacer()
            
            HStack(spacing: 16) {
                // Pause Script Pill
                Button(action: onPauseToggled) {
                    HStack(spacing: 8) {
                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                            .foregroundColor(DesignSystem.Colors.primaryText)
                        Text(isPaused ? "RESUME" : "PAUSE SCRIPT")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                            .tracking(1.0)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .glassPanel(cornerRadius: 30)
                }
                
                Image(systemName: "sensors")
                    .font(.system(size: 18))
                    .foregroundColor(DesignSystem.Colors.accent)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16) // Safe area padding handled by safeGeo usually
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct PulsingModifier: ViewModifier {
    @State private var isPulsing = false
    
    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.3 : 1.0)
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

// MARK: - Countdown Overlay
struct CountdownOverlay: View {
    let value: Int
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            Text("\(value)")
                .font(.system(size: 150, weight: .bold))
                .foregroundColor(.white)
                .shadow(radius: 10)
        }
    }
}

// MARK: - Permission Denied View
struct PermissionDeniedView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                
                Text("Camera Access Required")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                
                Text("Please enable camera access in Settings to use the teleprompter.")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

// MARK: - Quick Settings Sheet
struct QuickSettingsSheet: View {
    @EnvironmentObject var settings: TeleprompterSettings
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Text") {
                    HStack {
                        Text("Font Size")
                        Slider(value: $settings.fontSize, in: TeleprompterSettings.fontSizeRange)
                        Text("\(Int(settings.fontSize))")
                            .frame(width: 30)
                    }
                }
                
                Section("Scrolling") {
                    HStack {
                        Text("Speed")
                        Slider(value: $settings.scrollSpeed, in: TeleprompterSettings.scrollSpeedRange)
                        Text("\(Int(settings.scrollSpeed))")
                            .frame(width: 30)
                    }
                }
                
                Section("Display") {
                    HStack {
                        Text("Background")
                        Slider(value: $settings.backgroundOpacity, in: TeleprompterSettings.opacityRange)
                        Text("\(Int(settings.backgroundOpacity * 100))%")
                            .frame(width: 40)
                    }
                }
            }
            .navigationTitle("Quick Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Script Picker Sheet
struct ScriptPickerSheet: View {
    @Binding var selectedScript: Script?
    @StateObject private var storage = ScriptStorageService()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List(storage.scripts) { script in
                Button {
                    selectedScript = script
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(script.title)
                                .font(.headline)
                                .foregroundColor(.primary)
                            let wordCount = script.content.split(separator: " ").count
                            Text("\(wordCount) words")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if selectedScript?.id == script.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
            .navigationTitle("Select Script")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                await storage.loadScripts()
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    RecordingView()
        .environmentObject(AppState())
        .environmentObject(TeleprompterSettings())
}

// MARK: - Camera Loading Overlay

/// Premium animated loading overlay shown during camera hardware initialization.
/// Displays a pulsing camera icon with animated gradient ring and branding.
struct CameraLoadingOverlay: View {
    @State private var ringRotation: Double = 0
    @State private var pulseScale: CGFloat = 0.95
    
    var body: some View {
        ZStack {
            // Full-bleed dark background
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 28) {
                Spacer()
                
                // Animated ring + camera icon
                ZStack {
                    // Outer gradient ring (rotating)
                    Circle()
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    DesignSystem.Colors.accentContainer.opacity(0.0),
                                    DesignSystem.Colors.accentContainer.opacity(0.3),
                                    DesignSystem.Colors.accent.opacity(0.8),
                                    DesignSystem.Colors.accent,
                                    DesignSystem.Colors.accentContainer.opacity(0.0)
                                ]),
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 88, height: 88)
                        .rotationEffect(.degrees(ringRotation))
                    
                    // Inner subtle ring
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        .frame(width: 72, height: 72)
                    
                    // Camera icon
                    Image(systemName: "video.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [DesignSystem.Colors.accent, DesignSystem.Colors.accentContainer],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(pulseScale)
                }
                
                // Status text
                VStack(spacing: 8) {
                    Text("Initializing Camera")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                    
                    Text("Setting up your recording session…")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(DesignSystem.Colors.primaryText.opacity(0.5))
                }
                
                Spacer()
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulseScale = 1.08
            }
        }
    }
}

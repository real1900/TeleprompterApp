import SwiftUI

/// Main recording view with camera preview, teleprompter overlay, and controls
struct RecordingView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var cameraService = CinematicCameraService()
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
                        CameraPreviewView(session: cameraService.captureSession)
                            .ignoresSafeArea()
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onEnded { value in
                                        handleTapToFocus(at: value.location, in: fullGeo.size)
                                    }
                            )
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
                                    settings: appState.settings,
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
                                    settings: appState.settings,
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
                                settings: appState.settings,
                                isLandscape: false
                            )
                            .frame(height: fullGeo.size.height * 0.45)
                            .padding(.top, cameraService.isRecording ? 60 : 0) // Leave space for HUD
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
            await setupCamera()
        }
        .sheet(isPresented: $showSettings) {
             // Let settings sheet handle dismissing correctly to unpause
            QuickSettingsSheet(settings: $appState.settings)
        }
        .sheet(isPresented: $showScriptPicker) {
            ScriptPickerSheet(selectedScript: $appState.currentScript)
        }
        .onDisappear {
            if !showSettings && !showScriptPicker {
                cameraService.stopSession()
                teleprompterEngine.stopScrolling()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            let newOrientation = UIDevice.current.orientation
            if newOrientation.isLandscape || newOrientation == .portrait {
                deviceOrientation = newOrientation
            }
            cameraService.updateVideoOrientation(newOrientation)
        }
        .onAppear {
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            if !cameraService.isSessionRunning && !permissionDenied {
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
        .onChange(of: appState.settings) { _, _ in
            syncCameraSettings()
        }
    }
    
    // MARK: - Methods
    
    // Formatting duration for Top HUD
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func setupCamera() async {
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
        
        do {
            try await cameraService.configureSession()
            syncCameraSettings()
            cameraService.startSession()
        } catch {
            print("Camera setup failed: \(error)")
        }
    }
    
    private func syncCameraSettings() {
        cameraService.applyVideoSettings(
            quality: appState.settings.videoQuality,
            frameRate: appState.settings.frameRate,
            stabilization: appState.settings.stabilizationEnabled
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
        
        if appState.settings.showCountdown {
            startCountdown()
        } else {
            startRecording()
        }
    }
    
    private func startCountdown() {
        countdownValue = appState.settings.countdownDuration
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
        if !cameraService.isSessionRunning {
            cameraService.startSession()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.beginRecording()
                self.isStartingRecording = false
            }
        } else {
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
                
                let title = appState.currentScript?.title
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
    @Binding var settings: TeleprompterSettings
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
}

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
            // Uses its own GeometryReader to capture full device dimensions for focus/aspect ratio
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
                    
                    // Focus indicator (Must be in Layer 1 to match full-screen tap coordinates)
                    FocusIndicatorView(
                        position: focusIndicatorPosition,

                        isVisible: showFocusIndicator
                    )
                    
                    // Teleprompter Overlay - adaptive to orientation
                    // MOVED TO LAYER 1 to allow background gradient to extend to top edge (status bar)
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
                            .clipped()
                            Spacer()
                        }
                    }
                    
                    // Countdown Overlay (also full screen)
                    if showCountdown {
                        CountdownOverlay(value: countdownValue)
                    }
                    
                    // Permission Request Overlay (also full screen)
                    if permissionDenied {
                        PermissionDeniedView()
                    }
                }
            }
            .ignoresSafeArea() // Allows video to fill behind notches and tab bars
            
            // LAYER 2: Controls & Interfaces (Respects Safe Area)
            // This ensures controls sit ABOVE the TabBar and dynamic island automatically
            GeometryReader { safeGeo in
                ZStack {
                    // Focus indicator (positioned absolutely based on tap, so might need full coords? 
                    // Actually focus indicator should track tap. Tap was in fullGeo. 
                    // But here we are in safeGeo. We might need to adjust or put FocusIndicator in Layer 1.
                    // For simplicity, let's put FocusIndicator in Layer 1? 
                    // Or Render it here with global offset. 
                    // Pivot: Put FocusIndicator in Layer 1 (inside Background).
                    

                    
                    // Camera Controls Overlay
                    if showCameraControls {
                        VStack {
                            Spacer()
                            CameraControlsOverlay(cameraService: cameraService)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 160) // Keep relative padding for visual hierarchy
                                .frame(maxWidth: safeGeo.size.width) // Prevent overflow expansion
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(2)
                    }
                    
                    // Recording Controls (bottom)
                    VStack {
                        Spacer()
                        RecordingControlsView(
                            cameraService: cameraService,
                            teleprompterEngine: teleprompterEngine,
                            showCameraControls: $showCameraControls,
                            onSettingsTapped: { showSettings = true },
                            onScriptTapped: { showScriptPicker = true },
                            onRecordTapped: handleRecordTapped,
                            onStopTapped: handleStopTapped
                        )
                        // No logic padding needed! The GeometryReader respects Safe Area (TabBar height), 
                        // so this will sit on top of the TabBar automatically.
                    }
                }
            }
        }
        // Removed global .ignoresSafeArea() to allow Layer 2 to respect bounds
        .toolbar(cameraService.isRecording ? .hidden : .visible, for: .tabBar)
        .animation(.easeInOut(duration: 0.3), value: cameraService.isRecording)
        .task {
            await setupCamera()
        }
        .sheet(isPresented: $showSettings) {
            QuickSettingsSheet(settings: $appState.settings)
        }
        .sheet(isPresented: $showScriptPicker) {
            ScriptPickerSheet(selectedScript: $appState.currentScript)
        }
        .onDisappear {
            // Only stop if we're actually leaving the screen (not just showing a sheet)
            // We'll rely on onAppear to restart if needed
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
            // Update camera connection orientation for Metal preview
            cameraService.updateVideoOrientation(newOrientation)
        }
        .onAppear {
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            // Restart session if it was stopped
            if !cameraService.isSessionRunning && !permissionDenied {
                cameraService.startSession()
            }
            // Ensure correct initial orientation
            cameraService.updateVideoOrientation(UIDevice.current.orientation)
        }
        .onChange(of: showSettings) { _, isShowing in
            // Restart session when settings sheet is dismissed
            if !isShowing && !cameraService.isSessionRunning && !permissionDenied {
                cameraService.startSession()
            }
        }
        .onChange(of: showScriptPicker) { _, isShowing in
            // Restart session when script picker sheet is dismissed
            if !isShowing && !cameraService.isSessionRunning && !permissionDenied {
                cameraService.startSession()
            }
        }
    }
    
    // MARK: - Methods
    
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
            cameraService.startSession()
        } catch {
            print("Camera setup failed: \(error)")
        }
    }
    
    private func handleTapToFocus(at location: CGPoint, in size: CGSize) {
        // Convert to normalized coordinates (0-1)
        let normalizedPoint = CGPoint(
            x: location.x / size.width,
            y: location.y / size.height
        )
        
        // Show focus indicator
        focusIndicatorPosition = location
        showFocusIndicator = true
        
        // Apply focus on camera
        cameraService.setFocus(at: normalizedPoint)
        
        // Hide indicator after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showFocusIndicator = false
        }
    }
    
    private func handleRecordTapped() {
        if appState.settings.showCountdown {
            startCountdown()
        } else {
            startRecording()
        }
    }
    
    private func startCountdown() {
        countdownValue = appState.settings.countdownDuration
        showCountdown = true
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] timer in
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
        // Ensure session is running before attempting to record
        if !cameraService.isSessionRunning {
            print("Session not running, starting session first...")
            cameraService.startSession()
            // Wait briefly for session to start, then try recording
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.beginRecording()
            }
        } else {
            beginRecording()
        }
    }
    
    private func beginRecording() {
        do {
            _ = try cameraService.startRecording()
            
            // Configure teleprompter engine with current script for WPM-based speed
            if let script = appState.currentScript {
                teleprompterEngine.configureForScript(script)
            }
            
            // START AUTO-SCROLLING when recording begins (with 2-second ease-in)
            teleprompterEngine.resetToTop()
            teleprompterEngine.startScrolling()
            print("Teleprompter scrolling started with 2s ease-in!")
        } catch {
            print("Recording failed: \(error)")
        }
    }
    
    private func handleStopTapped() {
        print("📹 handleStopTapped: Starting stop process")
        Task {
            do {
                print("📹 handleStopTapped: Calling stopRecording...")
                let videoURL = try await cameraService.stopRecording()
                print("📹 handleStopTapped: Got video URL: \(videoURL)")
                
                teleprompterEngine.stopScrolling()
                teleprompterEngine.resetToTop()
                
                // Export to Photos
                print("📹 handleStopTapped: Calling exportToPhotos...")
                try await cameraService.exportToPhotos(videoURL: videoURL)
                print("✅ handleStopTapped: Video exported successfully")
                
                // Clean up temp file after successful export
                try? FileManager.default.removeItem(at: videoURL)
                print("📹 handleStopTapped: Cleaned up temp file")
            } catch {
                print("❌ handleStopTapped: Stop recording failed: \(error)")
            }
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
                            Text("\(script.content.split(separator: " ").count) words")
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

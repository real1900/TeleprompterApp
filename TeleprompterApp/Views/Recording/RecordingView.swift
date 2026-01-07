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
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Camera Preview (full screen background)
                CameraPreviewView(session: cameraService.captureSession)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                handleTapToFocus(at: value.location, in: geometry.size)
                            }
                    )
                
                // Focus indicator
                FocusIndicatorView(
                    position: focusIndicatorPosition,
                    isVisible: showFocusIndicator
                )
                
                // Teleprompter Overlay (top portion, eye-contact optimized)
                // Uses top ~25% of screen with narrow column near camera
                VStack(spacing: 0) {
                    TeleprompterOverlay(
                        script: appState.currentScript ?? Script.sample,
                        engine: teleprompterEngine,
                        settings: appState.settings
                    )
                    .frame(height: geometry.size.height * 0.25)
                    .clipped()
                    
                    Spacer()
                }
                .ignoresSafeArea(edges: .top)
                
                // Camera Controls Overlay
                if showCameraControls {
                    VStack {
                        Spacer()
                        CameraControlsOverlay(cameraService: cameraService)
                            .padding(.bottom, 160)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
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
                }
                
                // Active filter badge
                if cameraService.activeFilter != .none {
                    VStack {
                        HStack {
                            Spacer()
                            FilterBadge(filter: cameraService.activeFilter)
                                .padding(.trailing, 16)
                                .padding(.top, 60)
                        }
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
        .animation(.spring(response: 0.3), value: showCameraControls)
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
            cameraService.stopSession()
            teleprompterEngine.stopScrolling()
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
        Task {
            do {
                let videoURL = try await cameraService.stopRecording()
                teleprompterEngine.stopScrolling()
                teleprompterEngine.resetToTop()
                
                // Export to Photos
                try await cameraService.exportToPhotos(videoURL: videoURL)
            } catch {
                print("Stop recording failed: \(error)")
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

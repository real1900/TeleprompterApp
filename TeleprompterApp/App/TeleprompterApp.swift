import SwiftUI

// MARK: - Main Thread Watchdog (DEBUG ONLY)
// Detects when the main thread is blocked for >500ms and prints a warning.
// Remove this class once performance debugging is complete.
class MainThreadWatchdog {
    private let watchdogQueue = DispatchQueue(label: "com.teleprompter.watchdog")
    private let threshold: TimeInterval = 0.5 // 500ms
    private var isRunning = false
    private let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()
    
    func start() {
        guard !isRunning else { return }
        isRunning = true
        scheduleCheck()
    }
    
    private func scheduleCheck() {
        guard isRunning else { return }
        let deadline = CFAbsoluteTimeGetCurrent()
        var mainResponded = false
        
        // Ask main thread to respond
        DispatchQueue.main.async {
            mainResponded = true
        }
        
        // Check after threshold
        watchdogQueue.asyncAfter(deadline: .now() + threshold) { [weak self] in
            guard let self = self else { return }
            if !mainResponded {
                let blocked = CFAbsoluteTimeGetCurrent() - deadline
                // Capture main thread backtrace
                let bt = Thread.callStackSymbols.joined(separator: "\n  ")
                print("🚨 [\(self.fmt.string(from: Date()))] MAIN THREAD BLOCKED for >\(String(format: "%.1f", blocked))s")
                print("🔍 Watchdog thread stack:\n  \(bt)")
                
                // Keep checking until main responds
                self.waitForMainToRespond(since: deadline)
            } else {
                self.scheduleCheck()
            }
        }
    }
    
    private func waitForMainToRespond(since startTime: CFAbsoluteTime) {
        var responded = false
        DispatchQueue.main.async {
            responded = true
        }
        
        watchdogQueue.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            if !responded {
                print("🚨 [\(self.fmt.string(from: Date()))] MAIN THREAD STILL BLOCKED — \(String(format: "%.1f", elapsed))s total")
                self.waitForMainToRespond(since: startTime)
            } else {
                print("✅ [\(self.fmt.string(from: Date()))] Main thread unblocked after \(String(format: "%.1f", elapsed))s")
                self.scheduleCheck()
            }
        }
    }
}

@main
struct TeleprompterApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var cameraService = CinematicCameraService()
    @StateObject private var scriptStorage = ScriptStorageService()
    @StateObject private var settings = TeleprompterSettings()
    private let watchdog = MainThreadWatchdog()
    
    init() {
        // Pre-warm the CoreData SQLite stack on boot to prevent lazy initialization deadlocks
        // when jumping directly to RecordingGalleryView's background fetch.
        _ = VideoMetadataCache.shared
    }
    
    private func preWarmCamera() {
        cameraService.warmUp(quality: settings.videoQuality)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(cameraService)
                .environmentObject(scriptStorage)
                .environmentObject(settings)
                .onAppear {
                    preWarmCamera()
                    watchdog.start()
                }
        }
    }
}

/// Global app state for sharing across views
@MainActor
class AppState: ObservableObject {
    @Published var currentScript: Script?
}

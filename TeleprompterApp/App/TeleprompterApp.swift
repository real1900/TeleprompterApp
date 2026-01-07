import SwiftUI

@main
struct TeleprompterApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

/// Global app state for sharing across views
@MainActor
class AppState: ObservableObject {
    @Published var currentScript: Script?
    @Published var settings: TeleprompterSettings = .default
    
    init() {
        loadSettings()
    }
    
    func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "teleprompterSettings"),
           let decoded = try? JSONDecoder().decode(TeleprompterSettings.self, from: data) {
            settings = decoded
        }
    }
    
    func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: "teleprompterSettings")
        }
    }
}

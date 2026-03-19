import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: Tab = .record
    
    enum Tab {
        case scripts
        case gallery
        case record
        case settings
    }
    
    init() {
        // Configure tab bar with premium translucent dark appearance
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        
        // Unselected icon color mapping
        UITabBar.appearance().unselectedItemTintColor = UIColor(white: 0.6, alpha: 1)
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ScriptListView()
                .tabItem {
                    Label("Scripts", systemImage: "doc.text")
                }
                .tag(Tab.scripts)
                
            RecordingGalleryView()
                .tabItem {
                    Label("Gallery", systemImage: "photo.on.rectangle")
                }
                .tag(Tab.gallery)
            
            RecordingView()
                .tabItem {
                    Label("Record", systemImage: "video.fill")
                }
                .tag(Tab.record)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(Tab.settings)
        }
        .tint(DesignSystem.Colors.accent)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}

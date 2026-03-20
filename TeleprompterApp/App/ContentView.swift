import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var cameraService: CinematicCameraService
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: Tab = .record
    
    enum Tab {
        case scripts
        case gallery
        case record
        case settings
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // RecordingView is ALWAYS alive to avoid destroying/recreating
            // CameraPreviewView (which triggers a 10s+ AVFoundation deadlock
            // when AVCaptureVideoPreviewLayer is disconnected from a running session).
            RecordingView()
                .safeAreaInset(edge: .bottom) {
                    CustomTabBar(selectedTab: $selectedTab)
                        .opacity(0)
                        .allowsHitTesting(false)
                }
                .opacity(selectedTab == .record ? 1 : 0)
                .allowsHitTesting(selectedTab == .record)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Other tabs use switch (lightweight, no expensive teardown)
            if selectedTab != .record {
                Group {
                    switch selectedTab {
                    case .scripts:
                        ScriptListView()
                    case .gallery:
                        RecordingGalleryView()
                    case .settings:
                        SettingsView()
                    case .record:
                        EmptyView() // Never reached
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // Floating Tab Bar
            CustomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                cameraService.stopSession()
            case .active:
                if selectedTab == .record && !cameraService.isSessionRunning {
                    cameraService.startSession()
                }
            default:
                break
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: ContentView.Tab
    @Namespace private var tabNamespace
    
    var body: some View {
        HStack(spacing: 0) {
            TabBarButton(
                tab: .scripts,
                title: "Scripts",
                icon: "doc.text",
                selectedTab: $selectedTab,
                namespace: tabNamespace
            )
            
            TabBarButton(
                tab: .record,
                title: "Recorder", 
                icon: "record.circle.fill",
                selectedTab: $selectedTab,
                namespace: tabNamespace
            )
            
            TabBarButton(
                tab: .gallery,
                title: "Gallery",
                icon: "photo.on.rectangle",
                selectedTab: $selectedTab,
                namespace: tabNamespace
            )
            
            TabBarButton(
                tab: .settings,
                title: "Settings",
                icon: "gearshape.fill",
                selectedTab: $selectedTab,
                namespace: tabNamespace
            )
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(Color(hexString: "#2a2a2a").opacity(0.6))
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 20)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

struct TabBarButton: View {
    let tab: ContentView.Tab
    let title: String
    let icon: String // SF Symbol
    @Binding var selectedTab: ContentView.Tab
    let namespace: Namespace.ID
    
    var isSelected: Bool {
        selectedTab == tab
    }
    
    var body: some View {
        Button(action: {
            let t = CFAbsoluteTimeGetCurrent()
            let fmt = DateFormatter()
            fmt.dateFormat = "HH:mm:ss.SSS"
            print("⏱️ [\(fmt.string(from: Date()))] [TAB] switching to \(tab) ...")
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
            print("⏱️ [\(fmt.string(from: Date()))] [TAB] selectedTab set in \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - t))s")
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .frame(height: 24)
                Text(title)
                    .font(DesignSystem.Typography.label)
                    .fontWeight(isSelected ? .bold : .medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundColor(isSelected ? Color(hexString: "#131313") : DesignSystem.Colors.primaryText.opacity(0.5))
            .background {
                if isSelected {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(hexString: "#ffb4aa"), Color(hexString: "#ff5545")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color(hexString: "#ff5545").opacity(0.3), radius: 8, x: 0, y: 4)
                        .matchedGeometryEffect(id: "TAB_BACKGROUND", in: namespace)
                }
            }
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

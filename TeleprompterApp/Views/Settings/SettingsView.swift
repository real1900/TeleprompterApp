import SwiftUI

/// Full settings screen with all teleprompter configuration options
/// Updated to match the high-fidelity native Stitch GoPrompt UI.
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingResetAlert = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        
                        // Screen Header matching Stitch HTML
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Settings")
                                .font(DesignSystem.Typography.largeTitle)
                                .foregroundColor(DesignSystem.Colors.primaryText)
                            Text("Configuration & Performance")
                                .font(DesignSystem.Typography.label)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                                .textCase(.uppercase)
                                .tracking(2.0)
                        }
                        .padding(.top, 24)
                        
                        // Prompter Settings Section
                        settingsSection(title: "Prompter Settings") {
                            VStack(spacing: 0) {
                                SettingsRow(
                                    icon: "arrow.left.and.right.righttriangle.left.righttriangle.right",
                                    title: "Mirroring",
                                    subtitle: "Horizontal Reflection",
                                    isLast: false
                                ) {
                                    Toggle("", isOn: $appState.settings.mirrorText)
                                        .labelsHidden()
                                        .tint(DesignSystem.Colors.accentContainer)
                                }
                                
                                SettingsRow(
                                    icon: "speedometer",
                                    title: "Speed",
                                    subtitle: "Words per minute",
                                    isLast: false
                                ) {
                                    Stepper(value: $appState.settings.scrollSpeed, in: TeleprompterSettings.scrollSpeedRange, step: 5) {
                                        Text("\(Int(appState.settings.scrollSpeed)) WPM")
                                            .font(DesignSystem.Typography.label)
                                            .foregroundColor(DesignSystem.Colors.secondary)
                                            .bold()
                                    }
                                    .labelsHidden()
                                    .frame(width: 100)
                                    .overlay(alignment: .leading) {
                                        Text("\(Int(appState.settings.scrollSpeed)) WPM")
                                            .font(DesignSystem.Typography.label)
                                            .foregroundColor(DesignSystem.Colors.secondary)
                                            .bold()
                                            .offset(x: -60)
                                    }
                                }
                                
                                SettingsRow(
                                    icon: "textformat.size",
                                    title: "Font Size",
                                    subtitle: "Optimal reading scale",
                                    isLast: true
                                ) {
                                    Stepper(value: $appState.settings.fontSize, in: TeleprompterSettings.fontSizeRange, step: 2) {
                                        Text("\(Int(appState.settings.fontSize))pt")
                                    }
                                    .labelsHidden()
                                    .frame(width: 100)
                                    .overlay(alignment: .leading) {
                                        Text("\(Int(appState.settings.fontSize))pt")
                                            .font(DesignSystem.Typography.label)
                                            .foregroundColor(DesignSystem.Colors.secondaryText)
                                            .offset(x: -50)
                                    }
                                }
                            }
                        }
                        
                        // Camera Settings Section
                        settingsSection(title: "Camera Settings") {
                            VStack(spacing: 0) {
                                SettingsRow(
                                    icon: "4k.tv",
                                    title: "Resolution",
                                    subtitle: "4K UHD High Dynamic Range",
                                    isLast: false
                                ) {
                                    HStack(spacing: 8) {
                                        Text("PRO")
                                            .font(.system(size: 10, weight: .bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(DesignSystem.Colors.secondaryContainer.opacity(0.2))
                                            .foregroundColor(DesignSystem.Colors.secondary)
                                            .cornerRadius(4)
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(DesignSystem.Colors.secondaryText)
                                    }
                                }
                                
                                SettingsRow(
                                    icon: "camera.aperture",
                                    title: "Frame Rate",
                                    subtitle: "Cinematic Standard",
                                    isLast: false
                                ) {
                                    Text("24 FPS")
                                        .font(DesignSystem.Typography.label)
                                        .foregroundColor(DesignSystem.Colors.secondaryText)
                                }
                                
                                SettingsRow(
                                    icon: "video.badge.checkmark",
                                    title: "Stabilization",
                                    subtitle: "Digital Gimbal Mode",
                                    isLast: true
                                ) {
                                    Toggle("", isOn: .constant(false))
                                        .labelsHidden()
                                        .tint(DesignSystem.Colors.accentContainer)
                                }
                            }
                        }
                        
                        // Account Section
                        settingsSection(title: "Account") {
                            VStack(spacing: 0) {
                                SettingsRow(
                                    icon: "person.crop.circle",
                                    title: "Profile",
                                    subtitle: "Director ID: #8829",
                                    isLast: false
                                ) {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(DesignSystem.Colors.secondaryText)
                                }
                                
                                SettingsRow(
                                    icon: "rosette",
                                    title: "Subscription",
                                    subtitle: "Obsidian Elite • Active",
                                    iconColor: DesignSystem.Colors.secondary,
                                    isLast: true
                                ) {
                                    Text("MANAGE")
                                        .font(DesignSystem.Typography.label)
                                        .foregroundColor(DesignSystem.Colors.secondary)
                                        .tracking(1.0)
                                }
                            }
                        }
                        
                        // Footer
                        VStack(spacing: 8) {
                            Text("GOPROMPT BUILD V1.0.0")
                                .font(.system(size: 10, weight: .medium, design: .default))
                                .foregroundColor(DesignSystem.Colors.secondaryText.opacity(0.4))
                                .tracking(2.0)
                            
                            Button(action: {
                                showingResetAlert = true
                            }) {
                                Text("RESET SETTINGS")
                                    .font(.system(size: 12, weight: .semibold, design: .default))
                                    .foregroundColor(DesignSystem.Colors.destructive)
                                    .tracking(1.0)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 16)
                        .padding(.bottom, 100)
                    }
                    .padding(.horizontal, DesignSystem.Layout.paddingLarge)
                }
            }
            // Hide default nav bar since we use custom Stitch header styles internally if needed
            .navigationBarHidden(true)
            .alert("Reset Settings?", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    appState.settings = .default
                    appState.saveSettings()
                }
            } message: {
                Text("This will reset all settings to their default values.")
            }
            .onChange(of: appState.settings) { _, _ in
                appState.saveSettings()
            }
        }
    }
    
    // MARK: - Section Container
    
    @ViewBuilder
    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .default))
                .foregroundColor(DesignSystem.Colors.secondary)
                .textCase(.uppercase)
                .tracking(1.0)
                .padding(.leading, 4)
            
            content()
                .glassPanel(cornerRadius: DesignSystem.Layout.cornerRadiusStandard)
        }
    }
}

// MARK: - Custom List Row for Settings
struct SettingsRow<Action: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    var iconColor: Color = DesignSystem.Colors.accent
    let isLast: Bool
    @ViewBuilder let action: () -> Action
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Icon Box
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(DesignSystem.Colors.surfaceHighest)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(iconColor)
                    )
                
                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                    Text(subtitle)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
                
                Spacer()
                
                // Right Action View
                action()
            }
            .padding(20)
            
            if !isLast {
                Divider()
                    .background(Color.white.opacity(0.05))
                    .padding(.horizontal, 20)
            }
        }
        // Hover/Active effect placeholder
        .contentShape(Rectangle())
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}

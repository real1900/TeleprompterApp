import SwiftUI

/// Full settings screen with all teleprompter configuration options
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var showingResetAlert = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Text Settings
                        settingsSection(title: "Text", footer: "Adjust the font size and line spacing to match your reading comfort.") {
                            fontSizeRow
                            Divider().background(Color.white.opacity(0.1))
                            lineSpacingRow
                            Divider().background(Color.white.opacity(0.1))
                            textColorRow
                        }
                        
                        // Scrolling Settings
                        settingsSection(title: "Scrolling", footer: "Slower speeds are better for beginners. The teleprompter pauses when you tap during recording.") {
                            scrollSpeedRow
                        }
                        
                        // Appearance Settings
                        settingsSection(title: "Appearance") {
                            backgroundOpacityRow
                            Divider().background(Color.white.opacity(0.1))
                            mirrorTextRow
                        }
                        
                        // Recording Settings
                        settingsSection(title: "Recording") {
                            countdownToggle
                            if appState.settings.showCountdown {
                                Divider().background(Color.white.opacity(0.1))
                                countdownDurationRow
                            }
                        }
                        
                        // Reset Settings
                        settingsSection(title: "Reset") {
                            Button(role: .destructive) {
                                showingResetAlert = true
                            } label: {
                                HStack {
                                    Spacer()
                                    Text("Reset to Defaults")
                                        .bold()
                                    Spacer()
                                }
                            }
                        }
                        
                        // App Info
                        settingsSection(title: "About") {
                            HStack {
                                Text("Version")
                                Spacer()
                                Text("1.0.0")
                                    .foregroundColor(DesignSystem.Colors.secondaryText)
                            }
                        }
                    }
                    .padding(DesignSystem.Layout.paddingStandard)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(.dark)
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
    
    // MARK: - Section Helper
    
    private func settingsSection<Content: View>(title: String, footer: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .padding(.leading, 8)
            
            VStack(spacing: 16) {
                content()
            }
            .padding(DesignSystem.Layout.paddingStandard)
            .glassPanel(cornerRadius: DesignSystem.Layout.cornerRadiusStandard)
            
            if let footer = footer {
                Text(footer)
                    .font(.caption2)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .padding(.leading, 8)
            }
        }
    }
    
    // MARK: - Row Views
    
    private var fontSizeRow: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Font Size")
                Spacer()
                Text("\(Int(appState.settings.fontSize)) pt")
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            
            Slider(
                value: $appState.settings.fontSize,
                in: TeleprompterSettings.fontSizeRange,
                step: 2
            ) {
                Text("Font Size")
            } minimumValueLabel: {
                Text("A")
                    .font(.caption)
            } maximumValueLabel: {
                Text("A")
                    .font(.title2)
            }
        }
    }
    
    private var lineSpacingRow: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Line Spacing")
                Spacer()
                Text("\(Int(appState.settings.lineSpacing)) pt")
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            
            Slider(
                value: $appState.settings.lineSpacing,
                in: 0...24,
                step: 2
            )
        }
    }
    
    private var textColorRow: some View {
        ColorPicker("Text Color", selection: Binding(
            get: { appState.settings.textColor },
            set: { newColor in
                if let hex = newColor.toHex() {
                    appState.settings.textColorHex = hex
                }
            }
        ))
    }
    
    private var scrollSpeedRow: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Scroll Speed")
                Spacer()
                Text(speedLabel)
                    .foregroundColor(.secondary)
            }
            
            Slider(
                value: $appState.settings.scrollSpeed,
                in: TeleprompterSettings.scrollSpeedRange,
                step: 5
            ) {
                Text("Speed")
            } minimumValueLabel: {
                Image(systemName: "tortoise")
                    .font(.caption)
            } maximumValueLabel: {
                Image(systemName: "hare")
                    .font(.caption)
            }
        }
    }
    
    private var speedLabel: String {
        let speed = appState.settings.scrollSpeed
        if speed < 40 {
            return "Slow"
        } else if speed < 80 {
            return "Normal"
        } else if speed < 140 {
            return "Fast"
        } else {
            return "Very Fast"
        }
    }
    
    private var backgroundOpacityRow: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Background Opacity")
                Spacer()
                Text("\(Int(appState.settings.backgroundOpacity * 100))%")
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            
            Slider(
                value: $appState.settings.backgroundOpacity,
                in: TeleprompterSettings.opacityRange
            )
            
            // Preview
            HStack {
                Spacer()
                Text("Preview")
                    .font(.caption)
                    .foregroundColor(appState.settings.textColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(appState.settings.backgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Spacer()
            }
            .padding(.top, 8)
        }
    }
    
    private var mirrorTextRow: some View {
        Toggle("Mirror Text", isOn: $appState.settings.mirrorText)
    }
    
    private var countdownToggle: some View {
        Toggle("Show Countdown", isOn: $appState.settings.showCountdown)
    }
    
    private var countdownDurationRow: some View {
        Stepper(
            "Countdown: \(appState.settings.countdownDuration) seconds",
            value: $appState.settings.countdownDuration,
            in: 1...10
        )
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}

import SwiftUI

/// Full settings screen with all teleprompter configuration options
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var showingResetAlert = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Text Settings
                Section {
                    fontSizeRow
                    lineSpacingRow
                    textColorRow
                } header: {
                    Text("Text")
                } footer: {
                    Text("Adjust the font size and line spacing to match your reading comfort.")
                }
                
                // Scrolling Settings
                Section {
                    scrollSpeedRow
                } header: {
                    Text("Scrolling")
                } footer: {
                    Text("Slower speeds are better for beginners. The teleprompter pauses when you tap during recording.")
                }
                
                // Appearance Settings
                Section {
                    backgroundOpacityRow
                    mirrorTextRow
                } header: {
                    Text("Appearance")
                }
                
                // Recording Settings
                Section {
                    countdownToggle
                    if appState.settings.showCountdown {
                        countdownDurationRow
                    }
                } header: {
                    Text("Recording")
                }
                
                // Reset Settings
                Section {
                    Button("Reset to Defaults", role: .destructive) {
                        showingResetAlert = true
                    }
                }
                
                // App Info
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
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

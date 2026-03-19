import SwiftUI

/// Professional camera controls overlay with expandable panels
struct CameraControlsOverlay: View {
    @ObservedObject var cameraService: CinematicCameraService
    
    @State private var expandedPanel: ControlPanel? = nil
    @State private var showFilterPicker = false
    
    enum ControlPanel {
        case focus, exposure, whiteBalance, filter, depth, quality
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Expanded panel content
            if let panel = expandedPanel {
                panelContent(for: panel)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Control buttons bar
            VStack(spacing: 12) {
                // Row 1: Camera Basics & Face Tracking
                HStack(spacing: 16) {
                    // Focus
                    ControlPanelButton(
                        icon: cameraService.focusMode.systemImage,
                        label: "Focus",
                        isActive: expandedPanel == .focus
                    ) {
                        togglePanel(.focus)
                    }
                    
                    // Exposure
                    ControlPanelButton(
                        icon: cameraService.exposureMode.systemImage,
                        label: "Expo",
                        isActive: expandedPanel == .exposure
                    ) {
                        togglePanel(.exposure)
                    }
                    
                    // White Balance
                    ControlPanelButton(
                        icon: cameraService.whiteBalanceMode.systemImage,
                        label: "WB",
                        isActive: expandedPanel == .whiteBalance
                    ) {
                        togglePanel(.whiteBalance)
                    }
                    
                    // Center Stage (Face Tracking)
                    ControlPanelButton(
                        icon: cameraService.centerStageEnabled ? "person.crop.rectangle.fill" : "person.crop.rectangle",
                        label: "Track",
                        isActive: cameraService.centerStageEnabled
                    ) {
                        cameraService.toggleCenterStage()
                    }
                }
                
                // Row 2: Effects & Quality
                HStack(spacing: 16) {
                    // Filter
                    ControlPanelButton(
                        icon: "camera.filters",
                        label: cameraService.activeFilter == .none ? "Filter" : cameraService.activeFilter.rawValue,
                        isActive: cameraService.activeFilter != .none
                    ) {
                        showFilterPicker = true
                    }
                    
                    // Depth (Portrait Mode)
                    ControlPanelButton(
                        icon: cameraService.depthEnabled ? "camera.aperture" : "camera.aperture",
                        label: "Blur",
                        isActive: expandedPanel == .depth || cameraService.depthEnabled
                    ) {
                        togglePanel(.depth)
                    }
                    
                    // Green Screen
                    ControlPanelButton(
                        icon: "person.crop.rectangle.badge.plus",
                        label: "Green",
                        isActive: cameraService.greenScreenEnabled
                    ) {
                        cameraService.greenScreenEnabled.toggle()
                    }
                    
                    // Quality
                    ControlPanelButton(
                        icon: "video.fill",
                        label: cameraService.videoQuality.rawValue,
                        isActive: expandedPanel == .quality
                    ) {
                        togglePanel(.quality)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Layout.paddingStandard)
            .padding(.vertical, 12)
            .glassPanel(cornerRadius: DesignSystem.Layout.cornerRadiusLarge)
            .padding(.horizontal, DesignSystem.Layout.paddingStandard)
        }
        .padding(.horizontal, DesignSystem.Layout.paddingStandard)
        .sheet(isPresented: $showFilterPicker) {
            FilterPickerSheet(selectedFilter: $cameraService.activeFilter)
                .presentationDetents([.medium])
        }
    }
    
    private func togglePanel(_ panel: ControlPanel) {
        withAnimation(.spring(response: 0.3)) {
            expandedPanel = expandedPanel == panel ? nil : panel
        }
    }
    
    @ViewBuilder
    private func panelContent(for panel: ControlPanel) -> some View {
        VStack(spacing: 12) {
            switch panel {
            case .focus:
                FocusControlPanel(cameraService: cameraService)
            case .exposure:
                ExposureControlPanel(cameraService: cameraService)
            case .whiteBalance:
                WhiteBalanceControlPanel(cameraService: cameraService)
            case .filter:
                EmptyView() // Filter uses sheet, not inline panel
            case .depth:
                DepthControlPanel(cameraService: cameraService)
            case .quality:
                QualityControlPanel(cameraService: cameraService)
            }
        }
        .padding(DesignSystem.Layout.paddingStandard)
        .glassPanel(cornerRadius: DesignSystem.Layout.cornerRadiusLarge)
    }
}

// MARK: - Control Panel Button

struct ControlPanelButton: View {
    let icon: String
    let label: String
    var isActive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(label)
                    .font(DesignSystem.Typography.caption)
            }
            .foregroundColor(isActive ? DesignSystem.Colors.accent : DesignSystem.Colors.primaryText)
            .frame(minWidth: 50)
        }
    }
}

// MARK: - Focus Control Panel

struct FocusControlPanel: View {
    @ObservedObject var cameraService: CinematicCameraService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FOCUS")
                .font(.caption.bold())
                .foregroundColor(.secondary)
            
            // Focus mode picker
            HStack(spacing: 8) {
                ForEach(FocusMode.allCases) { mode in
                    Button {
                        cameraService.focusMode = mode
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: mode.systemImage)
                            Text(mode.rawValue)
                                .font(.caption2)
                        }
                        .foregroundColor(cameraService.focusMode == mode ? DesignSystem.Colors.accent : DesignSystem.Colors.primaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(cameraService.focusMode == mode ? DesignSystem.Colors.accent.opacity(0.2) : Color.clear)
                        .cornerRadius(8)
                    }
                }
            }
            
            // Manual focus slider
            if cameraService.focusMode == .manual {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Focus Distance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        Text("Near")
                            .font(.caption2)
                        Slider(value: $cameraService.focusPosition, in: 0...1)
                            .tint(.red)
                        Text("Far")
                            .font(.caption2)
                    }
                }
            }
        }
    }
}

// MARK: - Exposure Control Panel

struct ExposureControlPanel: View {
    @ObservedObject var cameraService: CinematicCameraService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("EXPOSURE")
                .font(.caption.bold())
                .foregroundColor(.secondary)
            
            // Exposure compensation slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("EV")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%+.1f", cameraService.exposureCompensation))
                        .font(.caption.monospacedDigit())
                }
                Slider(value: $cameraService.exposureCompensation, in: -3...3)
                    .tint(.red)
            }
            
            // Exposure mode picker
            HStack(spacing: 8) {
                ForEach(ExposureMode.allCases) { mode in
                    Button {
                        cameraService.exposureMode = mode
                    } label: {
                        Text(mode.rawValue)
                            .font(.caption)
                            .foregroundColor(cameraService.exposureMode == mode ? DesignSystem.Colors.accent : DesignSystem.Colors.primaryText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(cameraService.exposureMode == mode ? DesignSystem.Colors.accent.opacity(0.2) : Color.clear)
                            .cornerRadius(6)
                    }
                }
            }
            
            // Manual controls
            if cameraService.exposureMode == .manual {
                VStack(spacing: 8) {
                    HStack {
                        Text("ISO")
                            .font(.caption)
                            .frame(width: 60, alignment: .leading)
                        Slider(value: $cameraService.iso, in: cameraService.minISO...cameraService.maxISO)
                            .tint(.red)
                        Text("\(Int(cameraService.iso))")
                            .font(.caption.monospacedDigit())
                            .frame(width: 50)
                    }
                }
            }
        }
    }
}

// MARK: - White Balance Control Panel

struct WhiteBalanceControlPanel: View {
    @ObservedObject var cameraService: CinematicCameraService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WHITE BALANCE")
                .font(.caption.bold())
                .foregroundColor(.secondary)
            
            // Preset buttons (scrollable)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(WhiteBalanceMode.allCases) { mode in
                        Button {
                            cameraService.whiteBalanceMode = mode
                        } label: {
                            VStack(spacing: 4) {
                                Text(mode.rawValue)
                                    .font(.caption2)
                            }
                            .foregroundColor(cameraService.whiteBalanceMode == mode ? DesignSystem.Colors.accent : DesignSystem.Colors.primaryText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(cameraService.whiteBalanceMode == mode ? DesignSystem.Colors.accent.opacity(0.2) : Color.clear)
                            .cornerRadius(8)
                        }
                    }
                }
            }
            
            // Manual controls
            if cameraService.whiteBalanceMode == .locked {
                VStack(spacing: 8) {
                    HStack {
                        Text("Temp")
                            .font(.caption)
                            .frame(width: 50, alignment: .leading)
                        Slider(value: $cameraService.colorTemperature, in: 2500...10000)
                            .tint(.orange)
                        Text("\(Int(cameraService.colorTemperature))K")
                            .font(.caption.monospacedDigit())
                            .frame(width: 60)
                    }
                    
                    HStack {
                        Text("Tint")
                            .font(.caption)
                            .frame(width: 50, alignment: .leading)
                        Slider(value: $cameraService.tint, in: -150...150)
                            .tint(.green)
                        Text(String(format: "%+.0f", cameraService.tint))
                            .font(.caption.monospacedDigit())
                            .frame(width: 60)
                    }
                }
            }
        }
    }
}

// MARK: - Quality Control Panel

struct QualityControlPanel: View {
    @ObservedObject var cameraService: CinematicCameraService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("VIDEO QUALITY")
                .font(.caption.bold())
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                ForEach(VideoQuality.allCases) { quality in
                    Button {
                        cameraService.videoQuality = quality
                    } label: {
                        Text(quality.rawValue)
                            .font(.caption.bold())
                            .foregroundColor(cameraService.videoQuality == quality ? .black : DesignSystem.Colors.primaryText)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(cameraService.videoQuality == quality ? DesignSystem.Colors.accent : Color.white.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
            }
        }
    }
}

// MARK: - Depth Control Panel

struct DepthControlPanel: View {
    @ObservedObject var cameraService: CinematicCameraService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BLUR BACKGROUND")
                .font(.caption.bold())
                .foregroundColor(.secondary)
            
            // Portrait Effect Toggle
            HStack {
                Text("Background Blur")
                    .font(.caption)
                Spacer()
                Toggle("", isOn: $cameraService.depthEnabled)
                    .labelsHidden()
                    .tint(.red)
            }
            
            // Aperture slider (when depth is enabled)
            if cameraService.depthEnabled {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Aperture")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("f/\(String(format: "%.1f", cameraService.simulatedAperture))")
                            .font(.caption.monospacedDigit())
                    }
                    HStack {
                        Text("More blur")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Slider(
                            value: $cameraService.simulatedAperture,
                            in: CinematicCameraService.minAperture...CinematicCameraService.maxAperture
                        )
                        .tint(DesignSystem.Colors.accent)
                        Text("Less blur")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Info text
            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundColor(.blue)
                Text("Background blur creates a cinematic look.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
        }
    }
}

// MARK: - Filter Picker Sheet

struct FilterPickerSheet: View {
    @Binding var selectedFilter: CameraFilter
    @Environment(\.dismiss) private var dismiss
    
    let columns = [GridItem(.adaptive(minimum: 80))]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Notice banner
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text("Filter preview coming soon. Selected filter will be applied to saved video.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
                .padding(.top)
                
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(CameraFilter.allCases) { filter in
                            Button {
                                selectedFilter = filter
                                dismiss()
                            } label: {
                                VStack(spacing: 8) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(filterPreviewColor(for: filter))
                                        .frame(width: 60, height: 60)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(selectedFilter == filter ? Color.red : Color.clear, lineWidth: 3)
                                        )
                                    
                                    Text(filter.rawValue)
                                        .font(.caption)
                                        .foregroundColor(selectedFilter == filter ? .red : .primary)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func filterPreviewColor(for filter: CameraFilter) -> Color {
        switch filter {
        case .none: return .gray
        case .vivid, .vividWarm: return .orange
        case .vividCool: return .cyan
        case .dramatic, .dramaticWarm: return .indigo
        case .dramaticCool: return .blue
        case .mono, .noir: return .black
        case .silvertone: return .gray
        case .sepia: return .brown
        case .chrome: return .purple
        case .fade: return .mint
        case .instant: return .pink
        case .process: return .teal
        case .transfer: return .red
        case .cinematic: return .red
        }
    }
}

// MARK: - Filter Badge

struct FilterBadge: View {
    let filter: CameraFilter
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "camera.filters")
                .font(.caption)
            Text(filter.rawValue)
                .font(.caption.bold())
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.purple.opacity(0.8))
        .clipShape(Capsule())
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            Spacer()
            CameraControlsOverlay(cameraService: CinematicCameraService())
                .padding(.bottom, 100)
        }
    }
}

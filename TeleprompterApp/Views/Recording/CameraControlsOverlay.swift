import SwiftUI

/// Professional camera controls overlay derived from Stitch HUD design
struct CameraControlsOverlay: View {
    @ObservedObject var cameraService: CinematicCameraService
    @State private var showFilterPicker = false
    
    
    private var exposureRow: some View {
        VStack(spacing: 12) {
            HStack {
                Text("EXPOSURE BIAS")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(DesignSystem.Colors.accent)
                    .tracking(2.0)
                
                Spacer()
                
                Text("\(cameraService.exposureCompensation > 0 ? "+" : "")\(String(format: "%.1f", cameraService.exposureCompensation)) EV")
                    .font(DesignSystem.Typography.headline.weight(.bold))
                    .foregroundColor(DesignSystem.Colors.accent)
            }
            
            // Slider Track
            ZStack(alignment: .center) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(white: 0.15))
                    .frame(height: 48)
                
                // Real visible slider over top
                Slider(value: $cameraService.exposureCompensation, in: -3...3, step: 0.1)
                    .tint(DesignSystem.Colors.accent)
                    .padding(.horizontal, 16)
                    .frame(height: 48)
            }
        }
    }
    
    private var gridRow: some View {
        HStack(spacing: 12) {
            // Focus Mode (AF-C vs Manual)
            Button {
                cameraService.focusMode = cameraService.focusMode == .continuousAutoFocus ? .manual : .continuousAutoFocus
            } label: {
                VStack(spacing: 12) {
                    Image(systemName: "viewfinder.rectangular")
                        .font(.system(size: 20, weight: .light))
                        .foregroundColor(cameraService.focusMode == .continuousAutoFocus ? DesignSystem.Colors.accent : DesignSystem.Colors.secondaryText)
                    Text(cameraService.focusMode == .continuousAutoFocus ? "AF-C" : "MANUAL")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.0)
                        .foregroundColor(cameraService.focusMode == .continuousAutoFocus ? DesignSystem.Colors.accent : DesignSystem.Colors.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(DesignSystem.Colors.surfaceHighlight)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(cameraService.focusMode == .continuousAutoFocus ? DesignSystem.Colors.accent : Color.clear, lineWidth: 1.5))
            }
            
            // Center Stage (Face On/Off)
            Button {
                cameraService.toggleCenterStage()
            } label: {
                VStack(spacing: 12) {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 20, weight: .light))
                        .foregroundColor(cameraService.centerStageEnabled ? DesignSystem.Colors.accent : DesignSystem.Colors.secondaryText)
                    Text(cameraService.centerStageEnabled ? "FACE ON" : "FACE OFF")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.0)
                        .foregroundColor(cameraService.centerStageEnabled ? DesignSystem.Colors.accent : DesignSystem.Colors.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(DesignSystem.Colors.surfaceHighlight)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(cameraService.centerStageEnabled ? DesignSystem.Colors.accent : Color.clear, lineWidth: 1.5))
            }
            
            // Depth (Portrait)
            Button {
                cameraService.depthEnabled.toggle()
            } label: {
                VStack(spacing: 12) {
                    Image(systemName: "circle.grid.3x3")
                        .font(.system(size: 20, weight: .light))
                        .foregroundColor(cameraService.depthEnabled ? DesignSystem.Colors.accent : DesignSystem.Colors.secondaryText)
                    Text("PORTRAIT")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.0)
                        .foregroundColor(cameraService.depthEnabled ? DesignSystem.Colors.accent : DesignSystem.Colors.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(DesignSystem.Colors.surfaceHighlight)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(cameraService.depthEnabled ? DesignSystem.Colors.accent : Color.clear, lineWidth: 1.5))
            }
            
            // Filters (LUTs)
            Button {
                showFilterPicker = true
            } label: {
                VStack(spacing: 12) {
                    Image(systemName: "square.3.layers.3d")
                        .font(.system(size: 20, weight: .light))
                        .foregroundColor(cameraService.activeFilter != .none ? DesignSystem.Colors.accent : DesignSystem.Colors.secondaryText)
                    Text(cameraService.activeFilter != .none ? "LUTS ON" : "LUTS")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.0)
                        .foregroundColor(cameraService.activeFilter != .none ? DesignSystem.Colors.accent : DesignSystem.Colors.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(DesignSystem.Colors.surfaceHighlight)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(cameraService.activeFilter != .none ? DesignSystem.Colors.accent : Color.clear, lineWidth: 1.5))
            }
        }
    }
    
    private var greenScreenRow: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(cameraService.greenScreenEnabled ? Color(red: 0.3, green: 0.9, blue: 0.5) : DesignSystem.Colors.secondaryText.opacity(0.5))
                .frame(width: 8, height: 8)
                .shadow(color: cameraService.greenScreenEnabled ? Color(red: 0.3, green: 0.9, blue: 0.5).opacity(0.6) : .clear, radius: 8, x: 0, y: 0)
            
            Text(cameraService.greenScreenEnabled ? "GREEN SCREEN ACTIVE" : "GREEN SCREEN")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.0)
                .foregroundColor(Color(white: 0.8))
            
            Spacer()
            
            Button(action: { cameraService.greenScreenEnabled.toggle() }) {
                Image(systemName: "chevron.down")
                    .foregroundColor(Color(white: 0.5))
                    .font(.system(size: 14, weight: .semibold))
            }
        }
    }

    private var depthSliderRow: some View {
        VStack(spacing: 12) {
            HStack {
                Text("BLUR INTENSITY (f/\(String(format: "%.1f", cameraService.simulatedAperture)))")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(DesignSystem.Colors.accent)
                    .tracking(2.0)
                
                Spacer()
            }
            
            // Slider Track
            ZStack(alignment: .center) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(white: 0.15))
                    .frame(height: 48)
                
                // Real visible slider over top
                // Inverted so turning slider right (Higher) = lower f-stop (More Blur)
                Slider(value: Binding(
                    get: { 17.4 - Double(cameraService.simulatedAperture) },
                    set: { cameraService.simulatedAperture = Float(17.4 - $0) }
                ), in: 1.4...16.0, step: 0.1)
                    .tint(DesignSystem.Colors.accent)
                    .padding(.horizontal, 16)
                    .frame(height: 48)
            }
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            exposureRow
            
            if cameraService.depthEnabled {
                depthSliderRow
            }
            
            gridRow
            greenScreenRow
                .padding(.top, 8)
                .padding(.horizontal, 8)
        }
        .padding(24)
        .glassPanel(cornerRadius: 24)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.3), radius: 30, x: 0, y: 10)
        
        // Filter picker sheet
        .sheet(isPresented: $showFilterPicker) {
            FilterPickerSheet(selectedFilter: $cameraService.activeFilter)
                .presentationDetents([.medium])
        }
    }
}

// Keep the Filter Picker Sheet unchanged, it works perfectly in sheets
struct FilterPickerSheet: View {
    @Binding var selectedFilter: CameraFilter
    @Environment(\.dismiss) private var dismiss
    
    let columns = [GridItem(.adaptive(minimum: 80))]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(DesignSystem.Colors.accent)
                    Text("Selected filter will be applied to saved video.")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
                .padding(12)
                .background(DesignSystem.Colors.surfaceHighlight)
                .cornerRadius(8)
                .padding()
                
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
                                                .stroke(selectedFilter == filter ? DesignSystem.Colors.accent : Color.clear, lineWidth: 3)
                                        )
                                    
                                    Text(filter.rawValue)
                                        .font(.caption)
                                        .foregroundColor(selectedFilter == filter ? DesignSystem.Colors.accent : DesignSystem.Colors.primaryText)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .background(DesignSystem.Colors.background.ignoresSafeArea())
            .navigationTitle("LUTs & Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(DesignSystem.Colors.accent)
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

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        CameraControlsOverlay(cameraService: CinematicCameraService())
            .padding(16)
    }
}

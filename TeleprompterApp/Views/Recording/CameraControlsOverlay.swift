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
                    .foregroundColor(DesignSystem.Colors.secondary)
                    .tracking(2.0)
                
                Spacer()
                
                Text("\(cameraService.exposureCompensation > 0 ? "+" : "")\(String(format: "%.1f", cameraService.exposureCompensation)) EV")
                    .font(DesignSystem.Typography.headline.weight(.bold))
                    .foregroundColor(DesignSystem.Colors.secondary)
            }
            
            // Slider Track
            ZStack(alignment: .center) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(DesignSystem.Colors.surfaceHighest.opacity(0.3))
                    .frame(height: 48)
                
                // Real visible slider over top
                Slider(value: $cameraService.exposureCompensation, in: -3...3, step: 0.1)
                    .tint(DesignSystem.Colors.secondary)
                    .padding(.horizontal, 16)
                    .frame(height: 48)
            }
        }
    }
    
    private var gridRow: some View {
        HStack(spacing: 16) {
            // Focus Mode (AF-C vs Manual)
            Button {
                cameraService.focusMode = cameraService.focusMode == .continuousAutoFocus ? .manual : .continuousAutoFocus
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "scope")
                        .font(.system(size: 20))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    Text(cameraService.focusMode == .continuousAutoFocus ? "AF-C" : "MANUAL")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.0)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(DesignSystem.Colors.surfaceHighest.opacity(0.4))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.05), lineWidth: 1))
                .cornerRadius(16)
            }
            
            // Center Stage (Face On/Off)
            Button {
                cameraService.toggleCenterStage()
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "face.dashed")
                        .font(.system(size: 20))
                        .foregroundColor(cameraService.centerStageEnabled ? DesignSystem.Colors.secondary : DesignSystem.Colors.secondaryText)
                    Text(cameraService.centerStageEnabled ? "FACE ON" : "FACE OFF")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.0)
                        .foregroundColor(cameraService.centerStageEnabled ? DesignSystem.Colors.secondary : DesignSystem.Colors.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(cameraService.centerStageEnabled ? DesignSystem.Colors.secondary.opacity(0.1) : DesignSystem.Colors.surfaceHighest.opacity(0.4))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(cameraService.centerStageEnabled ? DesignSystem.Colors.secondary.opacity(0.2) : Color.white.opacity(0.05), lineWidth: 1))
                .cornerRadius(16)
            }
            
            // Depth (Portrait)
            Button {
                cameraService.depthEnabled.toggle()
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 20))
                        .foregroundColor(cameraService.depthEnabled ? DesignSystem.Colors.primaryText : DesignSystem.Colors.secondaryText)
                    Text("PORTRAIT")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.0)
                        .foregroundColor(cameraService.depthEnabled ? DesignSystem.Colors.primaryText : DesignSystem.Colors.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(cameraService.depthEnabled ? DesignSystem.Colors.surfaceHighlight : DesignSystem.Colors.surfaceHighest.opacity(0.4))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.05), lineWidth: 1))
                .cornerRadius(16)
            }
            
            // Filters (LUTs)
            Button {
                showFilterPicker = true
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "camera.filters")
                        .font(.system(size: 20))
                        .foregroundColor(cameraService.activeFilter != .none ? DesignSystem.Colors.accent : DesignSystem.Colors.secondaryText)
                    Text(cameraService.activeFilter != .none ? "LUTS ON" : "LUTS")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.0)
                        .foregroundColor(cameraService.activeFilter != .none ? DesignSystem.Colors.accent : DesignSystem.Colors.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(cameraService.activeFilter != .none ? DesignSystem.Colors.accent.opacity(0.1) : DesignSystem.Colors.surfaceHighest.opacity(0.4))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(cameraService.activeFilter != .none ? DesignSystem.Colors.accent.opacity(0.2) : Color.white.opacity(0.05), lineWidth: 1))
                .cornerRadius(16)
            }
        }
    }
    
    private var greenScreenRow: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(cameraService.greenScreenEnabled ? Color.green : DesignSystem.Colors.secondaryText.opacity(0.5))
                .frame(width: 8, height: 8)
                .shadow(color: cameraService.greenScreenEnabled ? Color.green.opacity(0.6) : .clear, radius: 8, x: 0, y: 0)
            
            Text(cameraService.greenScreenEnabled ? "GREEN SCREEN ACTIVE" : "GREEN SCREEN")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.5)
                .foregroundColor(DesignSystem.Colors.secondaryText)
            
            Spacer()
            
            Button(action: { cameraService.greenScreenEnabled.toggle() }) {
                Image(systemName: cameraService.greenScreenEnabled ? "switch.2" : "switch.2")
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            exposureRow
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

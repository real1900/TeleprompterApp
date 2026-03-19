import SwiftUI

/// Collection of saved scripts with search, create, edit, and delete functionality
/// Updated to match the high-fidelity native Stitch GoPrompt UI.
struct ScriptListView: View {
    @StateObject private var storage = ScriptStorageService()
    @EnvironmentObject var appState: AppState
    
    @State private var editingScript: Script?
    @State private var isCreatingNew = false
    @State private var searchText = ""
    
    // Filtered scripts based on search
    private var filteredScripts: [Script] {
        if searchText.isEmpty {
            return storage.scripts
        }
        return storage.scripts.filter { script in
            script.title.localizedCaseInsensitiveContains(searchText) ||
            script.content.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()
                
                if storage.isLoading {
                    ProgressView("Loading scripts...")
                        .tint(DesignSystem.Colors.accent)
                } else if storage.scripts.isEmpty && !isCreatingNew {
                    emptyStateView
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            
                            // Custom Stitch Header
                            HStack(alignment: .bottom) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Production Vault")
                                        .font(DesignSystem.Typography.label)
                                        .foregroundColor(DesignSystem.Colors.secondary)
                                        .textCase(.uppercase)
                                        .tracking(2.0)
                                    Text("Script Library")
                                        .font(DesignSystem.Typography.largeTitle)
                                        .foregroundColor(DesignSystem.Colors.primaryText)
                                }
                                
                                Spacer()
                                
                                Button(action: createNewScript) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 14, weight: .bold))
                                        Text("New Script")
                                            .font(DesignSystem.Typography.headline)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(DesignSystem.Colors.accentContainer)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                    .shadow(color: DesignSystem.Colors.accentContainer.opacity(0.3), radius: 8, x: 0, y: 4)
                                }
                            }
                            .padding(.top, 24)
                            .padding(.horizontal, DesignSystem.Layout.paddingLarge)
                            
                            // Search fallback visualization
                            if filteredScripts.isEmpty && !searchText.isEmpty {
                                ContentUnavailableView.search(text: searchText)
                                    .padding(.top, 60)
                            } else {
                                
                                // Scripts Layout Grid
                                VStack(spacing: 16) {
                                    if let featured = filteredScripts.first {
                                        FeaturedScriptCardView(
                                            script: featured,
                                            speedWPM: appState.settings.scrollSpeed,
                                            onTap: { editScript(featured) },
                                            onUse: { appState.currentScript = featured }
                                        )
                                        // The featured card context menu is identical to others
                                        .contextMenu {
                                            Button {
                                                appState.currentScript = featured
                                            } label: {
                                                Label("Use Script", systemImage: "checkmark.circle")
                                            }
                                            Button(role: .destructive) {
                                                deleteScript(featured)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                    }
                                    
                                    // Regular Grid for remaining scripts
                                    let remaining = Array(filteredScripts.dropFirst())
                                    if !remaining.isEmpty {
                                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                                            ForEach(remaining) { script in
                                                ScriptCardView(
                                                    script: script,
                                                    speedWPM: appState.settings.scrollSpeed,
                                                    isSelected: appState.currentScript?.id == script.id,
                                                    onTap: { editScript(script) }
                                                )
                                                .contextMenu {
                                                    Button {
                                                        appState.currentScript = script
                                                    } label: {
                                                        Label("Use Script", systemImage: "checkmark.circle")
                                                    }
                                                    Button(role: .destructive) {
                                                        deleteScript(script)
                                                    } label: {
                                                        Label("Delete", systemImage: "trash")
                                                    }
                                                }
                                            }
                                            
                                            // Import Card Button at the end
                                            ImportScriptCardView()
                                        }
                                    } else if filteredScripts.count == 1 {
                                        // Still show import button if there's only the featured card
                                        ImportScriptCardView()
                                            .frame(height: 180)
                                    }
                                }
                                .padding(.horizontal, DesignSystem.Layout.paddingLarge)
                                .padding(.bottom, 100)
                            }
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search scripts...")
            .sheet(item: $editingScript) { script in
                ScriptEditorView(
                    script: Binding(
                        get: { script },
                        set: { newScript in
                            if storage.scripts.contains(where: { $0.id == script.id }) {
                                Task { try? await storage.save(newScript) }
                            }
                        }
                    ),
                    isNewScript: isCreatingNew,
                    onSave: { savedScript in
                        Task { await storage.loadScripts() }
                        editingScript = nil
                    },
                    onDelete: {
                        Task { try? await storage.delete(script) }
                        editingScript = nil
                    }
                )
            }
            .task {
                await storage.loadScripts()
            }
        }
    }
    
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("Vault Empty", systemImage: "doc.text.magnifyingglass")
        } description: {
            Text("Create your first prompter script to start the engine.")
        } actions: {
            Button(action: createNewScript) {
                Text("Start Production")
                    .font(DesignSystem.Typography.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(DesignSystem.Colors.accentContainer)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Methods
    
    private func createNewScript() {
        isCreatingNew = true
        editingScript = storage.createNewScript()
    }
    
    private func editScript(_ script: Script) {
        isCreatingNew = false
        editingScript = script
    }
    
    private func deleteScript(_ script: Script) {
        Task {
            try? await storage.delete(script)
        }
    }
}

// MARK: - SubViews

struct FeaturedScriptCardView: View {
    let script: Script
    let speedWPM: Double
    let onTap: () -> Void
    let onUse: () -> Void
    
    var computedDuration: String {
        let words = max(1.0, Double(script.content.split(separator: " ").count))
        let minutes = Int(words / speedWPM)
        let seconds = Int((words.truncatingRemainder(dividingBy: speedWPM) / speedWPM) * 60)
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 16) {
                // Badge
                Text("Ready to Record")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.accent)
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(DesignSystem.Colors.accent.opacity(0.15))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(DesignSystem.Colors.accent.opacity(0.3), lineWidth: 1)
                    )
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(script.title)
                        .font(DesignSystem.Typography.title)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text(script.content)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .opacity(0.8)
                }
                .padding(.top, 8)
                
                Spacer(minLength: 24)
                
                HStack(alignment: .bottom) {
                    HStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("DURATION")
                                .font(DesignSystem.Typography.label)
                                .foregroundColor(DesignSystem.Colors.secondaryText.opacity(0.6))
                                .tracking(1.0)
                            Text(computedDuration)
                                .font(DesignSystem.Typography.headline)
                                .foregroundColor(DesignSystem.Colors.primaryText)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("LAST EDITED")
                                .font(DesignSystem.Typography.label)
                                .foregroundColor(DesignSystem.Colors.secondaryText.opacity(0.6))
                                .tracking(1.0)
                            Text(script.updatedAt, style: .relative)
                                .font(DesignSystem.Typography.headline)
                                .foregroundColor(DesignSystem.Colors.primaryText)
                        }
                    }
                    Spacer()
                    
                    Button(action: onUse) {
                        Circle()
                            .fill(DesignSystem.Colors.accentContainer)
                            .frame(width: 50, height: 50)
                            .overlay(
                                Image(systemName: "video.fill")
                                    .foregroundColor(.white)
                                    .font(.title3)
                            )
                            .shadow(color: DesignSystem.Colors.accentContainer.opacity(0.4), radius: 10, x: 0, y: 5)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassPanel(cornerRadius: DesignSystem.Layout.cornerRadiusLarge)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusLarge)
                    .stroke(DesignSystem.Colors.surfaceHighlight.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ScriptCardView: View {
    let script: Script
    let speedWPM: Double
    let isSelected: Bool
    let onTap: () -> Void
    
    var computedDuration: String {
        let words = max(1.0, Double(script.content.split(separator: " ").count))
        let minutes = Int(words / speedWPM)
        let seconds = Int((words.truncatingRemainder(dividingBy: speedWPM) / speedWPM) * 60)
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Text(isSelected ? "ACTIVE" : "TECH SPEC")
                        .font(DesignSystem.Typography.label)
                        .foregroundColor(isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.secondaryText.opacity(0.6))
                        .textCase(.uppercase)
                        .tracking(1.0)
                    
                    Spacer()
                    Image(systemName: "ellipsis")
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
                
                Text(script.title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Text(script.content)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .opacity(0.8)
                
                Spacer(minLength: 16)
                
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.Colors.secondary)
                        Text(computedDuration)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                    }
                    Spacer()
                    Text(script.updatedAt, style: .date)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
                .padding(.top, 12)
                .overlay(
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 1),
                    alignment: .top
                )
            }
            .padding(16)
            .frame(height: 200)
            .glassPanel(cornerRadius: DesignSystem.Layout.cornerRadiusStandard)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusStandard)
                    .stroke(isSelected ? DesignSystem.Colors.accent : Color.clear, lineWidth: isSelected ? 2 : 0)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ImportScriptCardView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 24))
                .foregroundColor(DesignSystem.Colors.secondaryText)
            
            Text("Import Script")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(DesignSystem.Colors.primaryText)
            
            Text("PDF, TXT, or DOCX")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minHeight: 180)
        .background(DesignSystem.Colors.surface.opacity(0.6))
        .cornerRadius(DesignSystem.Layout.cornerRadiusStandard)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusStandard)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                )
                .foregroundColor(DesignSystem.Colors.secondaryText.opacity(0.3))
        )
    }
}

#Preview {
    ScriptListView()
        .environmentObject(AppState())
}

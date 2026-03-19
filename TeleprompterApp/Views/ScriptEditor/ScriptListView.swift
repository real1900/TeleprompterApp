import SwiftUI

/// Collection of saved scripts with search, create, edit, and delete functionality
struct ScriptListView: View {
    @StateObject private var storage = ScriptStorageService()
    @EnvironmentObject var appState: AppState
    
    @State private var editingScript: Script?
    @State private var isCreatingNew = false
    @State private var searchText = ""
    
    // Grid layout
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
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
                
                Group {
                    if storage.isLoading {
                        ProgressView("Loading scripts...")
                            .tint(DesignSystem.Colors.accent)
                    } else if storage.scripts.isEmpty {
                        emptyStateView
                    } else {
                        scriptsCollection
                    }
                }
            }
            .navigationTitle("Scripts")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search scripts...")
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        createNewScript()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $editingScript) { script in
                ScriptEditorView(
                    script: Binding(
                        get: { script },
                        set: { newScript in
                            if let index = storage.scripts.firstIndex(where: { $0.id == script.id }) {
                                Task {
                                    try? await storage.save(newScript)
                                }
                            }
                        }
                    ),
                    isNewScript: isCreatingNew,
                    onSave: { savedScript in
                        Task {
                            await storage.loadScripts()
                        }
                        editingScript = nil
                    },
                    onDelete: {
                        Task {
                            try? await storage.delete(script)
                        }
                        editingScript = nil
                    }
                )
            }
            .task {
                await storage.loadScripts()
            }
        }
    }
    
    // MARK: - Views
    
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Scripts", systemImage: "doc.text")
        } description: {
            Text("Create your first teleprompter script to get started.")
        } actions: {
            Button("Create Script") {
                createNewScript()
            }
            .buttonStyle(.borderedProminent)
            .tint(DesignSystem.Colors.accent)
        }
    }
    
    private var scriptsCollection: some View {
        ScrollView {
            // Show message if search has no results
            if filteredScripts.isEmpty && !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .padding(.top, 60)
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(filteredScripts) { script in
                        ScriptCardView(
                            script: script,
                            isSelected: appState.currentScript?.id == script.id
                        )
                        .onTapGesture {
                            editScript(script)
                        }
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
                }
                .padding(16)
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

// MARK: - Script Card View

struct ScriptCardView: View {
    let script: Script
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title with selection indicator
            HStack {
                Text(script.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            
            // Content preview
            Text(script.content)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)
            
            Spacer()
            
            // Metadata
            HStack {
                Label("\(script.content.split(separator: " ").count)", systemImage: "text.word.spacing")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(script.updatedAt, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .frame(height: 150)
        .glassPanel(cornerRadius: DesignSystem.Layout.cornerRadiusStandard)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusStandard)
                .stroke(isSelected ? DesignSystem.Colors.accent : Color.clear, lineWidth: isSelected ? 2 : 0)
        )
    }
}

#Preview {
    ScriptListView()
        .environmentObject(AppState())
}


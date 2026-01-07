import SwiftUI

/// List of saved scripts with create, edit, and delete functionality
struct ScriptListView: View {
    @StateObject private var storage = ScriptStorageService()
    @EnvironmentObject var appState: AppState
    
    @State private var showingEditor = false
    @State private var editingScript: Script?
    @State private var isCreatingNew = false
    
    var body: some View {
        NavigationStack {
            Group {
                if storage.isLoading {
                    ProgressView("Loading scripts...")
                } else if storage.scripts.isEmpty {
                    emptyStateView
                } else {
                    scriptsList
                }
            }
            .navigationTitle("Scripts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        createNewScript()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                if let script = editingScript {
                    ScriptEditorView(
                        script: Binding(
                            get: { script },
                            set: { editingScript = $0 }
                        ),
                        isNewScript: isCreatingNew,
                        onSave: { savedScript in
                            Task {
                                await storage.loadScripts()
                            }
                        },
                        onDelete: {
                            Task {
                                if let script = editingScript {
                                    try? await storage.delete(script)
                                }
                            }
                        }
                    )
                }
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
        }
    }
    
    private var scriptsList: some View {
        List {
            ForEach(storage.scripts) { script in
                ScriptRowView(script: script)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editScript(script)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteScript(script)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            appState.currentScript = script
                        } label: {
                            Label("Use", systemImage: "checkmark")
                        }
                        .tint(.green)
                    }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Methods
    
    private func createNewScript() {
        isCreatingNew = true
        editingScript = storage.createNewScript()
        showingEditor = true
    }
    
    private func editScript(_ script: Script) {
        isCreatingNew = false
        editingScript = script
        showingEditor = true
    }
    
    private func deleteScript(_ script: Script) {
        Task {
            try? await storage.delete(script)
        }
    }
}

// MARK: - Script Row View

struct ScriptRowView: View {
    let script: Script
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(script.title)
                    .font(.headline)
                
                Spacer()
                
                Text(script.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(script.content)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                Label("\(script.content.split(separator: " ").count) words", systemImage: "text.word.spacing")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ScriptListView()
        .environmentObject(AppState())
}

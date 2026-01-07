import SwiftUI

/// Script editor view for creating and editing teleprompter scripts
struct ScriptEditorView: View {
    @Binding var script: Script
    @StateObject private var storage = ScriptStorageService()
    @Environment(\.dismiss) var dismiss
    
    @State private var showingDeleteAlert = false
    @State private var isSaving = false
    @FocusState private var isContentFocused: Bool
    
    var isNewScript: Bool
    var onSave: ((Script) -> Void)?
    var onDelete: (() -> Void)?
    
    init(
        script: Binding<Script>,
        isNewScript: Bool = false,
        onSave: ((Script) -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self._script = script
        self.isNewScript = isNewScript
        self.onSave = onSave
        self.onDelete = onDelete
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Title field
                TextField("Script Title", text: $script.title)
                    .font(.title2.bold())
                    .padding()
                    .background(Color(.systemBackground))
                
                Divider()
                
                // Content editor
                TextEditor(text: $script.content)
                    .font(.body)
                    .padding(.horizontal)
                    .focused($isContentFocused)
                    .scrollContentBackground(.hidden)
                    .background(Color(.systemBackground))
                
                // Word count footer
                HStack {
                    Text("\(wordCount) words")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("~\(estimatedReadTime) min read")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
            }
            .navigationTitle(isNewScript ? "New Script" : "Edit Script")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveScript()
                    }
                    .disabled(script.title.isEmpty || isSaving)
                }
                
                if !isNewScript {
                    ToolbarItem(placement: .destructiveAction) {
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
            .alert("Delete Script?", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var wordCount: Int {
        script.content.split(separator: " ").count
    }
    
    private var estimatedReadTime: Int {
        // Average reading speed: 150 words per minute for teleprompter
        max(1, wordCount / 150)
    }
    
    // MARK: - Methods
    
    private func saveScript() {
        isSaving = true
        
        Task {
            do {
                try await storage.save(script)
                onSave?(script)
                dismiss()
            } catch {
                print("Error saving script: \(error)")
            }
            isSaving = false
        }
    }
}

#Preview {
    ScriptEditorView(
        script: .constant(Script.sample),
        isNewScript: false
    )
}

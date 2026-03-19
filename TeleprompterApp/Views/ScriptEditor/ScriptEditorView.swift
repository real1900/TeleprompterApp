import SwiftUI

/// Script editor view for creating and editing teleprompter scripts
/// Updated to match the high-fidelity native Stitch GoPrompt UI.
struct ScriptEditorView: View {
    // Use local State copy instead of Binding to avoid revert issues
    @State private var editableScript: Script
    @StateObject private var storage = ScriptStorageService()
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    
    @State private var showingDeleteAlert = false
    @State private var isSaving = false
    @FocusState private var isContentFocused: Bool
    
    let originalScript: Script
    var isNewScript: Bool
    var onSave: ((Script) -> Void)?
    var onDelete: (() -> Void)?
    
    init(
        script: Binding<Script>,
        isNewScript: Bool = false,
        onSave: ((Script) -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        let scriptValue = script.wrappedValue
        self._editableScript = State(initialValue: scriptValue)
        self.originalScript = scriptValue
        self.isNewScript = isNewScript
        self.onSave = onSave
        self.onDelete = onDelete
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom Stitch Header
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 16) {
                            if !isNewScript {
                                Button(role: .destructive) {
                                    showingDeleteAlert = true
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(DesignSystem.Colors.secondaryText)
                                }
                            }
                            
                            Button(action: saveScript) {
                                Text("SAVE")
                                    .font(DesignSystem.Typography.headline)
                                    .fontWeight(.bold)
                                    .tracking(1.0)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(DesignSystem.Colors.accentContainer)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                    .shadow(color: DesignSystem.Colors.accentContainer.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            .disabled(editableScript.title.isEmpty || isSaving)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Layout.paddingLarge)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // Title & Metadata
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("UNTITLED SCRIPT", text: $editableScript.title)
                                    .font(DesignSystem.Typography.largeTitle)
                                    .fontWeight(.heavy)
                                    .foregroundColor(DesignSystem.Colors.accent)
                                    .autocorrectionDisabled()
                                
                                HStack(spacing: 16) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "timer")
                                            .font(.system(size: 14))
                                        Text(estimatedReadTimeFormatted)
                                    }
                                    HStack(spacing: 4) {
                                        Image(systemName: "book")
                                            .font(.system(size: 14))
                                        Text("\(wordCount) WORDS")
                                    }
                                }
                                .font(DesignSystem.Typography.label)
                                .foregroundColor(DesignSystem.Colors.secondaryText.opacity(0.6))
                                .tracking(1.5)
                            }
                            .padding(.top, 24)
                            
                            // Editor Area
                            TextEditor(text: $editableScript.content)
                                .font(DesignSystem.Typography.headline.weight(.semibold))
                                .foregroundColor(DesignSystem.Colors.primaryText)
                                .scrollContentBackground(.hidden)
                                .background(Color.clear)
                                .frame(minHeight: 400)
                                .focused($isContentFocused)
                                .lineSpacing(appState.settings.lineSpacing)
                        }
                        .padding(.horizontal, DesignSystem.Layout.paddingLarge)
                        .padding(.bottom, 120) // padding for toolbar
                    }
                }
                
                // Formatting Toolbar Overlay (floating at bottom)
                VStack {
                    Spacer()
                    formattingToolbar
                        .padding(.bottom, 32)
                        .padding(.horizontal, DesignSystem.Layout.paddingLarge)
                        .ignoresSafeArea(.keyboard, edges: .bottom)
                }
            }
            .navigationBarHidden(true)
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
    
    // MARK: - Toolbar View
    
    private var formattingToolbar: some View {
        HStack(spacing: 16) {
            // Font Size
            HStack(spacing: 8) {
                Image(systemName: "textformat.size")
                    .foregroundColor(DesignSystem.Colors.secondary)
                
                HStack(spacing: 4) {
                    Button {
                        if appState.settings.fontSize >= TeleprompterSettings.fontSizeRange.lowerBound + 2 {
                            appState.settings.fontSize -= 2
                        }
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 30, height: 30)
                            .background(DesignSystem.Colors.background)
                            .cornerRadius(6)
                    }
                    
                    Text("\(Int(appState.settings.fontSize))px")
                        .font(DesignSystem.Typography.label.weight(.bold))
                        .frame(width: 44)
                        .multilineTextAlignment(.center)
                    
                    Button {
                        if appState.settings.fontSize <= TeleprompterSettings.fontSizeRange.upperBound - 2 {
                            appState.settings.fontSize += 2
                        }
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 30, height: 30)
                            .background(DesignSystem.Colors.background)
                            .cornerRadius(6)
                    }
                }
            }
            
            Spacer()
            
            // Mirror Toggle
            HStack(spacing: 8) {
                Text("MIRROR")
                    .font(DesignSystem.Typography.label)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .tracking(1.0)
                
                Toggle("", isOn: $appState.settings.mirrorText)
                    .labelsHidden()
                    .tint(DesignSystem.Colors.accent)
                    .scaleEffect(0.8)
            }
        }
        .padding(16)
        .glassPanel(cornerRadius: DesignSystem.Layout.cornerRadiusLarge)
        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
    
    // MARK: - Computed Properties
    
    private var wordCount: Int {
        editableScript.content.split(separator: " ").count
    }
    
    private var estimatedReadTimeFormatted: String {
        let words = max(1.0, Double(wordCount))
        let speedWPM = appState.settings.scrollSpeed
        let minutes = Int(words / speedWPM)
        let seconds = Int((words.truncatingRemainder(dividingBy: speedWPM) / speedWPM) * 60)
        return String(format: "%02d:%02d EST.", minutes, seconds)
    }
    
    // MARK: - Methods
    
    private func saveScript() {
        isSaving = true
        
        var scriptToSave = editableScript
        scriptToSave.updatedAt = Date()
        
        Task {
            do {
                try await storage.save(scriptToSave)
                onSave?(scriptToSave)
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
    .environmentObject(AppState())
}

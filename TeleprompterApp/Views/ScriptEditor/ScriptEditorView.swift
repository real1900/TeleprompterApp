import SwiftUI

/// Script editor view for creating and editing teleprompter scripts
/// Updated to match the high-fidelity native Stitch GoPrompt UI.
struct ScriptEditorView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settings: TeleprompterSettings
    @EnvironmentObject var storage: ScriptStorageService
    @StateObject private var viewModel: ScriptEditorViewModel
    
    @FocusState private var isContentFocused: Bool
    
    init(
        script: Script,
        isNewScript: Bool = false,
        onSave: ((Script) -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        // ViewModel expects storage to be injected on Appear or directly. 
        // We initialize ViewModel directly.
        _viewModel = StateObject(wrappedValue: ScriptEditorViewModel(
            script: script,
            isNewScript: isNewScript,
            storage: nil,
            onSave: onSave,
            onDelete: onDelete
        ))
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
                            if !viewModel.isNewScript {
                                Button(role: .destructive) {
                                    viewModel.showingDeleteAlert = true
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(DesignSystem.Colors.secondaryText)
                                }
                            }
                            
                            Button(action: { viewModel.saveScript(dismiss: dismiss) }) {
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
                            .disabled(viewModel.editableScript.title.isEmpty || viewModel.isSaving)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Layout.paddingLarge)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // Title & Metadata
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("UNTITLED SCRIPT", text: $viewModel.editableScript.title)
                                    .font(DesignSystem.Typography.largeTitle)
                                    .fontWeight(.heavy)
                                    .foregroundColor(DesignSystem.Colors.accent)
                                    .autocorrectionDisabled()
                                
                                HStack(spacing: 16) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "timer")
                                            .font(.system(size: 14))
                                        Text(viewModel.estimatedReadTimeFormatted(speedWPM: settings.scrollSpeed))
                                    }
                                    HStack(spacing: 4) {
                                        Image(systemName: "book")
                                            .font(.system(size: 14))
                                        Text("\(viewModel.wordCount) WORDS")
                                    }
                                }
                                .font(DesignSystem.Typography.label)
                                .foregroundColor(DesignSystem.Colors.secondaryText.opacity(0.6))
                                .tracking(1.5)
                            }
                            .padding(.top, 24)
                            
                            // Editor Area
                            TextEditor(text: $viewModel.editableScript.content)
                                .font(DesignSystem.Typography.headline.weight(.semibold))
                                .foregroundColor(DesignSystem.Colors.primaryText)
                                .scrollContentBackground(.hidden)
                                .background(Color.clear)
                                .frame(minHeight: 400)
                                .focused($isContentFocused)
                                .lineSpacing(settings.lineSpacing)
                                .scaleEffect(x: settings.mirrorText ? -1 : 1, y: 1)
                        }
                        .padding(.horizontal, DesignSystem.Layout.paddingLarge)
                        .padding(.bottom, 120)
                    }
                }
                
                VStack {
                    Spacer()
                    formattingToolbar
                        .padding(.bottom, 32)
                        .padding(.horizontal, DesignSystem.Layout.paddingLarge)
                        .ignoresSafeArea(.keyboard, edges: .bottom)
                }
            }
            .navigationBarHidden(true)
            .alert("Delete Script?", isPresented: $viewModel.showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    viewModel.deleteScript(dismiss: dismiss)
                }
            } message: {
                Text("This action cannot be undone.")
            }
            .onAppear {
                viewModel.storage = storage
            }
        }
    }
    
    // MARK: - Toolbar View
    
    private var formattingToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 24) {
                // Font Size
                HStack(spacing: 8) {
                    Image(systemName: "textformat.size")
                        .foregroundColor(DesignSystem.Colors.secondary)
                    
                    HStack(spacing: 4) {
                        Button {
                            if settings.fontSize >= TeleprompterSettings.fontSizeRange.lowerBound + 2 {
                                settings.fontSize -= 2
                            }
                        } label: {
                            Image(systemName: "minus")
                                .frame(width: 30, height: 30)
                                .background(DesignSystem.Colors.background)
                                .cornerRadius(6)
                                .foregroundColor(DesignSystem.Colors.primaryText)
                        }
                        
                        Text("\(Int(settings.fontSize))px")
                            .font(DesignSystem.Typography.label.weight(.bold))
                            .frame(width: 44)
                            .multilineTextAlignment(.center)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                        
                        Button {
                            if settings.fontSize <= TeleprompterSettings.fontSizeRange.upperBound - 2 {
                                settings.fontSize += 2
                            }
                        } label: {
                            Image(systemName: "plus")
                                .frame(width: 30, height: 30)
                                .background(DesignSystem.Colors.background)
                                .cornerRadius(6)
                                .foregroundColor(DesignSystem.Colors.primaryText)
                        }
                    }
                }
                
                // Line Spacing
                HStack(spacing: 8) {
                    Image(systemName: "text.alignleft")
                        .foregroundColor(DesignSystem.Colors.secondary)
                    
                    HStack(spacing: 4) {
                        ForEach([1.0, 1.5, 2.0], id: \.self) { spacing in
                            Button {
                                settings.lineSpacing = spacing * 8
                            } label: {
                                Text(String(format: "%.1f", spacing))
                                    .font(DesignSystem.Typography.label.weight(.bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(abs(settings.lineSpacing - (spacing * 8)) < 1 ? DesignSystem.Colors.accent : DesignSystem.Colors.background)
                                    .foregroundColor(abs(settings.lineSpacing - (spacing * 8)) < 1 ? .white : DesignSystem.Colors.primaryText)
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
                
                // Speed Control
                HStack(spacing: 8) {
                    Image(systemName: "speedometer")
                        .foregroundColor(DesignSystem.Colors.secondary)
                    
                    HStack(spacing: 4) {
                        Button {
                            let current = settings.scrollSpeed
                            if current < 150 {
                                settings.scrollSpeed += 10
                            } else {
                                settings.scrollSpeed = 20
                            }
                        } label: {
                            Text("x\(String(format: "%.1f", settings.scrollSpeed / 45.0))")
                                .font(DesignSystem.Typography.label.weight(.bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(DesignSystem.Colors.background)
                                .foregroundColor(DesignSystem.Colors.primaryText)
                                .cornerRadius(6)
                        }
                    }
                }
                
                // Mirror Toggle
                HStack(spacing: 8) {
                    Text("MIRROR")
                        .font(DesignSystem.Typography.label)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .tracking(1.0)
                    
                    Toggle("", isOn: $settings.mirrorText)
                        .labelsHidden()
                        .tint(DesignSystem.Colors.accent)
                        .scaleEffect(0.8)
                }
            }
            .padding(16)
        }
        .glassPanel(cornerRadius: DesignSystem.Layout.cornerRadiusLarge)
        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}

#Preview {
    ScriptEditorView(
        script: Script.sample,
        isNewScript: false
    )
    .environmentObject(AppState())
    .environmentObject(TeleprompterSettings())
}
import SwiftUI

@MainActor
class ScriptEditorViewModel: ObservableObject {
    @Published var editableScript: Script
    @Published var isSaving = false
    @Published var showingDeleteAlert = false
    
    weak var storage: ScriptStorageService?
    
    let originalScript: Script
    let isNewScript: Bool
    var onSave: ((Script) -> Void)?
    var onDelete: (() -> Void)?
    
    init(script: Script, isNewScript: Bool, storage: ScriptStorageService?, onSave: ((Script) -> Void)?, onDelete: (() -> Void)?) {
        self.editableScript = script
        self.originalScript = script
        self.isNewScript = isNewScript
        self.storage = storage
        self.onSave = onSave
        self.onDelete = onDelete
    }
    
    var wordCount: Int {
        editableScript.content.split(separator: " ").count
    }
    
    func estimatedReadTimeFormatted(speedWPM: Double) -> String {
        let words = max(1.0, Double(wordCount))
        let minutes = Int(words / speedWPM)
        let seconds = Int((words.truncatingRemainder(dividingBy: speedWPM) / speedWPM) * 60)
        return String(format: "%02d:%02d EST.", minutes, seconds)
    }
    
    func saveScript(dismiss: DismissAction) {
        isSaving = true
        
        editableScript.updatedAt = Date()
        let scriptToSave = editableScript
        
        Task {
            do {
                try await storage?.save(scriptToSave)
                self.onSave?(scriptToSave)
                dismiss()
            } catch {
                print("Error saving script: \(error)")
            }
            self.isSaving = false
        }
    }
    
    func deleteScript(dismiss: DismissAction) {
        self.onDelete?()
        dismiss()
    }
}

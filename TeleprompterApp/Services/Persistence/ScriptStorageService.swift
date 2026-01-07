import Foundation

/// Service for persisting and retrieving scripts
@MainActor
class ScriptStorageService: ObservableObject {
    // MARK: - Published Properties
    
    @Published private(set) var scripts: [Script] = []
    @Published private(set) var isLoading = false
    
    // MARK: - Private Properties
    
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private var scriptsDirectory: URL {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent("Scripts", isDirectory: true)
    }
    
    // MARK: - Initialization
    
    init() {
        createDirectoryIfNeeded()
    }
    
    // MARK: - Public Methods
    
    /// Load all scripts from disk
    func loadScripts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let files = try fileManager.contentsOfDirectory(at: scriptsDirectory, includingPropertiesForKeys: nil)
            let jsonFiles = files.filter { $0.pathExtension == "json" }
            
            var loadedScripts: [Script] = []
            
            for file in jsonFiles {
                if let data = try? Data(contentsOf: file),
                   let script = try? decoder.decode(Script.self, from: data) {
                    loadedScripts.append(script)
                }
            }
            
            // Sort by updated date, newest first
            scripts = loadedScripts.sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            print("Error loading scripts: \(error)")
            scripts = []
        }
    }
    
    /// Save a script to disk
    func save(_ script: Script) async throws {
        var updatedScript = script
        updatedScript.updatedAt = Date()
        
        let data = try encoder.encode(updatedScript)
        let fileURL = scriptsDirectory.appendingPathComponent("\(script.id.uuidString).json")
        try data.write(to: fileURL)
        
        // Update local cache
        if let index = scripts.firstIndex(where: { $0.id == script.id }) {
            scripts[index] = updatedScript
        } else {
            scripts.insert(updatedScript, at: 0)
        }
        
        // Re-sort
        scripts.sort { $0.updatedAt > $1.updatedAt }
    }
    
    /// Delete a script from disk
    func delete(_ script: Script) async throws {
        let fileURL = scriptsDirectory.appendingPathComponent("\(script.id.uuidString).json")
        try fileManager.removeItem(at: fileURL)
        
        // Update local cache
        scripts.removeAll { $0.id == script.id }
    }
    
    /// Delete multiple scripts
    func delete(atOffsets offsets: IndexSet) async throws {
        for index in offsets {
            let script = scripts[index]
            let fileURL = scriptsDirectory.appendingPathComponent("\(script.id.uuidString).json")
            try fileManager.removeItem(at: fileURL)
        }
        
        scripts.remove(atOffsets: offsets)
    }
    
    /// Create a new empty script
    func createNewScript() -> Script {
        return Script(
            title: "New Script",
            content: "Enter your script text here...",
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    // MARK: - Private Methods
    
    private func createDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: scriptsDirectory.path) {
            try? fileManager.createDirectory(at: scriptsDirectory, withIntermediateDirectories: true)
        }
    }
}

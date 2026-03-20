import Foundation
import PDFKit
import UniformTypeIdentifiers

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

/// Service for importing scripts from various document formats (PDF, TXT, DOCX, RTF)
enum DocumentImportError: LocalizedError {
    case unreadableFile
    case noTextContent
    case unsupportedFormat
    
    var errorDescription: String? {
        switch self {
        case .unreadableFile:
            return "The selected file could not be read. Please make sure it's not corrupted or locked."
        case .noTextContent:
            return "No text could be extracted from this document."
        case .unsupportedFormat:
            return "This file format is not supported for script import."
        }
    }
}

class DocumentImportService {
    
    /// Extracts text content from a securely accessed file URL.
    /// Supports .pdf, .txt, .docx, and .rtf files.
    ///
    /// - Parameter url: The URL of the file to import.
    /// - Returns: A tuple containing the extracted `String` and a suggested default `title` based on the file name.
    static func extractText(from url: URL) async throws -> (content: String, defaultTitle: String) {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        // Use file coordinator for safe read (especially for Word docs or RTF that might be accessed externally)
        return try await withCheckedThrowingContinuation { continuation in
            let fileCoordinator = NSFileCoordinator()
            var fileError: NSError?
            
            fileCoordinator.coordinate(readingItemAt: url, options: .withoutChanges, error: &fileError) { safeURL in
                do {
                    let text = try extractContent(from: safeURL)
                    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        continuation.resume(throwing: DocumentImportError.noTextContent)
                        return
                    }
                    
                    let title = url.deletingPathExtension().lastPathComponent
                    continuation.resume(returning: (content: text, defaultTitle: title))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            
            if let error = fileError {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private static func extractContent(from safeURL: URL) throws -> String {
        guard let uti = try safeURL.resourceValues(forKeys: [.contentTypeKey]).contentType else {
            throw DocumentImportError.unsupportedFormat
        }
        
        // 1. Handle PDF
        if uti.conforms(to: .pdf) {
            guard let pdfDocument = PDFDocument(url: safeURL) else {
                throw DocumentImportError.unreadableFile
            }
            
            guard let fullText = pdfDocument.string else {
                throw DocumentImportError.noTextContent
            }
            return fullText
        }
        
        // 2. Handle Plain Text (TXT, Markdown, etc)
        if uti.conforms(to: .plainText) {
            do {
                return try String(contentsOf: safeURL, encoding: .utf8)
            } catch {
                // Fallback to ASCII or other encodings if UTF-8 fails
                return try String(contentsOf: safeURL)
            }
        }
        
        // 3. Handle Rich Text (RTF and RTFD) and Microsoft Word (DOC, DOCX)
        if uti.conforms(to: .rtf) || uti.conforms(to: .rtfd) ||
            uti.conforms(to: .compositeContent) || // Some word docs might show up as composite
            uti.conforms(to: .data) // docx often registers as data depending on system extensions
        {
            // Attempt extraction using NSAttributedString
            do {
                let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [:]
                let attrString = try NSAttributedString(url: safeURL, options: options, documentAttributes: nil)
                return attrString.string
            } catch {
                // If NSAttributedString fails and we strictly needed word, fail
                throw DocumentImportError.unreadableFile
            }
        }
        
        // If it's a docx and we reached here (e.g. strict checking)
        if safeURL.pathExtension.lowercased() == "docx" || safeURL.pathExtension.lowercased() == "doc" {
            do {
                let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [:]
                let attrString = try NSAttributedString(url: safeURL, options: options, documentAttributes: nil)
                return attrString.string
            } catch {
                throw DocumentImportError.unreadableFile
            }
        }
        
        throw DocumentImportError.unsupportedFormat
    }
}

import Foundation
import PDFKit
import UniformTypeIdentifiers
import CoreData

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
        
        let loadedScripts = await Task.detached(priority: .userInitiated) { () -> [Script] in
            let fm = FileManager.default
            let decoder = JSONDecoder()
            guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return [] }
            let dir = docs.appendingPathComponent("Scripts", isDirectory: true)
            
            guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return [] }
            let jsonFiles = files.filter { $0.pathExtension == "json" }
            
            var results: [Script] = []
            for file in jsonFiles {
                if let data = try? Data(contentsOf: file),
                   let script = try? decoder.decode(Script.self, from: data) {
                    results.append(script)
                }
            }
            return results.sorted { $0.updatedAt > $1.updatedAt }
        }.value
        
        self.scripts = loadedScripts
    }
    
    /// Save a script to disk
    func save(_ script: Script) async throws {
        var updatedScript = script
        updatedScript.updatedAt = Date()
        
        // Update local UI cache immediately for flawless responsiveness
        if let index = scripts.firstIndex(where: { $0.id == script.id }) {
            scripts[index] = updatedScript
        } else {
            scripts.insert(updatedScript, at: 0)
        }
        scripts.sort { $0.updatedAt > $1.updatedAt }
        
        // Fire physical disk writes into isolated detached utility thread
        let dir = scriptsDirectory
        try await Task.detached(priority: .utility) {
            let encoder = JSONEncoder()
            let data = try encoder.encode(updatedScript)
            let fileURL = dir.appendingPathComponent("\(updatedScript.id.uuidString).json")
            try data.write(to: fileURL)
        }.value
    }
    
    /// Delete a script from disk
    func delete(_ script: Script) async throws {
        // Update local UI cache immediately
        scripts.removeAll { $0.id == script.id }
        
        let dir = scriptsDirectory
        try await Task.detached(priority: .utility) {
            let fileURL = dir.appendingPathComponent("\(script.id.uuidString).json")
            try? FileManager.default.removeItem(at: fileURL)
        }.value
    }
    
    /// Delete multiple scripts
    func delete(atOffsets offsets: IndexSet) async throws {
        let scriptsToDelete = offsets.map { scripts[$0] }
        scripts.remove(atOffsets: offsets)
        
        let dir = scriptsDirectory
        try await Task.detached(priority: .utility) {
            let fileManager = FileManager.default
            for script in scriptsToDelete {
                let fileURL = dir.appendingPathComponent("\(script.id.uuidString).json")
                try? fileManager.removeItem(at: fileURL)
            }
        }.value
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

// MARK: - Video Metadata Cache (Core Data)

@objc(VideoMetadata)
public class VideoMetadata: NSManagedObject {
    @NSManaged public var localIdentifier: String
    @NSManaged public var title: String?
}

class VideoMetadataCache {
    static let shared = VideoMetadataCache()
    
    let container: NSPersistentContainer
    
    init() {
        let model = NSManagedObjectModel()
        
        let entity = NSEntityDescription()
        entity.name = "VideoMetadata"
        entity.managedObjectClassName = "VideoMetadata"
        
        let idAttr = NSAttributeDescription()
        idAttr.name = "localIdentifier"
        idAttr.attributeType = .stringAttributeType
        idAttr.isOptional = false
        
        let titleAttr = NSAttributeDescription()
        titleAttr.name = "title"
        titleAttr.attributeType = .stringAttributeType
        titleAttr.isOptional = true
        
        entity.properties = [idAttr, titleAttr]
        
        let indexElement = NSFetchIndexElementDescription(property: idAttr, collationType: .binary)
        let indexDesc = NSFetchIndexDescription(name: "idIndex", elements: [indexElement])
        entity.indexes = [indexDesc]
        
        model.entities = [entity]
        
        container = NSPersistentContainer(name: "TeleprompterVideoCache", managedObjectModel: model)
        container.loadPersistentStores { _, error in
            if let error = error { print("Failed to load Core Data Cache: \(error)") }
        }
    }
    
    func getTitle(for localIdentifier: String) -> String? {
        let context = container.newBackgroundContext()
        var title: String? = nil
        context.performAndWait {
            let request = NSFetchRequest<VideoMetadata>(entityName: "VideoMetadata")
            request.predicate = NSPredicate(format: "localIdentifier == %@", localIdentifier)
            request.fetchLimit = 1
            title = try? context.fetch(request).first?.title
        }
        return title
    }
    
    func getAllMetadata() -> [(localIdentifier: String, title: String?)] {
        let context = container.newBackgroundContext()
        var resultsArray: [(localIdentifier: String, title: String?)] = []
        context.performAndWait {
            let request = NSFetchRequest<VideoMetadata>(entityName: "VideoMetadata")
            if let results = try? context.fetch(request) {
                resultsArray = results.map { ($0.localIdentifier, $0.title) }
            }
        }
        return resultsArray
    }
    
    func saveTitle(_ title: String, for localIdentifier: String) {
        let context = container.newBackgroundContext()
        context.perform {
            let request = NSFetchRequest<VideoMetadata>(entityName: "VideoMetadata")
            request.predicate = NSPredicate(format: "localIdentifier == %@", localIdentifier)
            request.fetchLimit = 1
            let existing = try? context.fetch(request).first
            
            if let metadata = existing {
                metadata.title = title
            } else {
                let metadata = VideoMetadata(context: context)
                metadata.localIdentifier = localIdentifier
                metadata.title = title
            }
            try? context.save()
        }
    }
}

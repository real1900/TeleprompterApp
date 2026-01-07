import Foundation
import SwiftUI

/// Represents a teleprompter script with its content and metadata
struct Script: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var content: String
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        title: String = "Untitled Script",
        content: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    /// Sample script for previews and testing
    static let sample = Script(
        title: "Welcome Script",
        content: """
        Hello and welcome to this video!
        
        Today we're going to talk about something really exciting.
        
        This teleprompter app makes it easy to record professional videos while reading your script.
        
        You can adjust the font size and scroll speed to match your reading pace.
        
        Let's get started!
        """
    )
    
    /// Empty script for new entries
    static let empty = Script(title: "", content: "")
}

/// Recording session metadata
struct RecordingSession: Identifiable, Codable {
    let id: UUID
    let scriptId: UUID?
    let startedAt: Date
    var endedAt: Date?
    var duration: TimeInterval
    var videoURL: URL?
    
    init(
        id: UUID = UUID(),
        scriptId: UUID? = nil,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        duration: TimeInterval = 0,
        videoURL: URL? = nil
    ) {
        self.id = id
        self.scriptId = scriptId
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.duration = duration
        self.videoURL = videoURL
    }
}

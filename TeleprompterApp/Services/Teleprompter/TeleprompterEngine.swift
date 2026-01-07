import Foundation
import SwiftUI
import Combine

/// Engine that controls teleprompter scrolling animation
@MainActor
class TeleprompterEngine: ObservableObject {
    // MARK: - Published Properties
    
    /// Current scroll offset in points from top
    @Published var scrollOffset: CGFloat = 0
    
    /// Whether the teleprompter is actively scrolling
    @Published private(set) var isScrolling = false
    
    /// Whether scrolling is paused
    @Published private(set) var isPaused = false
    
    /// Total content height for scroll bounds
    @Published var contentHeight: CGFloat = 1000  // Default non-zero
    
    /// Visible height of the teleprompter view
    @Published var visibleHeight: CGFloat = 300   // Default non-zero
    
    // MARK: - Configuration
    
    /// Scroll speed in points per second
    var scrollSpeed: Double = 50 {
        didSet {
            // Clamp to valid range
            scrollSpeed = min(max(scrollSpeed, TeleprompterSettings.scrollSpeedRange.lowerBound),
                            TeleprompterSettings.scrollSpeedRange.upperBound)
        }
    }
    
    /// Font size for the teleprompter text
    var fontSize: CGFloat = 32 {
        didSet {
            fontSize = min(max(fontSize, TeleprompterSettings.fontSizeRange.lowerBound),
                          TeleprompterSettings.fontSizeRange.upperBound)
        }
    }
    
    // MARK: - Private Properties
    
    private var displayLink: CADisplayLink?
    private var displayLinkTarget: DisplayLinkTarget?
    private var lastTimestamp: CFTimeInterval = 0
    
    // MARK: - Initialization
    
    init() {}
    
    deinit {
        displayLink?.invalidate()
        displayLink = nil
        displayLinkTarget = nil
    }
    
    // MARK: - Public Methods
    
    /// Start the teleprompter scrolling
    func startScrolling() {
        guard !isScrolling else { 
            print("TeleprompterEngine: Already scrolling")
            return 
        }
        
        print("TeleprompterEngine: Starting scroll - contentHeight: \(contentHeight), visibleHeight: \(visibleHeight), speed: \(scrollSpeed)")
        
        isScrolling = true
        isPaused = false
        lastTimestamp = 0
        
        // Create and retain the display link target
        let target = DisplayLinkTarget { [weak self] timestamp in
            self?.updateScroll(timestamp: timestamp)
        }
        displayLinkTarget = target
        
        // Create display link for smooth 60fps scrolling
        displayLink = CADisplayLink(target: target, selector: #selector(DisplayLinkTarget.handleDisplayLink(_:)))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 60)
        displayLink?.add(to: .main, forMode: .common)
        
        print("TeleprompterEngine: Display link created and added to run loop")
    }
    
    /// Pause the teleprompter scrolling
    func pauseScrolling() {
        guard isScrolling, !isPaused else { return }
        isPaused = true
        displayLink?.isPaused = true
        print("TeleprompterEngine: Paused")
    }
    
    /// Resume the teleprompter scrolling from paused state
    func resumeScrolling() {
        guard isScrolling, isPaused else { return }
        isPaused = false
        displayLink?.isPaused = false
        lastTimestamp = 0 // Reset timestamp to avoid jump
        print("TeleprompterEngine: Resumed")
    }
    
    /// Toggle between pause and resume
    func togglePause() {
        if isPaused {
            resumeScrolling()
        } else {
            pauseScrolling()
        }
    }
    
    /// Stop the teleprompter scrolling completely
    func stopScrolling() {
        isScrolling = false
        isPaused = false
        
        displayLink?.invalidate()
        displayLink = nil
        displayLinkTarget = nil
        lastTimestamp = 0
        print("TeleprompterEngine: Stopped")
    }
    
    /// Reset scroll position to the top
    func resetToTop() {
        scrollOffset = 0
        print("TeleprompterEngine: Reset to top")
    }
    
    /// Reset scroll position to the bottom
    func resetToBottom() {
        let maxOffset = max(0, contentHeight - visibleHeight)
        scrollOffset = maxOffset
    }
    
    /// Manually set scroll offset (for user interaction)
    func setOffset(_ offset: CGFloat) {
        let maxOffset = max(0, contentHeight - visibleHeight)
        scrollOffset = min(max(0, offset), maxOffset)
    }
    
    /// Update scroll based on display link
    private func updateScroll(timestamp: CFTimeInterval) {
        guard isScrolling, !isPaused else { return }
        
        // Calculate delta time
        if lastTimestamp == 0 {
            lastTimestamp = timestamp
            return
        }
        
        let deltaTime = timestamp - lastTimestamp
        lastTimestamp = timestamp
        
        // Calculate scroll delta based on speed
        let scrollDelta = scrollSpeed * deltaTime
        
        // Update offset
        let newOffset = scrollOffset + scrollDelta
        let maxOffset = max(0, contentHeight - visibleHeight)
        
        if maxOffset > 0 && newOffset >= maxOffset {
            // Reached the end
            scrollOffset = maxOffset
            stopScrolling()
        } else {
            scrollOffset = newOffset
        }
    }
    
    /// Calculate estimated time to finish scrolling
    var estimatedTimeRemaining: TimeInterval {
        guard scrollSpeed > 0, contentHeight > 0 else { return 0 }
        let remainingDistance = max(0, (contentHeight - visibleHeight) - scrollOffset)
        return remainingDistance / scrollSpeed
    }
    
    /// Progress through the script (0.0 to 1.0)
    var progress: Double {
        guard contentHeight > visibleHeight else { return 0 }
        let maxOffset = contentHeight - visibleHeight
        guard maxOffset > 0 else { return 0 }
        return min(1.0, scrollOffset / maxOffset)
    }
}

// MARK: - DisplayLink Target

/// Helper class to avoid retain cycle with CADisplayLink
private class DisplayLinkTarget: NSObject {
    private let callback: (CFTimeInterval) -> Void
    
    init(callback: @escaping (CFTimeInterval) -> Void) {
        self.callback = callback
        super.init()
    }
    
    @objc func handleDisplayLink(_ displayLink: CADisplayLink) {
        Task { @MainActor in
            callback(displayLink.timestamp)
        }
    }
}

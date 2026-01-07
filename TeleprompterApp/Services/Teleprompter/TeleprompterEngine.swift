import Foundation
import SwiftUI
import Combine

/// Engine that controls teleprompter scrolling animation with smart physics
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
    
    /// Current effective scroll speed (affected by ease-in)
    @Published private(set) var currentSpeed: Double = 0
    
    // MARK: - Configuration
    
    /// Target words per minute for scroll speed calculation
    var targetWPM: Double = 140
    
    /// Word count of the current script (set externally)
    var wordCount: Int = 100 {
        didSet {
            recalculateSpeed()
        }
    }
    
    /// Scroll speed in points per second (calculated from WPM or set manually)
    var scrollSpeed: Double = 50 {
        didSet {
            scrollSpeed = min(max(scrollSpeed, 10), 300)
        }
    }
    
    /// Font size for the teleprompter text
    var fontSize: CGFloat = 28 {
        didSet {
            fontSize = min(max(fontSize, TeleprompterSettings.fontSizeRange.lowerBound),
                          TeleprompterSettings.fontSizeRange.upperBound)
            recalculateSpeed()
        }
    }
    
    // MARK: - Ease-in Configuration
    
    /// Duration of the ease-in acceleration period (seconds)
    private let easeInDuration: Double = 2.0
    
    /// Time elapsed since scroll started
    private var scrollElapsedTime: Double = 0
    
    /// Whether currently in ease-in phase
    private var isEasingIn: Bool = true
    
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
    
    // MARK: - Speed Calculation
    
    /// Calculate scroll speed based on WPM and content
    /// Formula: (Total Height / (Word Count / Target WPM)) / 60 = pixels/second
    private func recalculateSpeed() {
        guard wordCount > 0, contentHeight > 0 else { return }
        
        // Calculate reading time in seconds for the entire script at target WPM
        let readingTimeSeconds = (Double(wordCount) / targetWPM) * 60.0
        
        // Calculate required scroll speed (pixels per second)
        let scrollableHeight = max(1, contentHeight - visibleHeight)
        let calculatedSpeed = scrollableHeight / readingTimeSeconds
        
        // Clamp to reasonable range
        scrollSpeed = min(max(calculatedSpeed, 20), 200)
        
        print("TeleprompterEngine: Calculated speed \(scrollSpeed) px/s for \(wordCount) words at \(targetWPM) WPM")
    }
    
    /// Configure for a specific script
    func configureForScript(_ script: Script) {
        wordCount = script.content.split(separator: " ").count
        recalculateSpeed()
    }
    
    // MARK: - Ease-in Curve
    
    /// Calculate the ease-in multiplier (0.0 to 1.0) based on elapsed time
    /// Uses a smooth ease-in-out curve for natural acceleration
    private func easeInMultiplier() -> Double {
        guard isEasingIn else { return 1.0 }
        
        let t = min(scrollElapsedTime / easeInDuration, 1.0)
        
        // Ease-in-out cubic: smoother acceleration
        // f(t) = t^2 * (3 - 2t) for smooth S-curve
        // Or simpler ease-in: t^2
        let easedT = t * t * (3.0 - 2.0 * t)  // Smooth S-curve
        
        if t >= 1.0 {
            isEasingIn = false
        }
        
        return easedT
    }
    
    // MARK: - Public Methods
    
    /// Start the teleprompter scrolling with ease-in
    func startScrolling() {
        guard !isScrolling else { 
            print("TeleprompterEngine: Already scrolling")
            return 
        }
        
        print("TeleprompterEngine: Starting scroll - words: \(wordCount), speed: \(scrollSpeed), ease-in: \(easeInDuration)s")
        
        isScrolling = true
        isPaused = false
        lastTimestamp = 0
        scrollElapsedTime = 0
        isEasingIn = true
        currentSpeed = 0
        
        // Create and retain the display link target
        let target = DisplayLinkTarget { [weak self] timestamp in
            self?.updateScroll(timestamp: timestamp)
        }
        displayLinkTarget = target
        
        // Create display link for smooth 60fps scrolling
        displayLink = CADisplayLink(target: target, selector: #selector(DisplayLinkTarget.handleDisplayLink(_:)))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 60)
        displayLink?.add(to: .main, forMode: .common)
        
        print("TeleprompterEngine: Display link started with 2s ease-in")
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
        isEasingIn = false
        currentSpeed = 0
        
        displayLink?.invalidate()
        displayLink = nil
        displayLinkTarget = nil
        lastTimestamp = 0
        scrollElapsedTime = 0
        print("TeleprompterEngine: Stopped")
    }
    
    /// Reset scroll position to the top
    func resetToTop() {
        scrollOffset = 0
        scrollElapsedTime = 0
        isEasingIn = true
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
    
    /// Update scroll based on display link with ease-in physics
    private func updateScroll(timestamp: CFTimeInterval) {
        guard isScrolling, !isPaused else { return }
        
        // Calculate delta time
        if lastTimestamp == 0 {
            lastTimestamp = timestamp
            return
        }
        
        let deltaTime = timestamp - lastTimestamp
        lastTimestamp = timestamp
        
        // Accumulate elapsed time for ease-in calculation
        scrollElapsedTime += deltaTime
        
        // Apply ease-in multiplier to speed
        let easeMultiplier = easeInMultiplier()
        currentSpeed = scrollSpeed * easeMultiplier
        
        // Calculate scroll delta based on eased speed
        let scrollDelta = currentSpeed * deltaTime
        
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
    
    /// Current words per minute based on actual scroll speed
    var currentWPM: Double {
        guard contentHeight > visibleHeight, wordCount > 0 else { return targetWPM }
        let scrollableHeight = contentHeight - visibleHeight
        let secondsToComplete = scrollableHeight / currentSpeed
        guard secondsToComplete > 0 else { return targetWPM }
        return (Double(wordCount) / secondsToComplete) * 60.0
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

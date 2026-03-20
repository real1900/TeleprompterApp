import Foundation
import SwiftUI

/// User preferences for the teleprompter display and behavior
@MainActor
class TeleprompterSettings: ObservableObject {
    
    // MARK: - AppStorage Properties
    
    /// Font size for the teleprompter text (16-72 points)
    @AppStorage("ts_fontSize") var fontSize: Double = 28
    
    /// Scroll speed in points per second (10-200)
    @AppStorage("ts_scrollSpeed") var scrollSpeed: Double = 50
    
    /// Text color for the teleprompter
    @AppStorage("ts_textColorHex") var textColorHex: String = "#FFFFFF"
    
    /// Background opacity for the teleprompter overlay (0.0-1.0)
    @AppStorage("ts_backgroundOpacity") var backgroundOpacity: Double = 0.6
    
    /// Line spacing multiplier
    @AppStorage("ts_lineSpacing") var lineSpacing: Double = 8
    
    /// Horizontal padding from screen edges
    @AppStorage("ts_horizontalPadding") var horizontalPadding: Double = 20
    
    /// Mirror text horizontally (for external teleprompter setups)
    @AppStorage("ts_mirrorText") var mirrorText: Bool = false
    
    /// Show countdown before recording starts
    @AppStorage("ts_showCountdown") var showCountdown: Bool = true
    
    /// Countdown duration in seconds
    @AppStorage("ts_countdownDuration") var countdownDuration: Int = 3
    
    // MARK: - Camera Settings
    
    /// Raw representation for VideoQuality since AppStorage doesn't natively support custom Enums
    @AppStorage("ts_videoQualityRaw") private var videoQualityRaw: String = VideoQuality.medium.rawValue
    
    /// Video capture resolution (e.g. 1080p, 4K)
    var videoQuality: VideoQuality {
        get { VideoQuality(rawValue: videoQualityRaw) ?? .medium }
        set {
            videoQualityRaw = newValue.rawValue
            objectWillChange.send()
        }
    }
    
    /// Video frame rate (e.g. 24, 30, 60)
    @AppStorage("ts_frameRate") var frameRate: Int = 30
    
    /// Enable video stabilization
    @AppStorage("ts_stabilizationEnabled") var stabilizationEnabled: Bool = true
    
    // MARK: - Computed Properties
    
    var textColor: Color {
        Color(hex: textColorHex) ?? .white
    }
    
    var backgroundColor: Color {
        Color.black.opacity(backgroundOpacity)
    }
    
    // MARK: - Operations
    
    func resetToDefaults() {
        fontSize = 28
        scrollSpeed = 50
        textColorHex = "#FFFFFF"
        backgroundOpacity = 0.6
        lineSpacing = 8
        horizontalPadding = 20
        mirrorText = false
        showCountdown = true
        countdownDuration = 3
        videoQuality = .medium
        frameRate = 30
        stabilizationEnabled = true
    }
    
    // MARK: - Ranges
    
    static let fontSizeRange: ClosedRange<Double> = 16...72
    static let scrollSpeedRange: ClosedRange<Double> = 10...200
    static let opacityRange: ClosedRange<Double> = 0.3...1.0
}

// MARK: - Color Hex Extension

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
    
    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components else {
            return nil
        }
        
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

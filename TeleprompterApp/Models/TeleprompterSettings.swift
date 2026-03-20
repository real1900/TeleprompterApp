import Foundation
import SwiftUI

/// User preferences for the teleprompter display and behavior
struct TeleprompterSettings: Codable, Equatable {
    /// Font size for the teleprompter text (16-72 points)
    var fontSize: CGFloat
    
    /// Scroll speed in points per second (10-200)
    var scrollSpeed: Double
    
    /// Text color for the teleprompter
    var textColorHex: String
    
    /// Background opacity for the teleprompter overlay (0.0-1.0)
    var backgroundOpacity: Double
    
    /// Line spacing multiplier
    var lineSpacing: CGFloat
    
    /// Horizontal padding from screen edges
    var horizontalPadding: CGFloat
    
    /// Mirror text horizontally (for external teleprompter setups)
    var mirrorText: Bool
    
    /// Show countdown before recording starts
    var showCountdown: Bool
    
    /// Countdown duration in seconds
    var countdownDuration: Int
    
    // MARK: - Camera Settings
    
    /// Video capture resolution (e.g. 1080p, 4K)
    var videoQuality: VideoQuality
    
    /// Video frame rate (e.g. 24, 30, 60)
    var frameRate: Int
    
    /// Enable video stabilization
    var stabilizationEnabled: Bool
    
    // MARK: - Computed Properties
    
    var textColor: Color {
        Color(hex: textColorHex) ?? .white
    }
    
    var backgroundColor: Color {
        Color.black.opacity(backgroundOpacity)
    }
    
    // MARK: - Static Defaults
    
    static let `default` = TeleprompterSettings(
        fontSize: 28,
        scrollSpeed: 50,
        textColorHex: "#FFFFFF",
        backgroundOpacity: 0.6,
        lineSpacing: 8,
        horizontalPadding: 20,
        mirrorText: false,
        showCountdown: true,
        countdownDuration: 3,
        videoQuality: .medium,
        frameRate: 30,
        stabilizationEnabled: true
    )
    
    // MARK: - Ranges
    
    static let fontSizeRange: ClosedRange<CGFloat> = 16...72
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

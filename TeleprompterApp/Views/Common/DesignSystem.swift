import SwiftUI

/// Centralized Design System for the Teleprompter App
/// Based on the new native Stitch UI design tokens.
public enum DesignSystem {
    
    // MARK: - Colors
    public struct Colors {
        public static let background = Color(hexString: "#131313")
        public static let surface = Color(hexString: "#1c1b1b")          // surface-container-low
        public static let surfaceHighlight = Color(hexString: "#2a2a2a") // surface-container-high
        public static let surfaceHighest = Color(hexString: "#353534")   // surface-container-highest
        
        public static let primaryText = Color(hexString: "#e5e2e1")      // on-surface
        public static let secondaryText = Color(hexString: "#ebbbb4")    // on-surface-variant
        
        // Brand/Action Accent
        public static let accent = Color(hexString: "#ffb4aa")           // primary
        public static let accentContainer = Color(hexString: "#ff5545")  // primary-container
        public static let secondary = Color(hexString: "#e9c349")        // secondary
        public static let secondaryContainer = Color(hexString: "#af8d11")
        public static let destructive = Color(hexString: "#ffb4ab")      // error
        
        public static let glassmorphismBackground = Color(red: 42/255, green: 42/255, blue: 42/255, opacity: 0.8)
    }
    
    // MARK: - Typography
    public struct Typography {
        /// The main high-legibility teleprompter scrolling text font
        public static func prompterText(size: CGFloat) -> Font {
            return .system(size: size, weight: .bold, design: .rounded)
        }
        
        public static let largeTitle = Font.system(size: 30, weight: .bold, design: .rounded)
        public static let title = Font.system(size: 24, weight: .bold, design: .rounded)
        public static let headline = Font.system(size: 18, weight: .semibold, design: .default)
        public static let body = Font.system(size: 16, weight: .regular, design: .default)
        public static let caption = Font.system(size: 12, weight: .medium, design: .default)
        public static let label = Font.system(size: 10, weight: .semibold, design: .default)
    }
    
    // MARK: - Layout & Styling
    public struct Layout {
        public static let paddingSmall: CGFloat = 8
        public static let paddingStandard: CGFloat = 16
        public static let paddingLarge: CGFloat = 24
        
        public static let cornerRadiusSmall: CGFloat = 8
        public static let cornerRadiusStandard: CGFloat = 16
        public static let cornerRadiusLarge: CGFloat = 24
    }
}

// MARK: - View Modifiers

/// Applies a premium glassmorphic effect to any View panel
public struct GlassmorphicPanelModifier: ViewModifier {
    var cornerRadius: CGFloat
    var borderOpacity: Double
    
    public func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .background(DesignSystem.Colors.glassmorphismBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(borderOpacity), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: 10)
    }
}

/// Applies a pill-shaped glass background, typically for toolbars
public struct PillPanelModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .background(DesignSystem.Colors.glassmorphismBackground)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 12)
    }
}

extension View {
    /// Applies a standard glass panel background
    public func glassPanel(cornerRadius: CGFloat = DesignSystem.Layout.cornerRadiusStandard, borderOpacity: Double = 0.15) -> some View {
        self.modifier(GlassmorphicPanelModifier(cornerRadius: cornerRadius, borderOpacity: borderOpacity))
    }
    
    /// Applies a pill-shaped glass background
    public func glassPill() -> some View {
        self.modifier(PillPanelModifier())
    }
}

// MARK: - Color Hex Extension
extension Color {
    init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

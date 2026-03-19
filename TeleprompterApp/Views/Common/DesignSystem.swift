import SwiftUI

/// Centralized Design System for the Teleprompter App
/// Based on a modern, high-contrast, glassmorphic aesthetic.
public enum DesignSystem {
    
    // MARK: - Colors
    public struct Colors {
        public static let background = Color.black
        public static let surface = Color(white: 0.12)
        public static let surfaceHighlight = Color(white: 0.18)
        
        public static let primaryText = Color.white
        public static let secondaryText = Color(white: 0.6)
        
        // Brand/Action Accent
        public static let accent = Color.red
        public static let destructive = Color.red
        
        public static let glassmorphismBackground = Color.black.opacity(0.4)
    }
    
    // MARK: - Typography
    public struct Typography {
        /// The main high-legibility teleprompter scrolling text font
        public static func prompterText(size: CGFloat) -> Font {
            return .system(size: size, weight: .bold, design: .rounded)
        }
        
        public static let largeTitle = Font.system(size: 32, weight: .bold, design: .rounded)
        public static let title = Font.system(size: 24, weight: .bold, design: .rounded)
        public static let headline = Font.system(size: 18, weight: .semibold, design: .default)
        public static let body = Font.system(size: 16, weight: .regular, design: .default)
        public static let caption = Font.system(size: 13, weight: .medium, design: .default)
    }
    
    // MARK: - Layout & Styling
    public struct Layout {
        public static let paddingSmall: CGFloat = 8
        public static let paddingStandard: CGFloat = 16
        public static let paddingLarge: CGFloat = 24
        
        public static let cornerRadiusStandard: CGFloat = 16
        public static let cornerRadiusLarge: CGFloat = 24
    }
}

// MARK: - View Modifiers

/// Applies a premium glassmorphic effect to any View panel
public struct GlassmorphicPanelModifier: ViewModifier {
    var cornerRadius: CGFloat
    
    public func body(content: Content) -> some View {
        content
            .background(.thinMaterial)
            .background(DesignSystem.Colors.glassmorphismBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}

/// Applies a pill-shaped glass background, typically for toolbars
public struct PillPanelModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .background(.regularMaterial)
            .background(DesignSystem.Colors.glassmorphismBackground)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: 8)
    }
}

extension View {
    /// Applies a standard glass panel background
    public func glassPanel(cornerRadius: CGFloat = DesignSystem.Layout.cornerRadiusStandard) -> some View {
        self.modifier(GlassmorphicPanelModifier(cornerRadius: cornerRadius))
    }
    
    /// Applies a pill-shaped glass background
    public func glassPill() -> some View {
        self.modifier(PillPanelModifier())
    }
}

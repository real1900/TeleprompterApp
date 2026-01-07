import SwiftUI

/// Animated focus indicator that appears when tapping to focus
struct FocusIndicatorView: View {
    let position: CGPoint
    let isVisible: Bool
    
    @State private var scale: CGFloat = 1.5
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            // Focus brackets
            FocusBrackets()
                .stroke(Color.yellow, lineWidth: 2)
                .frame(width: 80, height: 80)
            
            // Center dot
            Circle()
                .fill(Color.yellow)
                .frame(width: 6, height: 6)
        }
        .scaleEffect(scale)
        .opacity(opacity)
        .position(position)
        .onChange(of: isVisible) { _, visible in
            if visible {
                showIndicator()
            } else {
                hideIndicator()
            }
        }
    }
    
    private func showIndicator() {
        scale = 1.5
        opacity = 1
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            scale = 1.0
        }
        
        // Auto-hide after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            hideIndicator()
        }
    }
    
    private func hideIndicator() {
        withAnimation(.easeOut(duration: 0.3)) {
            opacity = 0
            scale = 0.8
        }
    }
}

// MARK: - Focus Brackets Shape

struct FocusBrackets: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cornerLength: CGFloat = 15
        let cornerRadius: CGFloat = 4
        
        // Top-left corner
        path.move(to: CGPoint(x: 0, y: cornerLength))
        path.addLine(to: CGPoint(x: 0, y: cornerRadius))
        path.addQuadCurve(to: CGPoint(x: cornerRadius, y: 0), 
                          control: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: cornerLength, y: 0))
        
        // Top-right corner
        path.move(to: CGPoint(x: rect.width - cornerLength, y: 0))
        path.addLine(to: CGPoint(x: rect.width - cornerRadius, y: 0))
        path.addQuadCurve(to: CGPoint(x: rect.width, y: cornerRadius), 
                          control: CGPoint(x: rect.width, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: cornerLength))
        
        // Bottom-right corner
        path.move(to: CGPoint(x: rect.width, y: rect.height - cornerLength))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - cornerRadius))
        path.addQuadCurve(to: CGPoint(x: rect.width - cornerRadius, y: rect.height), 
                          control: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: rect.width - cornerLength, y: rect.height))
        
        // Bottom-left corner
        path.move(to: CGPoint(x: cornerLength, y: rect.height))
        path.addLine(to: CGPoint(x: cornerRadius, y: rect.height))
        path.addQuadCurve(to: CGPoint(x: 0, y: rect.height - cornerRadius), 
                          control: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height - cornerLength))
        
        return path
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        FocusIndicatorView(
            position: CGPoint(x: 200, y: 400),
            isVisible: true
        )
    }
}

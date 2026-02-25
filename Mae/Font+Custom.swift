import SwiftUI

// MARK: - Typography Native Extension
extension Font {
    static func cormorantGaramond(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let fontName: String
        switch weight {
        case .light: fontName = "CormorantGaramond-Light"
        case .medium: fontName = "CormorantGaramond-Medium"
        case .semibold: fontName = "CormorantGaramond-SemiBold"
        case .bold: fontName = "CormorantGaramond-Bold"
        default: fontName = "CormorantGaramond-Regular"
        }
        return .custom(fontName, size: size)
    }
}

// MARK: - Core Theme
enum Theme {
    enum Colors {
        /// Base background for the main window and chat Area
        static let background = Color(NSColor(red: 0.1, green: 0.1, blue: 0.11, alpha: 1.0))
        /// Base background for secondary windows (like Settings)
        static let backgroundSecondary = Color(NSColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1.0))
        
        /// Surface elements like assistant bubbles, header
        static let surface = Color(NSColor(red: 0.12, green: 0.12, blue: 0.13, alpha: 0.8))
        /// Text field backgrounds and secondary elements
        static let surfaceSecondary = Color.white.opacity(0.05)
        
        /// Borders and dividers
        static let border = Color.white.opacity(0.1)
        /// Thicker borders for highlights
        static let borderHighlight = Color.white.opacity(0.15)
        
        /// Primary text
        static let textPrimary = Color.white
        /// Secondary text and placeholders
        static let textSecondary = Color.white.opacity(0.6)
        /// Subtle/Muted text
        static let textMuted = Color.white.opacity(0.3)
        
        /// Accent color (active states)
        static let accent = Color.white
    }
    
    enum Typography {
        static let title = Font.cormorantGaramond(size: 24, weight: .bold)
        static let heading = Font.cormorantGaramond(size: 18, weight: .semibold)
        static let bodyBold = Font.cormorantGaramond(size: 16, weight: .medium)
        static let body = Font.cormorantGaramond(size: 16, weight: .regular)
        static let bodySmall = Font.cormorantGaramond(size: 14, weight: .regular)
        static let caption = Font.cormorantGaramond(size: 12, weight: .light)
    }
    
    enum Metrics {
        static let radiusSmall: CGFloat = 8
        static let radiusMedium: CGFloat = 14
        static let radiusLarge: CGFloat = 18
        
        static let spacingSmall: CGFloat = 8
        static let spacingDefault: CGFloat = 12
        static let spacingLarge: CGFloat = 16
        static let spacingXLarge: CGFloat = 24
    }
}

// MARK: - Reusable UI Components
extension View {
    /// Glassmorphism style for user bubbles and floating areas
    func maeGlassBackground(cornerRadius: CGFloat = Theme.Metrics.radiusMedium) -> some View {
        self
            .background(AnyShapeStyle(.ultraThinMaterial))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Theme.Colors.border, lineWidth: 1)
            )
    }
    
    /// Default surface style for assistant bubbles and cards
    func maeSurfaceBackground(cornerRadius: CGFloat = Theme.Metrics.radiusMedium) -> some View {
        self
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Theme.Colors.border, lineWidth: 1)
            )
    }
}

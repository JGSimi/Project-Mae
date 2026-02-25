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
        /// Base background — near-black
        static let background = Color(NSColor(red: 0.04, green: 0.04, blue: 0.045, alpha: 1.0))
        /// Secondary background — even deeper
        static let backgroundSecondary = Color(NSColor(red: 0.03, green: 0.03, blue: 0.035, alpha: 1.0))
        
        /// Surface elements like assistant bubbles, cards
        static let surface = Color.white.opacity(0.04)
        /// Text fields, secondary cards
        static let surfaceSecondary = Color.white.opacity(0.03)
        
        /// Borders and dividers — very subtle
        static let border = Color.white.opacity(0.06)
        /// Slightly stronger borders for focused elements
        static let borderHighlight = Color.white.opacity(0.10)
        
        /// Primary text
        static let textPrimary = Color.white.opacity(0.95)
        /// Secondary/placeholder text
        static let textSecondary = Color.white.opacity(0.50)
        /// Muted/disabled text
        static let textMuted = Color.white.opacity(0.25)
        
        /// Warm gold accent — elegant & sophisticated
        static let accent = Color(red: 0.788, green: 0.663, blue: 0.431) // #C9A96E
        /// Subtle accent for backgrounds
        static let accentSubtle = Color(red: 0.788, green: 0.663, blue: 0.431).opacity(0.15)
    }
    
    enum Typography {
        static let title = Font.cormorantGaramond(size: 26, weight: .bold)
        static let heading = Font.cormorantGaramond(size: 20, weight: .semibold)
        static let bodyBold = Font.cormorantGaramond(size: 15, weight: .medium)
        static let body = Font.cormorantGaramond(size: 15, weight: .regular)
        static let bodySmall = Font.cormorantGaramond(size: 13, weight: .regular)
        static let caption = Font.cormorantGaramond(size: 11, weight: .light)
    }
    
    enum Metrics {
        static let radiusSmall: CGFloat = 8
        static let radiusMedium: CGFloat = 16
        static let radiusLarge: CGFloat = 22
        
        static let spacingSmall: CGFloat = 8
        static let spacingDefault: CGFloat = 12
        static let spacingLarge: CGFloat = 16
        static let spacingXLarge: CGFloat = 24
    }
}

// MARK: - Reusable UI Components
extension View {
    /// Glassmorphism style for user bubbles — subtle gold tint
    func maeGlassBackground(cornerRadius: CGFloat = Theme.Metrics.radiusMedium) -> some View {
        self
            .background(.ultraThinMaterial)
            .background(Theme.Colors.accent.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Theme.Colors.accent.opacity(0.12), lineWidth: 1)
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

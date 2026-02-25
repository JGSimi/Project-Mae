import SwiftUI

// ╔══════════════════════════════════════════════════════════════════╗
// ║                     Mae · Design System                        ║
// ║  Single source of truth for all visual tokens and components.  ║
// ╚══════════════════════════════════════════════════════════════════╝

// MARK: - Font Extension (Cormorant Garamond)

extension Font {
    static func cormorantGaramond(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let fontName: String
        switch weight {
        case .light:    fontName = "CormorantGaramond-Light"
        case .medium:   fontName = "CormorantGaramond-Medium"
        case .semibold: fontName = "CormorantGaramond-SemiBold"
        case .bold:     fontName = "CormorantGaramond-Bold"
        default:        fontName = "CormorantGaramond-Regular"
        }
        return .custom(fontName, size: size)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 1. Design Tokens
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

enum Theme {

    // MARK: Colors
    enum Colors {
        // Backgrounds
        static let background          = Color(NSColor(red: 0.04, green: 0.04, blue: 0.045, alpha: 1.0))
        static let backgroundSecondary = Color(NSColor(red: 0.03, green: 0.03, blue: 0.035, alpha: 1.0))

        // Surfaces
        static let surface             = Color.white.opacity(0.04)
        static let surfaceSecondary    = Color.white.opacity(0.03)

        // Borders
        static let border              = Color.white.opacity(0.06)
        static let borderHighlight     = Color.white.opacity(0.10)

        // Text
        static let textPrimary         = Color.white.opacity(0.95)
        static let textSecondary       = Color.white.opacity(0.50)
        static let textMuted           = Color.white.opacity(0.25)

        // Accent — warm gold
        static let accent              = Color(red: 0.788, green: 0.663, blue: 0.431) // #C9A96E
        static let accentSubtle        = Color(red: 0.788, green: 0.663, blue: 0.431).opacity(0.15)

        // Semantic
        static let success             = Color.green
        static let error               = Color.red
    }

    // MARK: Typography
    enum Typography {
        static let largeTitle   = Font.cormorantGaramond(size: 32, weight: .semibold)
        static let title        = Font.cormorantGaramond(size: 26, weight: .bold)
        static let heading      = Font.cormorantGaramond(size: 20, weight: .semibold)
        static let bodyBold     = Font.cormorantGaramond(size: 15, weight: .medium)
        static let body         = Font.cormorantGaramond(size: 15, weight: .regular)
        static let bodySmall    = Font.cormorantGaramond(size: 13, weight: .regular)
        static let caption      = Font.cormorantGaramond(size: 11, weight: .light)
        static let sectionHeader = Font.cormorantGaramond(size: 11, weight: .bold)
    }

    // MARK: Metrics
    enum Metrics {
        static let radiusSmall:  CGFloat = 8
        static let radiusMedium: CGFloat = 16
        static let radiusLarge:  CGFloat = 22

        static let spacingSmall:  CGFloat = 8
        static let spacingDefault: CGFloat = 12
        static let spacingLarge:  CGFloat = 16
        static let spacingXLarge: CGFloat = 24
    }

    // MARK: Shadows
    enum Shadows {
        static let soft   = (color: Color.black.opacity(0.10), radius: CGFloat(4), x: CGFloat(0), y: CGFloat(2))
        static let medium = (color: Color.black.opacity(0.15), radius: CGFloat(6), x: CGFloat(0), y: CGFloat(3))
    }

    // MARK: Animation
    enum Animation {
        static let smooth  = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.8)
        static let gentle  = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.8)
        static let hover   = SwiftUI.Animation.easeInOut(duration: 0.25)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 2. View Modifiers
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

extension View {

    /// Glassmorphism — gold-tinted frost (user bubbles)
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

    /// Neutral dark surface (assistant bubbles, cards)
    func maeSurfaceBackground(cornerRadius: CGFloat = Theme.Metrics.radiusMedium) -> some View {
        self
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Theme.Colors.border, lineWidth: 1)
            )
    }

    /// Standard card shape: surfaceSecondary + border
    func maeCardStyle(cornerRadius: CGFloat = Theme.Metrics.radiusMedium) -> some View {
        self
            .background(Theme.Colors.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Theme.Colors.border, lineWidth: 1)
            )
    }

    /// Text input style
    func maeInputStyle(cornerRadius: CGFloat = Theme.Metrics.radiusMedium) -> some View {
        self
            .textFieldStyle(.plain)
            .font(Theme.Typography.bodySmall)
            .foregroundStyle(Theme.Colors.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Theme.Colors.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Theme.Colors.border, lineWidth: 1)
            )
    }

    /// Soft shadow token
    func maeSoftShadow() -> some View {
        let s = Theme.Shadows.soft
        return self.shadow(color: s.color, radius: s.radius, x: s.x, y: s.y)
    }
    
    /// Medium shadow token
    func maeMediumShadow() -> some View {
        let s = Theme.Shadows.medium
        return self.shadow(color: s.color, radius: s.radius, x: s.x, y: s.y)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 3. Reusable Components
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// MARK: MaeDivider
/// Subtle divider using Theme border color.
struct MaeDivider: View {
    var body: some View {
        Divider().background(Theme.Colors.border)
    }
}

// MARK: MaeGradientDivider
/// Gradient fade divider (center → edges).
struct MaeGradientDivider: View {
    var body: some View {
        LinearGradient(
            colors: [.clear, Theme.Colors.border, .clear],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 1)
    }
}

// MARK: MaeCard
/// Themed GroupBox with dark surface + subtle border.
struct MaeCardStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            configuration.content
        }
        .background(Theme.Colors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusMedium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Metrics.radiusMedium, style: .continuous)
                .stroke(Theme.Colors.border, lineWidth: 1)
        )
    }
}

// MARK: MaeSectionHeader
/// Uppercased section label for settings panels.
struct MaeSectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(Theme.Typography.sectionHeader)
            .foregroundStyle(Theme.Colors.textSecondary)
            .padding(.bottom, 4)
            .padding(.top, 16)
            .padding(.horizontal, 4)
    }
}

// MARK: MaeActionRow
/// Themed row for settings: icon + title + optional subtitle.
struct MaeActionRow: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var iconColor: Color = Theme.Colors.accent

    var body: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(Theme.Typography.bodyBold)
                    .foregroundStyle(iconColor)
                    .frame(width: 24, height: 24)
                    .background(iconColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Typography.bodySmall)
                    .foregroundStyle(Theme.Colors.textPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            Spacer()
        }
    }
}

// MARK: MaeIconButton
/// Circular icon button with optional accent highlighting.
struct MaeIconButton: View {
    let icon: String
    var size: CGFloat = 14
    var color: Color = Theme.Colors.textSecondary
    var bgColor: Color = .clear
    var helpText: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .regular))
                .foregroundStyle(color)
                .padding(bgColor == .clear ? 0 : 8)
                .background(bgColor)
        }
        .buttonStyle(.plain)
        .help(helpText ?? "")
    }
}

// MARK: MaePageBackground
/// Deep black background with optional accent radial glow.
struct MaePageBackground: View {
    var showGlow: Bool = false

    var body: some View {
        ZStack {
            Theme.Colors.backgroundSecondary.ignoresSafeArea()
            if showGlow {
                RadialGradient(
                    gradient: Gradient(colors: [Theme.Colors.accent.opacity(0.04), .clear]),
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 400
                )
            } else {
                RadialGradient(
                    gradient: Gradient(colors: [Color.white.opacity(0.015), .clear]),
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 400
                )
            }
        }
    }
}

// MARK: MaeTextField
/// Themed text field with consistent styling.
struct MaeTextField: View {
    let placeholder: String
    @Binding var text: String
    var axis: Axis = .horizontal
    var lineLimit: ClosedRange<Int> = 1...1

    var body: some View {
        TextField(placeholder, text: $text, axis: axis)
            .maeInputStyle()
            .lineLimit(lineLimit)
    }
}

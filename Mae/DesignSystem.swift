import SwiftUI
import Combine

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
        // Durations
        static let durationFast:   Double = 0.2
        static let durationNormal: Double = 0.3
        static let durationSlow:   Double = 0.5

        // Springs — Core
        static let smooth  = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.8)
        static let gentle  = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.8)
        static let bouncy  = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.6)

        // Springs — Premium
        static let snappy     = SwiftUI.Animation.spring(response: 0.25, dampingFraction: 0.82)
        static let responsive = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.75)
        static let expressive = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.7)
        static let microBounce = SwiftUI.Animation.spring(response: 0.28, dampingFraction: 0.65)

        // Easing
        static let hover   = SwiftUI.Animation.easeInOut(duration: durationFast)
        static let fade    = SwiftUI.Animation.easeOut(duration: 0.25)
        static let slowFade = SwiftUI.Animation.easeInOut(duration: 0.6)

        // Stagger helper — delay for item at index in a list
        static func staggerDelay(index: Int, base: Double = 0.04) -> SwiftUI.Animation {
            Theme.Animation.responsive.delay(Double(index) * base)
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 1.5. Standardized Transitions
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

extension AnyTransition {
    /// Slide from trailing edge + fade — settings panels, drawers
    static var maeSlideIn: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .trailing).combined(with: .opacity)
        )
    }

    /// Scale up from 0.92 + fade — chat message pop-in (refined)
    static var maePopIn: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.92)
                .combined(with: .opacity)
                .combined(with: .offset(y: 8)),
            removal: .scale(scale: 0.95).combined(with: .opacity)
        )
    }

    /// Scale + fade — buttons, action items
    static var maeScaleFade: AnyTransition {
        .scale(scale: 0.9).combined(with: .opacity)
    }

    /// Slide from bottom + fade — toasts, input areas
    static var maeSlideUp: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
        )
    }

    /// Slide from leading + fade — sidebar content
    static var maeSlideFromLeading: AnyTransition {
        .move(edge: .leading).combined(with: .opacity)
    }

    /// Subtle scale fade — panel content switching
    static var maeFadeScale: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.96).combined(with: .opacity),
            removal: .scale(scale: 1.02).combined(with: .opacity)
        )
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 1.6. Animation View Modifiers
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// Micro-scale effect triggered on hover — chat bubbles, cards
struct MaeHoverEffect: ViewModifier {
    var scale: CGFloat = 1.005
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? scale : 1.0)
            .shadow(color: Theme.Colors.accent.opacity(isHovered ? 0.06 : 0), radius: 8)
            .onHover { hovering in
                withAnimation(Theme.Animation.snappy) {
                    isHovered = hovering
                }
            }
    }
}

/// Scale + fade appear animation triggered on `.onAppear`
struct MaeAppearAnimation: ViewModifier {
    var animation: SwiftUI.Animation = Theme.Animation.gentle
    var scale: CGFloat = 0.95
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isVisible ? 1.0 : scale)
            .opacity(isVisible ? 1.0 : 0.0)
            .onAppear {
                withAnimation(animation) {
                    isVisible = true
                }
            }
    }
}

/// Staggered appear — each item slides up + fades in with incremental delay
struct MaeStaggeredAppear: ViewModifier {
    var index: Int
    var baseDelay: Double = 0.04
    var offsetY: CGFloat = 12
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1.0 : 0.0)
            .offset(y: isVisible ? 0 : offsetY)
            .onAppear {
                withAnimation(Theme.Animation.staggerDelay(index: index, base: baseDelay)) {
                    isVisible = true
                }
            }
    }
}

/// Button press feedback — scales down on tap with spring return
struct MaeButtonPressEffect: ViewModifier {
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.94 : 1.0)
            .opacity(isPressed ? 0.85 : 1.0)
            .animation(Theme.Animation.snappy, value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

/// Shimmer loading effect — animated gradient overlay
struct MaeShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = -1.0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        .clear,
                        Theme.Colors.accent.opacity(0.08),
                        Theme.Colors.accent.opacity(0.15),
                        Theme.Colors.accent.opacity(0.08),
                        .clear
                    ],
                    startPoint: .init(x: phase - 0.5, y: 0.5),
                    endPoint: .init(x: phase + 0.5, y: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusMedium, style: .continuous))
            )
            .onAppear {
                withAnimation(
                    .linear(duration: 1.8)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 2.0
                }
            }
    }
}

/// Pulse effect — subtle scale + opacity breathing (status dots, icons)
struct MaePulseEffect: ViewModifier {
    var minScale: CGFloat = 0.92
    var maxOpacity: Double = 1.0
    var minOpacity: Double = 0.6
    var duration: Double = 1.6
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.0 : minScale)
            .opacity(isPulsing ? maxOpacity : minOpacity)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: duration)
                    .repeatForever(autoreverses: true)
                ) {
                    isPulsing = true
                }
            }
    }
}

/// Floating effect — gentle vertical oscillation (empty states, decorative icons)
struct MaeFloatingEffect: ViewModifier {
    var amplitude: CGFloat = 6
    var duration: Double = 3.0
    @State private var isFloating = false

    func body(content: Content) -> some View {
        content
            .offset(y: isFloating ? -amplitude : amplitude)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: duration)
                    .repeatForever(autoreverses: true)
                ) {
                    isFloating = true
                }
            }
    }
}

/// Glow hover effect — hover with radiant glow behind element
struct MaeGlowHoverEffect: ViewModifier {
    var glowColor: Color = Theme.Colors.accent
    var glowRadius: CGFloat = 12
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? 1.03 : 1.0)
            .shadow(color: glowColor.opacity(isHovered ? 0.35 : 0), radius: glowRadius)
            .brightness(isHovered ? 0.05 : 0)
            .animation(Theme.Animation.responsive, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

/// Animated typing dots for loading state
struct MaeTypingDots: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.35)) { context in
            let activeIndex = Int(context.date.timeIntervalSinceReferenceDate / 0.35) % 3

            HStack(spacing: 5) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Theme.Colors.accent.opacity(activeIndex == index ? 0.9 : 0.3))
                        .frame(width: 6, height: 6)
                        .scaleEffect(activeIndex == index ? 1.3 : 1.0)
                        .animation(Theme.Animation.microBounce, value: activeIndex)
                }
            }
        }
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

    /// Micro-scale hover effect
    func maeHover(scale: CGFloat = 1.005) -> some View {
        self.modifier(MaeHoverEffect(scale: scale))
    }

    /// Scale + fade appear animation on `.onAppear`
    func maeAppearAnimation(animation: SwiftUI.Animation = Theme.Animation.gentle, scale: CGFloat = 0.95) -> some View {
        self.modifier(MaeAppearAnimation(animation: animation, scale: scale))
    }

    /// Staggered appear — list items cascade in
    func maeStaggered(index: Int, baseDelay: Double = 0.04) -> some View {
        self.modifier(MaeStaggeredAppear(index: index, baseDelay: baseDelay))
    }

    /// Button press feedback
    func maePressEffect() -> some View {
        self.modifier(MaeButtonPressEffect())
    }

    /// Shimmer loading overlay
    func maeShimmer() -> some View {
        self.modifier(MaeShimmerEffect())
    }

    /// Pulse breathing effect
    func maePulse(duration: Double = 1.6) -> some View {
        self.modifier(MaePulseEffect(duration: duration))
    }

    /// Floating idle animation
    func maeFloating(amplitude: CGFloat = 6, duration: Double = 3.0) -> some View {
        self.modifier(MaeFloatingEffect(amplitude: amplitude, duration: duration))
    }

    /// Glow on hover
    func maeGlowHover(color: Color = Theme.Colors.accent) -> some View {
        self.modifier(MaeGlowHoverEffect(glowColor: color))
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
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(Theme.Typography.bodyBold)
                    .foregroundStyle(iconColor)
                    .symbolEffect(.bounce, value: appeared)
                    .frame(width: 24, height: 24)
                    .background(iconColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .accessibilityHidden(true)
                    .onAppear { appeared = true }
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(subtitle != nil ? "\(title), \(subtitle!)" : title)
    }
}

// MARK: MaeIconButton
/// Circular icon button with optional accent highlighting.
struct MaeIconButton: View {
    let icon: String
    var size: CGFloat = 16
    var color: Color = Theme.Colors.textSecondary
    var bgColor: Color = .clear
    var helpText: String? = nil
    let action: () -> Void
    @State private var tapCount: Int = 0

    var body: some View {
        Button {
            tapCount += 1
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: size, weight: .regular))
                .foregroundStyle(color)
                .symbolEffect(.bounce, value: tapCount)
                .padding(bgColor == .clear ? 6 : 8)
                .background(bgColor)
                .frame(width: 36, height: 36)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(helpText ?? "")
        .accessibilityLabel(helpText ?? "")
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

import SwiftUI

// MARK: - Glass Tint Colors

enum GlassTint: Equatable {
    case blue
    case green
    case orange
    case yellow
    case purple
    case red
    case neutral
    
    var color: Color {
        switch self {
        case .blue: return MFTTheme.accent
        case .green: return MFTTheme.accent
        case .orange, .yellow: return MFTTheme.amber
        case .purple: return .white
        case .red: return .red
        case .neutral: return .secondary
        }
    }

    var foregroundColor: Color {
        switch self {
        case .blue, .green, .orange, .yellow, .purple: return MFTTheme.performance
        case .red: return .white
        case .neutral: return .primary
        }
    }
}

// MARK: - Glass Intensity

enum GlassIntensity {
    case subtle
    case prominent
    
    var blurRadius: CGFloat {
        switch self {
        case .subtle: return 12
        case .prominent: return 25
        }
    }
    
    var opacity: Double {
        switch self {
        case .subtle: return 0.7
        case .prominent: return 0.85
        }
    }
}

// MARK: - Glass Card View (iOS 18+)

@available(iOS 18.0, *)
struct GlassCard: View {
    let tint: GlassTint
    let intensity: GlassIntensity
    
    init(tint: GlassTint = .neutral, intensity: GlassIntensity = .subtle) {
        self.tint = tint
        self.intensity = intensity
    }
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(MFTTheme.surface.opacity(intensity.opacity))

            Rectangle()
                .fill(tint.color.opacity(tint == .neutral ? 0.025 : 0.055))
        }
    }
}

// MARK: - Glass Background View (iOS 18+)

@available(iOS 18.0, *)
struct GlassBackground: View {
    let tint: GlassTint
    
    init(tint: GlassTint = .neutral) {
        self.tint = tint
    }
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(MFTTheme.surface)

            Rectangle()
                .fill(tint.color.opacity(tint == .neutral ? 0.03 : 0.075))
        }
    }
}

// MARK: - View Extension for Glass Modifiers

extension View {
    /// Applies a subtle glass card effect with optional tint
    /// - Parameters:
    ///   - tint: The color tint to apply through the glass
    ///   - cornerRadius: The corner radius for the glass card
    /// - Returns: A view with glass card styling
    func glassCard(tint: GlassTint = .neutral, cornerRadius: CGFloat = 12) -> some View {
        self.modifier(GlassCardModifier(tint: tint, cornerRadius: cornerRadius))
    }
    
    /// Applies a prominent glass background effect
    /// - Parameters:
    ///   - tint: The color tint to apply through the glass
    ///   - cornerRadius: The corner radius for the glass background
    /// - Returns: A view with glass background styling
    func glassBackground(tint: GlassTint = .neutral, cornerRadius: CGFloat = 12) -> some View {
        self.modifier(GlassBackgroundModifier(tint: tint, cornerRadius: cornerRadius))
    }
    
    /// Applies glass styling conditionally based on iOS version
    /// - Parameters:
    ///   - tint: The glass tint color
    ///   - intensity: The intensity of the glass effect
    ///   - cornerRadius: The corner radius
    ///   - fallbackColor: The fallback color for iOS 17
    /// - Returns: A view with conditional glass styling
    func conditionalGlass(
        tint: GlassTint = .neutral,
        intensity: GlassIntensity = .subtle,
        cornerRadius: CGFloat = 12,
        fallbackColor: Color? = nil
    ) -> some View {
        self.modifier(
            ConditionalGlassModifier(
                tint: tint,
                intensity: intensity,
                cornerRadius: cornerRadius,
                fallbackColor: fallbackColor
            )
        )
    }
}

// MARK: - Glass Card Modifier

struct GlassCardModifier: ViewModifier {
    let tint: GlassTint
    let cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        let radius = min(cornerRadius, 8)

        content
            .background {
                if #available(iOS 18.0, *) {
                    GlassCard(tint: tint, intensity: .subtle)
                        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                } else {
                    MFTTheme.surface
                        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(tint == .neutral ? MFTTheme.divider : tint.color.opacity(0.24), lineWidth: 1)
            }
    }
}

// MARK: - Glass Background Modifier

struct GlassBackgroundModifier: ViewModifier {
    let tint: GlassTint
    let cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        let radius = min(cornerRadius, 8)

        content
            .background {
                if #available(iOS 18.0, *) {
                    GlassBackground(tint: tint)
                        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                } else {
                    MFTTheme.surface
                        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                }
            }
    }
}

// MARK: - Conditional Glass Modifier

struct ConditionalGlassModifier: ViewModifier {
    let tint: GlassTint
    let intensity: GlassIntensity
    let cornerRadius: CGFloat
    let fallbackColor: Color?
    
    func body(content: Content) -> some View {
        let radius = min(cornerRadius, 8)

        content
            .background {
                if #available(iOS 18.0, *) {
                    GlassCard(tint: tint, intensity: intensity)
                        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                } else {
                    (fallbackColor ?? MFTTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                }
            }
    }
}

// MARK: - Helper Functions

/// Check if the current iOS version supports Liquid Glass
func isLiquidGlassAvailable() -> Bool {
    if #available(iOS 18.0, *) {
        return true
    }
    return false
}

/// Get the appropriate background for the iOS version
@ViewBuilder
func adaptiveGlassBackground(tint: GlassTint = .neutral) -> some View {
    if #available(iOS 18.0, *) {
        GlassBackground(tint: tint)
    } else {
        tint.color.opacity(0.15)
    }
}

/// Get the appropriate card background for the iOS version
@ViewBuilder
func adaptiveGlassCard(tint: GlassTint = .neutral) -> some View {
    if #available(iOS 18.0, *) {
        GlassCard(tint: tint, intensity: .subtle)
    } else {
        tint.color.opacity(0.1)
    }
}

// MARK: - Glass Border Modifier

extension View {
    /// Adds a subtle glass border effect
    func glassBorder(tint: GlassTint = .neutral, cornerRadius: CGFloat = 12) -> some View {
        self.overlay {
            RoundedRectangle(cornerRadius: min(cornerRadius, 8), style: .continuous)
                .strokeBorder(tint.color.opacity(tint == .neutral ? 0.12 : 0.28), lineWidth: 1)
        }
    }
}

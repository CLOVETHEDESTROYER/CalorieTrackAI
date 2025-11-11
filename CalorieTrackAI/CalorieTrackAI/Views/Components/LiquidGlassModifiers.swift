import SwiftUI

// MARK: - Glass Tint Colors

enum GlassTint {
    case blue
    case green
    case orange
    case yellow
    case purple
    case red
    case neutral
    
    var color: Color {
        switch self {
        case .blue: return .blue
        case .green: return .green
        case .orange: return .orange
        case .yellow: return .yellow
        case .purple: return .purple
        case .red: return .red
        case .neutral: return .gray
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
            // Base glass layer with blur
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(intensity.opacity)
            
            // Tint overlay
            Rectangle()
                .fill(tint.color.opacity(0.08))
                .blendMode(.overlay)
            
            // Subtle shimmer effect
            LinearGradient(
                colors: [
                    Color.white.opacity(0.1),
                    Color.clear,
                    Color.white.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
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
            // Prominent glass material
            Rectangle()
                .fill(.regularMaterial)
            
            // Color tint
            Rectangle()
                .fill(tint.color.opacity(0.12))
                .blendMode(.overlay)
            
            // Enhanced shimmer for prominent surfaces
            LinearGradient(
                colors: [
                    Color.white.opacity(0.15),
                    Color.clear,
                    tint.color.opacity(0.1),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
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
        content
            .background {
                if #available(iOS 18.0, *) {
                    GlassCard(tint: tint, intensity: .subtle)
                        .cornerRadius(cornerRadius)
                } else {
                    // iOS 17 fallback
                    tint.color.opacity(0.1)
                        .cornerRadius(cornerRadius)
                }
            }
    }
}

// MARK: - Glass Background Modifier

struct GlassBackgroundModifier: ViewModifier {
    let tint: GlassTint
    let cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .background {
                if #available(iOS 18.0, *) {
                    GlassBackground(tint: tint)
                        .cornerRadius(cornerRadius)
                } else {
                    // iOS 17 fallback
                    tint.color.opacity(0.15)
                        .cornerRadius(cornerRadius)
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
        content
            .background {
                if #available(iOS 18.0, *) {
                    GlassCard(tint: tint, intensity: intensity)
                        .cornerRadius(cornerRadius)
                } else {
                    // iOS 17 fallback - use provided color or default
                    (fallbackColor ?? tint.color.opacity(0.1))
                        .cornerRadius(cornerRadius)
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
            if #available(iOS 18.0, *) {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                tint.color.opacity(0.3),
                                tint.color.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            } else {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(tint.color.opacity(0.3), lineWidth: 1)
            }
        }
    }
}


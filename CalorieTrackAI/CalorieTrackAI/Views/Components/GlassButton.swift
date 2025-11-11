import SwiftUI

/// A button with glass morphism effect
struct GlassButton: View {
    let title: String
    let icon: String?
    let tint: GlassTint
    let action: () -> Void
    let isLoading: Bool
    let isDisabled: Bool
    let style: ButtonStyle
    
    enum ButtonStyle {
        case primary   // Prominent glass with bold styling
        case secondary // Subtle glass with lighter styling
        case compact   // Small, compact button
    }
    
    init(
        _ title: String,
        icon: String? = nil,
        tint: GlassTint = .blue,
        style: ButtonStyle = .primary,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.tint = tint
        self.style = style
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: spacing) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(loadingScale)
                        .tint(.white)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(iconFont)
                }
                
                Text(title)
                    .font(textFont)
                    .fontWeight(fontWeight)
            }
            .foregroundColor(foregroundColor)
            .frame(maxWidth: style == .compact ? nil : .infinity)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background {
                if #available(iOS 18.0, *) {
                    glassBackground
                } else {
                    fallbackBackground
                }
            }
            .cornerRadius(cornerRadius)
            .overlay {
                if #available(iOS 18.0, *) {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    tint.color.opacity(isDisabled ? 0.1 : 0.4),
                                    tint.color.opacity(isDisabled ? 0.05 : 0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(tint.color.opacity(isDisabled ? 0.2 : 0.4), lineWidth: 1)
                }
            }
        }
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.6 : 1.0)
    }
    
    // MARK: - Glass Background (iOS 18+)
    
    @available(iOS 18.0, *)
    private var glassBackground: some View {
        ZStack {
            if style == .primary {
                GlassBackground(tint: tint)
            } else {
                GlassCard(tint: tint, intensity: .subtle)
            }
            
            // Enhanced tint for buttons
            tint.color.opacity(style == .primary ? 0.3 : 0.15)
                .blendMode(.overlay)
        }
    }
    
    // MARK: - Fallback Background (iOS 17)
    
    private var fallbackBackground: some View {
        tint.color.opacity(style == .primary ? 0.8 : 0.2)
    }
    
    // MARK: - Style Properties
    
    private var spacing: CGFloat {
        switch style {
        case .primary: return 8
        case .secondary: return 6
        case .compact: return 4
        }
    }
    
    private var horizontalPadding: CGFloat {
        switch style {
        case .primary: return 16
        case .secondary: return 12
        case .compact: return 8
        }
    }
    
    private var verticalPadding: CGFloat {
        switch style {
        case .primary: return 12
        case .secondary: return 10
        case .compact: return 6
        }
    }
    
    private var cornerRadius: CGFloat {
        switch style {
        case .primary: return 12
        case .secondary: return 10
        case .compact: return 8
        }
    }
    
    private var textFont: Font {
        switch style {
        case .primary: return .body
        case .secondary: return .subheadline
        case .compact: return .caption
        }
    }
    
    private var iconFont: Font {
        switch style {
        case .primary: return .body
        case .secondary: return .subheadline
        case .compact: return .caption
        }
    }
    
    private var fontWeight: Font.Weight {
        switch style {
        case .primary: return .semibold
        case .secondary: return .medium
        case .compact: return .medium
        }
    }
    
    private var foregroundColor: Color {
        if isDisabled {
            return .secondary
        }
        if #available(iOS 18.0, *) {
            return style == .primary ? .white : .primary
        } else {
            return style == .primary ? .white : .primary
        }
    }
    
    private var loadingScale: CGFloat {
        switch style {
        case .primary: return 0.8
        case .secondary: return 0.7
        case .compact: return 0.6
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        GlassButton("Primary Button", icon: "star.fill", tint: .blue, style: .primary) {
            print("Primary tapped")
        }
        
        GlassButton("Secondary Button", icon: "heart.fill", tint: .red, style: .secondary) {
            print("Secondary tapped")
        }
        
        GlassButton("Compact", icon: "plus", tint: .green, style: .compact) {
            print("Compact tapped")
        }
        
        GlassButton("Loading", tint: .purple, style: .primary, isLoading: true) {
            print("Loading tapped")
        }
        
        GlassButton("Disabled", tint: .orange, style: .primary, isDisabled: true) {
            print("Disabled tapped")
        }
    }
    .padding()
    .background(
        LinearGradient(
            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}


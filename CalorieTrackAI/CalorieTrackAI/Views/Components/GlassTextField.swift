import SwiftUI

/// A text field with glass morphism effect
struct GlassTextField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String?
    let tint: GlassTint
    let keyboardType: UIKeyboardType
    let isSecure: Bool
    let isDisabled: Bool
    
    init(
        _ placeholder: String,
        text: Binding<String>,
        icon: String? = nil,
        tint: GlassTint = .neutral,
        keyboardType: UIKeyboardType = .default,
        isSecure: Bool = false,
        isDisabled: Bool = false
    ) {
        self.placeholder = placeholder
        self._text = text
        self.icon = icon
        self.tint = tint
        self.keyboardType = keyboardType
        self.isSecure = isSecure
        self.isDisabled = isDisabled
    }
    
    var body: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(tint.color)
                    .font(.body)
            }
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .textFieldStyle(PlainTextFieldStyle())
                    .disabled(isDisabled)
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(PlainTextFieldStyle())
                    .keyboardType(keyboardType)
                    .disabled(isDisabled)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            if #available(iOS 18.0, *) {
                glassBackground
            } else {
                fallbackBackground
            }
        }
        .cornerRadius(12)
        .overlay {
            if #available(iOS 18.0, *) {
                RoundedRectangle(cornerRadius: 12)
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
                RoundedRectangle(cornerRadius: 12)
                    .stroke(tint.color.opacity(0.3), lineWidth: 1)
            }
        }
        .opacity(isDisabled ? 0.6 : 1.0)
    }
    
    @available(iOS 18.0, *)
    private var glassBackground: some View {
        ZStack {
            GlassCard(tint: tint, intensity: .subtle)
            
            // Subtle tint
            tint.color.opacity(0.05)
                .blendMode(.overlay)
        }
    }
    
    private var fallbackBackground: some View {
        tint.color.opacity(0.08)
    }
}

/// A numeric text field with glass morphism effect for Double values
struct GlassNumberField: View {
    let placeholder: String
    @Binding var value: Double
    let icon: String?
    let tint: GlassTint
    let isDisabled: Bool
    
    init(
        _ placeholder: String,
        value: Binding<Double>,
        icon: String? = nil,
        tint: GlassTint = .neutral,
        isDisabled: Bool = false
    ) {
        self.placeholder = placeholder
        self._value = value
        self.icon = icon
        self.tint = tint
        self.isDisabled = isDisabled
    }
    
    var body: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(tint.color)
                    .font(.body)
            }
            
            TextField(placeholder, value: $value, format: .number)
                .textFieldStyle(PlainTextFieldStyle())
                .keyboardType(.decimalPad)
                .disabled(isDisabled)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            if #available(iOS 18.0, *) {
                glassBackground
            } else {
                fallbackBackground
            }
        }
        .cornerRadius(12)
        .overlay {
            if #available(iOS 18.0, *) {
                RoundedRectangle(cornerRadius: 12)
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
                RoundedRectangle(cornerRadius: 12)
                    .stroke(tint.color.opacity(0.3), lineWidth: 1)
            }
        }
        .opacity(isDisabled ? 0.6 : 1.0)
    }
    
    @available(iOS 18.0, *)
    private var glassBackground: some View {
        ZStack {
            GlassCard(tint: tint, intensity: .subtle)
            
            // Subtle tint
            tint.color.opacity(0.05)
                .blendMode(.overlay)
        }
    }
    
    private var fallbackBackground: some View {
        tint.color.opacity(0.08)
    }
}

/// A multi-line text editor with glass morphism effect
struct GlassTextEditor: View {
    let placeholder: String
    @Binding var text: String
    let tint: GlassTint
    let minHeight: CGFloat
    let isDisabled: Bool
    
    init(
        _ placeholder: String,
        text: Binding<String>,
        tint: GlassTint = .neutral,
        minHeight: CGFloat = 100,
        isDisabled: Bool = false
    ) {
        self.placeholder = placeholder
        self._text = text
        self.tint = tint
        self.minHeight = minHeight
        self.isDisabled = isDisabled
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
            }
            
            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .disabled(isDisabled)
        }
        .frame(minHeight: minHeight)
        .background {
            if #available(iOS 18.0, *) {
                glassBackground
            } else {
                fallbackBackground
            }
        }
        .cornerRadius(12)
        .overlay {
            if #available(iOS 18.0, *) {
                RoundedRectangle(cornerRadius: 12)
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
                RoundedRectangle(cornerRadius: 12)
                    .stroke(tint.color.opacity(0.3), lineWidth: 1)
            }
        }
        .opacity(isDisabled ? 0.6 : 1.0)
    }
    
    @available(iOS 18.0, *)
    private var glassBackground: some View {
        ZStack {
            GlassCard(tint: tint, intensity: .subtle)
            
            // Subtle tint
            tint.color.opacity(0.05)
                .blendMode(.overlay)
        }
    }
    
    private var fallbackBackground: some View {
        tint.color.opacity(0.08)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        GlassTextField(
            "Email",
            text: .constant(""),
            icon: "envelope.fill",
            tint: .blue
        )
        
        GlassTextField(
            "Password",
            text: .constant(""),
            icon: "lock.fill",
            tint: .blue,
            isSecure: true
        )
        
        GlassNumberField(
            "Calories",
            value: .constant(0),
            icon: "flame.fill",
            tint: .orange
        )
        
        GlassTextEditor(
            "Describe your meal...",
            text: .constant(""),
            tint: .purple,
            minHeight: 100
        )
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


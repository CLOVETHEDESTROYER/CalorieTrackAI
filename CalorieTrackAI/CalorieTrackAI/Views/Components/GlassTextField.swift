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
                    .accessibilityIdentifier("glass-text-field-\(placeholder)")
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(PlainTextFieldStyle())
                    .keyboardType(keyboardType)
                    .disabled(isDisabled)
                    .accessibilityIdentifier("glass-text-field-\(placeholder)")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(MFTTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(tint.color.opacity(0.28), lineWidth: 1)
                    .allowsHitTesting(false)
        }
        .opacity(isDisabled ? 0.6 : 1.0)
        .accessibilityIdentifier("glass-text-field-\(placeholder)")
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
                .accessibilityIdentifier("glass-number-field-\(placeholder)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(MFTTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(tint.color.opacity(0.28), lineWidth: 1)
                    .allowsHitTesting(false)
        }
        .opacity(isDisabled ? 0.6 : 1.0)
        .accessibilityIdentifier("glass-number-field-\(placeholder)")
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
                    .allowsHitTesting(false)
            }

            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .disabled(isDisabled)
                .accessibilityIdentifier("glass-text-editor-\(placeholder)")
        }
        .frame(minHeight: minHeight)
        .background(MFTTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(tint.color.opacity(0.28), lineWidth: 1)
                    .allowsHitTesting(false)
        }
        .opacity(isDisabled ? 0.6 : 1.0)
        .accessibilityIdentifier("glass-text-editor-\(placeholder)")
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
    .background(MFTTheme.background)
}

import SwiftUI

struct CoachCalloutView: View {
    let message: CoachMessage

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 6) {
                Text(message.title)
                    .font(.headline)
                    .fontWeight(.black)
                    .textCase(.uppercase)

                Text(message.body)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding()
        .glassCard(tint: tint, cornerRadius: 12)
        .glassBorder(tint: tint, cornerRadius: 12)
    }

    private var iconName: String {
        switch message.severity {
        case .praise: return "checkmark.seal.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .roast: return "flame.fill"
        }
    }

    private var color: Color {
        switch message.severity {
        case .praise: return .green
        case .warning: return .orange
        case .roast: return .red
        }
    }

    private var tint: GlassTint {
        switch message.severity {
        case .praise: return .green
        case .warning: return .orange
        case .roast: return .red
        }
    }
}

#Preview {
    CoachCalloutView(
        message: CoachMessage(
            title: "Fatness Alert",
            body: "You blew past the calorie line. Put the snacks down and go earn some dignity back.",
            severity: .roast
        )
    )
    .padding()
}

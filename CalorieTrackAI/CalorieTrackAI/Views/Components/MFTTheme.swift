import SwiftUI

enum MFTTheme {
    static let background = Color(red: 0.025, green: 0.03, blue: 0.027)
    static let surface = Color(red: 0.065, green: 0.076, blue: 0.068)
    static let elevatedSurface = Color(red: 0.095, green: 0.108, blue: 0.098)
    static let performance = Color(red: 0.018, green: 0.022, blue: 0.019)
    static let divider = Color.white.opacity(0.1)
    static let accent = Color(red: 0.72, green: 1.0, blue: 0.25)
    static let blue = Color.white.opacity(0.9)
    static let amber = Color(red: 1.0, green: 0.66, blue: 0.24)
    static let mutedText = Color.white.opacity(0.58)
    static let subduedLime = accent.opacity(0.12)

    static func challengeAccent(_ challengeType: MovementChallengeType) -> Color {
        switch challengeType {
        case .pushUp: return accent
        case .squat: return .white
        case .jumpingJack: return amber
        case .plank: return Color(red: 0.32, green: 0.82, blue: 1.0)
        }
    }
}

struct MFTPageHeader: View {
    let kicker: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Capsule()
                    .fill(MFTTheme.accent)
                    .frame(width: 28, height: 4)

                Text(kicker.uppercased())
                    .font(.caption2)
                    .fontWeight(.black)
                    .foregroundColor(MFTTheme.accent)
            }

            Text(title)
                .font(.system(.largeTitle, design: .rounded, weight: .black))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(MFTTheme.mutedText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    func mftPageChrome() -> some View {
        self
            .foregroundStyle(.white)
            .tint(MFTTheme.accent)
            .toolbarBackground(MFTTheme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }

    func mftPanel(accent: Color? = nil) -> some View {
        self
            .background(MFTTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(alignment: .leading) {
                if let accent {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(accent)
                        .frame(width: 3)
                        .padding(.vertical, 12)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(MFTTheme.divider, lineWidth: 1)
            }
    }
}

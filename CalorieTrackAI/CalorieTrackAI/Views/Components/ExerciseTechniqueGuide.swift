import SwiftUI

struct ExerciseTechniqueGuide: View {
    let challengeType: MovementChallengeType
    var isActive = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isFloating = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                groundLine(width: proxy.size.width)

                if !reduceMotion {
                    ArticulatedMannequinView(
                        challengeType: challengeType,
                        isAnimated: isActive
                    )
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .shadow(color: accent.opacity(0.20), radius: 12)
                } else {
                    staticGuide(
                        width: proxy.size.width,
                        height: proxy.size.height
                    )
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                isFloating = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Artist mannequin demonstrating proper \(challengeType.shortTitle) position")
    }

    private func staticGuide(width: CGFloat, height: CGFloat) -> some View {
        Image(assetName)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: width, maxHeight: height)
            .scaleEffect(imageScale)
            .offset(y: reduceMotion ? 0 : (isFloating ? -2 : 1))
            .shadow(color: accent.opacity(0.22), radius: 12)
            .shadow(color: .black.opacity(0.5), radius: 4, y: 3)
    }

    private var assetName: String {
        switch challengeType {
        case .pushUp:
            return "PushUpMannequin"
        case .squat:
            return "SquatMannequin"
        case .jumpingJack:
            return "JumpingJackMannequin"
        case .plank:
            return "PlankMannequin"
        }
    }

    private var imageScale: CGFloat {
        switch challengeType {
        case .pushUp:
            return 1.08
        case .squat:
            return 1.12
        case .jumpingJack:
            return 1.06
        case .plank:
            return 1.14
        }
    }

    private var accent: Color {
        MFTTheme.challengeAccent(challengeType)
    }

    private func groundLine(width: CGFloat) -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.13))
            .frame(width: width * 0.72, height: 1)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(accent.opacity(0.7))
                    .frame(width: width * 0.18, height: 2)
            }
            .padding(.bottom, 3)
    }
}

#Preview {
    HStack(spacing: 16) {
        ForEach(MovementChallengeType.allCases) { challenge in
            ExerciseTechniqueGuide(challengeType: challenge)
                .frame(width: 150, height: 180)
        }
    }
    .padding()
    .background(MFTTheme.performance)
}

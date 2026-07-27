import SwiftUI
import CoreImage.CIFilterBuiltins

enum SocialShareText {
    static func friendMessage(name: String, code: String) -> String {
        "Add \(name) on My Fatness Tracker. Open myfatnesstracker://friend?code=\(code), or enter friend code \(code) in Competition after you install the app."
    }

    static func challengeMessage(_ invite: SharedChallengeInvite) -> String {
        let challenge = invite.isTimedHold
            ? "I held a verified plank for \(invite.challengerScoreDisplay) on My Fatness Tracker. Beat it with a \(invite.targetScoreDisplay) hold."
            : "I hit \(invite.challengerScoreDisplay) verified \(invite.challenge_type.shortTitle.lowercased()) on My Fatness Tracker. Beat \(invite.targetScoreDisplay) clean reps."
        return "\(challenge) Open myfatnesstracker://challenge?code=\(invite.invite_code), or install the app and redeem challenge code \(invite.invite_code). Code expires in 7 days."
    }

    static func friendURL(code: String) -> URL? {
        URL(string: "myfatnesstracker://friend?code=\(code)")
    }
}

struct SocialQRCodeSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let subtitle: String
    let value: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer(minLength: 8)

                Image(uiImage: qrImage(for: value))
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 240, height: 240)
                    .padding(14)
                    .background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(spacing: 8) {
                    Text(title)
                        .font(.title3)
                        .fontWeight(.black)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Text(value)
                        .font(.title3.monospaced())
                        .fontWeight(.black)
                        .foregroundColor(MFTTheme.accent)
                }

                Spacer()
            }
            .padding(24)
            .background(MFTTheme.background.ignoresSafeArea())
            .navigationTitle("Scan to Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .mftPageChrome()
        }
    }

    private func qrImage(for value: String) -> UIImage {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(value.utf8)
        filter.correctionLevel = "M"

        let output = filter.outputImage ?? CIImage()
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        return UIImage(ciImage: scaled)
    }
}

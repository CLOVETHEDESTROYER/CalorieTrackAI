import SwiftUI

struct ResetPasswordView: View {
    @EnvironmentObject private var supabaseService: SupabaseService
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isUpdating = false
    @State private var errorMessage = ""

    private var isFormValid: Bool {
        password.count >= 6 && password == confirmPassword
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "lock.rotation")
                        .font(.system(size: 56, weight: .semibold))
                        .foregroundColor(MFTTheme.accent)

                    Text("Reset Password")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Set the new password, then get back to tracking. The coach has no patience for account limbo.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 12)

                VStack(spacing: 14) {
                    GlassTextField(
                        "New Password",
                        text: $password,
                        icon: "lock.fill",
                        tint: .blue,
                        isSecure: true
                    )

                    GlassTextField(
                        "Confirm New Password",
                        text: $confirmPassword,
                        icon: "lock.fill",
                        tint: .blue,
                        isSecure: true
                    )

                    if !password.isEmpty && password.count < 6 {
                        Text("Password must be at least 6 characters.")
                            .font(.caption)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !confirmPassword.isEmpty && password != confirmPassword {
                        Text("Passwords do not match.")
                            .font(.caption)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                GlassButton(
                    isUpdating ? "Updating..." : "Update Password",
                    icon: isUpdating ? nil : "checkmark.seal.fill",
                    tint: .blue,
                    style: .primary,
                    isLoading: isUpdating,
                    isDisabled: !isFormValid
                ) {
                    updatePassword()
                }

                Button(role: .destructive) {
                    cancelRecovery()
                } label: {
                    Text("Cancel Reset")
                        .font(.subheadline)
                }

                Spacer()
            }
            .padding(24)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func updatePassword() {
        isUpdating = true
        errorMessage = ""

        Task {
            do {
                try await supabaseService.updatePassword(password)
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isUpdating = false
                }
            }
        }
    }

    private func cancelRecovery() {
        Task {
            await supabaseService.cancelPasswordRecovery()
        }
    }
}

#Preview {
    ResetPasswordView()
        .environmentObject(SupabaseService.shared)
}

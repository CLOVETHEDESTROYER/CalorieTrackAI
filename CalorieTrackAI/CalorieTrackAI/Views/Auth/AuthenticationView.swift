import AuthenticationServices
import CryptoKit
import Security
import SwiftUI

struct AuthenticationView: View {
    @StateObject private var supabaseService = SupabaseService.shared
    @State private var showSignUp = false

    var body: some View {
        NavigationView {
            if supabaseService.isAuthenticated {
                ContentView()
            } else {
                if showSignUp {
                    SignUpView(showSignUp: $showSignUp)
                } else {
                    SignInView(showSignUp: $showSignUp)
                }
            }
        }
    }
}

struct SignInView: View {
    @StateObject private var supabaseService = SupabaseService.shared
    @Environment(\.showAuth) private var showAuth
    @Environment(\.dismiss) private var dismiss
    @Binding var showSignUp: Bool

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var isResettingPassword = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var successMessage = ""
    @State private var showSuccess = false
    @State private var currentAppleNonce: String?
    @State private var appleRequestSetupFailed = false

    var body: some View {
        ZStack {
            MFTTheme.background
                .ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    Button {
                        closeAuth()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                            .accessibilityLabel("Close sign in")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)

                // App Logo and Title
                VStack(spacing: 16) {
                    Image(systemName: "flame.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(MFTTheme.accent)

                    Text("My Fatness Tracker")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Log the food. Hit the plan. Survive the coach.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)

                Spacer()

                // Sign In Form
                VStack(spacing: 16) {
                    GlassTextField(
                        "Email",
                        text: $email,
                        icon: "envelope.fill",
                        tint: .blue,
                        keyboardType: .emailAddress
                    )

                    GlassTextField(
                        "Password",
                        text: $password,
                        icon: "lock.fill",
                        tint: .blue,
                        isSecure: true
                    )

                    GlassButton(
                        isLoading ? "Signing In..." : "Sign In",
                        icon: isLoading ? nil : "arrow.right.circle.fill",
                        tint: .blue,
                        style: .primary,
                        isLoading: isLoading,
                        isDisabled: email.isEmpty || password.isEmpty
                    ) {
                        signIn()
                    }

                    appleSignInButton

                    Button("Forgot Password?") {
                        resetPassword()
                    }
                    .foregroundColor(MFTTheme.blue)
                    .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isResettingPassword)

                    if isResettingPassword {
                        ProgressView("Sending reset email...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()

                // Sign Up Option
                HStack {
                    Text("Don't have an account?")
                        .foregroundColor(.secondary)

                    Button("Sign Up") {
                        showSignUp = true
                    }
                    .foregroundColor(MFTTheme.blue)
                }

                Button("Not now") {
                    closeAuth()
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.bottom, 32)
            }
        }
        .navigationBarHidden(true)
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .alert("Check Your Email", isPresented: $showSuccess) {
            Button("OK") { }
        } message: {
            Text(successMessage)
        }
    }

    private func signIn() {
        isLoading = true
        errorMessage = ""

        Task {
            do {
                _ = try await supabaseService.signIn(email: email, password: password)
                await MainActor.run {
                    isLoading = false
                    closeAuth()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private var appleSignInButton: some View {
        SignInWithAppleButton(.signIn) { request in
            do {
                let nonce = try AppleSignInNonce.randomNonceString()
                appleRequestSetupFailed = false
                currentAppleNonce = nonce
                request.requestedScopes = [.fullName, .email]
                request.nonce = AppleSignInNonce.sha256(nonce)
            } catch {
                appleRequestSetupFailed = true
                currentAppleNonce = nil
                errorMessage = AppleSignInErrorMessage.friendlyMessage(from: error)
                showError = true
            }
        } onCompletion: { result in
            guard !appleRequestSetupFailed else {
                appleRequestSetupFailed = false
                isLoading = false
                currentAppleNonce = nil
                return
            }
            handleAppleSignIn(result)
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let nonce = currentAppleNonce,
                  let identityToken = credential.identityToken,
                  let idToken = String(data: identityToken, encoding: .utf8) else {
                isLoading = false
                currentAppleNonce = nil
                errorMessage = "Apple sign-in did not return a usable identity token."
                showError = true
                return
            }

            let displayName = PersonNameComponentsFormatter().string(from: credential.fullName ?? PersonNameComponents())
            isLoading = true
            Task {
                do {
                    try await supabaseService.signInWithApple(
                        idToken: idToken,
                        nonce: nonce,
                        name: displayName.isEmpty ? nil : displayName
                    )
                    await MainActor.run {
                        isLoading = false
                        currentAppleNonce = nil
                        closeAuth()
                    }
                } catch {
                    await MainActor.run {
                        isLoading = false
                        currentAppleNonce = nil
                        errorMessage = AppleSignInErrorMessage.friendlyMessage(from: error)
                        showError = true
                    }
                }
            }
        case .failure(let error):
            isLoading = false
            currentAppleNonce = nil
            guard !AppleSignInErrorMessage.isUserCancellation(error) else {
                return
            }
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func closeAuth() {
        showAuth.wrappedValue = false
        dismiss()
    }

    private func resetPassword() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty else {
            errorMessage = "Enter your email first so Supabase knows where to send the reset link."
            showError = true
            return
        }

        isResettingPassword = true
        errorMessage = ""
        successMessage = ""

        Task {
            do {
                try await supabaseService.resetPassword(email: trimmedEmail)
                await MainActor.run {
                    isResettingPassword = false
                    successMessage = "Password reset sent to \(trimmedEmail). Check your inbox, then come back and sign in."
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isResettingPassword = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

enum AppleSignInNonce {
    enum NonceError: LocalizedError, Equatable {
        case invalidLength
        case randomGenerationFailed(OSStatus)

        var errorDescription: String? {
            switch self {
            case .invalidLength:
                return "Apple sign-in could not start because the request nonce length was invalid."
            case .randomGenerationFailed(let status):
                return "Apple sign-in could not start because iOS could not generate a secure request nonce. Try again. OSStatus: \(status)"
            }
        }
    }

    static func randomNonceString(length: Int = 32) throws -> String {
        try randomNonceString(length: length) { randoms in
            SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
        }
    }

    static func randomNonceString(
        length: Int = 32,
        randomBytes: (inout [UInt8]) -> OSStatus
    ) throws -> String {
        guard length > 0 else {
            throw NonceError.invalidLength
        }

        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = randomBytes(&randoms)
            if status != errSecSuccess {
                throw NonceError.randomGenerationFailed(status)
            }

            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }

                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.map { String(format: "%02x", $0) }.joined()
    }
}

struct SignUpView: View {
    @StateObject private var supabaseService = SupabaseService.shared
    @Environment(\.showAuth) private var showAuth
    @Environment(\.dismiss) private var dismiss
    @Binding var showSignUp: Bool

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var showSuccess = false
    @State private var currentAppleNonce: String?
    @State private var appleRequestSetupFailed = false

    var body: some View {
        NavigationView {
            ZStack {
                MFTTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 16) {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.system(size: 60))
                                .foregroundColor(MFTTheme.accent)

                            Text("Create Account")
                                .font(.largeTitle)
                                .fontWeight(.bold)

                            Text("Join My Fatness Tracker and give the coach receipts.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            #if os(iOS)
                                .multilineTextAlignment(.center)
                            #endif
                        }
                        .padding(.top, 20)

                        // Sign Up Form
                        VStack(spacing: 16) {
                            appleSignUpButton

                            HStack {
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.25))
                                    .frame(height: 1)

                                Text("or use email")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)

                                Rectangle()
                                    .fill(Color.secondary.opacity(0.25))
                                    .frame(height: 1)
                            }

                            GlassTextField(
                                "Full Name",
                                text: $name,
                                icon: "person.fill",
                                tint: .green
                            )

                            GlassTextField(
                                "Email",
                                text: $email,
                                icon: "envelope.fill",
                                tint: .blue,
                                keyboardType: .emailAddress
                            )

                            GlassTextField(
                                "Password",
                                text: $password,
                                icon: "lock.fill",
                                tint: .purple,
                                isSecure: true
                            )

                            GlassTextField(
                                "Confirm Password",
                                text: $confirmPassword,
                                icon: "lock.fill",
                                tint: .purple,
                                isSecure: true
                            )

                            if !password.isEmpty && password.count < 6 {
                                Text("Password must be at least 6 characters")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            if !confirmPassword.isEmpty && password != confirmPassword {
                                Text("Passwords don't match")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            GlassButton(
                                isLoading ? "Creating Account..." : "Create Account",
                                icon: isLoading ? nil : "person.badge.plus",
                                tint: .green,
                                style: .primary,
                                isLoading: isLoading,
                                isDisabled: !isFormValid
                            ) {
                                signUp()
                            }
                        }
                        .padding(.horizontal, 32)

                        Text("Creating an account stores your profile and app data so it can sync across devices. Privacy details are available from the App Store listing.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            #if os(iOS)
                            .multilineTextAlignment(.center)
                            #endif
                            .padding(.horizontal, 32)

                        Spacer(minLength: 20)
                    }
                }
            }
            .navigationBarItems(
                leading: Button("Back") {
                    showSignUp = false
                },
                trailing: Button("Close") {
                    closeAuth()
                }
            )
            .alert("Success", isPresented: $showSuccess) {
                Button("OK") {
                    showSignUp = false
                }
            } message: {
                Text("Account created successfully! Please check your email to verify your account.")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var isFormValid: Bool {
        !name.isEmpty &&
        !email.isEmpty &&
        password.count >= 6 &&
        password == confirmPassword
    }

    private func signUp() {
        isLoading = true
        errorMessage = ""

        Task {
            do {
                _ = try await supabaseService.signUp(email: email, password: password, name: name)
                await MainActor.run {
                    isLoading = false
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private var appleSignUpButton: some View {
        SignInWithAppleButton(.signUp) { request in
            do {
                let nonce = try AppleSignInNonce.randomNonceString()
                appleRequestSetupFailed = false
                currentAppleNonce = nonce
                request.requestedScopes = [.fullName, .email]
                request.nonce = AppleSignInNonce.sha256(nonce)
            } catch {
                appleRequestSetupFailed = true
                currentAppleNonce = nil
                errorMessage = AppleSignInErrorMessage.friendlyMessage(from: error)
                showError = true
            }
        } onCompletion: { result in
            guard !appleRequestSetupFailed else {
                appleRequestSetupFailed = false
                isLoading = false
                currentAppleNonce = nil
                return
            }
            handleAppleSignUp(result)
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func handleAppleSignUp(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let nonce = currentAppleNonce,
                  let identityToken = credential.identityToken,
                  let idToken = String(data: identityToken, encoding: .utf8) else {
                isLoading = false
                currentAppleNonce = nil
                errorMessage = "Apple sign-up did not return a usable identity token."
                showError = true
                return
            }

            let appleDisplayName = PersonNameComponentsFormatter().string(from: credential.fullName ?? PersonNameComponents())
            let displayName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? appleDisplayName : name

            isLoading = true
            Task {
                do {
                    try await supabaseService.signInWithApple(
                        idToken: idToken,
                        nonce: nonce,
                        name: displayName.isEmpty ? nil : displayName
                    )
                    await MainActor.run {
                        isLoading = false
                        currentAppleNonce = nil
                        closeAuth()
                    }
                } catch {
                    await MainActor.run {
                        isLoading = false
                        currentAppleNonce = nil
                        errorMessage = AppleSignInErrorMessage.friendlyMessage(from: error)
                        showError = true
                    }
                }
            }
        case .failure(let error):
            isLoading = false
            currentAppleNonce = nil
            guard !AppleSignInErrorMessage.isUserCancellation(error) else {
                return
            }
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func closeAuth() {
        showAuth.wrappedValue = false
        dismiss()
    }
}

enum AppleSignInErrorMessage {
    static func isUserCancellation(_ error: Error) -> Bool {
        guard let authorizationError = error as? ASAuthorizationError else {
            return false
        }

        return authorizationError.code == .canceled
    }

    static func friendlyMessage(from error: Error) -> String {
        if let nonceError = error as? AppleSignInNonce.NonceError {
            return nonceError.localizedDescription
        }

        let message = error.localizedDescription
        let normalized = message.lowercased()

        if normalized.contains("appleid.apple.com") && normalized.contains("not enabled")
            || normalized.contains("provider") && normalized.contains("apple") && normalized.contains("not enabled") {
            return "Apple sign-in reached Supabase, but the Apple provider is not enabled for this Supabase project yet. Enable Authentication > Providers > Apple in Supabase, then try again."
        }

        if normalized.contains("audience")
            || normalized.contains("client id")
            || normalized.contains("client_id")
            || normalized.contains("invalid claim: aud")
            || normalized.contains("invalid audience")
            || normalized.contains("invalid jwt") && normalized.contains("aud") {
            return "Apple sign-in reached Supabase, but the Apple client ID does not match this app. In Supabase Authentication > Providers > Apple, add client ID com.hyperlabsAI.CalorieTrackAI, then archive with a provisioning profile that includes Sign in with Apple."
        }

        if normalized.contains("nonce") {
            return "Apple sign-in could not verify the request nonce. Try again; if it keeps happening, reinstall the TestFlight build so the stored Apple authorization state is fresh."
        }

        if normalized.contains("entitlement")
            || normalized.contains("capability")
            || normalized.contains("authorization failed") {
            return "Apple sign-in is not available in this build yet. Make sure Sign in with Apple is enabled for com.hyperlabsAI.CalorieTrackAI in Apple Developer, then refresh the provisioning profile and rebuild."
        }

        return message
    }
}

#Preview {
    AuthenticationView()
}

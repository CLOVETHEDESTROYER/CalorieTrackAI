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
    @Binding var showSignUp: Bool
    
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    
    var body: some View {
        VStack(spacing: 24) {
            // App Logo and Title
            VStack(spacing: 16) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("CalTrack AI")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Track your nutrition with AI")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 40)
            
            Spacer()
            
            // Sign In Form
            VStack(spacing: 16) {
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button(action: signIn) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Sign In")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(isLoading || email.isEmpty || password.isEmpty)
                
                Button("Forgot Password?") {
                    // TODO: Implement password reset
                }
                .foregroundColor(.blue)
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
                .foregroundColor(.blue)
            }
            .padding(.bottom, 32)
        }
        .navigationBarHidden(true)
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
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
}

struct SignUpView: View {
    @StateObject private var supabaseService = SupabaseService.shared
    @Binding var showSignUp: Bool
    
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var showSuccess = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Create Account")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Join CalTrack AI and start your nutrition journey")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Sign Up Form
                    VStack(spacing: 16) {
                        TextField("Full Name", text: $name)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textInputAutocapitalization(.words)
                        
                        TextField("Email", text: $email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                        
                        SecureField("Password", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        SecureField("Confirm Password", text: $confirmPassword)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
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
                        
                        Button(action: signUp) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Create Account")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isFormValid ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .disabled(!isFormValid || isLoading)
                    }
                    .padding(.horizontal, 32)
                    
                    // Terms and Privacy
                    Text("By creating an account, you agree to our Terms of Service and Privacy Policy")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    Spacer(minLength: 20)
                }
            }
            .navigationBarItems(
                leading: Button("Back") {
                    showSignUp = false
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
}

#Preview {
    AuthenticationView()
} 
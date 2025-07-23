import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showingEditProfile = false
    
    var body: some View {
        NavigationView {
            List {
                // Profile Header
                Section {
                    HStack {
                        Circle()
                            .fill(Color.blue.gradient)
                            .frame(width: 60, height: 60)
                            .overlay(
                                Text(viewModel.user.name.prefix(1).uppercased())
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.user.name)
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Daily Goal: \(Int(viewModel.user.dailyCalorieGoal)) cal")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Edit") {
                            showingEditProfile = true
                        }
                        .foregroundColor(.blue)
                    }
                    .padding(.vertical, 8)
                }
                
                // Daily Calorie Goal Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Daily Calorie Goal")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(Int(viewModel.user.dailyCalorieGoal))")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                                Text("calories per day")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(viewModel.user.goalType.rawValue.capitalized)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                Text("Goal")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if viewModel.user.goalType != .maintainWeight {
                            HStack {
                                Text("Weekly Target:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(abs(viewModel.user.weeklyWeightChange), specifier: "%.1f") lbs \(viewModel.user.goalType == .loseWeight ? "loss" : "gain")")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                
                // Stats Section
                Section("Your Stats") {
                    StatsRowView(title: "Age", value: "\(viewModel.user.age) years")
                    StatsRowView(title: "Weight", value: "\(formattedWeight(viewModel.user.weight, unit: viewModel.user.weightUnit))")
                    StatsRowView(title: "Height", value: "\(formattedHeight(viewModel.user.height, unit: viewModel.user.heightUnit))")
                    StatsRowView(title: "Activity Level", value: viewModel.user.activityLevel.rawValue)
                    StatsRowView(title: "Goal", value: viewModel.user.goalType.rawValue)
                }
                
                // Goals Section
                Section("Progress") {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Current Streak")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(viewModel.currentStreak) days")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Total Foods Logged")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(viewModel.totalFoodsLogged)")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Settings Section
                Section("Settings") {
                    NavigationLink("Notifications") {
                        NotificationSettingsView()
                    }
                    
                    NavigationLink("Data Export") {
                        DataExportView()
                    }
                    
                    NavigationLink("About") {
                        AboutView()
                    }
                }
                
                // Actions Section
                Section {
                    Button("Reset All Data", role: .destructive) {
                        viewModel.showingResetAlert = true
                    }
                    .foregroundColor(.red)
                    Button("Log Out", role: .destructive) {
                        Task {
                            do {
                                try await SupabaseService.shared.signOut()
                                // Optionally reset any local user state here
                            } catch {
                                print("Logout failed: \(error)")
                            }
                        }
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showingEditProfile, onDismiss: {
                // Save the updated user data when the sheet is dismissed
                viewModel.saveProfileSync()
            }) {
                EditProfileView(user: $viewModel.user)
            }
            .onAppear {
                // Refresh user data when view appears
                Task {
                    await viewModel.loadUserFromServer()
                }
            }
            .alert("Reset Data", isPresented: $viewModel.showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    Task {
                        await viewModel.resetAllData()
                    }
                }
            } message: {
                Text("This will permanently delete all your food logs and reset your profile. This action cannot be undone.")
            }
            .overlay {
                if viewModel.isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .overlay(
                            ProgressView("Processing...")
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                                .shadow(radius: 10)
                        )
                }
            }
        }
    }
}

struct StatsRowView: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

private func formattedWeight(_ weight: Double, unit: User.WeightUnit) -> String {
    switch unit {
    case .kg: return "\(Int(weight)) kg"
    case .lb: return "\(Int(weight)) lb"
    }
}

private func formattedHeight(_ height: Double, unit: User.HeightUnit) -> String {
    switch unit {
    case .cm: return "\(Int(height)) cm"
    case .inch: return "\(Int(height)) in"
    }
} 
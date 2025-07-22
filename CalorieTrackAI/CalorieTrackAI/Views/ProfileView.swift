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
                
                // Stats Section
                Section("Your Stats") {
                    StatsRowView(title: "Age", value: "\(viewModel.user.age) years")
                    StatsRowView(title: "Weight", value: "\(Int(viewModel.user.weight)) kg")
                    StatsRowView(title: "Height", value: "\(Int(viewModel.user.height)) cm")
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
                }
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView(user: $viewModel.user)
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
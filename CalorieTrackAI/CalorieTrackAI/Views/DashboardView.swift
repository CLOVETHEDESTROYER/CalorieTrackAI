import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                // Prominent glass background for iOS 18+
                if #available(iOS 18.0, *) {
                    LinearGradient(
                        colors: [.blue.opacity(0.2), .purple.opacity(0.1), .green.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                }
                
            ScrollView {
                VStack(spacing: 20) {
                    // Daily Calorie Goal Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Daily Calorie Goal")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        if viewModel.isLoading {
                            ProgressView("Loading...")
                                .frame(maxWidth: .infinity)
                        } else {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Target")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(Int(viewModel.dailyGoal))")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing) {
                                    Text("calories")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("per day")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding()
                    .glassCard(tint: .blue, cornerRadius: 12)
                    .glassBorder(tint: .blue, cornerRadius: 12)
                    
                    // User Stats Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Stats")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        if viewModel.isLoading {
                            ProgressView("Loading...")
                                .frame(maxWidth: .infinity)
                        } else {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Current Weight")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(viewModel.currentWeightDisplay)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.green)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Lean Body Mass")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(viewModel.leanBodyMassDisplay)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }
                    .padding()
                    .glassCard(tint: .green, cornerRadius: 12)
                    .glassBorder(tint: .green, cornerRadius: 12)
                    
                    // Daily Progress Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Today's Progress")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        if viewModel.isLoading {
                            ProgressView("Loading...")
                                .frame(maxWidth: .infinity)
                        } else {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Calories")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(Int(viewModel.consumedCalories))/\(Int(viewModel.dailyGoal))")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                }
                                
                                Spacer()
                                
                                CircularProgressView(
                                    progress: viewModel.calorieProgress,
                                    color: .blue
                                )
                                .frame(width: 60, height: 60)
                            }
                        }
                    }
                    .padding()
                    .glassCard(tint: .neutral, cornerRadius: 12)
                    
                    // Macros Summary
                    if !viewModel.isLoading {
                        MacrosView(
                            protein: viewModel.protein,
                            carbs: viewModel.carbs,
                            fat: viewModel.fat,
                            proteinGoal: viewModel.proteinGoal,
                            carbsGoal: viewModel.carbsGoal,
                            fatGoal: viewModel.fatGoal
                        )
                    }
                    
                    // Recent Foods
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Foods")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        if viewModel.isLoading {
                            ProgressView("Loading...")
                                .frame(maxWidth: .infinity)
                        } else if viewModel.recentFoods.isEmpty {
                            Text("No foods logged today")
                                .foregroundColor(.secondary)
                                .padding(.vertical)
                        } else {
                            ForEach(viewModel.recentFoods.prefix(3)) { food in
                                FoodRowView(food: food)
                            }
                        }
                    }
                    .padding()
                    .glassCard(tint: .neutral, cornerRadius: 12)
                }
                .padding()
            }
            }
            .navigationTitle("Dashboard")
            .refreshable {
                await viewModel.loadTodaysData()
            }
            .task {
                await viewModel.loadTodaysData()
            }
            .onAppear {
                // Refresh user's daily goal when view appears
                Task {
                    await viewModel.loadUserDailyGoal()
                }
            }
        }
    }
} 
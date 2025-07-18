import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Daily Progress Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Today's Progress")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
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
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Macros Summary
                    MacrosView(
                        protein: viewModel.protein,
                        carbs: viewModel.carbs,
                        fat: viewModel.fat
                    )
                    
                    // Recent Foods
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Foods")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        if viewModel.recentFoods.isEmpty {
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
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .onAppear {
                viewModel.loadTodaysData()
            }
        }
    }
} 
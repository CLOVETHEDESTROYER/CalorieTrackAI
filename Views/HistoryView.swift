import SwiftUI

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()
    @State private var selectedDate = Date()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Date Picker
                DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(CompactDatePickerStyle())
                    .padding()
                    .background(Color(.systemGray6))
                    .onChange(of: selectedDate) { newDate in
                        viewModel.loadFoodsForDate(newDate)
                    }
                
                // Daily Summary
                if !viewModel.foods.isEmpty {
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Total Calories")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(Int(viewModel.totalCalories))")
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text("Foods Logged")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(viewModel.foods.count)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                        }
                        
                        // Macros breakdown
                        HStack {
                            MacroCircle(label: "P", value: viewModel.totalProtein, color: .red)
                            MacroCircle(label: "C", value: viewModel.totalCarbs, color: .orange)
                            MacroCircle(label: "F", value: viewModel.totalFat, color: .yellow)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                }
                
                // Food List
                List {
                    if viewModel.foods.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "fork.knife.circle")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            
                            Text("No foods logged for this date")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("Start tracking your meals to see them here")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } else {
                        ForEach(viewModel.groupedFoods.keys.sorted(), id: \.self) { mealTime in
                            Section(mealTime) {
                                ForEach(viewModel.groupedFoods[mealTime] ?? []) { food in
                                    FoodRowView(food: food)
                                        .swipeActions(edge: .trailing) {
                                            Button("Delete", role: .destructive) {
                                                viewModel.deleteFood(food)
                                            }
                                        }
                                }
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("History")
            .onAppear {
                viewModel.loadFoodsForDate(selectedDate)
            }
        }
    }
}

struct MacroCircle: View {
    let label: String
    let value: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Text(label)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            
            Text("\(Int(value))g")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
} 
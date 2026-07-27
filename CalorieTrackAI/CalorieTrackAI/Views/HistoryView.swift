import SwiftUI

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()
    @State private var selectedDate = Date()
    
    var body: some View {
        NavigationView {
            ZStack {
                MFTTheme.background
                    .ignoresSafeArea()
                
            VStack(spacing: 0) {
                MFTPageHeader(
                    kicker: "Nutrition record",
                    title: "History.",
                    subtitle: "A clean daily receipt of what you logged."
                )
                .padding(.horizontal)
                .padding(.top, 12)

                // Date Picker
                DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(CompactDatePickerStyle())
                    .padding()
                    .glassCard(tint: .neutral, cornerRadius: 0)
                    .onChange(of: selectedDate) { oldDate, newDate in
                        Task {
                            await viewModel.loadFoodsForDate(newDate)
                        }
                    }
                
                // Loading indicator
                if viewModel.isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
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
                        .glassCard(tint: .orange, cornerRadius: 12)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
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
                                    #if os(iOS)
.multilineTextAlignment(.center)
#endif
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        } else {
                            ForEach(MealEntry.MealType.allCases, id: \.self) { mealType in
                                let foods = viewModel.groupedFoods[mealType] ?? []
                                if !foods.isEmpty {
                                    Section(mealType.displayName) {
                                        ForEach(foods) { food in
                                            FoodRowView(food: food)
                                            .swipeActions(edge: .trailing) {
                                                Button("Delete", role: .destructive) {
                                                    Task {
                                                        await viewModel.deleteFood(food)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                    .scrollContentBackground(.hidden)
                }
            }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .tint(MFTTheme.accent)
            .mftPageChrome()
            .task {
                await viewModel.loadInitialData()
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

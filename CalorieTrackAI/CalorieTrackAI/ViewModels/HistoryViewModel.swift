import Foundation
import SwiftUI

@MainActor
class HistoryViewModel: ObservableObject {
    @Published var foods: [Food] = []
    @Published var selectedDate: Date = Date()
    @Published var isLoading: Bool = false
    
    private let foodService = FoodService.shared
    
    var totalCalories: Double {
        foods.reduce(0) { $0 + $1.calories }
    }
    
    var totalProtein: Double {
        foods.reduce(0) { $0 + $1.protein }
    }
    
    var totalCarbs: Double {
        foods.reduce(0) { $0 + $1.carbs }
    }
    
    var totalFat: Double {
        foods.reduce(0) { $0 + $1.fat }
    }
    
    var groupedFoods: [MealEntry.MealType: [Food]] {
        Dictionary(grouping: foods) { food in
            food.mealType ?? MealTimeClassifier.mealType(for: food.dateLogged)
        }
    }
    
    func loadFoodsForDate(_ date: Date) async {
        selectedDate = date
        isLoading = true
        defer { isLoading = false }
        
        do {
            let startOfDay = Calendar.current.startOfDay(for: date)
            foods = try await foodService.getFoodsForDate(startOfDay)
        } catch {
            // Fallback to offline data
            let startOfDay = Calendar.current.startOfDay(for: date)
            foods = foodService.getFoodsForDateOffline(startOfDay)
            #if DEBUG
            print("Failed to load foods from server, using offline data: \(error)")
            #endif
        }
    }
    
    func deleteFood(_ food: Food) async {
        do {
            try await foodService.deleteFood(food)
            // Reload foods after successful deletion
            await loadFoodsForDate(selectedDate)
        } catch {
            print("Failed to delete food: \(error)")
            // Note: Food might still be deleted locally, so reload anyway
            await loadFoodsForDate(selectedDate)
        }
    }
    
    // Convenience method for initial load
    func loadInitialData() async {
        await loadFoodsForDate(selectedDate)
    }
}

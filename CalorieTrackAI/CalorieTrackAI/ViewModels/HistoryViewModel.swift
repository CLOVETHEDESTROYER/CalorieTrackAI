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
    
    var groupedFoods: [String: [Food]] {
        let calendar = Calendar.current
        
        return Dictionary(grouping: foods) { food in
            let hour = calendar.component(.hour, from: food.dateLogged)
            
            switch hour {
            case 5..<12:
                return "Breakfast"
            case 12..<17:
                return "Lunch"
            case 17..<21:
                return "Dinner"
            default:
                return "Snacks"
            }
        }
    }
    
    func loadFoodsForDate(_ date: Date) async {
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
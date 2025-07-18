import Foundation
import SwiftUI

class HistoryViewModel: ObservableObject {
    @Published var foods: [Food] = []
    @Published var selectedDate: Date = Date()
    
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
    
    func loadFoodsForDate(_ date: Date) {
        let startOfDay = Calendar.current.startOfDay(for: date)
        foods = foodService.getFoodsForDate(startOfDay)
    }
    
    func deleteFood(_ food: Food) {
        foodService.deleteFood(food)
        loadFoodsForDate(selectedDate)
    }
} 
import Foundation
import SwiftUI

class DashboardViewModel: ObservableObject {
    @Published var consumedCalories: Double = 0
    @Published var dailyGoal: Double = 2000
    @Published var protein: Double = 0
    @Published var carbs: Double = 0
    @Published var fat: Double = 0
    @Published var recentFoods: [Food] = []
    
    private let foodService = FoodService.shared
    private let userService = UserService.shared
    
    var calorieProgress: Double {
        dailyGoal > 0 ? consumedCalories / dailyGoal : 0
    }
    
    init() {
        loadTodaysData()
    }
    
    func loadTodaysData() {
        let today = Calendar.current.startOfDay(for: Date())
        let todaysFoods = foodService.getFoodsForDate(today)
        
        // Calculate totals
        consumedCalories = todaysFoods.reduce(0) { $0 + $1.calories }
        protein = todaysFoods.reduce(0) { $0 + $1.protein }
        carbs = todaysFoods.reduce(0) { $0 + $1.carbs }
        fat = todaysFoods.reduce(0) { $0 + $1.fat }
        
        // Get recent foods (last 3)
        recentFoods = Array(todaysFoods.suffix(3))
        
        // Load user's daily goal
        if let user = userService.getCurrentUser() {
            dailyGoal = user.dailyCalorieGoal
        }
    }
} 
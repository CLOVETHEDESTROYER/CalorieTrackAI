import Foundation
import SwiftUI

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var consumedCalories: Double = 0
    @Published var dailyGoal: Double = 2000
    @Published var protein: Double = 0
    @Published var carbs: Double = 0
    @Published var fat: Double = 0
    @Published var recentFoods: [Food] = []
    @Published var isLoading: Bool = false
    
    private let foodService = FoodService.shared
    private let userService = UserService.shared
    
    var calorieProgress: Double {
        guard !consumedCalories.isNaN && !dailyGoal.isNaN && 
              !consumedCalories.isInfinite && !dailyGoal.isInfinite &&
              dailyGoal > 0 else { return 0 }
        
        let progress = consumedCalories / dailyGoal
        return min(max(progress, 0), 1.0)  // Clamp between 0 and 1
    }
    
    init() {
        Task {
            await loadTodaysData()
        }
    }
    
    func loadTodaysData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let today = Calendar.current.startOfDay(for: Date())
            let todaysFoods = try await foodService.getFoodsForDate(today)
            
            // Calculate totals
            consumedCalories = todaysFoods.reduce(0) { $0 + $1.calories }
            protein = todaysFoods.reduce(0) { $0 + $1.protein }
            carbs = todaysFoods.reduce(0) { $0 + $1.carbs }
            fat = todaysFoods.reduce(0) { $0 + $1.fat }
            
            // Get recent foods (last 3)
            recentFoods = Array(todaysFoods.suffix(3))
            
        } catch {
            // Fallback to offline data
            let today = Calendar.current.startOfDay(for: Date())
            let todaysFoods = foodService.getFoodsForDateOffline(today)
            
            consumedCalories = todaysFoods.reduce(0) { $0 + $1.calories }
            protein = todaysFoods.reduce(0) { $0 + $1.protein }
            carbs = todaysFoods.reduce(0) { $0 + $1.carbs }
            fat = todaysFoods.reduce(0) { $0 + $1.fat }
            recentFoods = Array(todaysFoods.suffix(3))
            
            print("Failed to load today's data from server, using offline data: \(error)")
        }
        
        // Always load the latest user's daily goal
        await loadUserDailyGoal()
    }
    
    func loadUserDailyGoal() async {
        do {
            if let user = try await userService.getCurrentUser() {
                dailyGoal = user.dailyCalorieGoal
            }
        } catch {
            // Use offline user data
            if let user = userService.getCurrentUserOffline() {
                dailyGoal = user.dailyCalorieGoal
            }
        }
    }
} 
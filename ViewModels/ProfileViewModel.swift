import Foundation
import SwiftUI

class ProfileViewModel: ObservableObject {
    @Published var user: User
    @Published var showingResetAlert: Bool = false
    
    private let userService = UserService.shared
    private let foodService = FoodService.shared
    
    var currentStreak: Int {
        calculateCurrentStreak()
    }
    
    var totalFoodsLogged: Int {
        foodService.getTotalFoodsLogged()
    }
    
    init() {
        // Load user or create default
        if let savedUser = userService.getCurrentUser() {
            self.user = savedUser
        } else {
            self.user = User(
                name: "User",
                age: 25,
                weight: 70.0,
                height: 170.0
            )
            userService.saveUser(user)
        }
    }
    
    func saveProfile() {
        userService.saveUser(user)
    }
    
    func resetAllData() {
        foodService.deleteAllFoods()
        userService.resetUserData()
        
        // Reset to default user
        user = User(
            name: "User",
            age: 25,
            weight: 70.0,
            height: 170.0
        )
        userService.saveUser(user)
    }
    
    private func calculateCurrentStreak() -> Int {
        let calendar = Calendar.current
        var streak = 0
        var currentDate = Date()
        
        // Go backwards day by day until we find a day without food logs
        while streak < 365 { // Cap at 365 days to prevent infinite loops
            let startOfDay = calendar.startOfDay(for: currentDate)
            let foodsForDay = foodService.getFoodsForDate(startOfDay)
            
            if foodsForDay.isEmpty {
                break
            }
            
            streak += 1
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        }
        
        return streak
    }
} 
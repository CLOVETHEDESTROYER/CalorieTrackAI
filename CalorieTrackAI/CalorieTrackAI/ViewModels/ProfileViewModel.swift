import Foundation
import SwiftUI

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var user: User
    @Published var showingResetAlert: Bool = false
    @Published var isLoading: Bool = false
    
    private let userService = UserService.shared
    private let foodService = FoodService.shared
    
    var currentStreak: Int {
        calculateCurrentStreak()
    }
    
    var totalFoodsLogged: Int {
        foodService.getTotalFoodsLoggedOffline()
    }
    
    init() {
        // Load user or create default - use offline for initial load
        if let savedUser = userService.getCurrentUserOffline() {
            self.user = savedUser
        } else {
            self.user = User(
                name: "User",
                age: 25,
                weight: 70.0,
                height: 170.0
            )
            Task {
                await saveProfile()
            }
        }
        
        // Try to load from server in background
        Task {
            await loadUserFromServer()
        }
    }
    
    func saveProfile() async {
        isLoading = true
        defer { isLoading = false }
        // Always recalculate before saving
        user.dailyCalorieGoal = UserService.shared.calculateDailyCalorieGoal(for: user)
        do {
            try await userService.saveUser(user)
        } catch {
            // Fallback to offline save
            userService.saveUserOffline(user)
            print("Saved user offline: \(error)")
        }
    }
    
    // Convenience method for synchronous calls from UI
    func saveProfileSync() {
        Task {
            await saveProfile()
        }
    }
    
    func resetAllData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await foodService.deleteAllFoods()
            try await userService.resetUserData()
        } catch {
            // Fallback to offline reset
            foodService.deleteAllFoodsOffline()
            userService.resetUserDataOffline()
            print("Reset data offline: \(error)")
        }
        
        // Reset to default user
        user = User(
            name: "User",
            age: 25,
            weight: 70.0,
            height: 170.0
        )
        
        await saveProfile()
    }
    
    // Convenience method for synchronous calls from UI
    func resetAllDataSync() {
        Task {
            await resetAllData()
        }
    }
    
    func loadUserFromServer() async {
        do {
            if let serverUser = try await userService.getCurrentUser() {
                user = serverUser
            }
        } catch {
            print("Failed to load user from server: \(error)")
        }
    }
    
    private func calculateCurrentStreak() -> Int {
        let calendar = Calendar.current
        var streak = 0
        var currentDate = Date()
        
        // Go backwards day by day until we find a day without food logs
        while streak < 365 { // Cap at 365 days to prevent infinite loops
            let startOfDay = calendar.startOfDay(for: currentDate)
            let foodsForDay = foodService.getFoodsForDateOffline(startOfDay)
            
            if foodsForDay.isEmpty {
                break
            }
            
            streak += 1
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        }
        
        return streak
    }
} 

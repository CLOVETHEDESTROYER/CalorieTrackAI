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
    @Published var currentUser: User?
    
    private let foodService = FoodService.shared
    private let userService = UserService.shared
    
    // Calculate lean body mass in kg using the Boer Formula
    private var leanBodyMassKg: Double {
        guard let user = currentUser else { return 70.0 }
        // Convert weight to kg if needed
        let weightKg = user.weightUnit == .kg ? user.weight : user.weight * 0.453592
        // Convert height to cm if needed
        let heightCm = user.heightUnit == .cm ? user.height : user.height * 2.54

        switch user.gender {
        case .male:
            return 0.407 * weightKg + 0.267 * heightCm - 19.2
        case .female:
            return 0.252 * weightKg + 0.473 * heightCm - 48.3
        }
    }
    
    // MARK: - Macro Calculations
    
    // Calculate protein goal based on lean body mass and activity level
    var proteinGoal: Double {
        guard let user = currentUser else { return (dailyGoal * 0.25) / 4 } // Fallback
        
        // Base protein per kg lean mass
        let baseProteinPerKg: Double
        switch user.activityLevel {
        case .sedentary: baseProteinPerKg = 1.0
        case .lightlyActive: baseProteinPerKg = 1.2
        case .moderatelyActive: baseProteinPerKg = 1.4
        case .veryActive: baseProteinPerKg = 1.6
        }
        
        // Goal multiplier
        let goalMultiplier: Double
        switch user.goalType {
        case .loseWeight: goalMultiplier = 1.8 // Higher for muscle preservation
        case .maintainWeight: goalMultiplier = 1.0
        case .gainWeight: goalMultiplier = 1.6 // Higher for muscle building
        }
        
        return leanBodyMassKg * baseProteinPerKg * goalMultiplier
    }
    
    // Calculate carbs goal based on lean body mass, activity, and remaining calories
    var carbsGoal: Double {
        guard let user = currentUser else { return (dailyGoal * 0.45) / 4 } // Fallback
        
        // Calculate protein calories first
        let proteinCalories = proteinGoal * 4
        
        // Base carbs per kg lean mass
        let baseCarbsPerKg: Double
        switch user.activityLevel {
        case .sedentary: baseCarbsPerKg = 2.5
        case .lightlyActive: baseCarbsPerKg = 3.5
        case .moderatelyActive: baseCarbsPerKg = 4.5
        case .veryActive: baseCarbsPerKg = 6.0
        }
        
        // Goal multiplier for carbs
        let goalMultiplier: Double
        switch user.goalType {
        case .loseWeight: goalMultiplier = 0.7 // Lower for weight loss
        case .maintainWeight: goalMultiplier = 1.0
        case .gainWeight: goalMultiplier = 1.2 // Higher for muscle building
        }
        
        // Calculate carbs based on lean mass
        let leanMassCarbs = leanBodyMassKg * baseCarbsPerKg * goalMultiplier
        
        // Calculate remaining calories after protein
        let remainingCalories = dailyGoal - proteinCalories
        
        // Calculate carbs based on remaining calories (fallback method)
        let calorieBasedCarbs = (remainingCalories * 0.6) / 4 // 60% of remaining as carbs
        
        // Use the higher of the two methods, but cap at remaining calories
        let maxCarbsFromCalories = remainingCalories / 4 // All remaining as carbs
        return min(max(leanMassCarbs, calorieBasedCarbs), maxCarbsFromCalories)
    }
    
    // Calculate fat goal based on remaining calories after protein and carbs
    var fatGoal: Double {
        guard let user = currentUser else { return (dailyGoal * 0.30) / 9 } // Fallback
        
        // Calculate protein and carb calories
        let proteinCalories = proteinGoal * 4
        let carbCalories = carbsGoal * 4
        let remainingCalories = dailyGoal - proteinCalories - carbCalories
        
        // Ensure minimum fat for essential fatty acids
        let minFatGrams = leanBodyMassKg * 0.8
        
        // Calculate fat from remaining calories
        let fatFromCalories = remainingCalories / 9
        
        // Use the higher of minimum fat or calorie-based fat
        return max(fatFromCalories, minFatGrams)
    }
    
    // MARK: - Progress Calculations
    
    var calorieProgress: Double {
        guard !consumedCalories.isNaN && !dailyGoal.isNaN && 
              !consumedCalories.isInfinite && !dailyGoal.isInfinite &&
              dailyGoal > 0 else { return 0 }
        
        return consumedCalories / dailyGoal
    }
    
    var isOverGoal: Bool {
        return calorieProgress > 1.0
    }
    
    // MARK: - User Info Display
    
    var currentWeightDisplay: String {
        guard let user = currentUser else { return "N/A" }
        
        let weight = user.weight
        let unit = user.weightUnit.rawValue
        
        if user.weightUnit == .lb {
            return "\(Int(weight)) lb"
        } else {
            return "\(Int(weight)) kg"
        }
    }
    
    var leanBodyMassDisplay: String {
        let leanMassKg = leanBodyMassKg
        guard let user = currentUser else { return "N/A" }
        
        if user.weightUnit == .lb {
            let leanMassLb = leanMassKg * 2.20462
            return "\(Int(leanMassLb)) lb"
        } else {
            return "\(Int(leanMassKg)) kg"
        }
    }
    
    // MARK: - Initialization and Data Loading
    
    init() {
        Task {
            await loadTodaysData()
        }
    }
    
    func loadTodaysData() async {
        isLoading = true
        defer { isLoading = false }
        
        // Load user data first
        await loadUserDailyGoal()
        
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
    }
    
    func loadUserDailyGoal() async {
        do {
            if let user = try await userService.getCurrentUser() {
                dailyGoal = user.dailyCalorieGoal
                currentUser = user
            }
        } catch {
            // Use offline user data
            if let user = userService.getCurrentUserOffline() {
                dailyGoal = user.dailyCalorieGoal
                currentUser = user
            }
        }
    }
} 
import Foundation
import SwiftUI

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var user: User
    @Published var showingResetAlert: Bool = false
    @Published var isLoading: Bool = false
    @Published var currentStreak: Int = 0
    @Published var totalFoodsLogged: Int = 0
    @Published var currentPlan: FitnessPlan?
    @Published var savedGymCount: Int = 0
    @Published var healthAccessRequested: Bool = false
    @Published var peptideSummary: PeptideTrackerSummary = PeptideTrackerSummary.make(logs: [])
    
    private let userService = UserService.shared
    private let foodService = FoodService.shared
    private let supabaseService = SupabaseService.shared
    private let fitnessPlanService = FitnessPlanService.shared
    private let peptideLogStore = PeptideLogStore.shared
    private let gymLocationService = GymLocationService.shared
    private let movementChallengeStore = MovementChallengeStore.shared
    private let coachMessageService = CoachMessageService.shared
    private let coachNotificationService = CoachNotificationService.shared
    private let healthKitService = HealthKitService.shared
    
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
            await refreshProgress()
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
            #if DEBUG
            print("Saved user offline: \(error)")
            #endif
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
            if supabaseService.isAuthenticated {
                try await supabaseService.deleteAllUserGeneratedDataForCurrentUser()
            }
            try await foodService.deleteAllFoods()
            try await userService.resetUserData()
        } catch {
            // Fallback to offline reset
            foodService.deleteAllFoodsOffline()
            userService.resetUserDataOffline()
            print("Reset data offline: \(error)")
        }

        await resetFeatureState()
        
        // Reset to default user
        user = User(
            name: "User",
            age: 25,
            weight: 70.0,
            height: 170.0
        )
        
        await saveProfile()
        totalFoodsLogged = 0
        currentStreak = 0
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
    
    func refreshProgress() async {
        isLoading = true
        defer { isLoading = false }
        await refreshSettingsSummary()

        do {
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .year, value: -1, to: endDate)!
            let entries = try await FoodService.shared.getMealEntriesForDateRange(from: startDate, to: endDate)
            totalFoodsLogged = entries.count

            #if DEBUG
            // Debug logging only in debug builds
            for entry in entries {
                print("MealEntry: \(entry.food_name) at \(entry.consumed_at)")
            }
            #endif

            // Calculate streak
            let calendar = Calendar.current
            var streak = 0
            var currentDate = calendar.startOfDay(for: endDate)
            let grouped = Dictionary(grouping: entries, by: { calendar.startOfDay(for: $0.consumed_at.convertToLocalTime()) })
            while streak < 365 {
                if grouped[currentDate]?.isEmpty ?? true {
                    break
                }
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
            }
            currentStreak = streak
        } catch {
            #if DEBUG
            print("Failed to refresh progress: \(error)")
            #endif
            totalFoodsLogged = 0
            currentStreak = 0
        }
    }

    func refreshSettingsSummary() async {
        await fitnessPlanService.refreshFromServer()
        await gymLocationService.refreshFromServer()
        await peptideLogStore.refreshFromServer()

        currentPlan = fitnessPlanService.currentPlan
        savedGymCount = gymLocationService.savedGyms.count
        healthAccessRequested = healthKitService.hasRequestedAuthorization
        peptideSummary = PeptideTrackerSummary.make(logs: peptideLogStore.logs)
    }

    var planStatusDisplay: String {
        guard let currentPlan else {
            return "Missing"
        }

        return "\(Int(currentPlan.calorieTarget)) cal"
    }

    var healthStatusDisplay: String {
        healthAccessRequested ? "Linked" : "Off"
    }

    var gymStatusDisplay: String {
        savedGymCount == 0 ? "None" : "\(savedGymCount) saved"
    }

    var peptideStatusDisplay: String {
        if peptideSummary.plannedCount > 0 {
            return "\(peptideSummary.plannedCount) planned"
        }

        if peptideSummary.loggedCount > 0 {
            return "\(peptideSummary.loggedCount) logged"
        }

        return "Ready"
    }

    var mealPlanSettingsDetail: String {
        guard let currentPlan else {
            return "No active plan yet. Build calories, macros, steps, and workouts here."
        }

        return "\(Int(currentPlan.calorieTarget)) cal, \(Int(currentPlan.proteinGoal))g protein, \(currentPlan.stepGoal) steps, \(currentPlan.trainingDaysPerWeek) workouts/week."
    }

    var activitySettingsDetail: String {
        switch (healthAccessRequested, savedGymCount) {
        case (true, 0):
            return "Health is linked. Save a gym so auto check-ins know where to watch."
        case (true, 1):
            return "Health is linked with 1 saved gym for check-ins."
        case (true, let count):
            return "Health is linked with \(count) saved gyms for check-ins."
        case (false, 0):
            return "Connect Health for steps/workouts and save your gym addresses."
        case (false, 1):
            return "Connect Health for steps/workouts. 1 gym is saved."
        case (false, let count):
            return "Connect Health for steps/workouts. \(count) gyms are saved."
        }
    }

    var peptideSettingsDetail: String {
        if peptideSummary.overdueCount > 0 {
            return "\(peptideSummary.overdueCount) planned log overdue. Open the logbook and handle it."
        }

        if let nextPlanned = peptideSummary.nextPlanned {
            return "Next planned: \(nextPlanned.peptideName) at \(formattedPeptideDate(nextPlanned.scheduledAt ?? nextPlanned.loggedAt))."
        }

        if let lastLogged = peptideSummary.lastLogged {
            return "Last logged: \(lastLogged.peptideName) at \(formattedPeptideDate(lastLogged.loggedAt))."
        }

        return "Open label-math calculator, BAC water planner, and planned logs."
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

    private func resetFeatureState() async {
        fitnessPlanService.clearPlan()
        peptideLogStore.clearLocalLogs()
        gymLocationService.clearLocalData()
        movementChallengeStore.clearLocalSessions()
        healthKitService.clearLocalSummary()
        coachMessageService.resetLocalSettings()
        await coachNotificationService.resetLocalSettings()
        await refreshSettingsSummary()
    }

    private func formattedPeptideDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
} 

extension Date {
    func convertToLocalTime() -> Date {
        let timezone = TimeZone.current
        let seconds = TimeInterval(timezone.secondsFromGMT(for: self))
        return Date(timeInterval: seconds, since: self)
    }
} 

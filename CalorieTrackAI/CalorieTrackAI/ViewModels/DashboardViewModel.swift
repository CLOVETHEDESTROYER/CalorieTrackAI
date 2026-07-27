import Foundation
import SwiftUI

struct DailyMealSection: Identifiable {
    let mealType: MealEntry.MealType
    var foods: [Food]

    var id: String { mealType.rawValue }

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

    var itemCount: Int {
        foods.count
    }

    var macroSummaryText: String {
        "P \(Int(totalProtein))g | C \(Int(totalCarbs))g | F \(Int(totalFat))g"
    }

    func foodPreviewText(limit: Int = 3) -> String {
        foods
            .prefix(limit)
            .map(\.name)
            .joined(separator: ", ")
    }

    func remainingItemCount(after limit: Int = 3) -> Int {
        max(foods.count - limit, 0)
    }
}

struct DashboardNextAction: Equatable {
    enum Kind: Equatable {
        case buildPlan
        case connectActivity
        case saveGym
        case logFood
        case move
        case review
    }

    let kind: Kind
    let title: String
    let detail: String
    let icon: String
}

struct AccountabilityDayWindow: Equatable {
    let start: Date
    let nextReset: Date

    static func make(now: Date = Date(), calendar: Calendar = .current) -> AccountabilityDayWindow {
        let start = calendar.startOfDay(for: now)
        let nextReset = calendar.date(byAdding: .day, value: 1, to: start) ?? now
        return AccountabilityDayWindow(start: start, nextReset: nextReset)
    }

    static func countdownDisplay(now: Date = Date(), calendar: Calendar = .current) -> String {
        let window = make(now: now, calendar: calendar)
        let remainingSeconds = max(window.nextReset.timeIntervalSince(now), 0)
        let totalMinutes = max(Int(ceil(remainingSeconds / 60)), 1)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours == 0 {
            return "Resets in \(minutes)m"
        }

        if minutes == 0 {
            return "Resets in \(hours)h"
        }

        return "Resets in \(hours)h \(minutes)m"
    }

    static func resetTimeDisplay(calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale.current
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .none
        formatter.timeStyle = .short

        let reset = calendar.startOfDay(for: Date())
        return formatter.string(from: reset)
    }
}

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var consumedCalories: Double = 0
    @Published var dailyGoal: Double = 2000
    @Published var protein: Double = 0
    @Published var carbs: Double = 0
    @Published var fat: Double = 0
    @Published var recentFoods: [Food] = []
    @Published var mealSections: [DailyMealSection] = DailyMealSection.emptySections
    @Published var isLoading: Bool = false
    @Published var currentUser: User?
    @Published var activitySummary: ActivityDailySummary = .emptyToday
    @Published var currentPlan: FitnessPlan?
    @Published var latestPeptideLog: PeptideLog?
    @Published var savedGymCount: Int = 0
    @Published var autoCheckInsEnabled: Bool = false
    @Published var hasRequestedHealthAccess: Bool = false
    @Published var hasAcknowledgedPeptideCalculatorLimits: Bool = false
    
    private let foodService = FoodService.shared
    private let userService = UserService.shared
    private let healthKitService = HealthKitService.shared
    private let fitnessPlanService = FitnessPlanService.shared
    private let gymLocationService = GymLocationService.shared
    private let peptideLogStore = PeptideLogStore.shared
    
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
        guard currentUser != nil else { return (dailyGoal * 0.30) / 9 } // Fallback
        
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

    var caloriesRemaining: Double {
        dailyGoal - consumedCalories
    }

    var calorieBudgetDisplay: String {
        "\(Int(consumedCalories))/\(Int(dailyGoal))"
    }

    var calorieRemainingDisplay: String {
        if caloriesRemaining >= 0 {
            return "\(Int(caloriesRemaining)) left"
        }

        return "\(Int(abs(caloriesRemaining))) over"
    }

    func accountabilityDaySubtitle(now: Date = Date(), calendar: Calendar = .current) -> String {
        "Today closes at \(AccountabilityDayWindow.resetTimeDisplay(calendar: calendar)) | \(AccountabilityDayWindow.countdownDisplay(now: now, calendar: calendar))"
    }

    func mealResetSubtitle(now: Date = Date(), calendar: Calendar = .current) -> String {
        "\(AccountabilityDayWindow.countdownDisplay(now: now, calendar: calendar)). Calories, meals, steps, and gym receipts start over at midnight."
    }

    var dashboardNextAction: DashboardNextAction {
        if currentPlan == nil {
            return DashboardNextAction(
                kind: .buildPlan,
                title: "Build the plan",
                detail: "Set calories, macros, steps, and workouts so the coach has something real to judge.",
                icon: "list.clipboard.fill"
            )
        }

        if !hasRequestedHealthAccess {
            return DashboardNextAction(
                kind: .connectActivity,
                title: "Connect Apple Health",
                detail: "Steps and workouts cannot defend you until Health access is on.",
                icon: "heart.text.square.fill"
            )
        }

        if savedGymCount == 0 {
            return DashboardNextAction(
                kind: .saveGym,
                title: "Save your gym",
                detail: "Pick the right address so check-ins stop depending on guesswork.",
                icon: "location.fill"
            )
        }

        if !missingCoreMealTypes.isEmpty {
            return DashboardNextAction(
                kind: .logFood,
                title: "Log the next meal",
                detail: "\(missingMealSummary). The app cannot count calories you hide from it.",
                icon: "plus.circle.fill"
            )
        }

        if activitySummary.isBehindStepPace {
            return DashboardNextAction(
                kind: .move,
                title: "Go move",
                detail: "Step pace is behind. Take a walk before the couch starts winning the day.",
                icon: "figure.walk"
            )
        }

        return DashboardNextAction(
            kind: .review,
            title: "Review receipts",
            detail: "Food, steps, and setup are in decent shape. Keep the receipts honest.",
            icon: "checkmark.seal.fill"
        )
    }

    var stepProgress: Double {
        activitySummary.stepProgress
    }

    var trainerBriefingTitle: String {
        if activitySummary.completedWorkoutToday {
            return "Workout receipts detected"
        }

        if activitySummary.isBehindStepPace {
            return "Movement is looking suspicious"
        }

        if currentPlan == nil {
            return "No plan, no excuses"
        }

        return "Trainer briefing"
    }

    var trainerBriefingBody: String {
        if activitySummary.completedWorkoutToday {
            return "Good. The app found a workout, exercise minutes, or a gym visit. Keep logging food so the math does not wander off unsupervised."
        }

        if activitySummary.isBehindStepPace {
            return "Step count is lagging for this time of day. Go take a walk before the coach starts writing poetry about your couch."
        }

        if currentPlan == nil {
            return "Build a meal and workout plan so the coach has actual targets instead of yelling into the void."
        }

        return "Food, steps, and workouts all report here. Tiny dashboard, large accountability problem."
    }

    var todaysWorkoutTargetDisplay: String {
        guard let plan = currentPlan else {
            return "No plan"
        }

        return "\(plan.trainingDaysPerWeek)x/week"
    }

    var latestPeptideDisplay: String {
        guard let latestPeptideLog else {
            return "No logs"
        }

        return latestPeptideLog.peptideName
    }

    var loggedMealSectionCount: Int {
        mealSections.filter { !$0.foods.isEmpty }.count
    }

    var loggedMealSummary: String {
        let requiredMealCount = MealEntry.MealType.allCases.filter { $0 != .snack }.count
        let loggedRequiredMeals = mealSections.filter { section in
            section.mealType != .snack && !section.foods.isEmpty
        }.count

        if loggedRequiredMeals == requiredMealCount {
            return "Breakfast, lunch, and dinner all have receipts."
        }

        return "\(loggedRequiredMeals) of \(requiredMealCount) core meals logged. \(MealTimeClassifier.mealWindowSummary)"
    }

    var missingCoreMealTypes: [MealEntry.MealType] {
        mealSections
            .filter { $0.mealType != .snack && $0.foods.isEmpty }
            .map(\.mealType)
    }

    var missingMealSummary: String {
        let names = missingCoreMealTypes.map(\.displayName)
        guard !names.isEmpty else {
            return "Breakfast, lunch, and dinner all have receipts"
        }

        return "Missing \(names.joined(separator: ", "))"
    }

    var setupCompletedCount: Int {
        [
            currentPlan != nil,
            hasRequestedHealthAccess,
            savedGymCount > 0
        ].filter { $0 }.count
    }

    var setupTotalCount: Int {
        3
    }

    var setupProgress: Double {
        Double(setupCompletedCount) / Double(setupTotalCount)
    }

    var isSetupComplete: Bool {
        setupCompletedCount == setupTotalCount
    }

    var shouldShowSetupChecklist: Bool {
        !isSetupComplete
    }

    var setupSummary: String {
        if setupCompletedCount == setupTotalCount {
            return "The accountability machine is assembled. Now it just needs your receipts."
        }

        return "\(setupCompletedCount) of \(setupTotalCount) setup steps done. Peptides and extras live in Settings when you need them."
    }
    
    // MARK: - User Info Display
    
    var currentWeightDisplay: String {
        guard let user = currentUser else { return "N/A" }
        
        let weight = user.weight
        
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
        await loadTrainerBriefingData()
        
        do {
            let today = Calendar.current.startOfDay(for: Date())
            let mealEntries = try await foodService.getMealEntriesForDate(today)
            applyMealEntries(mealEntries)
            
        } catch {
            // Fallback to offline data
            let today = Calendar.current.startOfDay(for: Date())
            let todaysFoods = foodService.getFoodsForDateOffline(today)
            
            applyFoods(todaysFoods)
            
            #if DEBUG
            print("Failed to load today's data from server, using offline data: \(error)")
            #endif
        }
    }

    private func applyMealEntries(_ entries: [MealEntry]) {
        let foods = entries
            .sorted { $0.consumed_at < $1.consumed_at }
            .map { $0.toFood() }
        applyFoods(foods)
    }

    private func applyFoods(_ foods: [Food]) {
        consumedCalories = foods.reduce(0) { $0 + $1.calories }
        protein = foods.reduce(0) { $0 + $1.protein }
        carbs = foods.reduce(0) { $0 + $1.carbs }
        fat = foods.reduce(0) { $0 + $1.fat }
        recentFoods = Array(foods.suffix(3))
        mealSections = DailyMealSection.sections(from: foods)
    }

    func loadTrainerBriefingData() async {
        await fitnessPlanService.refreshFromServer()
        await gymLocationService.refreshFromServer()
        await peptideLogStore.refreshFromServer()

        currentPlan = fitnessPlanService.currentPlan
        latestPeptideLog = peptideLogStore.logs.first
        savedGymCount = gymLocationService.savedGyms.count
        autoCheckInsEnabled = gymLocationService.isMonitoring
        hasRequestedHealthAccess = healthKitService.hasRequestedAuthorization
        hasAcknowledgedPeptideCalculatorLimits = UserDefaults.standard.bool(forKey: "PeptideCalculatorAcknowledgement")

        let stepGoal = currentPlan?.stepGoal ?? 10_000
        let gymVisits = gymLocationService.todaysVisits()
        activitySummary = await healthKitService.refreshTodayIfConnected(
            stepGoal: stepGoal,
            gymVisits: gymVisits
        ) ?? ActivityDailySummary.emptyToday(
            stepGoal: stepGoal,
            gymVisits: gymVisits
        )
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

private extension DailyMealSection {
    static var emptySections: [DailyMealSection] {
        MealEntry.MealType.allCases.map { DailyMealSection(mealType: $0, foods: []) }
    }

    static func sections(from foods: [Food]) -> [DailyMealSection] {
        MealEntry.MealType.allCases.map { mealType in
            DailyMealSection(
                mealType: mealType,
                foods: foods.filter { food in
                    (food.mealType ?? MealTimeClassifier.mealType(for: food.dateLogged)) == mealType
                }
            )
        }
    }
}

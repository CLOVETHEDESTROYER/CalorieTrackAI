import Foundation

@MainActor
final class NutritionInsightsViewModel: ObservableObject {
    @Published private(set) var summary: CaloriePeriodSummary
    @Published private(set) var isLoading = false

    private let foodService = FoodService.shared
    private let planService = FitnessPlanService.shared
    private let userService = UserService.shared

    init() {
        summary = CaloriePeriodSummary.make(
            period: .week,
            entries: [],
            dailyTarget: 0
        )
    }

    func load(period: NutritionInsightPeriod) async {
        isLoading = true
        defer { isLoading = false }

        await planService.refreshFromServer()
        let targets = currentTargets
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(
            byAdding: .day,
            value: -(period.dayCount - 1),
            to: calendar.startOfDay(for: endDate)
        ) ?? endDate

        do {
            let entries = try await foodService.getMealEntriesForDateRange(
                from: startDate,
                to: endDate
            )
            summary = CaloriePeriodSummary.make(
                period: period,
                entries: entries,
                dailyTarget: targets.calories,
                calendar: calendar
            )
        } catch {
            let foods = foodService.getFoodsForDateRangeOffline(
                from: startDate,
                to: endDate
            )
            summary = CaloriePeriodSummary.make(
                period: period,
                foods: foods,
                dailyTarget: targets.calories,
                calendar: calendar
            )
        }
    }

    private var currentTargets: DailyNutritionTargets {
        if let plan = planService.currentPlan {
            return DailyNutritionTargets(plan: plan)
        }

        if let user = userService.getCurrentUserSync() {
            return FitnessPlanService.nutritionTargets(for: user)
        }

        return DailyNutritionTargets(calories: 2_000, protein: 0, carbs: 0, fat: 0)
    }
}

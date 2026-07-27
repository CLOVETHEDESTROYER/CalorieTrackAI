import Foundation

enum NutritionInsightPeriod: String, CaseIterable, Identifiable {
    case week
    case month
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        }
    }

    var dayCount: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .year: return 365
        }
    }
}

struct DailyCalorieRecord: Identifiable, Equatable {
    let date: Date
    let calories: Double
    let entryCount: Int

    var id: Date { date }
}

struct CaloriePeriodSummary: Equatable {
    let period: NutritionInsightPeriod
    let dailyTarget: Double
    let totalCalories: Double
    let entryCount: Int
    let daysWithEntries: Int
    let dailyRecords: [DailyCalorieRecord]

    var plannedCalories: Double {
        dailyTarget * Double(daysWithEntries)
    }

    /// Positive is over the plan; negative is under the plan.
    var calorieVariance: Double {
        totalCalories - plannedCalories
    }

    var averageCaloriesPerLoggedDay: Double {
        guard daysWithEntries > 0 else { return 0 }
        return totalCalories / Double(daysWithEntries)
    }

    var isSurplus: Bool {
        calorieVariance > 0
    }

    var varianceTitle: String {
        calorieVariance == 0 ? "On plan" : (isSurplus ? "Surplus" : "Deficit")
    }

    var varianceMagnitude: Double {
        abs(calorieVariance)
    }

    static func make(
        period: NutritionInsightPeriod,
        entries: [MealEntry],
        dailyTarget: Double,
        calendar: Calendar = .current
    ) -> CaloriePeriodSummary {
        let groupedEntries = Dictionary(grouping: entries) {
            calendar.startOfDay(for: $0.consumed_at)
        }
        let records = groupedEntries
            .map { date, dailyEntries in
                DailyCalorieRecord(
                    date: date,
                    calories: dailyEntries.reduce(0) { $0 + $1.totalCalories },
                    entryCount: dailyEntries.count
                )
            }
            .sorted { $0.date < $1.date }

        return CaloriePeriodSummary(
            period: period,
            dailyTarget: max(dailyTarget, 0),
            totalCalories: records.reduce(0) { $0 + $1.calories },
            entryCount: entries.count,
            daysWithEntries: records.count,
            dailyRecords: records
        )
    }

    static func make(
        period: NutritionInsightPeriod,
        foods: [Food],
        dailyTarget: Double,
        calendar: Calendar = .current
    ) -> CaloriePeriodSummary {
        make(
            period: period,
            entries: foods.map { MealEntry.from(food: $0) },
            dailyTarget: dailyTarget,
            calendar: calendar
        )
    }
}

struct MacroCatchUpSuggestion: Codable, Equatable {
    let name: String
    let description: String
    let calories: Double
    let protein: Double
    let carbohydrates: Double
    let fat: Double
    let whyItFits: String
}

struct MacroCatchUpBudget: Codable, Equatable {
    let caloriesRemaining: Double
    let proteinRemaining: Double
    let carbohydratesRemaining: Double
    let fatRemaining: Double

    init(progress: DailyNutritionProgress, targets: DailyNutritionTargets) {
        caloriesRemaining = max(targets.calories - progress.calories, 0)
        proteinRemaining = max(targets.protein - progress.protein, 0)
        carbohydratesRemaining = max(targets.carbs - progress.carbs, 0)
        fatRemaining = max(targets.fat - progress.fat, 0)
    }

    var canSuggestFood: Bool {
        caloriesRemaining >= 50 && proteinRemaining > 0
    }
}

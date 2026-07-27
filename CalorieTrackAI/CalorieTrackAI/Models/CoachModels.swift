import Foundation

struct CoachMessage: Identifiable, Equatable {
    enum Severity {
        case praise
        case warning
        case roast
    }

    let id = UUID()
    let title: String
    let body: String
    let severity: Severity
}

struct DailyNutritionProgress: Equatable {
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double

    init(calories: Double = 0, protein: Double = 0, carbs: Double = 0, fat: Double = 0) {
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
    }

    init(foods: [Food]) {
        self.init(
            calories: foods.reduce(0) { $0 + $1.calories },
            protein: foods.reduce(0) { $0 + $1.protein },
            carbs: foods.reduce(0) { $0 + $1.carbs },
            fat: foods.reduce(0) { $0 + $1.fat }
        )
    }

    func adding(_ food: Food) -> DailyNutritionProgress {
        DailyNutritionProgress(
            calories: calories + food.calories,
            protein: protein + food.protein,
            carbs: carbs + food.carbs,
            fat: fat + food.fat
        )
    }
}

struct CoachToneSettings: Codable, Equatable {
    var enabled: Bool
    var severity: Severity
    var foodRoastThresholdPercent: Double
    var activeStartHour: Int
    var activeEndHour: Int
    var allowExplicitBodyShame: Bool

    enum Severity: String, Codable, CaseIterable {
        case mild
        case spicy
        case fullRoast

        var displayName: String {
            switch self {
            case .mild: return "Mild"
            case .spicy: return "Spicy"
            case .fullRoast: return "Full Roast"
            }
        }
    }

    static let defaultFullRoast = CoachToneSettings(
        enabled: true,
        severity: .fullRoast,
        foodRoastThresholdPercent: 75,
        activeStartHour: 8,
        activeEndHour: 22,
        allowExplicitBodyShame: true
    )
}

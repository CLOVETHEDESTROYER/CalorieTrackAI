import Foundation

enum MealTimeClassifier {
    static func mealType(for date: Date = Date(), calendar: Calendar = .current) -> MealEntry.MealType {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minutes = ((components.hour ?? 0) * 60) + (components.minute ?? 0)

        switch minutes {
        case (5 * 60)..<(11 * 60):
            return .breakfast
        case (11 * 60)..<(15 * 60):
            return .lunch
        case (16 * 60)..<(21 * 60):
            return .dinner
        default:
            return .snack
        }
    }

    static func mealType(for date: Date = Date(), explicitText: String?, calendar: Calendar = .current) -> MealEntry.MealType {
        mealTypeMention(in: explicitText) ?? mealType(for: date, calendar: calendar)
    }

    static func mealTypeMention(in text: String?) -> MealEntry.MealType? {
        guard let text else { return nil }
        let normalized = text.lowercased()
        let keywordMap: [(MealEntry.MealType, [String])] = [
            (.breakfast, ["breakfast", "morning meal"]),
            (.lunch, ["lunch", "midday meal"]),
            (.dinner, ["dinner", "supper", "evening meal"]),
            (.snack, ["snack", "late night", "late-night"])
        ]

        return keywordMap.first { _, keywords in
            keywords.contains { keyword in
                normalized.range(of: "\\b\(NSRegularExpression.escapedPattern(for: keyword))\\b", options: .regularExpression) != nil
            }
        }?.0
    }

    static var mealWindowSummary: String {
        "Breakfast 5-11 AM, lunch 11 AM-3 PM, dinner 4-9 PM. Everything else counts as a snack."
    }
}

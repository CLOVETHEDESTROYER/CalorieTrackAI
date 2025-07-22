import Foundation

struct User: Identifiable, Codable {
    var id = UUID()
    var name: String
    var age: Int
    var weight: Double
    var height: Double
    var activityLevel: ActivityLevel
    var goalType: GoalType
    var dailyCalorieGoal: Double
    
    enum ActivityLevel: String, CaseIterable, Codable {
        case sedentary = "Sedentary"
        case lightlyActive = "Lightly Active"
        case moderatelyActive = "Moderately Active"
        case veryActive = "Very Active"
    }
    
    enum GoalType: String, CaseIterable, Codable {
        case loseWeight = "Lose Weight"
        case maintainWeight = "Maintain Weight"
        case gainWeight = "Gain Weight"
    }
    
    init(name: String, age: Int, weight: Double, height: Double, activityLevel: ActivityLevel = .sedentary, goalType: GoalType = .maintainWeight) {
        self.name = name
        self.age = age
        self.weight = weight
        self.height = height
        self.activityLevel = activityLevel
        self.goalType = goalType
        self.dailyCalorieGoal = 2000 // Default value, should be calculated
    }
} 
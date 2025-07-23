import Foundation

struct User: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var age: Int
    var weight: Double
    var height: Double
    var activityLevel: ActivityLevel
    var goalType: GoalType
    var dailyCalorieGoal: Double
    var weightUnit: WeightUnit
    var heightUnit: HeightUnit
    var bodyFatPercent: Double?
    var weeklyWeightChange: Double // lbs per week, positive for gain, negative for loss, 0 for maintain
    var gender: Gender
    
    enum ActivityLevel: String, CaseIterable, Codable {
        case sedentary = "Sedentary"
        case lightlyActive = "Lightly Active"
        case moderatelyActive = "Moderately Active"
        case veryActive = "Very Active"
    }
    
    enum GoalType: String, CaseIterable, Codable {
        case loseWeight = "lose weight"
        case maintainWeight = "maintain weight"
        case gainWeight = "gain weight"
    }
    
    enum WeightUnit: String, CaseIterable, Codable {
        case kg = "kg"
        case lb = "lb"
    }
    
    enum HeightUnit: String, CaseIterable, Codable {
        case cm = "cm"
        case inch = "in"
    }
    
    enum Gender: String, CaseIterable, Codable {
        case male = "Male"
        case female = "Female"
    }
    
    init(name: String, age: Int, weight: Double, height: Double, activityLevel: ActivityLevel = .sedentary, goalType: GoalType = .maintainWeight, dailyCalorieGoal: Double = 2000, weightUnit: WeightUnit = .kg, heightUnit: HeightUnit = .cm, bodyFatPercent: Double? = nil, weeklyWeightChange: Double = 0, gender: Gender = .male) {
        self.name = name
        self.age = age
        self.weight = weight
        self.height = height
        self.activityLevel = activityLevel
        self.goalType = goalType
        self.dailyCalorieGoal = dailyCalorieGoal  // Use the passed parameter
        self.weightUnit = weightUnit
        self.heightUnit = heightUnit
        self.bodyFatPercent = bodyFatPercent
        self.weeklyWeightChange = weeklyWeightChange
        self.gender = gender
    }
} 
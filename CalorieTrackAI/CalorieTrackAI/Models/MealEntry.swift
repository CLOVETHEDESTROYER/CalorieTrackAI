import Foundation

struct MealEntry: Identifiable, Codable {
    let id: UUID
    var user_id: UUID?
    let food_name: String
    let calories: Double
    let protein: Double
    let carbohydrates: Double
    let fat: Double
    let serving_size: String
    let serving_quantity: Double
    let meal_type: MealType
    let consumed_at: Date
    let created_at: Date?
    let updated_at: Date?
    
    // Optional fields for enhanced tracking
    let notes: String?
    let food_id: UUID? // Reference to food_database if available
    let image_url: String?
    
    enum MealType: String, CaseIterable, Codable {
        case breakfast = "breakfast"
        case lunch = "lunch"
        case dinner = "dinner"
        case snack = "snack"
        
        var displayName: String {
            switch self {
            case .breakfast: return "Breakfast"
            case .lunch: return "Lunch"
            case .dinner: return "Dinner"
            case .snack: return "Snack"
            }
        }
        
        var icon: String {
            switch self {
            case .breakfast: return "sunrise.fill"
            case .lunch: return "sun.max.fill"
            case .dinner: return "sunset.fill"
            case .snack: return "moon.stars.fill"
            }
        }
    }
    
    init(
        id: UUID = UUID(),
        user_id: UUID? = nil,
        food_name: String,
        calories: Double,
        protein: Double = 0,
        carbohydrates: Double = 0,
        fat: Double = 0,
        serving_size: String = "100g",
        serving_quantity: Double = 1.0,
        meal_type: MealType = .snack,
        consumed_at: Date = Date(),
        notes: String? = nil,
        food_id: UUID? = nil,
        image_url: String? = nil
    ) {
        self.id = id
        self.user_id = user_id
        self.food_name = food_name
        self.calories = calories
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fat = fat
        self.serving_size = serving_size
        self.serving_quantity = serving_quantity
        self.meal_type = meal_type
        self.consumed_at = consumed_at
        self.created_at = Date()
        self.updated_at = Date()
        self.notes = notes
        self.food_id = food_id
        self.image_url = image_url
    }
    
    // Convenience computed properties
    var totalCalories: Double {
        return calories * serving_quantity
    }
    
    var totalProtein: Double {
        return protein * serving_quantity
    }
    
    var totalCarbohydrates: Double {
        return carbohydrates * serving_quantity
    }
    
    var totalFat: Double {
        return fat * serving_quantity
    }
    
    // Convert from legacy Food model
    static func from(food: Food, mealType: MealType = .snack) -> MealEntry {
        return MealEntry(
            food_name: food.name,
            calories: food.calories,
            protein: food.protein,
            carbohydrates: food.carbs,
            fat: food.fat,
            serving_size: food.servingSize,
            meal_type: mealType,
            consumed_at: food.dateLogged
        )
    }
    
    // Convert to legacy Food model for backward compatibility
    func toFood() -> Food {
        return Food(
            name: food_name,
            calories: totalCalories,
            protein: totalProtein,
            carbs: totalCarbohydrates,
            fat: totalFat,
            servingSize: serving_size
        )
    }
}

// MARK: - Supporting Models

struct UserProfile: Codable {
    let user_id: UUID
    var name: String
    var age: Int
    var weight: Double
    var height: Double
    var activity_level: String
    var goal_type: String
    var daily_calorie_goal: Double
    var weight_unit: String  // Add this
    var height_unit: String  // Add this
    var body_fat_percent: Double?  // Add this
    var weekly_weight_change: Double  // Add this
    var gender: String  // Add this
    let created_at: Date?
    let updated_at: Date?
    
    init(
        user_id: UUID,
        name: String,
        age: Int,
        weight: Double,
        height: Double,
        activity_level: String = "sedentary",
        goal_type: String = "maintain weight",
        daily_calorie_goal: Double = 2000,
        weight_unit: String = "kg",  // Add this
        height_unit: String = "cm",  // Add this
        body_fat_percent: Double? = nil,  // Add this
        weekly_weight_change: Double = 0,  // Add this
        gender: String = "Male"  // Add this
    ) {
        self.user_id = user_id
        self.name = name
        self.age = age
        self.weight = weight
        self.height = height
        self.activity_level = activity_level
        self.goal_type = goal_type
        self.daily_calorie_goal = daily_calorie_goal
        self.weight_unit = weight_unit
        self.height_unit = height_unit
        self.body_fat_percent = body_fat_percent
        self.weekly_weight_change = weekly_weight_change
        self.gender = gender
        self.created_at = Date()
        self.updated_at = Date()
    }
    
    // Convert from legacy User model
    static func from(user: User, userId: UUID) -> UserProfile {
        let goalTypeString: String
        switch user.goalType {
        case .loseWeight: goalTypeString = "lose weight"
        case .maintainWeight: goalTypeString = "maintain weight"
        case .gainWeight: goalTypeString = "gain weight"
        }
        return UserProfile(
            user_id: userId,
            name: user.name,
            age: user.age,
            weight: user.weight,
            height: user.height,
            activity_level: user.activityLevel.rawValue.lowercased(),
            goal_type: goalTypeString,
            daily_calorie_goal: user.dailyCalorieGoal,
            weight_unit: user.weightUnit.rawValue,  // Add this
            height_unit: user.heightUnit.rawValue,  // Add this
            body_fat_percent: user.bodyFatPercent,  // Add this
            weekly_weight_change: user.weeklyWeightChange,  // Add this
            gender: user.gender.rawValue  // Add this
        )
    }
    
    // Convert to legacy User model
    func toUser() -> User {
        let activityLevel = User.ActivityLevel.allCases.first { 
            $0.rawValue.lowercased() == activity_level 
        } ?? .sedentary
        
        let goalType = User.GoalType.allCases.first { 
            $0.rawValue.lowercased() == goal_type 
        } ?? .maintainWeight
        
        let weightUnit = User.WeightUnit(rawValue: weight_unit) ?? .kg
        let heightUnit = User.HeightUnit(rawValue: height_unit) ?? .cm
        let gender = User.Gender(rawValue: gender) ?? .male
        
        return User(
            name: name,
            age: age,
            weight: weight,
            height: height,
            activityLevel: activityLevel,
            goalType: goalType,
            dailyCalorieGoal: daily_calorie_goal,
            weightUnit: weightUnit,  // Use saved value
            heightUnit: heightUnit,  // Use saved value
            bodyFatPercent: body_fat_percent,  // Use saved value
            weeklyWeightChange: weekly_weight_change,  // Use saved value
            gender: gender  // Use saved value
        )
    }
}

struct FoodItem: Codable, Identifiable {
    let id: UUID
    let name: String
    let brand: String?
    let barcode: String?
    let calories_per_100g: Double
    let protein_per_100g: Double
    let carbohydrates_per_100g: Double
    let fat_per_100g: Double
    let fiber_per_100g: Double?
    let sugar_per_100g: Double?
    let sodium_per_100g: Double?
    let verified: Bool
    let created_at: Date?
    
    init(
        id: UUID = UUID(),
        name: String,
        brand: String? = nil,
        barcode: String? = nil,
        calories_per_100g: Double,
        protein_per_100g: Double = 0,
        carbohydrates_per_100g: Double = 0,
        fat_per_100g: Double = 0,
        fiber_per_100g: Double? = nil,
        sugar_per_100g: Double? = nil,
        sodium_per_100g: Double? = nil,
        verified: Bool = false
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.barcode = barcode
        self.calories_per_100g = calories_per_100g
        self.protein_per_100g = protein_per_100g
        self.carbohydrates_per_100g = carbohydrates_per_100g
        self.fat_per_100g = fat_per_100g
        self.fiber_per_100g = fiber_per_100g
        self.sugar_per_100g = sugar_per_100g
        self.sodium_per_100g = sodium_per_100g
        self.verified = verified
        self.created_at = Date()
    }
    
    // Convert to MealEntry with serving information
    func toMealEntry(servingSize: String = "100g", servingQuantity: Double = 1.0, mealType: MealEntry.MealType = .snack) -> MealEntry {
        return MealEntry(
            food_name: name,
            calories: calories_per_100g,
            protein: protein_per_100g,
            carbohydrates: carbohydrates_per_100g,
            fat: fat_per_100g,
            serving_size: servingSize,
            serving_quantity: servingQuantity,
            meal_type: mealType,
            food_id: id
        )
    }
}

struct NutritionSummary: Codable {
    let totalCalories: Double
    let averageCalories: Double
    let totalProtein: Double
    let totalCarbohydrates: Double
    let totalFat: Double
    let entryCount: Int
    let period: Int // days
    
    var averageProtein: Double {
        return totalProtein / Double(period)
    }
    
    var averageCarbohydrates: Double {
        return totalCarbohydrates / Double(period)
    }
    
    var averageFat: Double {
        return totalFat / Double(period)
    }
} 
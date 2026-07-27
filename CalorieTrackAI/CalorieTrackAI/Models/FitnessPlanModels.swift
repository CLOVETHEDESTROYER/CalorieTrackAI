import Foundation

struct FitnessPlan: Identifiable, Codable, Equatable {
    let id: UUID
    var createdAt: Date
    var goal: User.GoalType
    var calorieTarget: Double
    var proteinGoal: Double
    var carbsGoal: Double
    var fatGoal: Double
    var stepGoal: Int
    var trainingDaysPerWeek: Int
    var meals: [MealPlanDay]
    var workouts: [WorkoutPlanDay]
    var coachNote: String

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        goal: User.GoalType,
        calorieTarget: Double,
        proteinGoal: Double,
        carbsGoal: Double,
        fatGoal: Double,
        stepGoal: Int,
        trainingDaysPerWeek: Int,
        meals: [MealPlanDay],
        workouts: [WorkoutPlanDay],
        coachNote: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.goal = goal
        self.calorieTarget = calorieTarget
        self.proteinGoal = proteinGoal
        self.carbsGoal = carbsGoal
        self.fatGoal = fatGoal
        self.stepGoal = stepGoal
        self.trainingDaysPerWeek = trainingDaysPerWeek
        self.meals = meals
        self.workouts = workouts
        self.coachNote = coachNote
    }
}

struct DailyNutritionTargets: Equatable {
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double

    init(calories: Double, protein: Double, carbs: Double, fat: Double) {
        self.calories = max(calories, 0)
        self.protein = max(protein, 0)
        self.carbs = max(carbs, 0)
        self.fat = max(fat, 0)
    }

    init(plan: FitnessPlan) {
        self.init(
            calories: plan.calorieTarget,
            protein: plan.proteinGoal,
            carbs: plan.carbsGoal,
            fat: plan.fatGoal
        )
    }
}

struct NutritionMetricProgress: Equatable {
    var consumed: Double
    var target: Double

    var fraction: Double {
        guard target > 0 else { return 0 }
        return min(max(consumed / target, 0), 1)
    }

    var remaining: Double {
        max(target - consumed, 0)
    }

    var hasReachedGoal: Bool {
        target > 0 && consumed >= target
    }
}

struct MealPlanDay: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var calorieTarget: Double
    var meals: [PlannedMeal]

    init(id: UUID = UUID(), title: String, calorieTarget: Double, meals: [PlannedMeal]) {
        self.id = id
        self.title = title
        self.calorieTarget = calorieTarget
        self.meals = meals
    }
}

struct PlannedMeal: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var notes: String

    init(
        id: UUID = UUID(),
        name: String,
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        notes: String
    ) {
        self.id = id
        self.name = name
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.notes = notes
    }
}

struct WorkoutPlanDay: Identifiable, Codable, Equatable {
    let id: UUID
    var dayName: String
    var focus: String
    var estimatedMinutes: Int
    var exercises: [PlannedExercise]
    var finisher: String
    var completionTarget: String?
    var progression: String?

    init(
        id: UUID = UUID(),
        dayName: String,
        focus: String,
        estimatedMinutes: Int,
        exercises: [PlannedExercise],
        finisher: String,
        completionTarget: String? = nil,
        progression: String? = nil
    ) {
        self.id = id
        self.dayName = dayName
        self.focus = focus
        self.estimatedMinutes = estimatedMinutes
        self.exercises = exercises
        self.finisher = finisher
        self.completionTarget = completionTarget
        self.progression = progression
    }
}

struct PlannedExercise: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var sets: Int
    var reps: String
    var notes: String

    init(id: UUID = UUID(), name: String, sets: Int, reps: String, notes: String) {
        self.id = id
        self.name = name
        self.sets = sets
        self.reps = reps
        self.notes = notes
    }
}

enum MealPlanStyle: String, CaseIterable, Codable {
    case balanced = "Balanced"
    case highProtein = "High Protein"
    case budget = "Budget"
    case glpSupport = "GLP Support"

    var displayName: String { rawValue }

    var pickerTitle: String {
        switch self {
        case .balanced: return "Balanced"
        case .highProtein: return "Protein"
        case .budget: return "Budget"
        case .glpSupport: return "GLP"
        }
    }

    var guidance: String {
        switch self {
        case .balanced:
            return "A straightforward calorie-controlled rotation with protein, carbs, and fats spread through the day."
        case .highProtein:
            return "More protein-forward meals for people who need the plan to stop losing arguments with snacks."
        case .budget:
            return "Lower-cost staples and repeatable meals so the grocery bill does not become the excuse."
        case .glpSupport:
            return "Smaller protein-forward meals and hydration/fiber prompts for users tracking GLP or peptide routines. This is food structure only, not medication or medical guidance."
        }
    }
}

struct FitnessPlanPayload: Codable, Equatable {
    var meals: [MealPlanDay]
    var workouts: [WorkoutPlanDay]
}

struct FitnessPlanRecord: Identifiable, Codable, Equatable {
    let id: UUID
    var user_id: UUID?
    var goal: String
    var calorie_target: Double
    var protein_goal: Double
    var carbs_goal: Double
    var fat_goal: Double
    var step_goal: Int
    var training_days_per_week: Int
    var plan_payload: FitnessPlanPayload
    var coach_note: String?
    var is_active: Bool
    var created_at: Date?
    var updated_at: Date?

    init(plan: FitnessPlan, userId: UUID? = nil, isActive: Bool = true) {
        id = plan.id
        user_id = userId
        goal = plan.goal.rawValue
        calorie_target = plan.calorieTarget
        protein_goal = plan.proteinGoal
        carbs_goal = plan.carbsGoal
        fat_goal = plan.fatGoal
        step_goal = plan.stepGoal
        training_days_per_week = plan.trainingDaysPerWeek
        plan_payload = FitnessPlanPayload(meals: plan.meals, workouts: plan.workouts)
        coach_note = plan.coachNote
        is_active = isActive
        created_at = plan.createdAt
        updated_at = nil
    }

    func toPlan() -> FitnessPlan {
        FitnessPlan(
            id: id,
            createdAt: created_at ?? Date(),
            goal: User.GoalType(rawValue: goal) ?? .loseWeight,
            calorieTarget: calorie_target,
            proteinGoal: protein_goal,
            carbsGoal: carbs_goal,
            fatGoal: fat_goal,
            stepGoal: step_goal,
            trainingDaysPerWeek: training_days_per_week,
            meals: plan_payload.meals,
            workouts: plan_payload.workouts,
            coachNote: coach_note ?? ""
        )
    }
}

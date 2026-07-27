import Foundation

@MainActor
final class FitnessPlanService: ObservableObject {
    static let shared = FitnessPlanService()

    @Published private(set) var currentPlan: FitnessPlan?
    @Published private(set) var isSyncing = false

    private let planKey = "CurrentFitnessPlan"
    private let supabaseService = SupabaseService.shared

    private init() {
        currentPlan = loadPlan()
    }

    func generatePlan(
        for user: User,
        trainingDaysPerWeek: Int,
        mealStyle: MealPlanStyle
    ) -> FitnessPlan {
        let targets = Self.nutritionTargets(for: user)
        let calories = targets.calories
        let protein = targets.protein
        let carbs = targets.carbs
        let fat = targets.fat
        let stepGoal = stepGoal(for: user, trainingDays: trainingDaysPerWeek)
        let workouts = workoutSplit(goal: user.goalType, trainingDays: trainingDaysPerWeek)
        let meals = mealDays(
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            style: mealStyle
        )

        let plan = FitnessPlan(
            goal: user.goalType,
            calorieTarget: calories,
            proteinGoal: protein,
            carbsGoal: carbs,
            fatGoal: fat,
            stepGoal: stepGoal,
            trainingDaysPerWeek: trainingDaysPerWeek,
            meals: meals,
            workouts: workouts,
            coachNote: coachNote(goal: user.goalType, trainingDays: trainingDaysPerWeek, style: mealStyle)
        )

        save(plan)
        Task {
            await syncPlan(plan)
            await CoachNotificationService.shared.rescheduleNotifications()
        }
        return plan
    }

    static func nutritionTargets(for user: User) -> DailyNutritionTargets {
        let calories = max(1200, user.dailyCalorieGoal.rounded())
        let weightPounds = user.weightUnit == .lb ? user.weight : user.weight * 2.20462
        let proteinMultiplier: Double = user.goalType == .gainWeight ? 0.8 : 0.9
        let protein = min(max(weightPounds * proteinMultiplier, 90), calories * 0.4 / 4).rounded()
        let fat = max((calories * 0.25 / 9).rounded(), 45)
        let carbs = max(((calories - (protein * 4) - (fat * 9)) / 4).rounded(), 75)

        return DailyNutritionTargets(
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat
        )
    }

    func save(_ plan: FitnessPlan) {
        currentPlan = plan
        if let data = try? JSONEncoder().encode(plan) {
            UserDefaults.standard.set(data, forKey: planKey)
        }
        Task {
            await CoachNotificationService.shared.rescheduleNotifications()
        }
    }

    func clearPlan() {
        currentPlan = nil
        UserDefaults.standard.removeObject(forKey: planKey)
        Task {
            await CoachNotificationService.shared.rescheduleNotifications()
        }
    }

    func refreshFromServer() async {
        guard supabaseService.isAuthenticated else {
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        do {
            if let remotePlan = try await supabaseService.getActiveFitnessPlan() {
                save(remotePlan)
            } else if let currentPlan {
                await syncPlan(currentPlan)
            }
        } catch {
            #if DEBUG
            print("Fitness plan refresh failed: \(error)")
            #endif
        }
    }

    private func syncPlan(_ plan: FitnessPlan) async {
        guard supabaseService.isAuthenticated else {
            return
        }

        do {
            let savedPlan = try await supabaseService.saveFitnessPlan(plan)
            save(savedPlan)
        } catch {
            #if DEBUG
            print("Fitness plan sync failed: \(error)")
            #endif
        }
    }

    private func loadPlan() -> FitnessPlan? {
        guard let data = UserDefaults.standard.data(forKey: planKey) else {
            return nil
        }
        return try? JSONDecoder().decode(FitnessPlan.self, from: data)
    }

    private func stepGoal(for user: User, trainingDays: Int) -> Int {
        let base: Int
        switch user.activityLevel {
        case .sedentary: base = 7_000
        case .lightlyActive: base = 8_500
        case .moderatelyActive: base = 10_000
        case .veryActive: base = 12_000
        }
        return user.goalType == .loseWeight ? base + 1_000 : base + max(0, trainingDays - 3) * 500
    }

    private func coachNote(goal: User.GoalType, trainingDays: Int, style: MealPlanStyle) -> String {
        if style == .glpSupport {
            return "GLP-support mode keeps meals smaller and protein-forward. Still track the numbers, hydrate like an adult, and follow your clinician for anything medication-related."
        }

        switch goal {
        case .loseWeight:
            return "This is not magic. Hit the protein, stay under the calorie line, and train \(trainingDays)x/week like you meant it."
        case .maintainWeight:
            return "Maintain does not mean coast. Keep the meals boring enough to work and the workouts loud enough to count."
        case .gainWeight:
            return "Eat like an adult, lift like you have plans, and stop calling random snacking a bulk."
        }
    }

    private func mealDays(
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        style: MealPlanStyle
    ) -> [MealPlanDay] {
        return [
            MealPlanDay(
                title: "\(style.displayName) Day A",
                calorieTarget: calories,
                meals: mealTemplateA(calories: calories, protein: protein, carbs: carbs, fat: fat, style: style)
            ),
            MealPlanDay(
                title: "\(style.displayName) Day B",
                calorieTarget: calories,
                meals: mealTemplateB(calories: calories, protein: protein, carbs: carbs, fat: fat, style: style)
            ),
            MealPlanDay(
                title: "\(style.displayName) Day C",
                calorieTarget: calories,
                meals: mealTemplateC(calories: calories, protein: protein, carbs: carbs, fat: fat, style: style)
            )
        ]
    }

    private func mealTemplateA(
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        style: MealPlanStyle
    ) -> [PlannedMeal] {
        if style == .glpSupport {
            return glpSupportTemplateA(calories: calories, protein: protein, carbs: carbs, fat: fat)
        }

        return [
            PlannedMeal(
                name: style == .budget ? "Greek yogurt, oats, berries" : "Egg scramble with oats",
                calories: calories * 0.28,
                protein: protein * 0.3,
                carbs: carbs * 0.32,
                fat: fat * 0.22,
                notes: "Breakfast that does not behave like dessert in a fake mustache."
            ),
            PlannedMeal(
                name: style == .highProtein ? "Chicken bowl with rice" : "Turkey rice bowl",
                calories: calories * 0.34,
                protein: protein * 0.36,
                carbs: carbs * 0.38,
                fat: fat * 0.28,
                notes: "Prep it once. Stop negotiating with drive-thru menus."
            ),
            PlannedMeal(
                name: "Lean protein, potatoes, vegetables",
                calories: calories * 0.28,
                protein: protein * 0.26,
                carbs: carbs * 0.24,
                fat: fat * 0.34,
                notes: "Boring works. Exciting is how snacks start holding meetings."
            ),
            PlannedMeal(
                name: "Protein snack",
                calories: calories * 0.1,
                protein: protein * 0.08,
                carbs: carbs * 0.06,
                fat: fat * 0.16,
                notes: "Use this before the pantry starts whispering nonsense."
            )
        ]
    }

    private func mealTemplateB(
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        style: MealPlanStyle
    ) -> [PlannedMeal] {
        if style == .glpSupport {
            return glpSupportTemplateB(calories: calories, protein: protein, carbs: carbs, fat: fat)
        }

        return [
            PlannedMeal(
                name: style == .budget ? "Eggs, toast, fruit" : "Protein smoothie and toast",
                calories: calories * 0.25,
                protein: protein * 0.26,
                carbs: carbs * 0.3,
                fat: fat * 0.22,
                notes: "Fast, measured, and harder to ruin than vibes-based breakfast."
            ),
            PlannedMeal(
                name: "Tuna or chicken wrap with salad",
                calories: calories * 0.3,
                protein: protein * 0.34,
                carbs: carbs * 0.28,
                fat: fat * 0.28,
                notes: "Portable discipline. Try not to accessorize it with fries."
            ),
            PlannedMeal(
                name: style == .highProtein ? "Steak or tofu stir fry" : "Salmon or tofu bowl",
                calories: calories * 0.35,
                protein: protein * 0.32,
                carbs: carbs * 0.34,
                fat: fat * 0.38,
                notes: "Vegetables are not decoration. Eat them."
            ),
            PlannedMeal(
                name: "Cottage cheese or shake",
                calories: calories * 0.1,
                protein: protein * 0.08,
                carbs: carbs * 0.08,
                fat: fat * 0.12,
                notes: "Snack with a job description."
            )
        ]
    }

    private func mealTemplateC(
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        style: MealPlanStyle
    ) -> [PlannedMeal] {
        if style == .glpSupport {
            return glpSupportTemplateC(calories: calories, protein: protein, carbs: carbs, fat: fat)
        }

        return [
            PlannedMeal(
                name: "Breakfast burrito bowl",
                calories: calories * 0.28,
                protein: protein * 0.3,
                carbs: carbs * 0.32,
                fat: fat * 0.26,
                notes: "Burrito energy without letting the tortilla run the company."
            ),
            PlannedMeal(
                name: style == .budget ? "Bean and chicken bowl" : "Lean burger plate",
                calories: calories * 0.32,
                protein: protein * 0.32,
                carbs: carbs * 0.32,
                fat: fat * 0.3,
                notes: "Looks like real food because it is. Shocking development."
            ),
            PlannedMeal(
                name: "Turkey chili or lentil chili",
                calories: calories * 0.3,
                protein: protein * 0.3,
                carbs: carbs * 0.28,
                fat: fat * 0.3,
                notes: "Batch cook this and remove excuses from the premises."
            ),
            PlannedMeal(
                name: "Fruit plus protein",
                calories: calories * 0.1,
                protein: protein * 0.08,
                carbs: carbs * 0.08,
                fat: fat * 0.14,
                notes: "Sweet enough. Do not make it weird."
            )
        ]
    }

    private func glpSupportTemplateA(
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double
    ) -> [PlannedMeal] {
        [
            PlannedMeal(
                name: "Greek yogurt protein bowl",
                calories: calories * 0.2,
                protein: protein * 0.24,
                carbs: carbs * 0.18,
                fat: fat * 0.16,
                notes: "Small, protein-first breakfast. Tiny meal, real job."
            ),
            PlannedMeal(
                name: "Chicken soup cup with vegetables",
                calories: calories * 0.18,
                protein: protein * 0.2,
                carbs: carbs * 0.14,
                fat: fat * 0.16,
                notes: "Easy volume, clear protein, and no heroic portion nonsense."
            ),
            PlannedMeal(
                name: "Turkey rice mini bowl",
                calories: calories * 0.24,
                protein: protein * 0.24,
                carbs: carbs * 0.26,
                fat: fat * 0.2,
                notes: "Measured carbs, lean protein, vegetables. The boring little plan that works."
            ),
            PlannedMeal(
                name: "Protein shake and fruit",
                calories: calories * 0.16,
                protein: protein * 0.16,
                carbs: carbs * 0.18,
                fat: fat * 0.1,
                notes: "Backup protein for low-appetite days. Still counts, so log it."
            ),
            PlannedMeal(
                name: "Salmon or tofu snack plate",
                calories: calories * 0.22,
                protein: protein * 0.16,
                carbs: carbs * 0.24,
                fat: fat * 0.38,
                notes: "Protein, fiber, fluids. Follow clinician guidance for medication-related symptoms."
            )
        ]
    }

    private func glpSupportTemplateB(
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double
    ) -> [PlannedMeal] {
        [
            PlannedMeal(
                name: "Egg bites with berries",
                calories: calories * 0.18,
                protein: protein * 0.22,
                carbs: carbs * 0.14,
                fat: fat * 0.18,
                notes: "Small start, real protein. Breakfast does not need a dramatic arc."
            ),
            PlannedMeal(
                name: "Tuna cucumber crackers",
                calories: calories * 0.18,
                protein: protein * 0.22,
                carbs: carbs * 0.16,
                fat: fat * 0.14,
                notes: "Crunch, protein, and portion control in the same room for once."
            ),
            PlannedMeal(
                name: "Lean burger lettuce bowl",
                calories: calories * 0.26,
                protein: protein * 0.26,
                carbs: carbs * 0.22,
                fat: fat * 0.28,
                notes: "Burger energy without letting the bun run payroll."
            ),
            PlannedMeal(
                name: "Cottage cheese and fruit",
                calories: calories * 0.16,
                protein: protein * 0.16,
                carbs: carbs * 0.2,
                fat: fat * 0.1,
                notes: "A small snack with actual protein. Revolutionary behavior."
            ),
            PlannedMeal(
                name: "Chicken chili cup",
                calories: calories * 0.22,
                protein: protein * 0.14,
                carbs: carbs * 0.28,
                fat: fat * 0.3,
                notes: "Fiber and protein. Eat slowly enough for your brain to receive the memo."
            )
        ]
    }

    private func glpSupportTemplateC(
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double
    ) -> [PlannedMeal] {
        [
            PlannedMeal(
                name: "Protein oatmeal cup",
                calories: calories * 0.2,
                protein: protein * 0.2,
                carbs: carbs * 0.24,
                fat: fat * 0.14,
                notes: "Warm, measured, and less chaotic than improvising from hunger."
            ),
            PlannedMeal(
                name: "Shrimp or tofu salad",
                calories: calories * 0.18,
                protein: protein * 0.22,
                carbs: carbs * 0.12,
                fat: fat * 0.2,
                notes: "Light meal, real protein, vegetables doing useful work."
            ),
            PlannedMeal(
                name: "Chicken potato mini plate",
                calories: calories * 0.26,
                protein: protein * 0.24,
                carbs: carbs * 0.28,
                fat: fat * 0.2,
                notes: "Simple fuel. The potato is measured because chaos has had enough turns."
            ),
            PlannedMeal(
                name: "Hydration plus protein snack",
                calories: calories * 0.14,
                protein: protein * 0.16,
                carbs: carbs * 0.12,
                fat: fat * 0.12,
                notes: "Drink water, get protein, stop treating basics like optional side quests."
            ),
            PlannedMeal(
                name: "Turkey meatballs and vegetables",
                calories: calories * 0.22,
                protein: protein * 0.18,
                carbs: carbs * 0.24,
                fat: fat * 0.34,
                notes: "Small dinner, high signal. Follow medical guidance for anything medication-related."
            )
        ]
    }

    private func workoutSplit(goal: User.GoalType, trainingDays: Int) -> [WorkoutPlanDay] {
        let days = [
            WorkoutPlanDay(
                dayName: "Day 1",
                focus: "Full Body Strength",
                estimatedMinutes: 55,
                exercises: [
                    PlannedExercise(name: "Goblet squat or back squat", sets: 4, reps: "6-10", notes: "Leave 1-2 reps in the tank."),
                    PlannedExercise(name: "Dumbbell press", sets: 4, reps: "8-12", notes: "Control the lowering."),
                    PlannedExercise(name: "Cable row", sets: 4, reps: "8-12", notes: "Pull with your back, not your ego."),
                    PlannedExercise(name: "Romanian deadlift", sets: 3, reps: "8-10", notes: "Hamstrings should complain politely.")
                ],
                finisher: goal == .loseWeight ? "10 minutes incline walk" : "Loaded carry: 4 rounds",
                completionTarget: "Log the workout when all listed sets plus the finisher are done. Half-finished does not get a victory parade.",
                progression: "When every set lands at the top of its rep range with clean form, add 5 lb next time or slow the tempo if equipment is limited."
            ),
            WorkoutPlanDay(
                dayName: "Day 2",
                focus: "Conditioning + Core",
                estimatedMinutes: 40,
                exercises: [
                    PlannedExercise(name: "Bike or treadmill intervals", sets: 8, reps: "45 sec hard / 75 sec easy", notes: "Hard means hard enough to stop scrolling."),
                    PlannedExercise(name: "Walking lunges", sets: 3, reps: "12 each leg", notes: "Stay tall."),
                    PlannedExercise(name: "Plank", sets: 3, reps: "45-60 sec", notes: "No sagging."),
                    PlannedExercise(name: "Dead bug", sets: 3, reps: "10 each side", notes: "Slow and annoying is the point.")
                ],
                finisher: "Easy walk until the step goal stops embarrassing you",
                completionTarget: "Finish the intervals, core work, and enough walking to keep the daily step target alive.",
                progression: "Add one interval round or five minutes of easy cardio next week if recovery is fine and the excuses are getting repetitive."
            ),
            WorkoutPlanDay(
                dayName: "Day 3",
                focus: "Upper Body Strength",
                estimatedMinutes: 50,
                exercises: [
                    PlannedExercise(name: "Lat pulldown or assisted pull-up", sets: 4, reps: "8-12", notes: "Full range."),
                    PlannedExercise(name: "Incline dumbbell press", sets: 4, reps: "8-12", notes: "Keep shoulders packed."),
                    PlannedExercise(name: "Seated row", sets: 3, reps: "10-12", notes: "Pause at the squeeze."),
                    PlannedExercise(name: "Lateral raise", sets: 3, reps: "12-15", notes: "Small weights still count.")
                ],
                finisher: "Arms superset: curls + pressdowns, 3 rounds",
                completionTarget: "Complete every upper-body set plus the arm superset. Write it down before your memory edits the footage.",
                progression: "Add reps before load. Once all sets hit the top of the range, bump weight slightly and keep the form boring."
            ),
            WorkoutPlanDay(
                dayName: "Day 4",
                focus: "Lower Body Strength",
                estimatedMinutes: 55,
                exercises: [
                    PlannedExercise(name: "Leg press or squat", sets: 4, reps: "8-12", notes: "Depth before drama."),
                    PlannedExercise(name: "Hip thrust", sets: 4, reps: "8-12", notes: "Pause at the top."),
                    PlannedExercise(name: "Hamstring curl", sets: 3, reps: "10-15", notes: "Control every rep."),
                    PlannedExercise(name: "Calf raise", sets: 4, reps: "12-20", notes: "Yes, calves count.")
                ],
                finisher: goal == .gainWeight ? "Sled push: 6 strong rounds" : "12 minutes steady cardio",
                completionTarget: "Finish the lower-body work and finisher without turning the last two sets into interpretive dance.",
                progression: "Add load only after depth, control, and full reps are consistent. Form first, ego last."
            ),
            WorkoutPlanDay(
                dayName: "Day 5",
                focus: "Optional Conditioning",
                estimatedMinutes: 35,
                exercises: [
                    PlannedExercise(name: "Zone 2 cardio", sets: 1, reps: "25-35 min", notes: "You should be able to talk, not sing."),
                    PlannedExercise(name: "Mobility circuit", sets: 3, reps: "5 min", notes: "Hips, back, shoulders."),
                    PlannedExercise(name: "Farmer carry", sets: 4, reps: "40 yards", notes: "Walk like the groceries matter.")
                ],
                finisher: "Stretch for 5 minutes before you claim you are too busy",
                completionTarget: "Stay in Zone 2, finish the carries, and stretch. This is recovery work, not punishment theater.",
                progression: "Add five Zone 2 minutes or one carry round when the session feels easy and your joints are not filing complaints."
            )
        ]

        return Array(days.prefix(max(2, min(trainingDays, days.count))))
    }
}

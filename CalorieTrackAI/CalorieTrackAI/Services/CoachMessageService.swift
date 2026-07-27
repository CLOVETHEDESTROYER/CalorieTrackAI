import Foundation

@MainActor
final class CoachMessageService: ObservableObject {
    static let shared = CoachMessageService()

    @Published private(set) var settings: CoachToneSettings

    private let settingsKey = "CoachToneSettings"
    private let supabaseService = SupabaseService.shared

    private init() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(CoachToneSettings.self, from: data) {
            settings = decoded
        } else {
            settings = .defaultFullRoast
        }
    }

    func updateSettings(_ newSettings: CoachToneSettings) {
        settings = newSettings
        saveLocal(newSettings)

        Task {
            await syncSettings(newSettings)
        }
    }

    func resetLocalSettings() {
        settings = .defaultFullRoast
        saveLocal(settings)
    }

    func refreshFromServer() async {
        guard supabaseService.isAuthenticated else {
            return
        }

        do {
            if let remoteSettings = try await supabaseService.getCoachToneSettings() {
                settings = remoteSettings
                saveLocal(remoteSettings)
            } else {
                await syncSettings(settings)
            }
        } catch {
            #if DEBUG
            print("Coach tone settings refresh failed: \(error)")
            #endif
        }
    }

    private func saveLocal(_ newSettings: CoachToneSettings) {
        if let data = try? JSONEncoder().encode(newSettings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }

    private func syncSettings(_ newSettings: CoachToneSettings) async {
        guard supabaseService.isAuthenticated else {
            return
        }

        do {
            let savedSettings = try await supabaseService.saveCoachToneSettings(newSettings)
            settings = savedSettings
            saveLocal(savedSettings)
        } catch {
            #if DEBUG
            print("Coach tone settings sync failed: \(error)")
            #endif
        }
    }

    func dashboardMessage(
        consumedCalories: Double,
        dailyGoal: Double,
        protein: Double,
        proteinGoal: Double
    ) -> CoachMessage {
        guard settings.enabled else {
            return CoachMessage(
                title: "Coach muted",
                body: "No yelling today. Suspiciously peaceful.",
                severity: .warning
            )
        }

        let calorieRatio = dailyGoal > 0 ? consumedCalories / dailyGoal : 0
        let proteinRatio = proteinGoal > 0 ? protein / proteinGoal : 0

        if calorieRatio > 1.0 {
            return CoachMessage(
                title: toned(
                    mild: "Over Budget",
                    spicy: "Calorie Warning",
                    fullRoast: "Fatness Alert",
                    fullRoastNoBodyShame: "Calorie Alert"
                ),
                body: toned(
                    mild: "You are over today's calorie target. Log the rest honestly and make the next choice easier.",
                    spicy: "You blew past the calorie line. Put the snacks down and go earn some dignity back.",
                    fullRoast: "You blew past the calorie line. Put the snacks down and go earn some dignity back.",
                    fullRoastNoBodyShame: "You blew past the calorie line. Tighten up the next meal and go earn some of that budget back."
                ),
                severity: .roast
            )
        }

        if proteinRatio >= 0.85 && calorieRatio <= 0.9 {
            return CoachMessage(
                title: toned(
                    mild: "Solid Progress",
                    spicy: "Fine, That Was Solid",
                    fullRoast: "Fine, That Was Solid"
                ),
                body: toned(
                    mild: "Protein is nearly handled and calories are still under control. Keep stacking choices like that.",
                    spicy: "Protein is almost handled and calories are still under control. Look at you acting like the plan matters.",
                    fullRoast: "Protein is almost handled and calories are still under control. Look at you acting like the plan matters."
                ),
                severity: .praise
            )
        }

        if calorieRatio >= settings.foodRoastThresholdPercent / 100 {
            return CoachMessage(
                title: toned(
                    mild: "Heads Up",
                    spicy: "Watch It",
                    fullRoast: "Watch It"
                ),
                body: toned(
                    mild: "You are getting close to the calorie limit. Plan the next meal before the day gets away from you.",
                    spicy: "You are cruising toward the limit like the pantry owes you money. Tighten it up.",
                    fullRoast: "You are cruising toward the limit like the pantry owes you money. Tighten it up."
                ),
                severity: .warning
            )
        }

        return CoachMessage(
            title: toned(
                mild: "Today's Focus",
                spicy: "Today's Assignment",
                fullRoast: "Today's Assignment"
            ),
            body: toned(
                mild: "Log your food, hit protein, and get your movement in. Simple day, done well.",
                spicy: "Log the food, hit the protein, move your body. Revolutionary stuff, apparently.",
                fullRoast: "Log the food, hit the protein, move your body. Revolutionary stuff, apparently."
            ),
            severity: .warning
        )
    }

    func foodLoggedMessage(food: Food, dailyGoal: Double = 2000) -> CoachMessage {
        guard settings.enabled && isWithinActiveHours() else {
            return CoachMessage(
                title: "Food Logged",
                body: "It is in the books. The coach is off the clock, but the calories still count.",
                severity: .praise
            )
        }

        let calorieRatio = dailyGoal > 0 ? food.calories / dailyGoal : 0
        let foodName = food.name.lowercased()
        let candyWords = ["candy", "chocolate", "cookie", "donut", "doughnut", "cake", "soda", "chips", "fries"]
        let looksLikeJunk = candyWords.contains { foodName.contains($0) }

        if looksLikeJunk {
            return CoachMessage(
                title: toned(
                    mild: "Check The Fit",
                    spicy: "Interesting Choice",
                    fullRoast: "Interesting Choice"
                ),
                body: toned(
                    mild: "A \(food.name) can fit sometimes, but make sure it actually belongs in today's plan.",
                    spicy: "A \(food.name)? Bold strategy for someone allegedly trying to lose weight. Maybe chase it with a walk and a better decision.",
                    fullRoast: "A \(food.name)? Bold strategy for someone allegedly trying to lose weight. Maybe chase it with a walk and a better decision."
                ),
                severity: .roast
            )
        }

        if calorieRatio >= 0.35 {
            return CoachMessage(
                title: toned(
                    mild: "Big Log",
                    spicy: "Big Swing",
                    fullRoast: "Big Swing"
                ),
                body: toned(
                    mild: "\(Int(food.calories)) calories in one log. Keep the rest of the day tighter and honest.",
                    spicy: "\(Int(food.calories)) calories in one log. Hope that was worth it, because your budget just got punched in the mouth.",
                    fullRoast: "\(Int(food.calories)) calories in one log. Hope that was worth it, because your budget just got punched in the mouth."
                ),
                severity: .warning
            )
        }

        if food.protein >= 25 {
            return CoachMessage(
                title: toned(
                    mild: "Good Protein",
                    spicy: "Acceptable Behavior",
                    fullRoast: "Acceptable Behavior"
                ),
                body: toned(
                    mild: "Protein showed up. Keep that energy going.",
                    spicy: "Protein showed up. Miracles happen when you stop eating like a confused vending machine.",
                    fullRoast: "Protein showed up. Miracles happen when you stop eating like a confused vending machine."
                ),
                severity: .praise
            )
        }

        return CoachMessage(
            title: toned(
                mild: "Logged",
                spicy: "Logged",
                fullRoast: "Logged"
            ),
            body: toned(
                mild: "It is tracked. Keep the rest of the day lined up with your target.",
                spicy: "Fine. It is tracked. Now do not pretend logging it magically burned it off.",
                fullRoast: "Fine. It is tracked. Now do not pretend logging it magically burned it off."
            ),
            severity: .warning
        )
    }

    func foodLoggedMessage(
        food: Food,
        progress: DailyNutritionProgress,
        plan: FitnessPlan?,
        fallbackDailyGoal: Double = 2000
    ) -> CoachMessage {
        guard settings.enabled && isWithinActiveHours() else {
            return CoachMessage(
                title: "Food Logged",
                body: "It is in the books. The coach is off the clock, but the calories still count.",
                severity: .praise
            )
        }

        guard let plan else {
            return foodLoggedMessage(food: food, dailyGoal: fallbackDailyGoal)
        }

        let calorieOverage = progress.calories - plan.calorieTarget
        if calorieOverage > 0 {
            return CoachMessage(
                title: toned(
                    mild: "Plan Check",
                    spicy: "Macro Collision",
                    fullRoast: "Macro Collision"
                ),
                body: toned(
                    mild: "\(food.name) puts today \(Int(calorieOverage.rounded())) calories over the plan. Log it honestly, then make the next meal boring and useful.",
                    spicy: "\(food.name) just shoved today \(Int(calorieOverage.rounded())) calories over the plan. This is where the app reminds you that vibes are not a macro.",
                    fullRoast: "\(food.name) just shoved today \(Int(calorieOverage.rounded())) calories over the plan. This is where the app reminds you that vibes are not a macro."
                ),
                severity: .roast
            )
        }

        let carbOverage = progress.carbs - plan.carbsGoal
        if carbOverage > max(10, plan.carbsGoal * 0.05) {
            return CoachMessage(
                title: toned(
                    mild: "Carbs Are High",
                    spicy: "Carb Budget Got Cooked",
                    fullRoast: "Carb Budget Got Cooked"
                ),
                body: toned(
                    mild: "\(food.name) pushes carbs \(Int(carbOverage.rounded()))g over target. Keep the rest of the day lean and protein-focused.",
                    spicy: "\(food.name) pushed carbs \(Int(carbOverage.rounded()))g over target. Bold move for someone with a plan and access to math.",
                    fullRoast: "\(food.name) pushed carbs \(Int(carbOverage.rounded()))g over target. Bold move for someone with a plan and access to math."
                ),
                severity: .warning
            )
        }

        let fatOverage = progress.fat - plan.fatGoal
        if fatOverage > max(5, plan.fatGoal * 0.05) {
            return CoachMessage(
                title: toned(
                    mild: "Fat Target",
                    spicy: "Fat Budget Is Wobbling",
                    fullRoast: "Fat Budget Is Wobbling"
                ),
                body: toned(
                    mild: "\(food.name) pushes fat \(Int(fatOverage.rounded()))g over target. Make the next choices lighter and cleaner.",
                    spicy: "\(food.name) pushed fat \(Int(fatOverage.rounded()))g over target. The plan is still there, unfortunately for your snack logic.",
                    fullRoast: "\(food.name) pushed fat \(Int(fatOverage.rounded()))g over target. The plan is still there, unfortunately for your snack logic."
                ),
                severity: .warning
            )
        }

        let calorieRatio = plan.calorieTarget > 0 ? progress.calories / plan.calorieTarget : 0
        let proteinRatio = plan.proteinGoal > 0 ? progress.protein / plan.proteinGoal : 0
        if calorieRatio >= 0.65 && proteinRatio < 0.45 && food.protein < 10 {
            return CoachMessage(
                title: toned(
                    mild: "Protein Gap",
                    spicy: "Where Is The Protein?",
                    fullRoast: "Where Is The Protein?"
                ),
                body: toned(
                    mild: "Calories are climbing, but protein is still behind. The next log needs to do actual work.",
                    spicy: "Calories are climbing while protein is missing. Impressive commitment to making the hard part harder.",
                    fullRoast: "Calories are climbing while protein is missing. Impressive commitment to making the hard part harder."
                ),
                severity: .warning
            )
        }

        return foodLoggedMessage(food: food, dailyGoal: plan.calorieTarget)
    }

    func missedWorkoutMessage() -> CoachMessage {
        CoachMessage(
            title: toned(
                mild: "Workout Check",
                spicy: "Gym Check",
                fullRoast: "Gym Check"
            ),
            body: toned(
                mild: "No workout logged yet. There is still time to get a useful session or a solid walk in.",
                spicy: "Are you too comfortable to train today? There is still time. Get up and go move something besides your thumb.",
                fullRoast: "Are you too comfortable to train today? There is still time. Get up and go move something besides your thumb.",
                fullRoastNoBodyShame: "No workout logged yet. There is still time. Get up and go move something besides your thumb."
            ),
            severity: .roast
        )
    }

    func workoutReminderMessage(summary: ActivityDailySummary, plan: FitnessPlan?) -> CoachMessage {
        guard settings.enabled else {
            return CoachMessage(
                title: "Workout Check",
                body: "Coach is muted, but the plan is still sitting there judging quietly.",
                severity: .warning
            )
        }

        if summary.completedWorkoutToday && summary.steps >= summary.stepGoal {
            return CoachMessage(
                title: toned(
                    mild: "Workout Handled",
                    spicy: "Fine, You Did It",
                    fullRoast: "Fine, You Did It"
                ),
                body: toned(
                    mild: "Workout and steps are handled today. Keep food honest and do not improvise yourself into chaos.",
                    spicy: "Workout and steps are handled. Annoyingly responsible. Keep food honest and do not ruin the evidence.",
                    fullRoast: "Workout and steps are handled. Annoyingly responsible. Keep food honest and do not ruin the evidence."
                ),
                severity: .praise
            )
        }

        if summary.completedWorkoutToday {
            return CoachMessage(
                title: toned(
                    mild: "Finish Steps",
                    spicy: "Do Not Coast",
                    fullRoast: "Do Not Coast"
                ),
                body: toned(
                    mild: "Workout is logged. Finish the step goal so the day actually matches the plan.",
                    spicy: "Workout is logged. Now finish the step goal before you start acting like one gym visit solved everything.",
                    fullRoast: "Workout is logged. Now finish the step goal before you start acting like one gym visit solved everything."
                ),
                severity: .warning
            )
        }

        if summary.steps >= summary.stepGoal {
            return CoachMessage(
                title: toned(
                    mild: "Workout Still Open",
                    spicy: "Steps Are Not A Workout",
                    fullRoast: "Steps Are Not A Workout"
                ),
                body: toned(
                    mild: "Step goal is done, but no workout is logged. Get a useful session in if today is a training day.",
                    spicy: "Steps are done, cute. No workout is logged. Go train if today is supposed to count.",
                    fullRoast: "Steps are done, cute. No workout is logged. Go train if today is supposed to count."
                ),
                severity: .warning
            )
        }

        if let plan {
            return CoachMessage(
                title: toned(
                    mild: "Training Reminder",
                    spicy: "Plan Reminder",
                    fullRoast: "Plan Reminder"
                ),
                body: toned(
                    mild: "No workout logged yet. Your plan calls for \(plan.trainingDaysPerWeek) training days and \(plan.stepGoal) steps. Move now.",
                    spicy: "No workout logged yet. The plan says \(plan.trainingDaysPerWeek) training days and \(plan.stepGoal) steps, not vibes and excuses.",
                    fullRoast: "No workout logged yet. The plan says \(plan.trainingDaysPerWeek) training days and \(plan.stepGoal) steps, not vibes and excuses."
                ),
                severity: .roast
            )
        }

        return missedWorkoutMessage()
    }

    func activityMessage(summary: ActivityDailySummary) -> CoachMessage {
        guard settings.enabled else {
            return CoachMessage(
                title: "Activity",
                body: "Steps, workouts, and gym visits are connected. The coach is muted, but the numbers are not.",
                severity: .warning
            )
        }

        if summary.completedWorkoutToday && summary.steps >= summary.stepGoal {
            return CoachMessage(
                title: toned(
                    mild: "Strong Day",
                    spicy: "Annoyingly Competent",
                    fullRoast: "Annoyingly Competent"
                ),
                body: toned(
                    mild: "Workout handled and steps hit. That is exactly the kind of day that moves the needle.",
                    spicy: "Workout handled and steps hit. The app has no notes, which is deeply inconvenient for the roast department.",
                    fullRoast: "Workout handled and steps hit. The app has no notes, which is deeply inconvenient for the roast department."
                ),
                severity: .praise
            )
        }

        if summary.completedWorkoutToday {
            return CoachMessage(
                title: "Workout Logged",
                body: toned(
                    mild: "Training is logged. Finish the steps so the day matches the plan.",
                    spicy: "Fine, you trained. Now finish the steps so this does not become a decorative fitness app.",
                    fullRoast: "Fine, you trained. Now finish the steps so this does not become a decorative fitness app."
                ),
                severity: .praise
            )
        }

        if summary.isBehindStepPace {
            return CoachMessage(
                title: toned(
                    mild: "Step Pace",
                    spicy: "Move Your Feet",
                    fullRoast: "Move Your Feet"
                ),
                body: toned(
                    mild: "Your step count is behind pace. Stand up and bank a short walk now.",
                    spicy: "Your step count is dragging. Stand up, walk around, and give your watch something useful to report.",
                    fullRoast: "Your step count is dragging. Stand up, walk around, and give your watch something useful to report."
                ),
                severity: .roast
            )
        }

        return missedWorkoutMessage()
    }

    func planMessage(plan: FitnessPlan?) -> CoachMessage {
        guard let plan else {
            return CoachMessage(
                title: "No Plan, No Alibi",
                body: "Build a meal and workout plan so the app has something specific to yell about.",
                severity: .warning
            )
        }

        return CoachMessage(
            title: "Plan Locked",
            body: "\(Int(plan.calorieTarget)) calories, \(Int(plan.proteinGoal))g protein, \(plan.trainingDaysPerWeek) workouts, and \(plan.stepGoal) steps. Simple enough to follow, inconvenient enough to work.",
            severity: .praise
        )
    }

    private func isWithinActiveHours(now: Date = Date()) -> Bool {
        let hour = Calendar.current.component(.hour, from: now)
        if settings.activeStartHour <= settings.activeEndHour {
            return hour >= settings.activeStartHour && hour < settings.activeEndHour
        }
        return hour >= settings.activeStartHour || hour < settings.activeEndHour
    }

    private func toned(
        mild: String,
        spicy: String,
        fullRoast: String,
        fullRoastNoBodyShame: String? = nil
    ) -> String {
        switch settings.severity {
        case .mild:
            return mild
        case .spicy:
            return spicy
        case .fullRoast:
            if settings.allowExplicitBodyShame {
                return fullRoast
            }
            return fullRoastNoBodyShame ?? spicy
        }
    }
}

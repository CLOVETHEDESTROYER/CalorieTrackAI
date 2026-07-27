import SwiftUI

struct PlanBuilderView: View {
    @ObservedObject private var planService = FitnessPlanService.shared
    @ObservedObject private var coachService = CoachMessageService.shared

    @State private var user = User(
        name: "User",
        age: 25,
        weight: 185,
        height: 70,
        activityLevel: .lightlyActive,
        goalType: .loseWeight,
        dailyCalorieGoal: 2000,
        weightUnit: .lb,
        heightUnit: .inch,
        weeklyWeightChange: -1,
        gender: .male
    )
    @State private var trainingDaysPerWeek = 4
    @State private var mealStyle: MealPlanStyle = .balanced

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                MFTPageHeader(
                    kicker: "Built for the week",
                    title: "Your plan.",
                    subtitle: "Food targets and training days in one place. Adjust it, then do the work."
                )

                CoachCalloutView(message: coachService.planMessage(plan: planService.currentPlan))

                plannerControls

                if let plan = planService.currentPlan {
                    planSummary(plan)
                    mealPlan(plan)
                    workoutPlan(plan)
                } else {
                    emptyPlanCard
                }
            }
            .padding()
        }
        .background(MFTTheme.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .tint(MFTTheme.accent)
        .mftPageChrome()
        .task {
            loadProfile()
            await planService.refreshFromServer()
            if planService.currentPlan == nil {
                generatePlan()
            }
        }
    }

    private var plannerControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Plan Builder")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 8) {
                Text("Meal Style")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("Meal Style", selection: $mealStyle) {
                    ForEach(MealPlanStyle.allCases, id: \.self) { style in
                        Text(style.pickerTitle).tag(style)
                    }
                }
                .pickerStyle(.segmented)

                Text(mealStyle.guidance)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Stepper(value: $trainingDaysPerWeek, in: 2...5) {
                HStack {
                    Text("Training Days")
                    Spacer()
                    Text("\(trainingDaysPerWeek)/week")
                        .fontWeight(.semibold)
                }
            }

            Button {
                generatePlan()
            } label: {
                Label("Regenerate Plan", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .glassCard(tint: .blue, cornerRadius: 12)
        .glassBorder(tint: .blue, cornerRadius: 12)
    }

    private var emptyPlanCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No plan yet")
                .font(.headline)
            Text("Tap regenerate and give the coach a target to judge you against.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .glassCard(tint: .orange, cornerRadius: 12)
    }

    private func planSummary(_ plan: FitnessPlan) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Daily Targets")
                .font(.headline)
                .fontWeight(.semibold)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                metricTile("Calories", value: "\(Int(plan.calorieTarget))", tint: .blue)
                metricTile("Protein", value: "\(Int(plan.proteinGoal))g", tint: .green)
                metricTile("Carbs", value: "\(Int(plan.carbsGoal))g", tint: .orange)
                metricTile("Fat", value: "\(Int(plan.fatGoal))g", tint: .purple)
                metricTile("Steps", value: "\(plan.stepGoal)", tint: .yellow)
                metricTile("Workouts", value: "\(plan.trainingDaysPerWeek)/wk", tint: .red)
            }

            Text(plan.coachNote)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if mealStyle == .glpSupport {
                Label("GLP-support meals are nutrition structure only. Medication, peptide, dosing, and symptom decisions belong with a licensed clinician.", systemImage: "cross.case.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .glassCard(tint: .neutral, cornerRadius: 12)
    }

    private func metricTile(_ title: String, value: String, tint: GlassTint) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.black)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
        .padding(10)
        .glassCard(tint: tint, cornerRadius: 10)
    }

    private func mealPlan(_ plan: FitnessPlan) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Meal Rotation")
                .font(.headline)
                .fontWeight(.semibold)

            ForEach(plan.meals) { day in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(day.title)
                            .font(.subheadline)
                            .fontWeight(.bold)
                        Spacer()
                        Text("\(Int(day.calorieTarget)) cal")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    ForEach(day.meals) { meal in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(meal.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("\(Int(meal.calories)) cal | P \(Int(meal.protein))g | C \(Int(meal.carbs))g | F \(Int(meal.fat))g")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(meal.notes)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 6)
                    }
                }
                .padding()
                .glassCard(tint: .green, cornerRadius: 12)
            }
        }
    }

    private func workoutPlan(_ plan: FitnessPlan) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Workout Split")
                .font(.headline)
                .fontWeight(.semibold)

            ForEach(plan.workouts) { day in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(day.dayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(day.focus)
                                .font(.subheadline)
                                .fontWeight(.bold)
                        }

                        Spacer()

                        Text("\(day.estimatedMinutes) min")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    ForEach(day.exercises) { exercise in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(exercise.sets)x")
                                .font(.caption)
                                .fontWeight(.black)
                                .foregroundColor(MFTTheme.accent)
                                .frame(width: 28, alignment: .leading)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(exercise.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("\(exercise.reps) | \(exercise.notes)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Label(day.finisher, systemImage: "flag.checkered")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let completionTarget = day.completionTarget, !completionTarget.isEmpty {
                        Label(completionTarget, systemImage: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let progression = day.progression, !progression.isEmpty {
                        Label(progression, systemImage: "chart.line.uptrend.xyaxis")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding()
                .glassCard(tint: .orange, cornerRadius: 12)
            }
        }
    }

    private func loadProfile() {
        if let savedUser = UserService.shared.getCurrentUserSync() {
            user = savedUser
        }
    }

    private func generatePlan() {
        loadProfile()
        user.dailyCalorieGoal = UserService.shared.calculateDailyCalorieGoal(for: user)
        _ = planService.generatePlan(
            for: user,
            trainingDaysPerWeek: trainingDaysPerWeek,
            mealStyle: mealStyle
        )
    }
}

#Preview {
    NavigationView {
        PlanBuilderView()
    }
}

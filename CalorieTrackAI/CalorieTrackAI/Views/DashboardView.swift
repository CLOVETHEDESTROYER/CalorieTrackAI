import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @ObservedObject private var coachService = CoachMessageService.shared
    @State private var expandedMealSectionIDs: Set<String> = []

    var body: some View {
        NavigationView {
            ZStack {
                // Prominent glass background for iOS 18+
                if #available(iOS 18.0, *) {
                    LinearGradient(
                        colors: [.blue.opacity(0.2), .purple.opacity(0.1), .green.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                }

            ScrollView {
                VStack(spacing: 20) {
                    if !viewModel.isLoading {
                        CoachCalloutView(
                            message: coachService.dashboardMessage(
                                consumedCalories: viewModel.consumedCalories,
                                dailyGoal: viewModel.dailyGoal,
                                protein: viewModel.protein,
                                proteinGoal: viewModel.proteinGoal
                            )
                        )
                    }

                    commandCenterCard

                    if viewModel.shouldShowSetupChecklist {
                        setupChecklistCard
                    }
                    trainerBriefingCard

                    // Macros Summary
                    if !viewModel.isLoading {
                        MacrosView(
                            protein: viewModel.protein,
                            carbs: viewModel.carbs,
                            fat: viewModel.fat,
                            proteinGoal: viewModel.proteinGoal,
                            carbsGoal: viewModel.carbsGoal,
                            fatGoal: viewModel.fatGoal
                        )
                    }

                    dailyMealBreakdownCard

                    // Recent Foods
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Latest Confessions")
                            .font(.headline)
                            .fontWeight(.semibold)

                        if viewModel.isLoading {
                            ProgressView("Loading...")
                                .frame(maxWidth: .infinity)
                        } else if viewModel.recentFoods.isEmpty {
                            Text("Nothing logged yet. Either you are fasting or lying to the app.")
                                .foregroundColor(.secondary)
                                .padding(.vertical)
                        } else {
                            ForEach(viewModel.recentFoods.prefix(3)) { food in
                                FoodRowView(food: food)
                            }
                        }
                    }
                    .padding()
                    .glassCard(tint: .neutral, cornerRadius: 12)
                }
                .padding()
            }
            }
            .navigationTitle("My Fatness Tracker")
            .refreshable {
                await viewModel.loadTodaysData()
            }
            .task {
                await viewModel.loadTodaysData()
            }
            .onReceive(NotificationCenter.default.publisher(for: .foodLogDidChange)) { _ in
                Task {
                    await viewModel.loadTodaysData()
                }
            }
            .onAppear {
                // Refresh user's daily goal when view appears
                Task {
                    await viewModel.loadUserDailyGoal()
                }
            }
        }
    }

    private var commandCenterCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today Command Center")
                        .font(.headline)
                        .fontWeight(.black)

                    TimelineView(.periodic(from: Date(), by: 60)) { timeline in
                        Text(viewModel.accountabilityDaySubtitle(now: timeline.date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()

                CircularProgressView(
                    progress: viewModel.calorieProgress,
                    color: viewModel.isOverGoal ? .red : .blue
                )
                .frame(width: 58, height: 58)
            }

            if viewModel.isLoading {
                ProgressView("Loading today's receipts...")
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 10) {
                    dashboardMetricTile(
                        title: "Calories",
                        value: viewModel.calorieBudgetDisplay,
                        subtitle: viewModel.calorieRemainingDisplay,
                        tint: viewModel.isOverGoal ? .red : .blue
                    )

                    dashboardMetricTile(
                        title: "Weight",
                        value: viewModel.currentWeightDisplay,
                        subtitle: "current",
                        tint: .green
                    )

                    dashboardMetricTile(
                        title: "LBM",
                        value: viewModel.leanBodyMassDisplay,
                        subtitle: "estimate",
                        tint: .orange
                    )
                }

                nextActionLink(for: viewModel.dashboardNextAction)
            }
        }
        .padding()
        .glassCard(tint: .blue, cornerRadius: 12)
        .glassBorder(tint: .blue, cornerRadius: 12)
    }

    @ViewBuilder
    private func nextActionLink(for action: DashboardNextAction) -> some View {
        NavigationLink {
            switch action.kind {
            case .buildPlan:
                PlanBuilderView()
            case .connectActivity, .saveGym, .move:
                ActivityCoachView()
            case .logFood, .review:
                LogFoodView()
            }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: action.icon)
                    .font(.headline)
                    .foregroundColor(nextActionTint(for: action.kind))
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text(action.title)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    Text(action.detail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .padding(.top, 3)
            }
            .padding(10)
            .background(nextActionTint(for: action.kind).opacity(0.08))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    private var setupChecklistCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: viewModel.setupCompletedCount == viewModel.setupTotalCount ? "checklist.checked" : "checklist.unchecked")
                    .font(.title2)
                    .foregroundColor(viewModel.setupCompletedCount == viewModel.setupTotalCount ? .green : .blue)
                    .frame(width: 34, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Accountability Setup")
                        .font(.headline)
                        .fontWeight(.black)

                    Text(viewModel.setupSummary)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            ProgressView(value: min(viewModel.setupProgress, 1.0))
                .tint(viewModel.setupCompletedCount == viewModel.setupTotalCount ? .green : .blue)

            VStack(spacing: 10) {
                if viewModel.currentPlan == nil {
                    NavigationLink {
                        PlanBuilderView()
                    } label: {
                        setupChecklistRow(
                            title: "Meal + workout plan",
                            detail: "Build calorie, macro, step, and workout targets.",
                            icon: "list.clipboard.fill",
                            isComplete: false
                        )
                    }
                    .buttonStyle(.plain)
                }

                if !viewModel.hasRequestedHealthAccess {
                    NavigationLink {
                        ActivityCoachView()
                    } label: {
                        setupChecklistRow(
                            title: "Apple Health + Watch",
                            detail: "Connect Health so steps, workouts, and exercise minutes count.",
                            icon: "heart.text.square.fill",
                            isComplete: false
                        )
                    }
                    .buttonStyle(.plain)
                }

                if viewModel.savedGymCount == 0 {
                    NavigationLink {
                        ActivityCoachView()
                    } label: {
                        setupChecklistRow(
                            title: "Gym check-ins",
                            detail: "Save a gym to unlock manual and geofence receipts.",
                            icon: "location.fill",
                            isComplete: false
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .glassCard(tint: .blue, cornerRadius: 12)
        .glassBorder(tint: .blue, cornerRadius: 12)
    }

    private func setupChecklistRow(title: String, detail: String, icon: String, isComplete: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : icon)
                .font(.subheadline)
                .foregroundColor(isComplete ? .green : .blue)
                .frame(width: 22, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(10)
    }

    private var trainerBriefingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: viewModel.activitySummary.completedWorkoutToday ? "checkmark.seal.fill" : "figure.walk.circle.fill")
                    .font(.title2)
                    .foregroundColor(viewModel.activitySummary.completedWorkoutToday ? .green : .orange)
                    .frame(width: 34, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.trainerBriefingTitle)
                        .font(.headline)
                        .fontWeight(.black)

                    Text(viewModel.trainerBriefingBody)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                dashboardMetricTile(
                    title: "Steps",
                    value: "\(viewModel.activitySummary.steps)",
                    subtitle: "of \(viewModel.activitySummary.stepGoal)",
                    tint: viewModel.activitySummary.steps >= viewModel.activitySummary.stepGoal ? .green : .orange
                )

                dashboardMetricTile(
                    title: "Workout",
                    value: viewModel.activitySummary.completedWorkoutToday ? "Done" : "Open",
                    subtitle: viewModel.todaysWorkoutTargetDisplay,
                    tint: viewModel.activitySummary.completedWorkoutToday ? .green : .red
                )

                dashboardMetricTile(
                    title: "Meals",
                    value: "\(viewModel.loggedMealSectionCount)",
                    subtitle: "buckets logged",
                    tint: viewModel.loggedMealSectionCount > 0 ? .green : .orange
                )
            }

            ProgressView(value: min(viewModel.stepProgress, 1.0))
                .tint(viewModel.activitySummary.steps >= viewModel.activitySummary.stepGoal ? .green : .orange)

            HStack(spacing: 10) {
                NavigationLink {
                    ActivityCoachView()
                } label: {
                    Label("Activity", systemImage: "figure.walk")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                NavigationLink {
                    LogFoodView()
                } label: {
                    Label("Log Food", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .glassCard(tint: .orange, cornerRadius: 12)
        .glassBorder(tint: .orange, cornerRadius: 12)
    }

    private var dailyMealBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Today by Meal")
                        .font(.headline)
                        .fontWeight(.semibold)

                    TimelineView(.periodic(from: Date(), by: 60)) { timeline in
                        Text(viewModel.mealResetSubtitle(now: timeline.date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()

                Text("\(Int(viewModel.consumedCalories))/\(Int(viewModel.dailyGoal)) cal")
                    .font(.subheadline)
                    .fontWeight(.black)
                    .foregroundColor(viewModel.isOverGoal ? .red : .primary)
            }

            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: min(viewModel.calorieProgress, 1.0))
                    .tint(viewModel.isOverGoal ? .red : MFTTheme.accent)

                Text(viewModel.loggedMealSummary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if viewModel.mealSections.allSatisfy({ $0.foods.isEmpty }) {
                Text("No meals logged today. The app cannot shame what it cannot see.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            }

            ForEach(viewModel.mealSections) { section in
                mealSectionRow(section, isExpanded: isMealSectionExpanded(section))
            }

            NavigationLink {
                LogFoodView()
            } label: {
                Label("Log food for the right meal", systemImage: "plus.circle.fill")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(MFTTheme.subduedLime)
                    .foregroundColor(MFTTheme.accent)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)

            if MealTimeClassifier.mealType() == .snack {
                Label("Outside meal windows, new food logs default to Snack. After 9 PM, maybe try sleeping instead of negotiating with the fridge.", systemImage: "moon.zzz.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(10)
                    .background(Color.orange.opacity(0.08))
                    .cornerRadius(10)
            }
        }
        .padding()
        .glassCard(tint: .neutral, cornerRadius: 12)
    }

    private func mealSectionRow(_ section: DailyMealSection, isExpanded: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: section.mealType.icon)
                    .foregroundColor(section.foods.isEmpty ? .secondary : .blue)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(section.mealType.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(mealWindowText(for: section.mealType))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(section.totalCalories)) cal")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(section.foods.isEmpty ? .secondary : .primary)

                    Text(section.itemCount == 1 ? "1 item" : "\(section.itemCount) items")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if section.foods.isEmpty {
                Text("Nothing logged")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(section.foodPreviewText())
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)

                    Text(section.macroSummaryText)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if section.remainingItemCount() > 0 {
                        Text("+\(section.remainingItemCount()) more logged item\(section.remainingItemCount() == 1 ? "" : "s")")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(MFTTheme.accent)
                    }

                    if isExpanded {
                        VStack(spacing: 6) {
                            ForEach(section.foods) { food in
                                mealFoodReceiptRow(food)
                            }
                        }
                        .padding(8)
                        .background(Color.primary.opacity(0.035))
                        .cornerRadius(8)
                    }

                    Button {
                        toggleMealSection(section)
                    } label: {
                        Label(
                            isExpanded ? "Hide receipts" : "Show all receipts",
                            systemImage: isExpanded ? "chevron.up.circle.fill" : "list.bullet.rectangle.fill"
                        )
                        .font(.caption)
                        .fontWeight(.semibold)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(MFTTheme.accent)
                }
            }
        }
        .padding(10)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(10)
    }

    private func mealFoodReceiptRow(_ food: Food) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(food.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)

                Text("P \(Int(food.protein))g | C \(Int(food.carbs))g | F \(Int(food.fat))g")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 8)

            Text("\(Int(food.calories)) cal")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private func isMealSectionExpanded(_ section: DailyMealSection) -> Bool {
        expandedMealSectionIDs.contains(section.id)
    }

    private func toggleMealSection(_ section: DailyMealSection) {
        if expandedMealSectionIDs.contains(section.id) {
            expandedMealSectionIDs.remove(section.id)
        } else {
            expandedMealSectionIDs.insert(section.id)
        }
    }

    private func mealWindowText(for mealType: MealEntry.MealType) -> String {
        switch mealType {
        case .breakfast:
            return "5-11 AM"
        case .lunch:
            return "11 AM-3 PM"
        case .dinner:
            return "4-9 PM"
        case .snack:
            return "Outside meal windows"
        }
    }

    private func dashboardMetricTile(title: String, value: String, subtitle: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.title3)
                .fontWeight(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
        .padding(10)
        .background(tint.opacity(0.09))
        .cornerRadius(10)
    }

    private func nextActionTint(for kind: DashboardNextAction.Kind) -> Color {
        switch kind {
        case .buildPlan, .connectActivity:
            return .blue
        case .saveGym, .move:
            return .orange
        case .logFood:
            return .green
        case .review:
            return .purple
        }
    }
}

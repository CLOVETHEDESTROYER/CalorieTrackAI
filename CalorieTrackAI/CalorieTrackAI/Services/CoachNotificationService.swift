import Foundation
import UserNotifications

@MainActor
final class CoachNotificationService: ObservableObject {
    static let shared = CoachNotificationService()

    @Published private(set) var settings: CoachNotificationSettings
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let settingsKey = "CoachNotificationSettings"
    private let center = UNUserNotificationCenter.current()
    private let supabaseService = SupabaseService.shared
    private let coachMessageService = CoachMessageService.shared
    private let healthKitService = HealthKitService.shared
    private let fitnessPlanService = FitnessPlanService.shared
    private let peptideLogStore = PeptideLogStore.shared

    private enum NotificationID {
        static let workout = "coach.workout.daily"
        static let breakfast = "coach.meal.breakfast"
        static let lunch = "coach.meal.lunch"
        static let dinner = "coach.meal.dinner"
        static let weekly = "coach.weekly.report"
        static let stepGoal = CoachNotificationPlanner.stepGoal
        static let gym = CoachNotificationPlanner.gymCheckIn
        static let lateEatingCutoff = CoachNotificationPlanner.lateEatingCutoff
        static let movementPrefix = CoachNotificationPlanner.movementPrefix
        static let peptidePrefix = "coach.peptide."

        static let staticIDs = [workout, breakfast, lunch, dinner, weekly, stepGoal, gym, lateEatingCutoff]
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(CoachNotificationSettings.self, from: data) {
            settings = decoded
        } else {
            settings = .defaults
        }

        Task {
            await refreshAuthorizationStatus()
        }
    }

    func refreshAuthorizationStatus() async {
        let notificationSettings = await center.notificationSettings()
        authorizationStatus = notificationSettings.authorizationStatus
    }

    func requestAuthorizationAndSchedule() async {
        do {
            _ = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            await refreshAuthorizationStatus()
            await rescheduleNotifications()
            await RemoteNotificationService.shared.registerIfAvailable()
        } catch {
            await refreshAuthorizationStatus()
        }
    }

    func updateSettings(_ newSettings: CoachNotificationSettings) {
        settings = newSettings
        saveLocal(newSettings)

        Task {
            await syncSettings(newSettings)
            await rescheduleNotifications()
        }
    }

    func resetLocalSettings() async {
        settings = .defaults
        saveLocal(settings)
        await rescheduleNotifications()
    }

    func refreshFromServer() async {
        guard supabaseService.isAuthenticated else {
            return
        }

        do {
            if let remoteSettings = try await supabaseService.getCoachNotificationSettings() {
                settings = remoteSettings
                saveLocal(remoteSettings)
                await rescheduleNotifications()
            } else {
                await syncSettings(settings)
            }
        } catch {
            #if DEBUG
            print("Coach notification settings refresh failed: \(error)")
            #endif
        }
    }

    func rescheduleNotifications() async {
        await removeManagedPendingNotifications()

        guard authorizationStatus == .authorized || authorizationStatus == .provisional else {
            return
        }

        let toneSettings = coachMessageService.settings
        let activitySummary = healthKitService.lastSummary

        if settings.dailyWorkoutReminder {
            let reminder = workoutReminderPreview()
            schedule(
                id: NotificationID.workout,
                title: reminder.title,
                body: reminder.body,
                components: settings.workoutTime,
                repeats: true
            )

            let activityItems = CoachNotificationPlanner.activityAccountabilityItems(
                summary: activitySummary,
                settings: settings,
                toneSettings: toneSettings
            )
            schedule(activityItems)

            let movementItems = CoachNotificationPlanner.movementReminderItems(
                settings: settings,
                toneSettings: toneSettings,
                lastMovementAt: healthKitService.lastStepMovementAt
            )
            schedule(movementItems)
        }

        if settings.mealReminders {
            let loggedMeals = await loggedMealTypesForToday()
            let mealItems = CoachNotificationPlanner.mealReminderItems(
                loggedMealTypes: loggedMeals,
                settings: settings,
                toneSettings: toneSettings
            )
            schedule(mealItems)

            if let cutoffItem = CoachNotificationPlanner.lateEatingCutoffItem(
                settings: settings,
                toneSettings: toneSettings
            ) {
                schedule([cutoffItem])
            }
        }

        if settings.weeklyReports {
            schedule(
                id: NotificationID.weekly,
                title: "Weekly Damage Report",
                body: weeklyReportBody(),
                components: settings.weeklyReportTime,
                repeats: true
            )
        }

        if settings.peptideReminders {
            schedulePeptideReminders()
        }
    }

    func workoutReminderPreview() -> CoachMessage {
        coachMessageService.workoutReminderMessage(
            summary: healthKitService.lastSummary,
            plan: fitnessPlanService.currentPlan
        )
    }

    func peptideReminderPreview(for log: PeptideLog) -> CoachMessage {
        let siteText = log.site.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? ""
            : " Site/note: \(log.site.trimmingCharacters(in: .whitespacesAndNewlines))."

        return CoachMessage(
            title: "Planned Log Reminder",
            body: "Your planned \(log.peptideName) log is due. Check your clinician, pharmacy, or product label instructions, then record what happened.\(siteText)",
            severity: .warning
        )
    }

    func sendImmediateGymCheckInReceipt(gymName: String) async {
        await refreshAuthorizationStatus()
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else {
            return
        }

        let copy = CoachNotificationPlanner.gymCheckInReceiptCopy(
            gymName: gymName,
            toneSettings: coachMessageService.settings
        )
        let content = UNMutableNotificationContent()
        content.title = copy.title
        content.body = copy.body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "coach.gym.receipt.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }

    private func weeklyReportBody() -> String {
        let summary = healthKitService.lastSummary
        let plan = fitnessPlanService.currentPlan
        let steps = "\(summary.steps)/\(summary.stepGoal) steps today"

        if let plan {
            return "\(steps). Plan target: \(Int(plan.calorieTarget)) calories, \(Int(plan.proteinGoal))g protein, \(plan.trainingDaysPerWeek) workouts. Review the receipts before excuses get creative."
        }

        return "\(steps). No active plan found. Build one, then review the week like someone who wants evidence instead of vibes."
    }

    private func schedulePeptideReminders(now: Date = Date()) {
        for log in peptideLogStore.pendingReminderLogs(now: now) {
            guard let scheduledAt = log.scheduledAt else {
                continue
            }

            let reminder = peptideReminderPreview(for: log)
            schedule(
                id: NotificationID.peptidePrefix + log.id.uuidString,
                title: reminder.title,
                body: reminder.body,
                components: Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: scheduledAt
                ),
                repeats: false
            )
        }
    }

    private func removeManagedPendingNotifications() async {
        let pendingRequests = await center.pendingNotificationRequests()
        let managedIDs = pendingRequests.map(\.identifier).filter { id in
            NotificationID.staticIDs.contains(id)
                || id.hasPrefix(NotificationID.peptidePrefix)
                || id.hasPrefix(NotificationID.movementPrefix)
        }

        if !managedIDs.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: managedIDs)
        }
    }

    private func schedule(
        id: String,
        title: String,
        body: String,
        components: DateComponents,
        repeats: Bool
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }

    private func schedule(_ items: [CoachNotificationPlanItem]) {
        for item in items {
            schedule(
                id: item.id,
                title: item.title,
                body: item.body,
                components: item.components,
                repeats: item.repeats
            )
        }
    }

    private func loggedMealTypesForToday() async -> Set<MealEntry.MealType> {
        if supabaseService.isAuthenticated,
           let entries = try? await FoodService.shared.getMealEntriesForDate(Date()) {
            return Set(entries.map(\.meal_type))
        }

        let foods = FoodService.shared.getFoodsForDateOffline(Date())
        return Set(foods.map { $0.mealType ?? MealTimeClassifier.mealType(for: $0.dateLogged) })
    }

    private func saveLocal(_ newSettings: CoachNotificationSettings) {
        if let data = try? JSONEncoder().encode(newSettings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }

    private func syncSettings(_ newSettings: CoachNotificationSettings) async {
        guard supabaseService.isAuthenticated else {
            return
        }

        do {
            let savedSettings = try await supabaseService.saveCoachNotificationSettings(newSettings)
            settings = savedSettings
            saveLocal(savedSettings)
        } catch {
            #if DEBUG
            print("Coach notification settings sync failed: \(error)")
            #endif
        }
    }
}

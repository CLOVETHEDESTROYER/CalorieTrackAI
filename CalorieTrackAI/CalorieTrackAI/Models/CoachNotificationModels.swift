import Foundation

struct CoachNotificationSettings: Codable, Equatable {
    var dailyWorkoutReminder: Bool
    var mealReminders: Bool
    var weeklyReports: Bool
    var peptideReminders: Bool
    var socialNotifications: Bool
    var breakfastTime: DateComponents
    var lunchTime: DateComponents
    var dinnerTime: DateComponents
    var workoutTime: DateComponents
    var weeklyReportTime: DateComponents

    static let defaults = CoachNotificationSettings(
        dailyWorkoutReminder: true,
        mealReminders: true,
        weeklyReports: true,
        peptideReminders: true,
        socialNotifications: true,
        breakfastTime: DateComponents(hour: 8, minute: 0),
        lunchTime: DateComponents(hour: 12, minute: 30),
        dinnerTime: DateComponents(hour: 18, minute: 30),
        workoutTime: DateComponents(hour: 18, minute: 0),
        weeklyReportTime: DateComponents(hour: 8, minute: 30, weekday: 2)
    )

    enum CodingKeys: String, CodingKey {
        case dailyWorkoutReminder
        case mealReminders
        case weeklyReports
        case peptideReminders
        case socialNotifications
        case breakfastTime
        case lunchTime
        case dinnerTime
        case workoutTime
        case weeklyReportTime
    }

    init(
        dailyWorkoutReminder: Bool,
        mealReminders: Bool,
        weeklyReports: Bool,
        peptideReminders: Bool,
        socialNotifications: Bool,
        breakfastTime: DateComponents,
        lunchTime: DateComponents,
        dinnerTime: DateComponents,
        workoutTime: DateComponents,
        weeklyReportTime: DateComponents
    ) {
        self.dailyWorkoutReminder = dailyWorkoutReminder
        self.mealReminders = mealReminders
        self.weeklyReports = weeklyReports
        self.peptideReminders = peptideReminders
        self.socialNotifications = socialNotifications
        self.breakfastTime = breakfastTime
        self.lunchTime = lunchTime
        self.dinnerTime = dinnerTime
        self.workoutTime = workoutTime
        self.weeklyReportTime = weeklyReportTime
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dailyWorkoutReminder = try container.decode(Bool.self, forKey: .dailyWorkoutReminder)
        mealReminders = try container.decode(Bool.self, forKey: .mealReminders)
        weeklyReports = try container.decode(Bool.self, forKey: .weeklyReports)
        peptideReminders = try container.decodeIfPresent(Bool.self, forKey: .peptideReminders) ?? true
        socialNotifications = try container.decodeIfPresent(Bool.self, forKey: .socialNotifications) ?? true
        breakfastTime = try container.decode(DateComponents.self, forKey: .breakfastTime)
        lunchTime = try container.decode(DateComponents.self, forKey: .lunchTime)
        dinnerTime = try container.decode(DateComponents.self, forKey: .dinnerTime)
        workoutTime = try container.decode(DateComponents.self, forKey: .workoutTime)
        weeklyReportTime = try container.decode(DateComponents.self, forKey: .weeklyReportTime)
    }
}

struct CoachNotificationPlanItem: Equatable {
    var id: String
    var title: String
    var body: String
    var components: DateComponents
    var repeats: Bool
}

struct CoachNotificationCopy: Equatable {
    var title: String
    var body: String
}

enum CoachNotificationPlanner {
    private static let movementInactivityInterval: TimeInterval = 40 * 60
    private static let overdueMovementGraceInterval: TimeInterval = 60

    static let movementPrefix = "coach.movement."
    static let stepGoal = "coach.steps.goal"
    static let gymCheckIn = "coach.gym.checkin"
    static let breakfast = "coach.meal.breakfast"
    static let lunch = "coach.meal.lunch"
    static let dinner = "coach.meal.dinner"
    static let lateEatingCutoff = "coach.meal.lateCutoff"

    static func movementReminderItems(
        settings: CoachNotificationSettings,
        toneSettings: CoachToneSettings,
        lastMovementAt: Date? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [CoachNotificationPlanItem] {
        guard settings.dailyWorkoutReminder, toneSettings.enabled else { return [] }

        let activeStartHour = min(max(toneSettings.activeStartHour, 0), 23)
        let activeEndHour = min(max(toneSettings.activeEndHour, activeStartHour + 1), 24)
        let startOfDay = calendar.startOfDay(for: now)
        let activeEnd = calendar.date(byAdding: .hour, value: activeEndHour, to: startOfDay) ?? now
        let movementAnchor = lastMovementAt ?? now
        var nextFire = movementAnchor.addingTimeInterval(movementInactivityInterval)
        if nextFire <= now {
            nextFire = now.addingTimeInterval(overdueMovementGraceInterval)
        }

        let activeStart = calendar.date(byAdding: .hour, value: activeStartHour, to: startOfDay) ?? now
        if nextFire < activeStart {
            nextFire = activeStart
        }

        guard nextFire < activeEnd else { return [] }

        var items: [CoachNotificationPlanItem] = []
        var cursor = nextFire

        while cursor < activeEnd && items.count < 16 {
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: cursor)
            items.append(CoachNotificationPlanItem(
                id: movementPrefix + "\(items.count)",
                title: toned(
                    toneSettings,
                    mild: "Time To Move",
                    spicy: "Get Moving",
                    fullRoast: "Get Moving"
                ),
                body: toned(
                    toneSettings,
                    mild: "Stand up and take yourself for a walk. Future you can complain later.",
                    spicy: "Get your butt moving and stand up. Take yourself for a walk before the couch wins.",
                    fullRoast: "Get your butt moving and stand up. Take yourself for a walk before the couch wins."
                ),
                components: components,
                repeats: false
            ))
            cursor = cursor.addingTimeInterval(movementInactivityInterval)
        }

        return items
    }

    static func mealReminderItems(
        loggedMealTypes: Set<MealEntry.MealType>,
        settings: CoachNotificationSettings,
        toneSettings: CoachToneSettings,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [CoachNotificationPlanItem] {
        guard settings.mealReminders, toneSettings.enabled else { return [] }

        let meals: [(MealEntry.MealType, DateComponents, String)] = [
            (.breakfast, settings.breakfastTime, breakfast),
            (.lunch, settings.lunchTime, lunch),
            (.dinner, settings.dinnerTime, dinner)
        ]

        return meals.compactMap { mealType, time, id in
            guard !loggedMealTypes.contains(mealType),
                  let fireDate = accountabilityDate(for: time, now: now, calendar: calendar) else {
                return nil
            }

            return CoachNotificationPlanItem(
                id: id,
                title: "\(mealType.displayName) Receipts Missing",
                body: mealReminderBody(for: mealType, toneSettings: toneSettings),
                components: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
                repeats: false
            )
        }
    }

    static func lateEatingCutoffItem(
        settings: CoachNotificationSettings,
        toneSettings: CoachToneSettings,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> CoachNotificationPlanItem? {
        guard settings.mealReminders, toneSettings.enabled,
              let fireDate = accountabilityDate(for: DateComponents(hour: 21, minute: 0), now: now, calendar: calendar) else {
            return nil
        }

        return CoachNotificationPlanItem(
            id: lateEatingCutoff,
            title: toned(
                toneSettings,
                mild: "Kitchen Closed",
                spicy: "Kitchen Closed",
                fullRoast: "Kitchen Closed"
            ),
            body: toned(
                toneSettings,
                mild: "It is 9 PM. Log what you already ate, then stop auditioning for snack chaos.",
                spicy: "It is 9 PM. Kitchen is closed. Brush your teeth and stop negotiating with snacks.",
                fullRoast: "It is 9 PM. Kitchen is closed. Brush your teeth and stop negotiating with snacks."
            ),
            components: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
            repeats: false
        )
    }

    static func activityAccountabilityItems(
        summary: ActivityDailySummary,
        settings: CoachNotificationSettings,
        toneSettings: CoachToneSettings,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [CoachNotificationPlanItem] {
        guard settings.dailyWorkoutReminder, toneSettings.enabled else { return [] }

        var items: [CoachNotificationPlanItem] = []

        if summary.steps < summary.stepGoal,
           let fireDate = accountabilityDate(
            for: DateComponents(hour: max(toneSettings.activeEndHour - 1, toneSettings.activeStartHour), minute: 0),
            now: now,
            calendar: calendar
           ) {
            let remainingSteps = max(summary.stepGoal - summary.steps, 0)
            items.append(CoachNotificationPlanItem(
                id: stepGoal,
                title: "Step Goal Is Still Sitting There",
                body: toned(
                    toneSettings,
                    mild: "\(remainingSteps) steps left. Go take a walk and close the gap.",
                    spicy: "\(remainingSteps) steps left. Get up and walk like your goal is not decorative.",
                    fullRoast: "\(remainingSteps) steps left. Get up and walk like your goal is not decorative."
                ),
                components: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
                repeats: false
            ))
        }

        if summary.gymVisits.isEmpty && summary.workoutCount == 0,
           let fireDate = accountabilityDate(for: settings.workoutTime, now: now, calendar: calendar) {
            items.append(CoachNotificationPlanItem(
                id: gymCheckIn,
                title: "Gym Receipt Missing",
                body: toned(
                    toneSettings,
                    mild: "No gym visit or workout logged yet. Go move, then log the receipt.",
                    spicy: "No gym check-in and no workout logged. Get yourself to the gym or log the workout you keep pretending happened.",
                    fullRoast: "No gym check-in and no workout logged. Get yourself to the gym or log the workout you keep pretending happened."
                ),
                components: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
                repeats: false
            ))
        }

        return items
    }

    static func gymCheckInReceiptCopy(
        gymName: String,
        toneSettings: CoachToneSettings
    ) -> CoachNotificationCopy {
        CoachNotificationCopy(
            title: toned(
                toneSettings,
                mild: "Gym Check-In Logged",
                spicy: "Gym Receipt Captured",
                fullRoast: "Gym Receipt Captured"
            ),
            body: toned(
                toneSettings,
                mild: "You made it to \(gymName). Good. Now do the workout part too.",
                spicy: "Caught you at \(gymName). Nice. Now lift something before this becomes a parking-lot achievement.",
                fullRoast: "Caught you at \(gymName). Nice. Now lift something before this becomes a parking-lot achievement."
            )
        )
    }

    private static func mealReminderBody(
        for mealType: MealEntry.MealType,
        toneSettings: CoachToneSettings
    ) -> String {
        switch mealType {
        case .breakfast:
            return toned(
                toneSettings,
                mild: "Breakfast is not logged. Put the food in the app before your memory edits the portions.",
                spicy: "Breakfast is missing. Log it before your memory turns toast into a nutrition plan.",
                fullRoast: "Breakfast is missing. Log it before your memory turns toast into a nutrition plan."
            )
        case .lunch:
            return toned(
                toneSettings,
                mild: "Lunch needs a receipt. Log it and keep the day honest.",
                spicy: "Lunch is missing. Open the app and log it before the afternoon becomes snack chaos.",
                fullRoast: "Lunch is missing. Open the app and log it before the afternoon becomes snack chaos."
            )
        case .dinner:
            return toned(
                toneSettings,
                mild: "Dinner is not logged yet. Finish the day with actual numbers.",
                spicy: "Dinner is missing. Do not let the day end with mystery calories and wishful thinking.",
                fullRoast: "Dinner is missing. Do not let the day end with mystery calories and wishful thinking."
            )
        case .snack:
            return "Snack needs a receipt. Log it before it becomes folklore."
        }
    }

    private static func accountabilityDate(
        for time: DateComponents,
        now: Date,
        calendar: Calendar
    ) -> Date? {
        let today = calendar.startOfDay(for: now)
        var components = DateComponents()
        components.hour = time.hour ?? 8
        components.minute = time.minute ?? 0

        guard let scheduledToday = calendar.date(byAdding: components, to: today) else {
            return nil
        }

        if scheduledToday > now {
            return scheduledToday
        }

        let graceDate = now.addingTimeInterval(5 * 60)
        let activeEnd = calendar.date(byAdding: .hour, value: 23, to: today) ?? now
        return graceDate < activeEnd ? graceDate : nil
    }

    private static func toned(
        _ settings: CoachToneSettings,
        mild: String,
        spicy: String,
        fullRoast: String
    ) -> String {
        switch settings.severity {
        case .mild:
            return mild
        case .spicy:
            return spicy
        case .fullRoast:
            return settings.allowExplicitBodyShame ? fullRoast : spicy
        }
    }
}

struct CoachUserSettingsRecord: Codable, Equatable {
    var user_id: UUID
    var coach_enabled: Bool
    var severity: String
    var food_roast_threshold_percent: Double
    var active_start_hour: Int
    var active_end_hour: Int
    var allow_explicit_body_shame: Bool
    var daily_workout_reminder: Bool
    var meal_reminders: Bool
    var weekly_reports: Bool
    var peptide_reminders: Bool?
    var social_notifications: Bool?
    var breakfast_time: String
    var lunch_time: String
    var dinner_time: String
    var workout_time: String
    var weekly_report_weekday: Int
    var weekly_report_time: String
    var created_at: Date?
    var updated_at: Date?

    init(settings: CoachNotificationSettings, userId: UUID) {
        self.init(
            toneSettings: .defaultFullRoast,
            notificationSettings: settings,
            userId: userId
        )
    }

    init(
        toneSettings: CoachToneSettings,
        notificationSettings: CoachNotificationSettings,
        userId: UUID
    ) {
        user_id = userId
        coach_enabled = toneSettings.enabled
        severity = toneSettings.severity.rawValue
        food_roast_threshold_percent = toneSettings.foodRoastThresholdPercent
        active_start_hour = toneSettings.activeStartHour
        active_end_hour = toneSettings.activeEndHour
        allow_explicit_body_shame = toneSettings.allowExplicitBodyShame
        daily_workout_reminder = notificationSettings.dailyWorkoutReminder
        meal_reminders = notificationSettings.mealReminders
        weekly_reports = notificationSettings.weeklyReports
        peptide_reminders = notificationSettings.peptideReminders
        social_notifications = notificationSettings.socialNotifications
        breakfast_time = CoachTimeFormatter.string(from: notificationSettings.breakfastTime)
        lunch_time = CoachTimeFormatter.string(from: notificationSettings.lunchTime)
        dinner_time = CoachTimeFormatter.string(from: notificationSettings.dinnerTime)
        workout_time = CoachTimeFormatter.string(from: notificationSettings.workoutTime)
        weekly_report_weekday = notificationSettings.weeklyReportTime.weekday ?? 2
        weekly_report_time = CoachTimeFormatter.string(from: notificationSettings.weeklyReportTime)
        created_at = nil
        updated_at = nil
    }

    func toToneSettings() -> CoachToneSettings {
        CoachToneSettings(
            enabled: coach_enabled,
            severity: CoachToneSettings.Severity(rawValue: severity) ?? .fullRoast,
            foodRoastThresholdPercent: food_roast_threshold_percent,
            activeStartHour: active_start_hour,
            activeEndHour: active_end_hour,
            allowExplicitBodyShame: allow_explicit_body_shame
        )
    }

    func toNotificationSettings() -> CoachNotificationSettings {
        CoachNotificationSettings(
            dailyWorkoutReminder: daily_workout_reminder,
            mealReminders: meal_reminders,
            weeklyReports: weekly_reports,
            peptideReminders: peptide_reminders ?? true,
            socialNotifications: social_notifications ?? true,
            breakfastTime: CoachTimeFormatter.components(from: breakfast_time),
            lunchTime: CoachTimeFormatter.components(from: lunch_time),
            dinnerTime: CoachTimeFormatter.components(from: dinner_time),
            workoutTime: CoachTimeFormatter.components(from: workout_time),
            weeklyReportTime: CoachTimeFormatter.components(
                from: weekly_report_time,
                weekday: weekly_report_weekday
            )
        )
    }
}

enum CoachTimeFormatter {
    static func string(from components: DateComponents) -> String {
        let hour = components.hour ?? 8
        let minute = components.minute ?? 0
        return String(format: "%02d:%02d", hour, minute)
    }

    static func components(from time: String, weekday: Int? = nil) -> DateComponents {
        let pieces = time.split(separator: ":").compactMap { Int($0) }
        var components = DateComponents()
        components.hour = pieces.first ?? 8
        components.minute = pieces.dropFirst().first ?? 0
        components.weekday = weekday
        return components
    }
}

extension DateComponents {
    var timeDate: Date {
        Calendar.current.nextDate(
            after: Calendar.current.startOfDay(for: Date()),
            matching: self,
            matchingPolicy: .nextTime
        ) ?? Date()
    }

    init(timeDate: Date) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: timeDate)
        self.init(hour: components.hour ?? 8, minute: components.minute ?? 0)
    }
}

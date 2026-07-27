import Foundation

@MainActor
final class ManualWorkoutStore: ObservableObject {
    static let shared = ManualWorkoutStore()

    @Published private(set) var logs: [ManualWorkoutLog] = []

    private let storageKey = "ManualWorkoutLogs"

    private init() {
        load()
    }

    func logWorkout(
        name: String = "Manual workout",
        durationMinutes: Double = 30,
        completedAt: Date = Date()
    ) async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let log = ManualWorkoutLog(
            name: trimmedName.isEmpty ? "Manual workout" : trimmedName,
            completedAt: completedAt,
            durationMinutes: max(durationMinutes, 1)
        )

        logs.insert(log, at: 0)
        sortAndSave()

        _ = await HealthKitService.shared.refreshTodayIfConnected(
            stepGoal: FitnessPlanService.shared.currentPlan?.stepGoal ?? 10_000,
            gymVisits: GymLocationService.shared.todaysVisits()
        )
        await CoachNotificationService.shared.rescheduleNotifications()
    }

    func clearLocalWorkouts() {
        logs = []
        save()
    }

    func todaysLogs(now: Date = Date(), calendar: Calendar = .current) -> [ManualWorkoutLog] {
        Self.logs(on: now, from: logs, calendar: calendar)
    }

    func rollup(for date: Date, calendar: Calendar = .current) -> ManualWorkoutDailyRollup {
        Self.rollup(for: date, from: logs, calendar: calendar)
    }

    nonisolated static func logs(
        on date: Date,
        from logs: [ManualWorkoutLog],
        calendar: Calendar = .current
    ) -> [ManualWorkoutLog] {
        logs
            .filter { calendar.isDate($0.completedAt, inSameDayAs: date) }
            .sorted { $0.completedAt > $1.completedAt }
    }

    nonisolated static func rollup(
        for date: Date,
        from logs: [ManualWorkoutLog],
        calendar: Calendar = .current
    ) -> ManualWorkoutDailyRollup {
        let dailyLogs = Self.logs(on: date, from: logs, calendar: calendar)
        return ManualWorkoutDailyRollup(
            count: dailyLogs.count,
            minutes: dailyLogs.reduce(0) { $0 + max($1.durationMinutes, 0) }
        )
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([ManualWorkoutLog].self, from: data) else {
            logs = []
            return
        }

        logs = decoded.sorted { $0.completedAt > $1.completedAt }
    }

    private func sortAndSave() {
        logs.sort { $0.completedAt > $1.completedAt }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(logs) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

import SwiftUI
import UIKit
import UserNotifications

struct NotificationSettingsView: View {
    @Environment(\.openURL) private var openURL

    @ObservedObject private var notificationService = CoachNotificationService.shared
    @State private var settings = CoachNotificationSettings.defaults

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: authorizationIcon)
                            .foregroundColor(authorizationColor)

                        Text(authorizationTitle)
                            .font(.headline)
                    }

                    Text(authorizationMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if canRequestNotificationAuthorization {
                        Button {
                            Task {
                                await notificationService.requestAuthorizationAndSchedule()
                            }
                        } label: {
                            Label("Enable Coach Reminders", systemImage: "bell.badge.fill")
                        }
                    }

                    if notificationService.authorizationStatus == .denied {
                        Button {
                            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                openURL(settingsURL)
                            }
                        } label: {
                            Label("Open iPhone Settings", systemImage: "gearshape.fill")
                        }
                    }
                }
            }

            Section("Reminders") {
                Toggle("Workout Accountability", isOn: boolBinding(\.dailyWorkoutReminder))
                Toggle("Meal Time Reminders", isOn: boolBinding(\.mealReminders))
                Toggle("Weekly Damage Reports", isOn: boolBinding(\.weeklyReports))
                Toggle("Peptide Log Reminders", isOn: boolBinding(\.peptideReminders))
                Toggle("Friend Challenges", isOn: boolBinding(\.socialNotifications))

                Text("Workout Accountability includes 40-minute movement nudges during active hours, late-day step goal checks, and gym receipt reminders when no workout or gym check-in is logged.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Workout") {
                DatePicker(
                    "Daily Reminder",
                    selection: timeBinding(\.workoutTime),
                    displayedComponents: .hourAndMinute
                )
                .disabled(!settings.dailyWorkoutReminder)
            }

            Section("Meal Timing") {
                DatePicker(
                    "Breakfast",
                    selection: timeBinding(\.breakfastTime),
                    displayedComponents: .hourAndMinute
                )
                .disabled(!settings.mealReminders)

                DatePicker(
                    "Lunch",
                    selection: timeBinding(\.lunchTime),
                    displayedComponents: .hourAndMinute
                )
                .disabled(!settings.mealReminders)

                DatePicker(
                    "Dinner",
                    selection: timeBinding(\.dinnerTime),
                    displayedComponents: .hourAndMinute
                )
                .disabled(!settings.mealReminders)
            }

            Section("Tone") {
                Text("Coach reminders run locally. Friend requests and verified challenge results use push notifications; no workout video or body-pose data leaves your device.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(MFTTheme.background)
        .navigationTitle("Notifications")
        .tint(MFTTheme.accent)
        .task {
            settings = notificationService.settings
            await notificationService.refreshAuthorizationStatus()
            await notificationService.refreshFromServer()
            settings = notificationService.settings
            await notificationService.rescheduleNotifications()
        }
    }

    private var authorizationTitle: String {
        switch notificationService.authorizationStatus {
        case .authorized, .provisional:
            return "Coach reminders are enabled"
        case .denied:
            return "Notifications are off"
        case .notDetermined:
            return "Coach reminders are not enabled yet"
        case .ephemeral:
            return "Temporary reminders are enabled"
        @unknown default:
            return "Notification status unknown"
        }
    }

    private var authorizationMessage: String {
        switch notificationService.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "The coach can send movement, step, gym, meal, peptide log, and weekly accountability reminders on this device."
        case .denied:
            return "Open iOS Settings to allow notifications if you want the coach to interrupt your excuses."
        case .notDetermined:
            return "Enable reminders if you want the app to nudge you before missed meals and skipped workouts become a personality trait."
        @unknown default:
            return "The app could not confirm whether reminders are available."
        }
    }

    private var canRequestNotificationAuthorization: Bool {
        switch notificationService.authorizationStatus {
        case .notDetermined, .ephemeral:
            return true
        default:
            return false
        }
    }

    private var authorizationIcon: String {
        switch notificationService.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return "bell.badge.fill"
        case .denied: return "bell.slash.fill"
        case .notDetermined: return "bell.fill"
        @unknown default: return "questionmark.circle.fill"
        }
    }

    private var authorizationColor: Color {
        switch notificationService.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return .green
        case .denied: return .red
        case .notDetermined: return .orange
        @unknown default: return .secondary
        }
    }

    private func boolBinding(_ keyPath: WritableKeyPath<CoachNotificationSettings, Bool>) -> Binding<Bool> {
        Binding {
            settings[keyPath: keyPath]
        } set: { newValue in
            settings[keyPath: keyPath] = newValue
            notificationService.updateSettings(settings)
        }
    }

    private func timeBinding(_ keyPath: WritableKeyPath<CoachNotificationSettings, DateComponents>) -> Binding<Date> {
        Binding {
            settings[keyPath: keyPath].timeDate
        } set: { newValue in
            settings[keyPath: keyPath] = DateComponents(timeDate: newValue)
            notificationService.updateSettings(settings)
        }
    }
}

struct DataExportView: View {
    @ObservedObject private var planService = FitnessPlanService.shared
    @ObservedObject private var healthService = HealthKitService.shared
    @ObservedObject private var gymService = GymLocationService.shared
    @ObservedObject private var peptideStore = PeptideLogStore.shared
    @ObservedObject private var coachService = CoachMessageService.shared

    @State private var startDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var exportURL: URL?
    @State private var exportMessage: String?
    @State private var exportError: String?
    @State private var isExporting = false

    var body: some View {
        List {
            Section("Export Options") {
                Button {
                    Task {
                        await exportCSV()
                    }
                } label: {
                    Label("Export Food Log CSV", systemImage: "tablecells")
                }
                .disabled(isExporting)

                Button {
                    Task {
                        await exportSummaryReport()
                    }
                } label: {
                    Label("Export Full Summary Report", systemImage: "doc.text")
                }
                .disabled(isExporting)

                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("Share Last Export", systemImage: "square.and.arrow.up")
                    }
                }

                if isExporting {
                    ProgressView("Building export...")
                }
            }

            Section("Data Range") {
                DatePicker("From", selection: $startDate, displayedComponents: .date)
                DatePicker("To", selection: $endDate, displayedComponents: .date)
            }

            if let exportMessage {
                Section("Ready") {
                    Text(exportMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let exportError {
                Section("Export Problem") {
                    Text(exportError)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(MFTTheme.background)
        .navigationTitle("Data Export")
        .tint(MFTTheme.accent)
    }

    private func exportCSV() async {
        await buildExport(extension: "csv", contentType: "food-log") { entries in
            csv(for: entries)
        }
    }

    private func exportSummaryReport() async {
        isExporting = true
        exportError = nil
        exportMessage = nil
        defer { isExporting = false }

        do {
            let range = try normalizedRange()
            await refreshFeatureDataForExport()
            let entries = try await mealEntries(from: range.start, to: range.end)
            let peptides = peptideStore.logs(in: range)
            let visits = gymService.visits(in: range)
            let content = summaryReport(
                for: entries,
                peptides: peptides,
                gymVisits: visits,
                activitySummary: healthService.lastSummary,
                plan: planService.currentPlan,
                coachSettings: coachService.settings,
                range: range
            )
            try writeExport(
                extension: "txt",
                contentType: "full-summary-report",
                content: content
            )
            exportMessage = "\(entries.count) food log\(entries.count == 1 ? "" : "s"), \(peptides.count) peptide log\(peptides.count == 1 ? "" : "s"), and \(visits.count) gym visit\(visits.count == 1 ? "" : "s") exported."
        } catch {
            exportURL = nil
            exportError = error.localizedDescription
        }
    }

    private func buildExport(
        extension fileExtension: String,
        contentType: String,
        makeContent: ([MealEntry]) -> String
    ) async {
        isExporting = true
        exportError = nil
        exportMessage = nil
        defer { isExporting = false }

        do {
            let range = try normalizedRange()
            let entries = try await mealEntries(from: range.start, to: range.end)
            let content = makeContent(entries)
            try writeExport(extension: fileExtension, contentType: contentType, content: content)
            exportMessage = "\(entries.count) food log\(entries.count == 1 ? "" : "s") exported. Use Share Last Export to send or save it."
        } catch {
            exportURL = nil
            exportError = error.localizedDescription
        }
    }

    private func normalizedRange() throws -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        guard let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) else {
            throw DataExportError.invalidDateRange
        }

        guard start < end else {
            throw DataExportError.invalidDateRange
        }

        return (start, end)
    }

    private func refreshFeatureDataForExport() async {
        guard SupabaseService.shared.isAuthenticated else {
            return
        }

        await planService.refreshFromServer()
        await gymService.refreshFromServer()
        await peptideStore.refreshFromServer()
        await coachService.refreshFromServer()
        _ = await healthService.refreshTodayIfConnected(
            stepGoal: planService.currentPlan?.stepGoal ?? 10_000,
            gymVisits: gymService.todaysVisits()
        )
    }

    private func mealEntries(from start: Date, to end: Date) async throws -> [MealEntry] {
        if SupabaseService.shared.isAuthenticated {
            return try await FoodService.shared.getMealEntriesForDateRange(from: start, to: end)
        }

        return FoodService.shared.getAllFoodsOffline()
            .filter { food in
                food.dateLogged >= start && food.dateLogged < end
            }
            .sorted { $0.dateLogged < $1.dateLogged }
            .map { MealEntry.from(food: $0, mealType: .snack) }
    }

    private func writeExport(
        extension fileExtension: String,
        contentType: String,
        content: String
    ) throws {
        let filename = "my-fatness-tracker-\(contentType)-\(Self.fileDateFormatter.string(from: Date())).\(fileExtension)"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try content.write(to: url, atomically: true, encoding: .utf8)
        exportURL = url
    }

    private func csv(for entries: [MealEntry]) -> String {
        let header = [
            "Date",
            "Time",
            "Meal Type",
            "Food",
            "Serving",
            "Quantity",
            "Calories",
            "Protein",
            "Carbs",
            "Fat",
            "Notes"
        ].joined(separator: ",")

        let rows = entries.map { entry in
            [
                Self.dayFormatter.string(from: entry.consumed_at),
                Self.timeFormatter.string(from: entry.consumed_at),
                entry.meal_type.displayName,
                entry.food_name,
                entry.serving_size,
                Self.numberFormatter.string(from: NSNumber(value: entry.serving_quantity)) ?? "\(entry.serving_quantity)",
                Self.numberFormatter.string(from: NSNumber(value: entry.totalCalories)) ?? "\(entry.totalCalories)",
                Self.numberFormatter.string(from: NSNumber(value: entry.totalProtein)) ?? "\(entry.totalProtein)",
                Self.numberFormatter.string(from: NSNumber(value: entry.totalCarbohydrates)) ?? "\(entry.totalCarbohydrates)",
                Self.numberFormatter.string(from: NSNumber(value: entry.totalFat)) ?? "\(entry.totalFat)",
                entry.notes ?? ""
            ]
            .map(Self.csvEscaped)
            .joined(separator: ",")
        }

        return ([header] + rows).joined(separator: "\n")
    }

    private func summaryReport(
        for entries: [MealEntry],
        peptides: [PeptideLog],
        gymVisits: [GymVisit],
        activitySummary: ActivityDailySummary,
        plan: FitnessPlan?,
        coachSettings: CoachToneSettings,
        range: (start: Date, end: Date)
    ) -> String {
        let calories = entries.reduce(0) { $0 + $1.totalCalories }
        let protein = entries.reduce(0) { $0 + $1.totalProtein }
        let carbs = entries.reduce(0) { $0 + $1.totalCarbohydrates }
        let fat = entries.reduce(0) { $0 + $1.totalFat }
        let days = max(Calendar.current.dateComponents([.day], from: range.start, to: range.end).day ?? 1, 1)

        return """
        My Fatness Tracker Export
        Generated: \(Self.reportDateFormatter.string(from: Date()))
        Range: \(Self.dayFormatter.string(from: range.start)) through \(Self.dayFormatter.string(from: range.end.addingTimeInterval(-1)))

        Nutrition
        Food logs: \(entries.count)
        Total calories: \(Self.wholeNumber(calories))
        Average calories/day: \(Self.wholeNumber(calories / Double(days)))
        Protein: \(Self.wholeNumber(protein)) g
        Carbs: \(Self.wholeNumber(carbs)) g
        Fat: \(Self.wholeNumber(fat)) g

        Current Plan
        \(Self.planSummary(plan))

        Activity
        Steps today: \(activitySummary.steps) / \(activitySummary.stepGoal)
        Exercise today: \(Self.wholeNumber(activitySummary.exerciseMinutes)) min
        Active energy today: \(Self.wholeNumber(activitySummary.activeEnergyCalories)) cal
        Workouts today: \(activitySummary.workoutCount)
        Gym visits in range: \(gymVisits.count)
        \(Self.gymVisitSummary(gymVisits))

        Peptide / GLP Logbook
        Logs in range: \(peptides.count)
        \(Self.peptideSummary(peptides))

        Coach
        Enabled: \(coachSettings.enabled ? "Yes" : "No")
        Tone: \(coachSettings.severity.rawValue)
        Explicit body-shame copy: \(coachSettings.allowExplicitBodyShame ? "Allowed" : "Disabled")

        This export is generated on device from your logged data. It is not medical advice, dosing guidance, sourcing guidance, or treatment guidance. It is just the receipts.
        """
    }

    private static func planSummary(_ plan: FitnessPlan?) -> String {
        guard let plan else {
            return "No active meal/workout plan found."
        }

        return """
        Goal: \(plan.goal.rawValue)
        Calories: \(wholeNumber(plan.calorieTarget))
        Protein: \(wholeNumber(plan.proteinGoal)) g
        Carbs: \(wholeNumber(plan.carbsGoal)) g
        Fat: \(wholeNumber(plan.fatGoal)) g
        Steps: \(plan.stepGoal)
        Training days/week: \(plan.trainingDaysPerWeek)
        Meals in rotation: \(plan.meals.count)
        Workout days: \(plan.workouts.count)
        Coach note: \(plan.coachNote)
        """
    }

    private static func gymVisitSummary(_ visits: [GymVisit]) -> String {
        guard !visits.isEmpty else {
            return "No gym visits found in this range."
        }

        return visits
            .sorted { $0.arrivedAt > $1.arrivedAt }
            .prefix(10)
            .map { visit in
                "- \(dayFormatter.string(from: visit.arrivedAt)) \(timeFormatter.string(from: visit.arrivedAt)): \(visit.gymName) (\(visit.source.rawValue))"
            }
            .joined(separator: "\n")
    }

    private static func peptideSummary(_ logs: [PeptideLog]) -> String {
        guard !logs.isEmpty else {
            return "No peptide/GLP logbook entries found in this range."
        }

        return logs
            .sorted { $0.loggedAt > $1.loggedAt }
            .prefix(10)
            .map { log in
                let schedule = log.scheduledAt.map { ", planned \(dayFormatter.string(from: $0))" } ?? ""
                let site = log.site.isEmpty ? "" : ", site/note \(log.site)"
                return "- \(dayFormatter.string(from: log.loggedAt)): \(log.peptideName) (\(log.status.title.lowercased())\(schedule)), vial \(wholeNumber(log.vialAmountMg)) mg, BAC \(wholeNumber(log.bacWaterMl)) mL, label amount \(wholeNumber(log.labelAmountMcg)) mcg, draw \(wholeNumber(log.drawVolumeMl)) mL / \(wholeNumber(log.syringeUnits)) units\(site)"
            }
            .joined(separator: "\n")
    }

    private static func csvEscaped(_ value: String) -> String {
        let cleaned = value.replacingOccurrences(of: "\n", with: " ")
        guard cleaned.contains(",") || cleaned.contains("\"") else {
            return cleaned
        }
        return "\"\(cleaned.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func wholeNumber(_ value: Double) -> String {
        numberFormatter.string(from: NSNumber(value: value)) ?? "\(Int(value.rounded()))"
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private static let fileDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    private static let reportDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        return formatter
    }()
}

private enum DataExportError: LocalizedError {
    case invalidDateRange

    var errorDescription: String? {
        switch self {
        case .invalidDateRange:
            return "Choose a valid export range with the start date before the end date."
        }
    }
}

private extension PeptideLogStore {
    func logs(in range: (start: Date, end: Date)) -> [PeptideLog] {
        logs.filter { log in
            log.loggedAt >= range.start && log.loggedAt < range.end
        }
    }
}

private extension GymLocationService {
    func visits(in range: (start: Date, end: Date)) -> [GymVisit] {
        visits.filter { visit in
            visit.arrivedAt >= range.start && visit.arrivedAt < range.end
        }
    }
}

struct AboutView: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        List {
            Section("App Information") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(version)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Build")
                    Spacer()
                    Text(build)
                        .foregroundColor(.secondary)
                }
            }

            Section("Support") {
                Text("Privacy, terms, and support links are managed from the App Store listing.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Credits") {
                Text("My Fatness Tracker uses AI-assisted food logging, Health activity data, and local planning tools to keep the plan harder to ignore.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(MFTTheme.background)
        .navigationTitle("About")
        .tint(MFTTheme.accent)
    }
}

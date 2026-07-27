import Foundation
import HealthKit

@MainActor
final class HealthKitService: ObservableObject {
    static let shared = HealthKitService()

    @Published private(set) var isAuthorized = false
    @Published private(set) var hasRequestedAuthorization = false
    @Published private(set) var lastSummary: ActivityDailySummary = .emptyToday
    @Published private(set) var lastStepMovementAt: Date?
    @Published private(set) var lastRefreshErrorMessage: String?
    @Published private(set) var lastRefreshAt: Date?

    private let healthStore = HKHealthStore()
    private let supabaseService = SupabaseService.shared
    private let authorizationRequestedKey = "HealthKitAuthorizationRequested"
    private let lastStepCountKey = "HealthKitLastObservedStepCount"
    private let lastStepCountDateKey = "HealthKitLastObservedStepDate"
    private let lastStepMovementAtKey = "HealthKitLastStepMovementAt"
    private var observerQueries: [HKObserverQuery] = []

    private init() {
        hasRequestedAuthorization = UserDefaults.standard.bool(forKey: authorizationRequestedKey)
        isAuthorized = hasRequestedAuthorization && HKHealthStore.isHealthDataAvailable()
        lastStepMovementAt = UserDefaults.standard.object(forKey: lastStepMovementAtKey) as? Date
    }

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async throws {
        guard isHealthDataAvailable else {
            throw HealthKitServiceError.notAvailable
        }

        let readTypes = Set([
            HKObjectType.quantityType(forIdentifier: .stepCount),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime),
            HKObjectType.workoutType()
        ].compactMap { $0 })

        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
        hasRequestedAuthorization = true
        UserDefaults.standard.set(true, forKey: authorizationRequestedKey)
        isAuthorized = true
        lastRefreshErrorMessage = nil
        startObservingActivityChanges()
    }

    func refreshTodayIfConnected(stepGoal: Int = 10_000, gymVisits: [GymVisit] = []) async -> ActivityDailySummary? {
        guard hasRequestedAuthorization else {
            return nil
        }

        return await fetchTodaySummary(stepGoal: stepGoal, gymVisits: gymVisits)
    }

    func clearLocalSummary() {
        lastSummary = .emptyToday
        lastStepMovementAt = nil
        UserDefaults.standard.removeObject(forKey: lastStepCountKey)
        UserDefaults.standard.removeObject(forKey: lastStepCountDateKey)
        UserDefaults.standard.removeObject(forKey: lastStepMovementAtKey)
        stopObservingActivityChanges()
    }

    func startObservingActivityChanges() {
        guard hasRequestedAuthorization, isHealthDataAvailable else {
            stopObservingActivityChanges()
            return
        }

        guard observerQueries.isEmpty else {
            return
        }

        for sampleType in observedSampleTypes {
            let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] _, completionHandler, error in
                Task { @MainActor in
                    defer { completionHandler() }

                    guard let self else { return }

                    if let error {
                        #if DEBUG
                        print("HealthKit observer update failed: \(error)")
                        #endif
                        return
                    }

                    await self.refreshCurrentPlanSummaryFromHealth()
                }
            }

            healthStore.execute(query)
            observerQueries.append(query)
            enableBackgroundDelivery(for: sampleType)
        }
    }

    func stopObservingActivityChanges() {
        observerQueries.forEach { healthStore.stop($0) }
        observerQueries.removeAll()
    }

    func fetchTodaySummary(stepGoal: Int = 10_000, gymVisits: [GymVisit] = []) async -> ActivityDailySummary {
        guard isHealthDataAvailable else {
            let summary = ActivityDailySummary.emptyToday(stepGoal: stepGoal, gymVisits: gymVisits)
            lastRefreshErrorMessage = HealthKitServiceError.notAvailable.localizedDescription
            lastRefreshAt = Date()
            lastSummary = summary
            return summary
        }

        let startOfDay = Calendar.current.startOfDay(for: Date())
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()

        async let steps = quantitySum(
            identifier: .stepCount,
            unit: .count(),
            start: startOfDay,
            end: endOfDay
        )
        async let activeEnergy = quantitySum(
            identifier: .activeEnergyBurned,
            unit: .kilocalorie(),
            start: startOfDay,
            end: endOfDay
        )
        async let exerciseMinutes = quantitySum(
            identifier: .appleExerciseTime,
            unit: .minute(),
            start: startOfDay,
            end: endOfDay
        )
        async let workoutCount = workoutCount(start: startOfDay, end: endOfDay)

        let manualWorkoutRollup = ManualWorkoutStore.shared.rollup(for: startOfDay)
        let movementRollup = MovementChallengeStore.shared.rollup(for: startOfDay)
        var readProblems: [String] = []
        let stepCount: Double
        do {
            stepCount = try await steps
        } catch {
            readProblems.append("steps")
            stepCount = 0
        }

        let activeEnergyCalories: Double
        do {
            activeEnergyCalories = try await activeEnergy
        } catch {
            readProblems.append("active energy")
            activeEnergyCalories = 0
        }

        let exerciseMinutesValue: Double
        do {
            exerciseMinutesValue = try await exerciseMinutes
        } catch {
            readProblems.append("exercise minutes")
            exerciseMinutesValue = 0
        }

        let workoutCountValue: Int
        do {
            workoutCountValue = try await workoutCount
        } catch {
            readProblems.append("workouts")
            workoutCountValue = 0
        }

        let summary = ActivityDailySummary(
            date: startOfDay,
            steps: Int(stepCount),
            stepGoal: stepGoal,
            activeEnergyCalories: activeEnergyCalories,
            exerciseMinutes: exerciseMinutesValue + manualWorkoutRollup.minutes + movementRollup.durationMinutes,
            workoutCount: workoutCountValue + manualWorkoutRollup.count + movementRollup.sessionCount,
            gymVisits: gymVisits
        )

        lastRefreshErrorMessage = Self.refreshProblemMessage(for: readProblems)
        lastRefreshAt = Date()
        updateLastStepMovement(using: summary)
        lastSummary = summary
        Task {
            await syncSummary(summary)
            await CoachNotificationService.shared.rescheduleNotifications()
        }
        return summary
    }

    nonisolated static func refreshProblemMessage(for problems: [String]) -> String? {
        guard !problems.isEmpty else { return nil }
        let uniqueProblems = Array(Set(problems)).sorted()
        let joinedProblems: String
        if uniqueProblems.count == 1 {
            joinedProblems = uniqueProblems[0]
        } else {
            joinedProblems = uniqueProblems.dropLast().joined(separator: ", ") + ", and " + uniqueProblems.last!
        }

        return "Health read problem: the app could not read \(joinedProblems). Open Health and confirm My Fatness Tracker is allowed to read activity data."
    }

    private func syncSummary(_ summary: ActivityDailySummary) async {
        guard supabaseService.isAuthenticated else {
            return
        }

        do {
            let savedSummary = try await supabaseService.saveActivitySummary(summary)
            lastSummary = savedSummary
        } catch {
            #if DEBUG
            print("Activity summary sync failed: \(error)")
            #endif
        }
    }

    private var observedSampleTypes: [HKSampleType] {
        [
            HKObjectType.quantityType(forIdentifier: .stepCount),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime),
            HKObjectType.workoutType()
        ].compactMap { $0 }
    }

    private func enableBackgroundDelivery(for sampleType: HKSampleType) {
        healthStore.enableBackgroundDelivery(for: sampleType, frequency: .immediate) { success, error in
            #if DEBUG
            if let error {
                print("HealthKit background delivery failed: \(error)")
            } else if !success {
                print("HealthKit background delivery was not enabled for \(sampleType.identifier)")
            }
            #endif
        }
    }

    private func refreshCurrentPlanSummaryFromHealth() async {
        let stepGoal = FitnessPlanService.shared.currentPlan?.stepGoal ?? 10_000
        let gymVisits = GymLocationService.shared.todaysVisits()
        _ = await refreshTodayIfConnected(stepGoal: stepGoal, gymVisits: gymVisits)
    }

    private func updateLastStepMovement(using summary: ActivityDailySummary, now: Date = Date()) {
        let snapshot = StepMovementTracker.updatedSnapshot(
            for: summary,
            previous: StepMovementSnapshot(
                lastStepCount: UserDefaults.standard.integer(forKey: lastStepCountKey),
                lastStepCountDate: UserDefaults.standard.object(forKey: lastStepCountDateKey) as? Date,
                lastMovementAt: UserDefaults.standard.object(forKey: lastStepMovementAtKey) as? Date
            ),
            now: now
        )

        lastStepMovementAt = snapshot.lastMovementAt
        UserDefaults.standard.set(snapshot.lastStepCount, forKey: lastStepCountKey)
        UserDefaults.standard.set(snapshot.lastStepCountDate, forKey: lastStepCountDateKey)
        UserDefaults.standard.set(snapshot.lastMovementAt, forKey: lastStepMovementAtKey)
    }

    private func quantitySum(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date
    ) async throws -> Double {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return 0
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [.strictStartDate])

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: [.cumulativeSum]
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let value = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }

            healthStore.execute(query)
        }
    }

    private func workoutCount(start: Date, end: Date) async throws -> Int {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [.strictStartDate])

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: samples?.count ?? 0)
            }

            healthStore.execute(query)
        }
    }
}

enum HealthKitServiceError: LocalizedError {
    case notAvailable

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Health data is not available on this device."
        }
    }
}

import Foundation

@MainActor
final class AppFeatureSyncService: ObservableObject {
    static let shared = AppFeatureSyncService()

    @Published private(set) var isSyncing = false

    private let supabaseService = SupabaseService.shared
    private let coachMessageService = CoachMessageService.shared
    private let notificationService = CoachNotificationService.shared
    private let fitnessPlanService = FitnessPlanService.shared
    private let gymLocationService = GymLocationService.shared
    private let healthKitService = HealthKitService.shared
    private let manualWorkoutStore = ManualWorkoutStore.shared
    private let movementChallengeStore = MovementChallengeStore.shared
    private let peptideLogStore = PeptideLogStore.shared
    private let userService = UserService.shared
    private let foodService = FoodService.shared

    private var lastSyncedUserId: UUID?
    private let lastAuthenticatedUserIdKey = "LastAuthenticatedSupabaseUserId"

    private init() {}

    func syncForCurrentAuthState(force: Bool = false) async {
        await notificationService.refreshAuthorizationStatus()

        guard supabaseService.isAuthenticated, let userId = supabaseService.currentUser?.id else {
            if lastSyncedUserId != nil || storedAuthenticatedUserId() != nil {
                await clearAccountScopedLocalData()
                UserDefaults.standard.removeObject(forKey: lastAuthenticatedUserIdKey)
            }

            lastSyncedUserId = nil
            await notificationService.rescheduleNotifications()
            return
        }

        if let storedUserId = storedAuthenticatedUserId(), storedUserId != userId {
            await clearAccountScopedLocalData()
        }

        guard force || lastSyncedUserId != userId else {
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        await coachMessageService.refreshFromServer()
        await notificationService.refreshFromServer()
        await fitnessPlanService.refreshFromServer()
        await gymLocationService.refreshFromServer()
        await movementChallengeStore.refreshFromServer()
        healthKitService.startObservingActivityChanges()
        _ = await healthKitService.refreshTodayIfConnected(
            stepGoal: fitnessPlanService.currentPlan?.stepGoal ?? 10_000,
            gymVisits: gymLocationService.todaysVisits()
        )
        await peptideLogStore.refreshFromServer()
        await notificationService.rescheduleNotifications()

        lastSyncedUserId = userId
        UserDefaults.standard.set(userId.uuidString, forKey: lastAuthenticatedUserIdKey)
    }

    private func storedAuthenticatedUserId() -> UUID? {
        guard let storedValue = UserDefaults.standard.string(forKey: lastAuthenticatedUserIdKey) else {
            return nil
        }

        return UUID(uuidString: storedValue)
    }

    private func clearAccountScopedLocalData() async {
        userService.resetUserDataSync()
        foodService.deleteAllFoodsOffline()
        fitnessPlanService.clearPlan()
        gymLocationService.clearLocalData()
        healthKitService.clearLocalSummary()
        manualWorkoutStore.clearLocalWorkouts()
        movementChallengeStore.clearLocalSessions()
        peptideLogStore.clearLocalLogs()
        coachMessageService.resetLocalSettings()
        await notificationService.resetLocalSettings()
    }
}
